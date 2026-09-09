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
