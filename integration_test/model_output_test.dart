// =============================================================================
// Model Output Integration Test
// =============================================================================
//
// Validates that the Flutter ONNX inference pipeline produces the same
// detections as the Python reference script (dev/run_onnx_reference.py).
//
// The test loads pre-extracted audio windows and their expected detections
// from test fixtures, runs each window through the real ONNX model on device,
// and compares the output against the Python ground truth.
//
// Run:
//   flutter test integration_test/model_output_test.dart -d <device_id>
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:birdnet_live/features/inference/classifier_model.dart';
import 'package:birdnet_live/features/inference/label_parser.dart';
import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/inference/post_processor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ClassifierModel model;
  late List<Species> labels;
  late ModelConfig config;
  late List<Map<String, dynamic>> fixtureWindows;
  late Float32List allAudioSamples;
  late int windowSamples;
  late double confidenceThreshold;
  late int topK;

  setUpAll(() async {
    // --- Load model config ---
    final configJson = await rootBundle.loadString(
      'assets/models/model_config.json',
    );
    config = ModelConfig.fromJson(
      jsonDecode(configJson) as Map<String, dynamic>,
    );

    // --- Load labels ---
    final labelsCsv = await rootBundle.loadString(
      'assets/models/${config.labels.file}',
    );
    labels = LabelParser.parse(labelsCsv, config: config.labels);

    // --- Load ONNX model ---
    model = ClassifierModel();
    final modelData = await rootBundle.load(
      'assets/models/${config.onnx.modelFile}',
    );
    await model.loadModel(
      modelData.buffer.asUint8List(),
      inputName: config.onnx.inputName,
      predictionsName: config.onnx.predictionsName,
      embeddingsName: config.onnx.embeddingsName,
    );

    // --- Load test fixture metadata ---
    final metaJson = await rootBundle.loadString(
      'assets/test_fixtures/test_windows_meta.json',
    );
    final meta = jsonDecode(metaJson) as Map<String, dynamic>;
    fixtureWindows = (meta['windows'] as List).cast<Map<String, dynamic>>();
    windowSamples = meta['windowSamples'] as int;
    confidenceThreshold = (meta['confidenceThreshold'] as num).toDouble();
    topK = meta['topK'] as int;

    // --- Load test fixture audio (raw Float32LE) ---
    final audioData = await rootBundle.load(
      'assets/test_fixtures/test_windows.bin',
    );
    allAudioSamples = audioData.buffer.asFloat32List();
  });

  tearDownAll(() {
    model.dispose();
  });

  // -------------------------------------------------------------------------
  // Per-window tests
  // -------------------------------------------------------------------------

  testWidgets('Model produces correct detections for all test windows',
      (tester) async {
    // Tolerance for confidence comparison.
    // FP16 model running on different ONNX runtime backends (x86 CPU vs
    // ARM CPU) may produce slightly different results due to FP16→FP32
    // promotion, math library differences, and parallel execution order.
    const confidenceTolerance = 0.05;

    final failures = <String>[];

    for (final window in fixtureWindows) {
      final fixtureIndex = window['fixtureIndex'] as int;
      final windowIndex = window['originalWindowIndex'] as int;
      final startSec = window['startSec'];
      final endSec = window['endSec'];
      final expectedDetections =
          (window['detections'] as List).cast<Map<String, dynamic>>();

      // Extract audio chunk for this window.
      final audioStart = fixtureIndex * windowSamples;
      final audioEnd = audioStart + windowSamples;
      final chunk = Float32List.sublistView(
        allAudioSamples,
        audioStart,
        audioEnd,
      );

      // Run inference.
      final output = await model.predict(
        chunk,
        windowSamples: windowSamples,
      );

      // Post-process: top-K with threshold, no sensitivity scaling.
      final detections = PostProcessor.topK(
        scores: output.predictions,
        labels: labels,
        k: topK,
        threshold: confidenceThreshold,
      );

      // --- Validate detection count ---
      if (detections.length != expectedDetections.length) {
        failures.add(
          'Window $windowIndex ($startSec–${endSec}s): '
          'expected ${expectedDetections.length} detections, '
          'got ${detections.length}\n'
          '  Expected: ${expectedDetections.map((d) => '${d['commonName']}=${(d['confidence'] as num).toStringAsFixed(3)}').join(', ')}\n'
          '  Got:      ${detections.map((d) => '${d.species.commonName}=${d.confidence.toStringAsFixed(3)}').join(', ')}',
        );
        continue;
      }

      // --- Validate each detection ---
      for (var i = 0; i < expectedDetections.length; i++) {
        final expected = expectedDetections[i];
        final actual = detections[i];

        final expectedIndex = expected['speciesIndex'] as int;
        final expectedName = expected['commonName'] as String;
        final expectedConf = (expected['confidence'] as num).toDouble();

        // Check species match by index.
        if (actual.species.index != expectedIndex) {
          failures.add(
            'Window $windowIndex, det $i: '
            'expected species index $expectedIndex ($expectedName), '
            'got ${actual.species.index} (${actual.species.commonName})',
          );
          continue;
        }

        // Check confidence within tolerance.
        final confDiff = (actual.confidence - expectedConf).abs();
        if (confDiff > confidenceTolerance) {
          failures.add(
            'Window $windowIndex, det $i ($expectedName): '
            'confidence ${actual.confidence.toStringAsFixed(4)} '
            'differs from expected ${expectedConf.toStringAsFixed(4)} '
            'by ${confDiff.toStringAsFixed(4)} '
            '(tolerance: $confidenceTolerance)',
          );
        }
      }
    }

    if (failures.isNotEmpty) {
      fail(
        'Model output validation failed:\n\n${failures.join('\n\n')}',
      );
    }
  });

  testWidgets('Model output tensor has expected size', (tester) async {
    // Use the first fixture window.
    final chunk = Float32List.sublistView(
      allAudioSamples,
      0,
      windowSamples,
    );

    final output = await model.predict(
      chunk,
      windowSamples: windowSamples,
    );

    // BirdNET V3 has 11,560 species classes.
    expect(output.predictions.length, equals(labels.length));
    expect(output.predictions.length, equals(11560));

    // Embeddings should be 1,280-dimensional.
    expect(output.embeddings, isNotNull);
    expect(output.embeddings!.length, equals(1280));
  });

  testWidgets('All model output values are valid probabilities',
      (tester) async {
    final chunk = Float32List.sublistView(
      allAudioSamples,
      0,
      windowSamples,
    );

    final output = await model.predict(
      chunk,
      windowSamples: windowSamples,
    );

    for (var i = 0; i < output.predictions.length; i++) {
      final p = output.predictions[i];
      expect(
        p >= 0.0 && p <= 1.0,
        isTrue,
        reason: 'Prediction[$i] = $p is outside [0, 1]',
      );
    }
  });

  testWidgets('Empty/silent audio produces no high-confidence detections',
      (tester) async {
    // All zeros = silence.
    final silence = Float32List(windowSamples);

    final output = await model.predict(
      silence,
      windowSamples: windowSamples,
    );

    final detections = PostProcessor.topK(
      scores: output.predictions,
      labels: labels,
      k: topK,
      threshold: 0.5, // Require high confidence.
    );

    expect(
      detections.isEmpty,
      isTrue,
      reason: 'Silent audio should not produce high-confidence detections, '
          'but got: ${detections.map((d) => '${d.species.commonName}=${d.confidence.toStringAsFixed(3)}').join(', ')}',
    );
  });
}
