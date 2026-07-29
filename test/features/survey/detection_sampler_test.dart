// =============================================================================
// Detection Sampler Tests — Clip-retention semantics for All / TopN / Smart
// =============================================================================
//
// The sampler never removes detection records; it only decides which records
// keep their `audioClipPath` (clip retained on disk) vs have it cleared
// (clip deleted, record stays without audio).
// =============================================================================

import 'dart:io';

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/survey/detection_sampler.dart';
import 'package:flutter_test/flutter_test.dart';

late Directory _tmp;

Future<DetectionRecord> _det(
  String sci,
  double conf, {
  Duration offset = Duration.zero,
  double? latitude,
  double? longitude,
  bool withClip = true,
}) async {
  String? clipPath;
  if (withClip) {
    final f = await File(
      '${_tmp.path}/clip_${sci}_${conf}_${offset.inMilliseconds}.wav',
    ).create(recursive: true);
    await f.writeAsString('fake');
    clipPath = f.path;
  }
  return DetectionRecord(
    scientificName: sci,
    commonName: sci,
    confidence: conf,
    timestamp: DateTime.utc(2025, 7, 1, 12).add(offset),
    audioClipPath: clipPath,
    // Clips follow the confidence peak, so the window on disk sits a little
    // after the detection started.
    clipTimestamp:
        clipPath == null
            ? null
            : DateTime.utc(
              2025,
              7,
              1,
              12,
            ).add(offset + const Duration(seconds: 2)),
    latitude: latitude,
    longitude: longitude,
  );
}

void main() {
  setUpAll(() async {
    _tmp = await Directory.systemTemp.createTemp('sampler_test_');
  });

  tearDownAll(() async {
    if (await _tmp.exists()) await _tmp.delete(recursive: true);
  });

  group('samplingModeFromString', () {
    test('parses known modes', () {
      expect(samplingModeFromString('all'), SamplingMode.all);
      expect(samplingModeFromString('topN'), SamplingMode.topN);
      expect(samplingModeFromString('smart'), SamplingMode.smart);
    });

    test('falls back to all for unknown', () {
      expect(samplingModeFromString('unknown'), SamplingMode.all);
      expect(samplingModeFromString(''), SamplingMode.all);
    });
  });

  group('SamplingMode.all', () {
    test('keeps every clip and never evicts', () async {
      final sampler = DetectionSampler(mode: SamplingMode.all);
      final d1 = await _det('Parus major', 0.9);
      final d2 = await _det('Parus major', 0.5);
      final d3 = await _det('Turdus merula', 0.7);

      expect(await sampler.onRecordClosed(d1), isTrue);
      expect(await sampler.onRecordClosed(d2), isTrue);
      expect(await sampler.onRecordClosed(d3), isTrue);
      expect(d1.audioClipPath, isNotNull);
      expect(d2.audioClipPath, isNotNull);
      expect(d3.audioClipPath, isNotNull);
      expect(sampler.droppedClipCount, 0);
    });
  });

  group('SamplingMode.topN', () {
    test('keeps up to N clips per species', () async {
      final sampler = DetectionSampler(mode: SamplingMode.topN, topN: 2);
      final d1 = await _det(
        'Parus major',
        0.9,
        offset: const Duration(seconds: 0),
      );
      final d2 = await _det(
        'Parus major',
        0.8,
        offset: const Duration(seconds: 3),
      );
      final d3 = await _det(
        'Parus major',
        0.7,
        offset: const Duration(seconds: 6),
      );

      expect(await sampler.onRecordClosed(d1), isTrue);
      expect(await sampler.onRecordClosed(d2), isTrue);
      expect(await sampler.onRecordClosed(d3), isFalse);

      expect(d1.audioClipPath, isNotNull);
      expect(d2.audioClipPath, isNotNull);
      expect(d3.audioClipPath, isNull);
      expect(sampler.keptClipCount, 2);
      expect(sampler.droppedClipCount, 1);
    });

    test('evicts weakest clip when a better record arrives', () async {
      final sampler = DetectionSampler(mode: SamplingMode.topN, topN: 2);
      final d1 = await _det(
        'Parus major',
        0.5,
        offset: const Duration(seconds: 0),
      );
      final d2 = await _det(
        'Parus major',
        0.6,
        offset: const Duration(seconds: 3),
      );
      final d3 = await _det(
        'Parus major',
        0.9,
        offset: const Duration(seconds: 6),
      );

      await sampler.onRecordClosed(d1);
      await sampler.onRecordClosed(d2);
      expect(await sampler.onRecordClosed(d3), isTrue);

      expect(d1.audioClipPath, isNull, reason: 'd1 was weakest, evicted');
      expect(d2.audioClipPath, isNotNull);
      expect(d3.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 2);
    });

    test('an evicted record stops advertising a clip window', () async {
      // The window a clip was cut from describes a file that no longer
      // exists once the clip is dropped; leaving it set would let session
      // review label a row with audio it cannot play.
      final sampler = DetectionSampler(mode: SamplingMode.topN, topN: 1);
      final kept = await _det(
        'Parus major',
        0.9,
        offset: const Duration(seconds: 0),
      );
      final dropped = await _det(
        'Parus major',
        0.4,
        offset: const Duration(seconds: 3),
      );

      await sampler.onRecordClosed(kept);
      await sampler.onRecordClosed(dropped);

      expect(dropped.audioClipPath, isNull);
      expect(dropped.clipTimestamp, isNull);
      // The record itself is untouched — the detection still happened.
      expect(dropped.timestamp, isNotNull);
      expect(kept.audioClipPath, isNotNull);
      expect(kept.clipTimestamp, isNotNull);
    });

    test('tracks species independently', () async {
      final sampler = DetectionSampler(mode: SamplingMode.topN, topN: 1);
      final d1 = await _det('Parus major', 0.9);
      final d2 = await _det('Turdus merula', 0.8);

      await sampler.onRecordClosed(d1);
      await sampler.onRecordClosed(d2);
      expect(sampler.keptClipCount, 2);
      expect(d1.audioClipPath, isNotNull);
      expect(d2.audioClipPath, isNotNull);
    });

    test('records without clips are ignored', () async {
      final sampler = DetectionSampler(mode: SamplingMode.topN, topN: 1);
      final d1 = await _det('Parus major', 0.5, withClip: false);
      expect(await sampler.onRecordClosed(d1), isFalse);
      expect(sampler.keptClipCount, 0);
      expect(sampler.droppedClipCount, 0);
    });

    test('deletes evicted file from disk', () async {
      final sampler = DetectionSampler(mode: SamplingMode.topN, topN: 1);
      final d1 = await _det('Parus major', 0.5);
      final d2 = await _det(
        'Parus major',
        0.9,
        offset: const Duration(seconds: 3),
      );
      final d1Path = d1.audioClipPath!;

      await sampler.onRecordClosed(d1);
      expect(await File(d1Path).exists(), isTrue);

      await sampler.onRecordClosed(d2);
      expect(d1.audioClipPath, isNull);
      expect(await File(d1Path).exists(), isFalse);
    });
  });

  group('SamplingMode.smart', () {
    test('keeps detections far apart in space', () async {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        topN: 5,
        distanceThresholdMeters: 500,
        timeThresholdSeconds: 120,
      );

      final d1 = await _det(
        'Parus major',
        0.9,
        offset: const Duration(seconds: 0),
        latitude: 52.0,
        longitude: 13.0,
      );
      final d2 = await _det(
        'Parus major',
        0.8,
        offset: const Duration(seconds: 30),
        latitude: 52.1,
        longitude: 13.0,
      ); // ~11 km north

      expect(await sampler.onRecordClosed(d1), isTrue);
      expect(await sampler.onRecordClosed(d2), isTrue);
      expect(sampler.keptClipCount, 2);
    });

    test('evicts weaker clip at the same spot', () async {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        topN: 1,
        distanceThresholdMeters: 500,
        timeThresholdSeconds: 120,
      );

      final d1 = await _det(
        'Parus major',
        0.5,
        offset: const Duration(seconds: 0),
        latitude: 52.0,
        longitude: 13.0,
      );
      final d2 = await _det(
        'Parus major',
        0.9,
        offset: const Duration(seconds: 30),
        latitude: 52.0001,
        longitude: 13.0001,
      ); // ~14 m away

      await sampler.onRecordClosed(d1);
      expect(await sampler.onRecordClosed(d2), isTrue);
      expect(d1.audioClipPath, isNull);
      expect(d2.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 1);
    });

    test('keeps both when time apart exceeds threshold', () async {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        topN: 5,
        distanceThresholdMeters: 500,
        timeThresholdSeconds: 120,
      );

      final d1 = await _det(
        'Parus major',
        0.9,
        offset: Duration.zero,
        latitude: 52.0,
        longitude: 13.0,
      );
      final d2 = await _det(
        'Parus major',
        0.8,
        offset: const Duration(minutes: 5),
        latitude: 52.0,
        longitude: 13.0,
      );

      expect(await sampler.onRecordClosed(d1), isTrue);
      expect(await sampler.onRecordClosed(d2), isTrue);
      expect(sampler.keptClipCount, 2);
    });

    test('drops new clip if weaker at the same spot', () async {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        topN: 1,
        distanceThresholdMeters: 500,
        timeThresholdSeconds: 120,
      );

      final d1 = await _det(
        'Parus major',
        0.9,
        offset: Duration.zero,
        latitude: 52.0,
        longitude: 13.0,
      );
      final d2 = await _det(
        'Parus major',
        0.3,
        offset: const Duration(seconds: 30),
        latitude: 52.0,
        longitude: 13.0,
      );

      await sampler.onRecordClosed(d1);
      expect(await sampler.onRecordClosed(d2), isFalse);
      expect(d1.audioClipPath, isNotNull);
      expect(d2.audioClipPath, isNull);
      expect(sampler.keptClipCount, 1);
    });

    test(
      'still enforces per-species topN when spots are all distinct',
      () async {
        final sampler = DetectionSampler(
          mode: SamplingMode.smart,
          topN: 2,
          distanceThresholdMeters: 500,
          timeThresholdSeconds: 120,
        );

        final d1 = await _det(
          'Parus major',
          0.5,
          offset: Duration.zero,
          latitude: 52.0,
          longitude: 13.0,
        );
        final d2 = await _det(
          'Parus major',
          0.6,
          offset: const Duration(minutes: 10),
          latitude: 52.5,
          longitude: 13.0,
        );
        final d3 = await _det(
          'Parus major',
          0.9,
          offset: const Duration(minutes: 20),
          latitude: 53.0,
          longitude: 13.0,
        );

        await sampler.onRecordClosed(d1);
        await sampler.onRecordClosed(d2);
        expect(await sampler.onRecordClosed(d3), isTrue);

        expect(d1.audioClipPath, isNull);
        expect(d2.audioClipPath, isNotNull);
        expect(d3.audioClipPath, isNotNull);
        expect(sampler.keptClipCount, 2);
      },
    );

    test('missing GPS falls back to time-only same-spot check', () async {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        topN: 1,
        distanceThresholdMeters: 500,
        timeThresholdSeconds: 120,
      );

      // No GPS on either record; within the time window â†’ same spot.
      final d1 = await _det('Parus major', 0.5, offset: Duration.zero);
      final d2 = await _det(
        'Parus major',
        0.9,
        offset: const Duration(seconds: 30),
      );

      await sampler.onRecordClosed(d1);
      expect(await sampler.onRecordClosed(d2), isTrue);
      expect(d1.audioClipPath, isNull);
      expect(d2.audioClipPath, isNotNull);
    });

    test(
      'admits same-spot clips freely until topN, then applies rivalry',
      () async {
        final sampler = DetectionSampler(
          mode: SamplingMode.smart,
          topN: 3,
          distanceThresholdMeters: 250,
          timeThresholdSeconds: 120,
        );

        // Three same-spot detections all within the time window. All should be
        // kept because rivalry doesn't fire until the topN slots are full.
        final d1 = await _det(
          'Parus major',
          0.5,
          offset: Duration.zero,
          latitude: 52.0,
          longitude: 13.0,
        );
        final d2 = await _det(
          'Parus major',
          0.6,
          offset: const Duration(seconds: 10),
          latitude: 52.0,
          longitude: 13.0,
        );
        final d3 = await _det(
          'Parus major',
          0.7,
          offset: const Duration(seconds: 20),
          latitude: 52.0,
          longitude: 13.0,
        );
        // Fourth same-spot detection: topN is now full, so rivalry fires and
        // this weaker clip loses to the weakest already-kept clip.
        final d4 = await _det(
          'Parus major',
          0.4,
          offset: const Duration(seconds: 30),
          latitude: 52.0,
          longitude: 13.0,
        );

        expect(await sampler.onRecordClosed(d1), isTrue);
        expect(await sampler.onRecordClosed(d2), isTrue);
        expect(await sampler.onRecordClosed(d3), isTrue);
        expect(await sampler.onRecordClosed(d4), isFalse);
        expect(sampler.keptClipCount, 3);
      },
    );
  });
}
