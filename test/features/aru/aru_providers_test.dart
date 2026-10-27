import 'dart:typed_data';

import 'package:birdnet_live/features/aru/aru_providers.dart';
import 'package:birdnet_live/features/audio/audio_capture_service.dart';
import 'package:birdnet_live/features/audio/ring_buffer.dart';
import 'package:birdnet_live/features/recording/recording_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('startAruCycleAudio', () {
    test(
      'clears stale audio and starts capture when recording is off',
      () async {
        final ringBuffer = RingBuffer(capacity: 16)
          ..write(Float32List.fromList([0.1, 0.2, 0.3]));
        var captureStarts = 0;
        var recordingStarts = 0;
        var gain = 0.0;
        var highPass = -1.0;

        final path = await startAruCycleAudio(
          ringBuffer: ringBuffer,
          captureState: CaptureState.stopped,
          startCapture: () async => captureStarts++,
          setGain: (value) => gain = value,
          setHighPassCutoff: (value) => highPass = value,
          startRecording:
              ({required sessionId, required mode, required format}) {
                recordingStarts++;
                return Future.value('/recordings/$sessionId');
              },
          recordingMode: RecordingMode.off,
          recordingSessionId: 'aru-1/cycle_000',
          recordingFormat: 'flac',
          gainLinear: 1.25,
          highPassHz: 150,
        );

        expect(path, isNull);
        expect(ringBuffer.available, 0);
        expect(captureStarts, 1);
        expect(recordingStarts, 0);
        expect(gain, 1.25);
        expect(highPass, 150);
      },
    );

    test(
      'starts file recording before capture when recording is enabled',
      () async {
        final ringBuffer = RingBuffer(capacity: 16)
          ..write(Float32List.fromList([0.1, 0.2, 0.3]));
        final events = <String>[];

        final path = await startAruCycleAudio(
          ringBuffer: ringBuffer,
          captureState: CaptureState.stopped,
          startCapture: () async => events.add('capture'),
          setGain: (_) => events.add('gain'),
          setHighPassCutoff: (_) => events.add('highPass'),
          startRecording:
              ({required sessionId, required mode, required format}) {
                events.add('record:$sessionId:$format:${mode.name}');
                return Future.value('/recordings/$sessionId/full.flac');
              },
          recordingMode: RecordingMode.full,
          recordingSessionId: 'aru-1/cycle_000',
          recordingFormat: 'flac',
          gainLinear: 1,
          highPassHz: 0,
        );

        expect(path, '/recordings/aru-1/cycle_000/full.flac');
        expect(ringBuffer.available, 0);
        expect(events, [
          'gain',
          'highPass',
          'record:aru-1/cycle_000:flac:full',
          'capture',
        ]);
      },
    );

    test('does not stop ownership of already-running capture', () async {
      var captureStarts = 0;

      await startAruCycleAudio(
        ringBuffer: RingBuffer(),
        captureState: CaptureState.capturing,
        startCapture: () async => captureStarts++,
        setGain: (_) {},
        setHighPassCutoff: (_) {},
        startRecording: ({required sessionId, required mode, required format}) {
          return Future.value('/recordings/$sessionId');
        },
        recordingMode: RecordingMode.off,
        recordingSessionId: 'aru-1/cycle_000',
        recordingFormat: 'flac',
        gainLinear: 1,
        highPassHz: 0,
      );

      expect(captureStarts, 0);
    });
  });
}
