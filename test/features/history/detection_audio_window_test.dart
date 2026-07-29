// =============================================================================
// Detection Audio Window Tests
// =============================================================================
//
// Covers the split between the two things a detection knows about time:
// when the *bird* was heard (timestamp .. endTimestamp) and where the *clip*
// on disk came from (clipTimestamp). Exports place the detection inside the
// clip using the latter, so getting it wrong silently mis-labels every
// Raven/CSV row of a detection-clip session.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/history/services/detection_audio_window.dart';
import 'package:birdnet_live/features/live/live_session.dart';

void main() {
  final sessionStart = DateTime.utc(2026, 2, 28, 14, 0, 0);

  LiveSession sessionWith(List<DetectionRecord> detections) {
    return LiveSession(
      id: 'window-test',
      startTime: sessionStart,
      detections: detections,
      settings: SessionSettings(
        windowDuration: 3,
        confidenceThreshold: 25,
        inferenceRate: 1.0,
        speciesFilterMode: 'off',
      ),
    );
  }

  DetectionRecord record({
    Duration start = const Duration(minutes: 1),
    Duration? end,
    String? clipPath,
    Duration? clipWindow,
  }) {
    return DetectionRecord(
      scientificName: 'Turdus merula',
      commonName: 'Eurasian Blackbird',
      confidence: 0.8,
      timestamp: sessionStart.add(start),
      endTimestamp: end == null ? null : sessionStart.add(end),
      audioClipPath: clipPath,
      clipTimestamp: clipWindow == null ? null : sessionStart.add(clipWindow),
    );
  }

  group('detectionDurationSeconds', () {
    test('uses the full span the species stayed above threshold', () {
      final r = record(
        start: const Duration(minutes: 1),
        end: const Duration(minutes: 1, seconds: 24),
      );
      expect(detectionDurationSeconds(r, sessionWith([r]).settings), 24.0);
    });

    test('falls back to one analysis window when still open', () {
      final r = record(start: const Duration(minutes: 1));
      expect(detectionDurationSeconds(r, sessionWith([r]).settings), 3.0);
    });
  });

  group('detectionAudioWindow', () {
    test('anchors the clip at the window it was cut from', () {
      // Heard 60 s .. 84 s into the session, but the clip holds the window
      // at 78 s — where the detection peaked — plus 1 s of padding.
      final r = record(
        start: const Duration(minutes: 1),
        end: const Duration(minutes: 1, seconds: 24),
        clipPath: '/recordings/clip.wav',
        clipWindow: const Duration(seconds: 78),
      );
      final w = detectionAudioWindow(
        sessionWith([r]),
        r,
        clipContextSeconds: 1,
      );

      // The detection itself is unchanged: it is still a 24-second event.
      expect(w.detectionStartSec, 60.0);
      expect(w.detectionDurationSec, 24.0);

      // The clip is one window plus padding on both sides, at the peak.
      expect(w.clipStartSec, 77.0);
      expect(w.clipDurationSec, 5.0);
      expect(w.clipDetectionStartSec, 1.0);
      expect(w.clipDetectionEndSec, 4.0);
    });

    test('a clip never claims the whole detection span', () {
      // The bug this guards: a 24-second detection whose clip is 5 seconds
      // long must not report a 26-second clip.
      final r = record(
        start: const Duration(minutes: 1),
        end: const Duration(minutes: 1, seconds: 24),
        clipPath: '/recordings/clip.wav',
        clipWindow: const Duration(seconds: 78),
      );
      final w = detectionAudioWindow(
        sessionWith([r]),
        r,
        clipContextSeconds: 1,
      );

      expect(w.clipDurationSec, lessThan(w.detectionDurationSec));
    });

    test('legacy clips still span exactly one analysis window', () {
      // Sessions recorded before clips followed the peak cut on arrival, so
      // the detection start is exactly where their clip begins.
      final r = record(
        start: const Duration(minutes: 1),
        end: const Duration(minutes: 1, seconds: 24),
        clipPath: '/recordings/clip.wav',
      );
      final w = detectionAudioWindow(
        sessionWith([r]),
        r,
        clipContextSeconds: 1,
      );

      expect(w.clipStartSec, 59.0);
      expect(w.clipDetectionStartSec, 1.0);
      expect(w.clipDetectionEndSec, 4.0);
      expect(w.clipDurationSec, 5.0);
    });

    test('clamps the clip start at the beginning of the recording', () {
      // A detection in the first second has less pre-roll than requested.
      final r = record(
        start: Duration.zero,
        clipPath: '/recordings/clip.wav',
        clipWindow: Duration.zero,
      );
      final w = detectionAudioWindow(
        sessionWith([r]),
        r,
        clipContextSeconds: 2,
      );

      expect(w.clipStartSec, 0.0);
      expect(w.clipDetectionStartSec, 2.0);
    });

    test('zero context yields a clip of exactly one window', () {
      final r = record(
        start: const Duration(minutes: 1),
        end: const Duration(minutes: 1, seconds: 24),
        clipPath: '/recordings/clip.wav',
        clipWindow: const Duration(seconds: 78),
      );
      final w = detectionAudioWindow(
        sessionWith([r]),
        r,
        clipContextSeconds: 0,
      );

      expect(w.clipStartSec, 78.0);
      expect(w.clipDurationSec, 3.0);
      expect(w.clipDetectionStartSec, 0.0);
    });
  });
}
