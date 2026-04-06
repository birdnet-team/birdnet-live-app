// =============================================================================
// Geomodel and Soundscape Integration Test
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:birdnet_live/features/inference/classifier_model.dart';
import 'package:birdnet_live/features/inference/geo_model.dart';
import 'package:birdnet_live/features/inference/label_parser.dart';
import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/inference/post_processor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ModelConfig config;
  late ClassifierModel audioModel;
  late GeoModel geoModel;
  late List<Species> audioLabels;

  setUpAll(() async {
    // --- Load model config ---
    final configJson =
        await rootBundle.loadString('assets/models/model_config.json');
    final Map<String, dynamic> configMap = jsonDecode(configJson);
    config =
        ModelConfig.fromJson(configMap['audioModel'] as Map<String, dynamic>);

    // --- Load audio labels ---
    final audioLabelsCsv =
        await rootBundle.loadString('assets/models/${config.labels.file}');
    audioLabels = LabelParser.parse(audioLabelsCsv, config: config.labels);

    // --- Load Audio Model ---
    audioModel = ClassifierModel();
    final audioModelData =
        await rootBundle.load('assets/models/${config.onnx.modelFile}');
    final audioModelBytes = audioModelData.buffer.asUint8List(
        audioModelData.offsetInBytes, audioModelData.lengthInBytes);
    await audioModel.loadModel(
      audioModelBytes,
      inputName: config.onnx.inputName,
      predictionsName: config.onnx.predictionsName,
      embeddingsName: config.onnx.embeddingsName,
    );

    // --- Load Geo Model ---
    geoModel = GeoModel();

    // Parse geomodel config details
    final geoMap = configMap['geoModel'] as Map<String, dynamic>;
    final geoModelFile = geoMap['modelFile'] as String;
    final geoLabelsFile = geoMap['labelsFile'] as String;
    final geoInputName = geoMap['inputName'] as String;
    final geoOutputName = geoMap['outputName'] as String;

    final geoLabelsTxt =
        await rootBundle.loadString('assets/models/$geoLabelsFile');
    geoModel.loadLabels(geoLabelsTxt);

    final geoModelData = await rootBundle.load('assets/models/$geoModelFile');

    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/geo_model_test.onnx');
    await tempFile.writeAsBytes(geoModelData.buffer
        .asUint8List(geoModelData.offsetInBytes, geoModelData.lengthInBytes));

    await geoModel.loadModel(
      tempFile.path,
      inputName: geoInputName,
      outputName: geoOutputName,
    );
  });

  tearDownAll(() {
    audioModel.dispose();
    geoModel.dispose();
  });

  testWidgets('Geo-model inference (Berlin, week 26) yields sensible results',
      (tester) async {
    // Berlin: 52.52°N, 13.40°E
    final probabilities = geoModel.predict(
      latitude: 52.52,
      longitude: 13.40,
      week: 26,
    );

    // Sort to get top species
    final sortedEntries = probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    print('--- Berlin week 26 top species ---');
    for (var i = 0; i < 10 && i < sortedEntries.length; i++) {
      print(
          '${sortedEntries[i].key}: ${sortedEntries[i].value.toStringAsFixed(3)}');
    }

    expect(sortedEntries.isNotEmpty, isTrue,
        reason: 'Geo model should return species probabilities');

    // Confirms it's working logically if it returns at least a handful of common species with > 0.01 prob
    final hasHighProb = sortedEntries.any((e) => e.value > 0.01);
    expect(hasHighProb, isTrue,
        reason:
            'Some species should be highly probable in Berlin during summer');
  });

  testWidgets(
      'Audio classifier on soundscape_32k.raw detects birds (Blue Jay, House Finch)',
      (tester) async {
    // Read raw 32kHz audio from test fixtures on device storage.
    // Push before running: adb push assets/test_fixtures /data/local/tmp/test_fixtures
    final fixtureFile =
        File('/data/local/tmp/test_fixtures/soundscape_32k.raw');
    expect(fixtureFile.existsSync(), isTrue,
        reason:
            'Run: adb push assets/test_fixtures /data/local/tmp/test_fixtures');
    final bytes = await fixtureFile.readAsBytes();
    final audioSamples = bytes.buffer.asFloat32List();

    final sampleRate = config.audio.sampleRate;
    final windowDuration = 3;
    final windowSamples = sampleRate * windowDuration;

    print('--- Soundscape Detections ---');

    bool foundBlueJay = false;
    bool foundHouseFinch = false;

    // Track the globally highest score to diagnose near-zero model outputs.
    double globalMaxScore = 0.0;
    String globalTopSpecies = '';

    // Run inference on 3-second chunks (non-overlapping)
    for (var i = 0;
        i < audioSamples.length - windowSamples;
        i += windowSamples) {
      final chunk = Float32List.sublistView(audioSamples, i, i + windowSamples);

      final output =
          await audioModel.predict(chunk, windowSamples: windowSamples);

      // Track global max for diagnostics.
      for (var j = 0; j < output.predictions.length; j++) {
        if (output.predictions[j] > globalMaxScore) {
          globalMaxScore = output.predictions[j];
          globalTopSpecies = audioLabels[j].commonName;
        }
      }

      final detections = PostProcessor.topK(
        scores: output.predictions,
        labels: audioLabels,
        k: 5,
        threshold: 0.1, // fairly low to catch them in the test
      );

      if (detections.isNotEmpty) {
        final startSec = i / sampleRate;
        final endSec = (i + windowSamples) / sampleRate;
        final detStrs = detections
            .map((d) =>
                '${d.species.commonName}=${d.confidence.toStringAsFixed(3)}')
            .join(', ');
        print(
            '[${startSec.toStringAsFixed(1)}s - ${endSec.toStringAsFixed(1)}s] $detStrs');

        for (final d in detections) {
          final commonName = d.species.commonName.toLowerCase();
          if (commonName.contains('blue jay')) foundBlueJay = true;
          if (commonName.contains('house finch')) foundHouseFinch = true;
        }
      }
    }

    print('Global max score: $globalMaxScore ($globalTopSpecies)');
    print(
        'NOTE: Python reference found 102× House Finch, 42× Blue Jay in this file.');

    expect(globalMaxScore, greaterThan(0.1),
        reason:
            'Audio classifier is producing near-zero scores across the entire soundscape '
            '(max=$globalMaxScore). This indicates a model inference bug — '
            'the Python reference scores above 0.9 for the same audio.\n'
            'Likely cause: opset conversion changed model behaviour.');

    expect(foundBlueJay, isTrue,
        reason: 'Blue Jay should be detected in soundscape');
    expect(foundHouseFinch, isTrue,
        reason: 'House Finch should be detected in soundscape');
  });
}
