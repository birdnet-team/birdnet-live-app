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

    test('microphone is not contested on a fresh service', () {
      final service = AudioCaptureService();
      expect(service.isMicContested, isFalse);
      service.dispose();
    });

    test('micContestedStream is a broadcast stream', () {
      final service = AudioCaptureService();
      // Two listeners must be allowed (UI + notification wiring both listen).
      final subA = service.micContestedStream.listen((_) {});
      final subB = service.micContestedStream.listen((_) {});
      subA.cancel();
      subB.cancel();
      service.dispose();
    });

    test('setForeground toggles without a running recorder', () {
      final service = AudioCaptureService();
      // Never started, so flipping foreground/background must be a safe no-op
      // (nothing to reclaim, nothing to release).
      service.setForeground(false);
      service.setForeground(true);
      expect(service.state, CaptureState.stopped);
      expect(service.isMicContested, isFalse);
      service.dispose();
    });

    test(
      'switchSource while stopped stores the choice without starting',
      () async {
        final service = AudioCaptureService();

        await service.switchSource(
          const AudioSourceSelection(profile: AudioSourceProfile.unprocessed),
        );

        // No capture was running, so nothing should have been started; the
        // selection is simply remembered for the next start().
        expect(service.state, CaptureState.stopped);
        expect(service.lastError, isNull);
      },
    );

    test('switchSource to the current source is a no-op', () async {
      final service = AudioCaptureService();

      // Guards the live-switch path: a picker rebuild that re-emits the same
      // selection must not tear down and restart a running recorder.
      await service.switchSource(AudioSourceSelection.systemDefault);

      expect(service.state, CaptureState.stopped);
      expect(service.lastError, isNull);
    });
  });

  group('AudioSourceProfile', () {
    test('fromName round-trips every profile', () {
      for (final profile in AudioSourceProfile.values) {
        expect(AudioSourceProfile.fromName(profile.name), profile);
      }
    });

    test(
      'fromName falls back to systemDefault for unknown or missing values',
      () {
        // A profile persisted by a newer build, or a fresh install with no value.
        expect(
          AudioSourceProfile.fromName('camcorder'),
          AudioSourceProfile.systemDefault,
        );
        expect(
          AudioSourceProfile.fromName(null),
          AudioSourceProfile.systemDefault,
        );
      },
    );
  });

  group('AudioSourceSelection', () {
    test('equality covers both dimensions', () {
      const a = AudioSourceSelection(
        deviceId: 'usb-1',
        profile: AudioSourceProfile.unprocessed,
      );
      const same = AudioSourceSelection(
        deviceId: 'usb-1',
        profile: AudioSourceProfile.unprocessed,
      );
      const otherDevice = AudioSourceSelection(
        deviceId: 'usb-2',
        profile: AudioSourceProfile.unprocessed,
      );
      const otherProfile = AudioSourceSelection(
        deviceId: 'usb-1',
        profile: AudioSourceProfile.voiceRecognition,
      );

      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(otherDevice));
      expect(a, isNot(otherProfile));
    });

    test('systemDefault is the default device with no processing override', () {
      expect(AudioSourceSelection.systemDefault.deviceId, isNull);
      expect(
        AudioSourceSelection.systemDefault.profile,
        AudioSourceProfile.systemDefault,
      );
    });

    // The whole point of splitting the picker into two controls: an external
    // mic must still be capturable unprocessed. Folding these together would
    // silently make them mutually exclusive.
    test('a device keeps its processing profile', () {
      final selection = AudioSourceSelection.systemDefault
          .withProfile(AudioSourceProfile.unprocessed)
          .withDevice('usb-1');

      expect(selection.deviceId, 'usb-1');
      expect(selection.profile, AudioSourceProfile.unprocessed);
    });

    test('a profile change keeps the selected device', () {
      final selection = const AudioSourceSelection(
        deviceId: 'usb-1',
      ).withProfile(AudioSourceProfile.voiceRecognition);

      expect(selection.deviceId, 'usb-1');
      expect(selection.profile, AudioSourceProfile.voiceRecognition);
    });

    test('withDevice(null) returns to the default mic, keeping processing', () {
      final selection = const AudioSourceSelection(
        deviceId: 'usb-1',
        profile: AudioSourceProfile.unprocessed,
      ).withDevice(null);

      expect(selection.deviceId, isNull);
      expect(selection.profile, AudioSourceProfile.unprocessed);
    });
  });
}
