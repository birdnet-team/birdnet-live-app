import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

import 'package:birdnet_live/features/audio/ring_buffer.dart';
import 'package:birdnet_live/features/inference/inference_window_driver.dart';

void main() {
  const sampleRate = 100;
  const windowSeconds = 3;
  const windowSamples = sampleRate * windowSeconds;

  RingBuffer bufferWith(int samples) {
    final buffer = RingBuffer(capacity: 10000);
    final data = Float32List(samples);
    for (var i = 0; i < samples; i++) {
      data[i] = ((i % 20) - 10) / 10.0;
    }
    buffer.write(data);
    return buffer;
  }

  InferenceWindowDriver driverOn(
    RingBuffer buffer, {
    required bool useBufferedAudio,
  }) {
    final driver = InferenceWindowDriver(
      ringBuffer: buffer,
      debugLabel: 'test',
    );
    driver.start(
      sampleRate: sampleRate,
      windowDurationSeconds: windowSeconds,
      inferenceRateHz: 1,
      useBufferedAudio: useBufferedAudio,
    );
    return driver;
  }

  test('a fresh session ignores audio captured before it started', () {
    // Live starts on a cleared buffer; anything already there belongs to
    // whatever ran before and must not be drained as a backlog.
    final buffer = bufferWith(windowSamples * 2);
    final driver = driverOn(buffer, useBufferedAudio: false);

    expect(driver.takeReadyWindow(), isNull);
  });

  test('a caller that filled the buffer itself analyzes it right away', () {
    // ARU opens the mic, then loads the model — seconds of cycle audio can
    // arrive before the session starts, and it is already on disk.
    final buffer = bufferWith(windowSamples * 2);
    final driver = driverOn(buffer, useBufferedAudio: true);

    final window = driver.takeReadyWindow();
    expect(window, isNotNull);
    expect(window!.samples, hasLength(windowSamples));
    expect(window.windowEndSample, buffer.totalWritten);
  });

  test('reaching back is capped at one window, not the whole buffer', () {
    final buffer = bufferWith(windowSamples * 5);
    final driver = driverOn(buffer, useBufferedAudio: true);

    // Exactly one window is ready; the rest is left alone rather than
    // replayed as a burst of catch-up inference.
    expect(driver.takeReadyWindow(), isNotNull);
    expect(driver.takeReadyWindow(), isNull);
  });

  test('partial buffered audio shortens the wait instead of discarding it', () {
    final buffer = bufferWith(windowSamples ~/ 3);
    final driver = driverOn(buffer, useBufferedAudio: true);

    // Not a whole window yet, so nothing is ready...
    expect(driver.takeReadyWindow(), isNull);

    // ...but the retained audio counts toward it, so the rest of one window
    // is enough rather than a further full window.
    buffer.write(Float32List(windowSamples - (windowSamples ~/ 3)));
    expect(driver.takeReadyWindow(), isNotNull);
  });

  group('falling behind', () {
    const hop = sampleRate; // 1 Hz

    /// Take the next window after [newSamples] more have been captured.
    InferenceWindowAudio take(InferenceWindowDriver driver, RingBuffer buffer,
        int newSamples) {
      buffer.write(Float32List(newSamples));
      final window = driver.takeReadyWindow();
      expect(window, isNotNull);
      return window!;
    }

    test('steps the rate down after a growing run of late windows', () {
      final buffer = RingBuffer(capacity: 10000);
      final driver = driverOn(buffer, useBufferedAudio: false);
      final lowered = <double>[];
      driver.onInferenceRateLowered = lowered.add;

      // On time, then one hop late and growing: capture is pulling away
      // from a model that is slower than the schedule.
      expect(take(driver, buffer, windowSamples).windowEndSample, 300);
      expect(take(driver, buffer, 2 * hop).windowEndSample, 400);
      expect(take(driver, buffer, 2 * hop).windowEndSample, 500);
      expect(lowered, isEmpty);

      // The third late window in a row is one too many.
      expect(take(driver, buffer, 2 * hop).windowEndSample, 600);

      expect(lowered, [0.7]);
      expect(driver.inferenceRateHz, 0.7);
      // The backlog is abandoned: the next window ends where capture is now,
      // and the one after that comes a 0.7 Hz hop later.
      expect(driver.takeReadyWindow()!.windowEndSample, buffer.totalWritten);
      buffer.write(Float32List(142));
      expect(driver.takeReadyWindow(), isNull);
      buffer.write(Float32List(1));
      expect(driver.takeReadyWindow(), isNotNull);
    });

    test('a stall that drains on its own leaves the rate alone', () {
      final buffer = RingBuffer(capacity: 10000);
      final driver = driverOn(buffer, useBufferedAudio: false);
      final lowered = <double>[];
      driver.onInferenceRateLowered = lowered.add;

      expect(take(driver, buffer, windowSamples).windowEndSample, 300);
      // A five-second stall: four windows are late, each less than the last.
      expect(take(driver, buffer, 5 * hop).windowEndSample, 400);
      for (final end in [500, 600, 700, 800]) {
        expect(driver.takeReadyWindow()!.windowEndSample, end);
      }

      expect(lowered, isEmpty);
      expect(driver.inferenceRateHz, 1);
    });

    test('at the floor only the backlog is dropped', () {
      final buffer = RingBuffer(capacity: 10000);
      final driver = InferenceWindowDriver(
        ringBuffer: buffer,
        debugLabel: 'test',
      );
      driver.start(
        sampleRate: sampleRate,
        windowDurationSeconds: windowSeconds,
        inferenceRateHz: 0.1,
      );
      final lowered = <double>[];
      driver.onInferenceRateLowered = lowered.add;
      const slowHop = 10 * sampleRate;

      expect(take(driver, buffer, windowSamples).windowEndSample, 300);
      expect(take(driver, buffer, 2 * slowHop).windowEndSample, 1300);
      expect(take(driver, buffer, slowHop + 100).windowEndSample, 2300);
      expect(take(driver, buffer, slowHop + 100).windowEndSample, 3300);

      expect(lowered, isEmpty);
      expect(driver.inferenceRateHz, 0.1);
      expect(driver.takeReadyWindow()!.windowEndSample, buffer.totalWritten);
    });
  });

  test('loweredInferenceRate steps by 0.3 Hz down to 0.1 Hz', () {
    expect(loweredInferenceRate(1.0), 0.7);
    expect(loweredInferenceRate(0.7), 0.4);
    expect(loweredInferenceRate(0.4), 0.1);
    expect(loweredInferenceRate(0.5), 0.2);
    expect(loweredInferenceRate(0.2), 0.1);
    expect(loweredInferenceRate(0.1), 0.1);
  });

  test('detects a reset even after the sample counter catches up', () {
    final buffer = RingBuffer(capacity: 10000);
    final driver = driverOn(buffer, useBufferedAudio: false);

    buffer.write(Float32List(windowSamples));
    expect(driver.takeReadyWindow(), isNotNull);

    // The new timeline has already reached the same counter value. Comparing
    // totalWritten alone cannot distinguish this from uninterrupted capture.
    buffer.clear();
    buffer.write(Float32List(windowSamples));

    expect(driver.takeReadyWindow(), isNull); // Notices and rebases.
    final restarted = driver.takeReadyWindow();
    expect(restarted, isNotNull);
    expect(restarted!.windowEndSample, windowSamples);
  });
}
