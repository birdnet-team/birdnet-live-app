import 'package:birdnet_live/features/aru/aru_detection_sampler.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/survey/detection_sampler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 6, 1, 4);

  DetectionRecord record({
    required double confidence,
    int cycle = 0,
    int secondsIntoCycle = 0,
    String species = 'Turdus merula',
    String clip = 'clip.flac',
  }) {
    final timestamp = start.add(
      Duration(hours: cycle, seconds: secondsIntoCycle),
    );
    return DetectionRecord(
      scientificName: species,
      commonName: 'Eurasian Blackbird',
      confidence: confidence,
      timestamp: timestamp,
      audioClipPath: '/tmp/$cycle-$secondsIntoCycle-$confidence-$clip',
    );
  }

  group('AruDetectionSampler', () {
    test('all mode keeps every clip', () async {
      final sampler = AruDetectionSampler(mode: SamplingMode.all);
      final det = record(confidence: 0.5);

      final kept = await sampler.onRecordClosed(det);

      expect(kept, isTrue);
      expect(det.audioClipPath, isNotNull);
      expect(sampler.droppedClipCount, 0);
    });

    test('topN keeps highest-confidence clips per species', () async {
      final sampler = AruDetectionSampler(mode: SamplingMode.topN, topN: 2);
      final low = record(confidence: 0.3, cycle: 0);
      final mid = record(confidence: 0.6, cycle: 1);
      final high = record(confidence: 0.9, cycle: 2);

      expect(await sampler.onRecordClosed(low), isTrue);
      expect(await sampler.onRecordClosed(mid), isTrue);
      expect(await sampler.onRecordClosed(high), isTrue);

      expect(low.audioClipPath, isNull);
      expect(mid.audioClipPath, isNotNull);
      expect(high.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 2);
      expect(sampler.droppedClipCount, 1);
    });

    test('smart mode keeps stronger clip from the same time window', () async {
      final sampler = AruDetectionSampler(mode: SamplingMode.smart, topN: 1);
      // Two detections seconds apart (within the same-spot time window).
      // topN=1: the first fills the slot, the second triggers rivalry and wins.
      final weaker = record(confidence: 0.4, secondsIntoCycle: 0);
      final stronger = record(confidence: 0.8, secondsIntoCycle: 10);

      expect(await sampler.onRecordClosed(weaker), isTrue);
      expect(await sampler.onRecordClosed(stronger), isTrue);

      expect(weaker.audioClipPath, isNull);
      expect(stronger.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 1);
    });

    test(
      'smart mode admits same-spot clips freely until topN, then rivalry',
      () async {
        final sampler = AruDetectionSampler(mode: SamplingMode.smart, topN: 3);
        // All within the same time window. Rivalry doesn't fire until topN is
        // full, so all three are kept.
        final a = record(confidence: 0.4, secondsIntoCycle: 0, clip: 'a.flac');
        final b = record(confidence: 0.5, secondsIntoCycle: 10, clip: 'b.flac');
        final c = record(confidence: 0.6, secondsIntoCycle: 20, clip: 'c.flac');
        // Fourth same-window clip: topN full, rivalry fires, weaker d loses.
        final d = record(confidence: 0.3, secondsIntoCycle: 30, clip: 'd.flac');

        expect(await sampler.onRecordClosed(a), isTrue);
        expect(await sampler.onRecordClosed(b), isTrue);
        expect(await sampler.onRecordClosed(c), isTrue);
        expect(await sampler.onRecordClosed(d), isFalse);

        expect(a.audioClipPath, isNotNull);
        expect(b.audioClipPath, isNotNull);
        expect(c.audioClipPath, isNotNull);
        expect(d.audioClipPath, isNull);
        expect(sampler.keptClipCount, 3);
      },
    );

    test('smart mode spreads clips across separate time windows', () async {
      final sampler = AruDetectionSampler(mode: SamplingMode.smart, topN: 2);
      // Same window: both admitted (topN=2 not yet full), then window1 evicts
      // the weaker one when the budget is full.
      final window0Low = record(
        confidence: 0.4,
        secondsIntoCycle: 0,
        clip: 'a.flac',
      );
      final window0High = record(
        confidence: 0.5,
        secondsIntoCycle: 10,
        clip: 'b.flac',
      );
      // A different window (hours later): admitted to its own slot.
      final window1 = record(confidence: 0.6, cycle: 1, clip: 'c.flac');

      expect(await sampler.onRecordClosed(window0Low), isTrue);
      expect(await sampler.onRecordClosed(window0High), isTrue);
      expect(await sampler.onRecordClosed(window1), isTrue);

      expect(window0Low.audioClipPath, isNull);
      expect(window0High.audioClipPath, isNotNull);
      expect(window1.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 2);
    });

    test('smart mode does not mix species budgets', () async {
      final sampler = AruDetectionSampler(mode: SamplingMode.smart, topN: 1);
      final blackbird = record(confidence: 0.4);
      final robin = record(confidence: 0.3, species: 'Erithacus rubecula');

      expect(await sampler.onRecordClosed(blackbird), isTrue);
      expect(await sampler.onRecordClosed(robin), isTrue);

      expect(blackbird.audioClipPath, isNotNull);
      expect(robin.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 2);
    });

    test('smart mode does not mix sampling scopes', () async {
      final sampler = AruDetectionSampler(
        mode: SamplingMode.smart,
        topN: 1,
        scopeKeyFor:
            (record) => 'cycle-${record.timestamp.difference(start).inHours}',
      );
      final cycle0 = record(confidence: 0.4, cycle: 0);
      final cycle1 = record(confidence: 0.3, cycle: 1);

      expect(await sampler.onRecordClosed(cycle0), isTrue);
      expect(await sampler.onRecordClosed(cycle1), isTrue);

      expect(cycle0.audioClipPath, isNotNull);
      expect(cycle1.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 2);
    });

    test(
      'replaceRecord keeps later evictions linked to session record',
      () async {
        final sampler = AruDetectionSampler(mode: SamplingMode.smart, topN: 1);
        final original = record(
          confidence: 0.8,
          cycle: 0,
          clip: 'original.flac',
        );
        final replacement = DetectionRecord(
          scientificName: original.scientificName,
          commonName: original.commonName,
          confidence: 0.9,
          timestamp: original.timestamp,
          endTimestamp: original.timestamp.add(const Duration(seconds: 20)),
          audioClipPath: original.audioClipPath,
        );
        final stronger = record(
          confidence: 0.95,
          cycle: 1,
          clip: 'stronger.flac',
        );

        expect(await sampler.onRecordClosed(original), isTrue);
        sampler.replaceRecord(original, replacement);
        expect(await sampler.onRecordClosed(stronger), isTrue);

        expect(replacement.audioClipPath, isNull);
        expect(stronger.audioClipPath, isNotNull);
        expect(stronger.audioClipPath, contains('stronger.flac'));
        expect(sampler.keptClipCount, 1);
      },
    );
  });
}
