// =============================================================================
// Model Config Tests
// =============================================================================
//
// Verifies JSON serialisation/deserialisation of ModelConfig and its nested
// config classes.  Tests cover:
//   - Full round-trip (fromJson → toJson → fromJson)
//   - Default values for optional fields
//   - Real config file parsing (integration test)
//   - Individual nested config classes
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Full config JSON matching the bundled model_config.json ───────────

  final fullJson = <String, dynamic>{
    'name': 'Test Model',
    'version': '1.0.0',
    'description': 'A test classification model',
    'audio': {
      'sampleRate': 44100,
      'channels': 1,
    },
    'onnx': {
      'modelFile': 'test_model.onnx',
      'inputName': 'audio_in',
      'outputNames': {
        'predictions': 'logits',
        'embeddings': 'features',
      },
    },
    'labels': {
      'file': 'species.csv',
      'delimiter': ',',
      'hasHeader': true,
      'columns': {
        'scientificName': 'species',
        'commonName': 'common',
      },
    },
    'inference': {
      'supportedWindowSeconds': [3, 5],
      'defaultWindowSeconds': 5,
      'defaultSensitivity': 1.2,
      'defaultConfidenceThreshold': 0.25,
      'defaultTopK': 5,
      'temporalPooling': {
        'maxWindows': 3,
        'alpha': 4.0,
      },
    },
  };

  group('ModelConfig', () {
    test('fromJson parses all fields', () {
      final config = ModelConfig.fromJson(fullJson);

      expect(config.name, 'Test Model');
      expect(config.version, '1.0.0');
      expect(config.description, 'A test classification model');
    });

    test('toJson round-trips correctly', () {
      final config = ModelConfig.fromJson(fullJson);
      final json = config.toJson();
      final config2 = ModelConfig.fromJson(json);

      expect(config2.name, config.name);
      expect(config2.version, config.version);
      expect(config2.audio.sampleRate, config.audio.sampleRate);
      expect(config2.onnx.modelFile, config.onnx.modelFile);
      expect(config2.onnx.inputName, config.onnx.inputName);
      expect(config2.labels.delimiter, config.labels.delimiter);
      expect(
        config2.inference.defaultWindowSeconds,
        config.inference.defaultWindowSeconds,
      );
      expect(
        config2.inference.temporalPooling.alpha,
        config.inference.temporalPooling.alpha,
      );
    });

    test('optional fields have sensible defaults', () {
      final minimal = <String, dynamic>{
        'name': 'Minimal',
        'audio': {'sampleRate': 16000},
        'onnx': {'modelFile': 'model.onnx'},
        'labels': {'file': 'labels.csv'},
        'inference': <String, dynamic>{},
      };

      final config = ModelConfig.fromJson(minimal);

      expect(config.version, '');
      expect(config.description, '');
      expect(config.audio.channels, 1);
      expect(config.onnx.inputName, 'input');
      expect(config.onnx.predictionsName, 'predictions');
      expect(config.onnx.embeddingsName, isNull);
      expect(config.labels.delimiter, ';');
      expect(config.labels.hasHeader, true);
      expect(config.inference.defaultWindowSeconds, 3);
      expect(config.inference.defaultSensitivity, 1.0);
      expect(config.inference.defaultConfidenceThreshold, 0.15);
      expect(config.inference.defaultTopK, 10);
      expect(config.inference.temporalPooling.maxWindows, 5);
      expect(config.inference.temporalPooling.alpha, 5.0);
    });
  });

  group('AudioConfig', () {
    test('parses sample rate and channels', () {
      final config = AudioConfig.fromJson({'sampleRate': 48000, 'channels': 2});

      expect(config.sampleRate, 48000);
      expect(config.channels, 2);
    });

    test('defaults channels to 1', () {
      final config = AudioConfig.fromJson({'sampleRate': 32000});
      expect(config.channels, 1);
    });
  });

  group('OnnxConfig', () {
    test('parses model file and tensor names', () {
      final config = OnnxConfig.fromJson({
        'modelFile': 'classifier.onnx',
        'inputName': 'waveform',
        'outputNames': {
          'predictions': 'output_0',
          'embeddings': 'output_1',
        },
      });

      expect(config.modelFile, 'classifier.onnx');
      expect(config.inputName, 'waveform');
      expect(config.predictionsName, 'output_0');
      expect(config.embeddingsName, 'output_1');
    });

    test('defaults tensor names to standard values', () {
      final config = OnnxConfig.fromJson({'modelFile': 'model.onnx'});

      expect(config.inputName, 'input');
      expect(config.predictionsName, 'predictions');
      expect(config.embeddingsName, isNull);
    });

    test('embeddingsName is null when not in outputNames', () {
      final config = OnnxConfig.fromJson({
        'modelFile': 'model.onnx',
        'outputNames': {'predictions': 'scores'},
      });

      expect(config.predictionsName, 'scores');
      expect(config.embeddingsName, isNull);
    });
  });

  group('LabelsConfig', () {
    test('parses full labels config', () {
      final config = LabelsConfig.fromJson({
        'file': 'taxa.tsv',
        'delimiter': '\t',
        'hasHeader': false,
        'columns': {
          'scientificName': 'name',
        },
      });

      expect(config.file, 'taxa.tsv');
      expect(config.delimiter, '\t');
      expect(config.hasHeader, false);
      expect(config.columns['scientificName'], 'name');
    });

    test('defaults delimiter and header', () {
      final config = LabelsConfig.fromJson({'file': 'labels.csv'});

      expect(config.delimiter, ';');
      expect(config.hasHeader, true);
    });
  });

  group('InferenceDefaults', () {
    test('parses all inference defaults', () {
      final config = InferenceDefaults.fromJson({
        'supportedWindowSeconds': [1, 2, 3],
        'defaultWindowSeconds': 2,
        'defaultSensitivity': 0.8,
        'defaultConfidenceThreshold': 0.3,
        'defaultTopK': 3,
        'temporalPooling': {
          'maxWindows': 10,
          'alpha': 3.0,
        },
      });

      expect(config.supportedWindowSeconds, [1, 2, 3]);
      expect(config.defaultWindowSeconds, 2);
      expect(config.defaultSensitivity, 0.8);
      expect(config.defaultConfidenceThreshold, 0.3);
      expect(config.defaultTopK, 3);
      expect(config.temporalPooling.maxWindows, 10);
      expect(config.temporalPooling.alpha, 3.0);
    });

    test('defaults all fields when JSON is empty', () {
      final config = InferenceDefaults.fromJson(<String, dynamic>{});

      expect(config.supportedWindowSeconds, [3]);
      expect(config.defaultWindowSeconds, 3);
      expect(config.defaultSensitivity, 1.0);
      expect(config.defaultConfidenceThreshold, 0.15);
      expect(config.defaultTopK, 10);
      expect(config.temporalPooling.maxWindows, 5);
      expect(config.temporalPooling.alpha, 5.0);
    });
  });

  group('TemporalPoolingConfig', () {
    test('parses maxWindows and alpha', () {
      final config =
          TemporalPoolingConfig.fromJson({'maxWindows': 8, 'alpha': 2.5});

      expect(config.maxWindows, 8);
      expect(config.alpha, 2.5);
    });

    test('defaults when empty', () {
      final config = TemporalPoolingConfig.fromJson(<String, dynamic>{});

      expect(config.maxWindows, 5);
      expect(config.alpha, 5.0);
    });
  });

  // ── Real config file (integration-level) ──────────────────────────────

  group('Real model_config.json', () {
    test('parses bundled config file', () {
      final file = File('assets/models/model_config.json');
      if (!file.existsSync()) return; // Skip in CI.

      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final config =
          ModelConfig.fromJson(json['audioModel'] as Map<String, dynamic>);

      expect(config.name, contains('BirdNET'));
      expect(config.audio.sampleRate, 32000);
      expect(config.onnx.modelFile, contains('.onnx'));
      expect(config.onnx.inputName, 'input');
      expect(config.onnx.predictionsName, 'predictions');
      expect(config.onnx.embeddingsName, 'embeddings');
      expect(config.labels.file, contains('Labels.csv'));
      expect(config.labels.delimiter, ';');
      expect(config.inference.supportedWindowSeconds, contains(3));
      expect(config.inference.defaultConfidenceThreshold, 0.15);
    });
  });
}
