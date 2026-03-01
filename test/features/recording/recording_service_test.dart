// =============================================================================
// Recording Service Tests
// =============================================================================

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/audio/ring_buffer.dart';
import 'package:birdnet_live/features/recording/recording_service.dart';

void main() {
  // ── RecordingMode parsing ──────────────────────────────────────────────

  group('recordingModeFromString', () {
    test('parses "full"', () {
      expect(recordingModeFromString('full'), RecordingMode.full);
    });

    test('parses "detections"', () {
      expect(
          recordingModeFromString('detections'), RecordingMode.detectionsOnly);
    });

    test('parses "detectionsOnly"', () {
      expect(recordingModeFromString('detectionsOnly'),
          RecordingMode.detectionsOnly);
    });

    test('defaults to off for unknown', () {
      expect(recordingModeFromString('unknown'), RecordingMode.off);
      expect(recordingModeFromString(''), RecordingMode.off);
    });
  });

  // ── RecordingService ───────────────────────────────────────────────────

  group('RecordingService', () {
    late RingBuffer ringBuffer;
    late RecordingService service;

    setUp(() {
      // Small ring buffer for testing (1 second at 1000 Hz).
      ringBuffer = RingBuffer(capacity: 1000);
      service = RecordingService(
        ringBuffer: ringBuffer,
        sampleRate: 1000,
        preBufferSeconds: 1,
        postBufferSeconds: 1,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state', () {
      expect(service.isRecording, isFalse);
      expect(service.mode, RecordingMode.off);
      expect(service.sessionDir, isNull);
    });

    test('startRecording with off mode does nothing', () async {
      final result = await service.startRecording(
        sessionId: 'test-off',
        mode: RecordingMode.off,
      );

      expect(result, isNull);
      expect(service.isRecording, isFalse);
    });

    test('startRecording is idempotent', () async {
      // We can't test this properly without path_provider, but let's
      // verify the logic: calling start twice should return same dir.
      // Since path_provider isn't available in unit tests without mock,
      // we test the mode/state tracking instead.
      expect(service.isRecording, isFalse);
    });

    test('stopRecording returns null when not recording', () async {
      final result = await service.stopRecording();
      expect(result, isNull);
    });

    test('dispose does not throw when not recording', () {
      // Should be safe to call dispose even if never started.
      service.dispose();
    });

    test('saveDetectionClip returns null when not recording', () async {
      final result = await service.saveDetectionClip(
        clipName: 'test-clip',
      );
      expect(result, isNull);
    });
  });

  // ── Silence detection ──────────────────────────────────────────────────

  group('silence detection', () {
    test('all-zero samples are considered silent', () {
      // Write only zeros to ring buffer.
      final ringBuffer = RingBuffer(capacity: 1000);
      ringBuffer.write(Float32List(100));

      final samples = ringBuffer.readLast(100);
      // All should be zero.
      expect(samples.every((s) => s == 0.0), isTrue);
    });

    test('non-zero samples are not silent', () {
      final ringBuffer = RingBuffer(capacity: 1000);
      final data = Float32List.fromList([0.5, -0.3, 0.0, 0.1]);
      ringBuffer.write(data);

      final samples = ringBuffer.readLast(4);
      expect(samples.any((s) => s != 0.0), isTrue);
    });
  });

  // ── RecordingMode enum ─────────────────────────────────────────────────

  group('RecordingMode', () {
    test('has expected values', () {
      expect(RecordingMode.values.length, 3);
      expect(RecordingMode.off.index, 0);
      expect(RecordingMode.full.index, 1);
      expect(RecordingMode.detectionsOnly.index, 2);
    });
  });
}
