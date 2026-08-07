import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/inference/realtime_inference_scheduler.dart';

void main() {
  final start = DateTime.utc(2026, 8, 6, 12);

  test('1 Hz windows match one-second offline steps', () {
    final scheduler = RealtimeInferenceScheduler(
      sampleRate: 10,
      windowDurationSeconds: 3,
      inferenceRateHz: 1,
      timelineStart: start,
    );

    expect(scheduler.takeNext(29), isNull);
    final first = scheduler.takeNext(30)!;
    final second = scheduler.takeNext(40)!;
    final third = scheduler.takeNext(50)!;

    expect(
      [first.startSample, second.startSample, third.startSample],
      [0, 10, 20],
    );
    expect([first.endSample, second.endSample, third.endSample], [30, 40, 50]);
    expect(second.timestamp, start.add(const Duration(seconds: 1)));
  });

  test('does not emit a zero-padded startup window', () {
    final scheduler = RealtimeInferenceScheduler(
      sampleRate: 32000,
      windowDurationSeconds: 5,
      inferenceRateHz: 1,
      timelineStart: start,
    );

    expect(scheduler.initialDelay, const Duration(seconds: 5));
    expect(scheduler.takeNext(159999), isNull);
    expect(scheduler.takeNext(160000)!.startSample, 0);
  });

  test('0.3 Hz exposes the expected gap with a three-second window', () {
    final scheduler = RealtimeInferenceScheduler(
      sampleRate: 32000,
      windowDurationSeconds: 3,
      inferenceRateHz: 0.3,
      timelineStart: start,
    );

    final first = scheduler.takeNext(96000)!;
    final second = scheduler.takeNext(202667)!;
    expect(second.startSample - first.endSample, 10667);
  });

  test('waits a whole hop when the hop is longer than the window', () {
    final fast = RealtimeInferenceScheduler(
      sampleRate: 32000,
      windowDurationSeconds: 3,
      inferenceRateHz: 1,
      timelineStart: start,
    );
    final slow = RealtimeInferenceScheduler(
      sampleRate: 32000,
      windowDurationSeconds: 3,
      inferenceRateHz: 0.3,
      timelineStart: start,
    );

    // At 1 Hz the window is the longer of the two and stays the bound; at
    // 0.3 Hz a window-length bound would wake three times per hop.
    expect(fast.maxWaitSamples, fast.windowSamples);
    expect(slow.maxWaitSamples, slow.hopSamples);
  });

  group('calibration', () {
    RealtimeInferenceScheduler schedulerAt(DateTime built) =>
        RealtimeInferenceScheduler(
          sampleRate: 10,
          windowDurationSeconds: 3,
          inferenceRateHz: 1,
          timelineStart: built,
        );

    test('timeline does not start until audio does', () {
      final scheduler = schedulerAt(start);
      expect(scheduler.isCalibrated, isFalse);

      // Capture is still spinning up: nothing has been written yet.
      final quiet = start.add(const Duration(milliseconds: 400));
      expect(scheduler.calibrate(0, quiet), isFalse);
      expect(scheduler.timelineStart, quiet);

      // First samples land 100 ms later. They cover the 100 ms just past, so
      // the timeline starts there rather than at construction.
      final firstAudio = quiet.add(const Duration(milliseconds: 100));
      expect(scheduler.calibrate(1, firstAudio), isTrue);
      expect(
        scheduler.timelineStart,
        firstAudio.subtract(const Duration(milliseconds: 100)),
      );
      expect(scheduler.timelineStart, quiet);
    });

    test('windows are dated from the calibrated start', () {
      final scheduler = schedulerAt(start);
      final firstAudio = start.add(const Duration(seconds: 2));
      scheduler.calibrate(10, firstAudio); // 10 samples = 1s at 10 Hz.

      // Audio began at firstAudio - 1s; window one starts with that sample.
      final window = scheduler.takeNext(30)!;
      expect(window.startSample, 0);
      expect(window.timestamp, start.add(const Duration(seconds: 1)));
    });

    test('calibrating again is a no-op once anchored', () {
      final scheduler = schedulerAt(start);
      scheduler.calibrate(10, start.add(const Duration(seconds: 1)));
      final anchored = scheduler.timelineStart;

      expect(scheduler.calibrate(500, start.add(const Duration(hours: 1))), isTrue);
      expect(scheduler.timelineStart, anchored);
    });

    test('a rewound buffer re-calibrates against the new capture', () {
      final scheduler = schedulerAt(start);
      scheduler.calibrate(10, start.add(const Duration(seconds: 1)));

      scheduler.rebase(start.add(const Duration(minutes: 5)));
      expect(scheduler.isCalibrated, isFalse);
    });
  });

  test('rebasing restarts the schedule on a rewound capture buffer', () {
    final scheduler = RealtimeInferenceScheduler(
      sampleRate: 10,
      windowDurationSeconds: 3,
      inferenceRateHz: 1,
      timelineStart: start,
    );
    scheduler.takeNext(30);
    scheduler.takeNext(40);

    final restarted = start.add(const Duration(minutes: 5));
    scheduler.rebase(restarted);

    expect(scheduler.nextWindowEndSample, 30);
    final first = scheduler.takeNext(30)!;
    expect(first.startSample, 0);
    expect(first.timestamp, restarted);
  });

  test('reports and skips windows lost to ring-buffer overwrite', () {
    final scheduler = RealtimeInferenceScheduler(
      sampleRate: 10,
      windowDurationSeconds: 3,
      inferenceRateHz: 1,
      timelineStart: start,
    );

    expect(scheduler.skipOverwritten(25), 3);
    expect(scheduler.nextWindowEndSample, 60);
    expect(scheduler.takeNext(60)!.startSample, 30);
  });
}
