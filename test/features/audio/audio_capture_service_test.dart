import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import 'package:birdnet_live/features/audio/audio_capture_service.dart';
import 'package:birdnet_live/features/audio/audio_providers.dart';
import 'package:birdnet_live/features/audio/ring_buffer.dart';

/// Stand-in for the `record` platform channel that enforces the one native
/// invariant we crashed on: `startStream` must never reach a recorder that is
/// already recording.
///
/// On Android that call makes `RecorderWrapper` stop the live recording and
/// restart it from inside the stop callback. If the new `AudioRecord` then
/// fails to initialize — the usual outcome, since something else is holding
/// the mic — the plugin answers the same method call twice and the engine
/// aborts the app with `IllegalStateException: Reply already submitted`.
class _FakeRecordPlatform extends RecordPlatform {
  /// Every platform call in order, for asserting teardown-before-start.
  final List<String> calls = [];

  /// Set if a recorder was ever asked to start while already recording.
  bool sawStartWhileRecording = false;

  final _streams = <String, StreamController<Uint8List>>{};
  final _recording = <String>{};

  void emitStreamError(Object error) {
    for (final ctrl in _streams.values) {
      ctrl.addError(error);
    }
  }

  @override
  Future<void> create(String recorderId) async => calls.add('create');

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      true;

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    calls.add('startStream');
    if (!_recording.add(recorderId)) {
      sawStartWhileRecording = true;
      throw StateError('startStream on an already recording recorder');
    }
    final ctrl = StreamController<Uint8List>.broadcast();
    _streams[recorderId] = ctrl;
    return ctrl.stream;
  }

  @override
  Future<String?> stop(String recorderId) async {
    calls.add('stop');
    await _release(recorderId);
    return null;
  }

  @override
  Future<void> dispose(String recorderId) async {
    calls.add('dispose');
    await _release(recorderId);
  }

  Future<void> _release(String recorderId) async {
    _recording.remove(recorderId);
    await _streams.remove(recorderId)?.close();
  }

  @override
  Stream<RecordState> onStateChanged(String recorderId) =>
      const Stream<RecordState>.empty();

  // Unused by [AudioCaptureService]; present to satisfy the interface.

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async => calls.add('start');

  @override
  Future<void> cancel(String recorderId) => _release(recorderId);

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<bool> isRecording(String recorderId) async =>
      _recording.contains(recorderId);

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: -160, max: -160);

  @override
  Future<bool> isEncoderSupported(String recorderId, AudioEncoder encoder) async =>
      true;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async => const [];

  @override
  void setOnConfigChanged(
    String recorderId,
    void Function(RecordConfig config)? handler,
  ) {}
}

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

    // Regression tests for the "Reply already submitted" crash: every one of
    // these used to leave the platform holding a live recorder while a second
    // startStream came in.
    group('never starts on top of a live recorder', () {
      late RecordPlatform original;
      late _FakeRecordPlatform fake;
      late AudioCaptureService service;

      setUp(() {
        original = RecordPlatform.instance;
        fake = _FakeRecordPlatform();
        RecordPlatform.instance = fake;
        service = AudioCaptureService(ringBuffer: RingBuffer(capacity: 1000));
      });

      tearDown(() async {
        await service.dispose();
        RecordPlatform.instance = original;
      });

      test('concurrent starts are serialized into one', () async {
        await Future.wait([service.start(), service.start()]);

        expect(fake.sawStartWhileRecording, isFalse);
        expect(fake.calls.where((c) => c == 'startStream'), hasLength(1));
        expect(service.state, CaptureState.capturing);
      });

      test('a start after a stream error releases the old recorder', () async {
        await service.start();
        expect(service.state, CaptureState.capturing);

        // Another app grabbed the mic: the stream errors out, but the native
        // recorder is still alive — `_state` alone can't tell us that.
        fake.emitStreamError(Exception('mic lost'));
        await pumpEventQueue();
        expect(service.state, CaptureState.error);

        fake.calls.clear();
        await service.start();

        expect(fake.sawStartWhileRecording, isFalse);
        expect(fake.calls, containsAllInOrder(['dispose', 'startStream']));
        expect(service.state, CaptureState.capturing);
      });

      test('a start racing a switchSource does not overlap', () async {
        await service.start();

        await Future.wait([
          service.switchSource(
            const AudioSourceSelection(profile: AudioSourceProfile.unprocessed),
          ),
          service.start(
            source: const AudioSourceSelection(
              profile: AudioSourceProfile.voiceRecognition,
            ),
          ),
        ]);

        expect(fake.sawStartWhileRecording, isFalse);
        expect(service.state, CaptureState.capturing);
      });

      test('stop releases the recorder even after a failed start', () async {
        await service.start();
        fake.emitStreamError(Exception('mic lost'));
        await pumpEventQueue();

        await service.stop();

        expect(service.state, CaptureState.stopped);
        expect(fake.calls, contains('dispose'));
      });
    });

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
