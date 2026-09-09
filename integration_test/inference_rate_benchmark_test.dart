// =============================================================================
// Survey inference-rate benchmark
// =============================================================================
//
// Runs one continuous PCM fixture through the production inference and
// accumulation pipeline at 1.0, 0.7, and 0.3 Hz. The 1.0 Hz result is the
// behavioral reference; lower rates report recall, confirmation latency,
// model work, and structural audio coverage for battery-policy tuning.
//
// Run:
//   adb push assets/test_fixtures /data/local/tmp/test_fixtures
//   flutter test integration_test/inference_rate_benchmark_test.dart \
//     -d <device_id>
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:birdnet_live/core/services/asset_pack_service.dart';
import 'package:birdnet_live/features/inference/detection_accumulator.dart';
import 'package:birdnet_live/features/inference/inference_service.dart';
import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:birdnet_live/features/inference/realtime_inference_scheduler.dart';
import 'package:birdnet_live/features/live/live_session.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late InferenceService service;
  late Float32List audio;
  late ModelConfig config;

  setUpAll(() async {
    final configMap =
        jsonDecode(
              await rootBundle.loadString('assets/models/model_config.json'),
            )
            as Map<String, dynamic>;
    config = ModelConfig.fromJson(
      configMap['audioModel'] as Map<String, dynamic>,
    );
    final labels = await rootBundle.loadString(
      'assets/models/${config.labels.file}',
    );
    final blacklist =
        config.scoreBlacklistFile == null
            ? null
            : await rootBundle.loadString(
              'assets/models/${config.scoreBlacklistFile}',
            );

    final modelFilePath = await AssetPackService.resolveModelPath(
      fileName: config.onnx.modelFile,
      version: config.version,
    );

    service = InferenceService();
    await service.initialize(
      modelFilePath: modelFilePath,
      labelsCsv: labels,
      config: config,
      scoreBlacklistJson: blacklist,
    );

    const fixturePath = '/data/local/tmp/test_fixtures/soundscape_32k.raw';
    final fixture = File(fixturePath);
    expect(
      fixture.existsSync(),
      isTrue,
      reason: 'Push assets/test_fixtures to /data/local/tmp first',
    );
    final bytes = await fixture.readAsBytes();
    audio = bytes.buffer.asFloat32List(
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ Float32List.bytesPerElement,
    );
  });

  tearDownAll(() => service.dispose());

  testWidgets('reports 1.0, 0.7, and 0.3 Hz tradeoffs', (tester) async {
    const benchmarkSeconds = 60;
    const windowSeconds = 3;
    const threshold = 0.35;
    final sampleRate = config.audio.sampleRate;
    final availableSeconds = audio.length ~/ sampleRate;
    final durationSeconds =
        availableSeconds < benchmarkSeconds
            ? availableSeconds
            : benchmarkSeconds;
    expect(durationSeconds, greaterThanOrEqualTo(windowSeconds));

    final results = <double, _RateResult>{};
    for (final rate in const [1.0, 0.7, 0.3]) {
      service
        ..setPoolingMode('adaptive_lme_peak')
        ..setMaxPoolWindows(5)
        ..setMaxPoolAgeSeconds(10)
        ..resetPooling();

      final records = <DetectionRecord>[];
      final startTime = DateTime.utc(2026, 8, 6, 12);
      final accumulator = DetectionAccumulator(
        sessionStart: startTime,
        records: records,
      );
      final hop = RealtimeInferenceScheduler.hopSamplesFor(sampleRate, rate);
      final windowSamples = sampleRate * windowSeconds;
      final endSample = durationSeconds * sampleRate;
      final confirmationDelays = <double>[];
      var windowCount = 0;
      final stopwatch = Stopwatch()..start();

      for (var offset = 0; offset + windowSamples <= endSample; offset += hop) {
        final timestamp = startTime.add(
          Duration(
            microseconds:
                (offset * Duration.microsecondsPerSecond / sampleRate).round(),
          ),
        );
        final detections = await service.infer(
          Float32List.sublistView(audio, offset, offset + windowSamples),
          windowSeconds: windowSeconds,
          sensitivity: 1,
          confidenceThreshold: threshold,
          timestamp: timestamp,
        );
        final cycle = accumulator.processCycle(
          detections: detections,
          windowEnd: timestamp.add(const Duration(seconds: windowSeconds)),
        );
        for (final change in cycle.changes) {
          if (!change.isNew) continue;
          confirmationDelays.add(
            timestamp.difference(change.record.timestamp).inMilliseconds / 1000,
          );
        }
        windowCount++;
      }
      accumulator.closeAll();
      stopwatch.stop();

      results[rate] = _RateResult(
        windows: windowCount,
        records: records.length,
        detectionRecords: List.unmodifiable(records),
        species: records.map((record) => record.scientificName).toSet().length,
        coveredFraction: _coveredFraction(
          durationSamples: endSample,
          windowSamples: windowSamples,
          hopSamples: hop,
        ),
        averageConfirmationDelay:
            confirmationDelays.isEmpty
                ? 0
                : confirmationDelays.reduce((a, b) => a + b) /
                    confirmationDelays.length,
        modelTime: stopwatch.elapsed,
      );
    }

    final baseline = results[1.0]!;
    for (final entry in results.entries) {
      final result = entry.value;
      final matchedBaselineEvents =
          baseline.detectionRecords.where((expected) {
            return result.detectionRecords.any(
              (candidate) => _sameDetectionSpan(expected, candidate),
            );
          }).length;
      final recall =
          baseline.records == 0
              ? 1.0
              : matchedBaselineEvents / baseline.records;
      // ignore: avoid_print
      print(
        '[RateBenchmark] ${entry.key.toStringAsFixed(1)} Hz: '
        '${result.windows} windows, ${result.records} detections, '
        '${result.species} species, ${(recall * 100).toStringAsFixed(1)}% '
        'event recall, ${(result.coveredFraction * 100).toStringAsFixed(1)}% '
        'audio coverage, ${result.averageConfirmationDelay.toStringAsFixed(2)}s '
        'mean pooling delay, ${result.modelTime.inMilliseconds}ms model time',
      );
    }

    expect(results[1.0]!.coveredFraction, 1);
    expect(results[0.7]!.coveredFraction, 1);
    expect(results[0.3]!.coveredFraction, lessThan(1));
  });
}

double _coveredFraction({
  required int durationSamples,
  required int windowSamples,
  required int hopSamples,
}) {
  var covered = 0;
  var coveredUntil = 0;
  for (
    var start = 0;
    start + windowSamples <= durationSamples;
    start += hopSamples
  ) {
    final end = start + windowSamples;
    if (end > coveredUntil) {
      covered += end - (start > coveredUntil ? start : coveredUntil);
      coveredUntil = end;
    }
  }
  // Ignore the unfinished tail after the final complete window. In a live
  // stream that tail becomes the next window; only holes *between* scheduled
  // windows represent permanent missed audio.
  return coveredUntil == 0 ? 0 : covered / coveredUntil;
}

bool _sameDetectionSpan(DetectionRecord a, DetectionRecord b) {
  if (a.scientificName != b.scientificName) return false;
  final aEnd = a.endTimestamp ?? a.timestamp;
  final bEnd = b.endTimestamp ?? b.timestamp;
  return !aEnd.isBefore(b.timestamp) && !bEnd.isBefore(a.timestamp);
}

class _RateResult {
  const _RateResult({
    required this.windows,
    required this.records,
    required this.detectionRecords,
    required this.species,
    required this.coveredFraction,
    required this.averageConfirmationDelay,
    required this.modelTime,
  });

  final int windows;
  final int records;
  final List<DetectionRecord> detectionRecords;
  final int species;
  final double coveredFraction;
  final double averageConfirmationDelay;
  final Duration modelTime;
}
