import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/audio/audio_capture_service.dart';
import 'package:birdnet_live/features/audio/audio_providers.dart';
import 'package:birdnet_live/features/audio/ring_buffer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CaptureStateNotifier', () {
    test('initial state is stopped', () {
      final ringBuffer = RingBuffer(capacity: 1000);
      final service = AudioCaptureService(ringBuffer: ringBuffer);
      final notifier = CaptureStateNotifier(service);

      expect(notifier.state, CaptureState.stopped);

      notifier.dispose();
    });
  });

  group('InputDeviceInfo', () {
    test('stores id and label', () {
      const info = InputDeviceInfo(id: 'mic1', label: 'Built-in Mic');
      expect(info.id, 'mic1');
      expect(info.label, 'Built-in Mic');
    });

    test('toString is descriptive', () {
      const info = InputDeviceInfo(id: 'mic1', label: 'Built-in Mic');
      expect(info.toString(), contains('mic1'));
      expect(info.toString(), contains('Built-in Mic'));
    });
  });

  group('AudioCaptureService', () {
    test('creates with default ring buffer', () {
      final service = AudioCaptureService();
      expect(service.state, CaptureState.stopped);
      expect(service.lastError, isNull);
      expect(service.ringBuffer, isNotNull);
    });

    test('creates with custom ring buffer', () {
      final buf = RingBuffer(capacity: 500);
      final service = AudioCaptureService(ringBuffer: buf);
      expect(service.ringBuffer, same(buf));
    });

    test('initial state is stopped', () {
      final service = AudioCaptureService();
      expect(service.state, CaptureState.stopped);
    });

    test('stop when already stopped does not throw', () async {
      final service = AudioCaptureService();
      await service.stop(); // Should not throw.
      expect(service.state, CaptureState.stopped);
    });
  });
}
