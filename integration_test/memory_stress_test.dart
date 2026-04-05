// =============================================================================
// Memory Stress Integration Test — Diagnose OOM during live sessions
// =============================================================================
//
// Simulates a ~4 minute live session on-device by repeatedly running the
// full inference pipeline (ONNX model → post-processing → species filter)
// while writing audio to the FLAC encoder. Logs VmRSS from /proc/self/status
// every cycle so the memory growth rate is visible.
//
// Run on a connected device:
//   flutter test integration_test/memory_stress_test.dart -d <device_id>
//
// The test PASSES if RSS growth stays below a threshold. If it fails, the
// log output shows exactly which second the memory started growing and at
// what rate.
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:birdnet_live/core/services/memory_monitor.dart';
import 'package:birdnet_live/features/audio/ring_buffer.dart';
import 'package:birdnet_live/features/inference/classifier_model.dart';
import 'package:birdnet_live/features/inference/geo_model.dart';
import 'package:birdnet_live/features/inference/label_parser.dart';
import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/inference/post_processor.dart';
import 'package:birdnet_live/features/recording/flac_encoder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // --- Shared state loaded once in setUpAll ---------------------------------
  late ModelConfig config;
  late ClassifierModel audioModel;
  late GeoModel geoModel;
  late List<Species> audioLabels;
  late Set<String> geoSpeciesNames;
  late Float32List testAudio; // 3 s of audio for inference
  late String tempDir;

  setUpAll(() async {
    // Load model config.
    final configJson = await rootBundle.loadString(
      'assets/models/model_config.json',
    );
    final fullConfig = jsonDecode(configJson) as Map<String, dynamic>;
    config = ModelConfig.fromJson(
      fullConfig['audioModel'] as Map<String, dynamic>,
    );

    // Load audio model.
    debugPrint('[MemStress] loading audio model …');
    final modelData = await rootBundle.load(
      'assets/models/${config.onnx.modelFile}',
    );
    audioModel = ClassifierModel();
    await audioModel.loadModel(
      modelData.buffer
          .asUint8List(modelData.offsetInBytes, modelData.lengthInBytes),
      inputName: config.onnx.inputName,
      predictionsName: config.onnx.predictionsName,
      embeddingsName: config.onnx.embeddingsName,
    );
    debugPrint('[MemStress] audio model loaded');

    // Load audio labels.
    final labelsCsv = await rootBundle.loadString(
      'assets/models/${config.labels.file}',
    );
    audioLabels = LabelParser.parse(labelsCsv, config: config.labels);

    // Load geo model.
    final geoConfig = fullConfig['geoModel'] as Map<String, dynamic>;
    final geoLabelsText = await rootBundle.loadString(
      'assets/models/${geoConfig['labelsFile']}',
    );

    // Extract geo ONNX to temp path.
    final appDir = await getApplicationDocumentsDirectory();
    tempDir = '${appDir.path}/mem_stress_test';
    await Directory(tempDir).create(recursive: true);

    final geoOnnxPath = '$tempDir/geo_model.onnx';
    if (!File(geoOnnxPath).existsSync()) {
      final geoData = await rootBundle.load(
        'assets/models/${geoConfig['modelFile']}',
      );
      await File(geoOnnxPath).writeAsBytes(
        geoData.buffer
            .asUint8List(geoData.offsetInBytes, geoData.lengthInBytes),
        flush: true,
      );
    }

    geoModel = GeoModel();
    geoModel.loadLabels(geoLabelsText);
    await geoModel.loadModel(geoOnnxPath);
    geoSpeciesNames = geoModel.labels.map((l) => l.scientificName).toSet();
    debugPrint('[MemStress] geo model loaded '
        '(${geoModel.labels.length} species)');

    // Create synthetic test audio (3 seconds of low-level noise).
    // This simulates real capture without needing the microphone.
    final sampleRate = config.audio.sampleRate;
    final windowSamples = sampleRate * 3;
    testAudio = Float32List(windowSamples);
    for (var i = 0; i < windowSamples; i++) {
      // Low amplitude pseudo-random noise (deterministic).
      testAudio[i] = ((i * 7 + 13) % 1000 - 500) / 50000.0;
    }

    MemoryMonitor.logOnce(tag: 'setup-complete');
  });

  tearDownAll(() {
    audioModel.dispose();
    geoModel.dispose();
    MemoryMonitor.stop();
  });

  // -------------------------------------------------------------------------
  // Main stress test
  // -------------------------------------------------------------------------

  testWidgets('Inference loop memory stays bounded over 240 cycles',
      (tester) async {
    // Simulate ~4 minutes of live mode at 1 Hz inference rate.
    // 240 cycles × 1 inference/cycle = 240 inferences.
    const totalCycles = 240;
    const sampleRate = 32000;
    const windowSamples = sampleRate * 3;
    const confidenceThreshold = 0.25;
    const topK = 10;
    const sensitivity = 1.0;

    // --- Phase 1: Pure inference loop (no recording) -----------------------
    debugPrint('[MemStress] ═══ Phase 1: Inference only ═══');
    final baseline = MemoryMonitor.logOnce(tag: 'inference-start');

    for (var i = 0; i < totalCycles; i++) {
      // Run model prediction.
      final output = await audioModel.predict(
        testAudio,
        windowSamples: windowSamples,
      );

      // Post-process (same path as InferenceService.infer).
      final adjusted =
          PostProcessor.applySensitivityAll(output.predictions, sensitivity);
      final detections = PostProcessor.topK(
        scores: adjusted,
        labels: audioLabels,
        k: topK,
        threshold: confidenceThreshold,
      );

      // Log memory every 10 cycles.
      if ((i + 1) % 10 == 0) {
        final snap = MemoryMonitor.logOnce(tag: 'infer-${i + 1}');
        final growthMb = snap.vmRssMb - baseline.vmRssMb;
        debugPrint('[MemStress] cycle ${i + 1}/$totalCycles '
            'dets=${detections.length} '
            'RSS_growth=${growthMb.toStringAsFixed(1)}MB');
      }
    }

    final afterInference = MemoryMonitor.logOnce(tag: 'inference-end');
    final inferenceGrowthMb = afterInference.vmRssMb - baseline.vmRssMb;
    debugPrint('[MemStress] Inference-only RSS growth: '
        '${inferenceGrowthMb.toStringAsFixed(1)}MB over $totalCycles cycles');

    // --- Phase 2: Inference + FLAC recording (same as live mode) -----------
    debugPrint('[MemStress] ═══ Phase 2: Inference + FLAC recording ═══');
    final ringBuffer = RingBuffer();
    final flacPath = '$tempDir/stress_test.flac';
    final encoder = FlacEncoder(filePath: flacPath, sampleRate: sampleRate);
    await encoder.open();

    final phase2Baseline = MemoryMonitor.logOnce(tag: 'recording-start');

    for (var i = 0; i < totalCycles; i++) {
      // Simulate audio capture: write test audio to ring buffer.
      ringBuffer.write(testAudio);

      // Run inference.
      final output = await audioModel.predict(
        testAudio,
        windowSamples: windowSamples,
      );

      final adjusted =
          PostProcessor.applySensitivityAll(output.predictions, sensitivity);
      PostProcessor.topK(
        scores: adjusted,
        labels: audioLabels,
        k: topK,
        threshold: confidenceThreshold,
      );

      // Simulate recording flush (every cycle, like the 1s timer).
      final samples = ringBuffer.readLast(sampleRate); // 1 second
      await encoder.writeSamples(samples);

      // Log memory every 10 cycles.
      if ((i + 1) % 10 == 0) {
        final snap = MemoryMonitor.logOnce(tag: 'rec-${i + 1}');
        final growthMb = snap.vmRssMb - phase2Baseline.vmRssMb;
        debugPrint('[MemStress] cycle ${i + 1}/$totalCycles '
            'RSS_growth=${growthMb.toStringAsFixed(1)}MB');
      }
    }

    await encoder.close();
    final afterRecording = MemoryMonitor.logOnce(tag: 'recording-end');
    final recordingGrowthMb = afterRecording.vmRssMb - phase2Baseline.vmRssMb;
    debugPrint('[MemStress] Recording+inference RSS growth: '
        '${recordingGrowthMb.toStringAsFixed(1)}MB over $totalCycles cycles');

    // --- Phase 3: Geo model predictions (single burst) ---------------------
    debugPrint('[MemStress] ═══ Phase 3: Geo model 48-week burst ═══');
    final phase3Baseline = MemoryMonitor.logOnce(tag: 'geo-start');

    // Simulate what happens at session start: predictAllWeeks.
    geoModel.predictAllWeeks(latitude: 52.5, longitude: 13.4);

    final afterGeo = MemoryMonitor.logOnce(tag: 'geo-end');
    debugPrint('[MemStress] Geo 48-week RSS growth: '
        '${(afterGeo.vmRssMb - phase3Baseline.vmRssMb).toStringAsFixed(1)}MB');

    // --- Summary -----------------------------------------------------------
    final totalGrowthMb = afterGeo.vmRssMb - baseline.vmRssMb;
    debugPrint('[MemStress] ═══ FINAL SUMMARY ═══');
    debugPrint('[MemStress] Total RSS growth: '
        '${totalGrowthMb.toStringAsFixed(1)}MB');
    debugPrint('[MemStress] Inference-only growth: '
        '${inferenceGrowthMb.toStringAsFixed(1)}MB');
    debugPrint('[MemStress] Recording growth: '
        '${recordingGrowthMb.toStringAsFixed(1)}MB');

    // Clean up temp file.
    try {
      await File(flacPath).delete();
    } catch (_) {}

    // PASS if total growth is under 100 MB. If this fails, the per-cycle
    // logs above show exactly where memory is growing.
    expect(
      totalGrowthMb,
      lessThan(100.0),
      reason: 'Process RSS grew by ${totalGrowthMb.toStringAsFixed(1)}MB '
          'over ${totalCycles * 2} inference cycles — likely a memory leak. '
          'Check the per-cycle logs above to identify the growth point.',
    );
  });
}
