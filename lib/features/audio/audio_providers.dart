import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';
import 'audio_capture_service.dart';
import 'audio_source.dart';
import 'ring_buffer.dart';

export 'audio_source.dart';

// =============================================================================
// Audio Providers — Riverpod wiring for the capture pipeline
// =============================================================================
//
// This file exposes the audio subsystem to the rest of the app through
// Riverpod providers.  The layering is intentional:
//
//   [ringBufferProvider]
//       ↓  (dependency)
//   [audioCaptureServiceProvider]
//       ↓  (exposes state / streams)
//   [captureStateProvider]    ← UI watches for start/stop/error
//   [inputDevicesProvider]    ← UI watches for the device list
//   [audioSourceProvider]     ← UI writes the picked device + profile
//
// ### Disposal
//
// The service is disposed when the provider scope is torn down (e.g.,
// app exit).  The ring buffer is a plain Dart object and needs no
// explicit disposal.
// =============================================================================

// ---------------------------------------------------------------------------
// Ring Buffer
// ---------------------------------------------------------------------------

/// Shared ring buffer for the audio pipeline.
///
/// Capacity = 2 × 10 s × 32 000 Hz = 640 000 samples.
/// All audio data flows through this single buffer instance.
final ringBufferProvider = Provider<RingBuffer>((ref) {
  return RingBuffer();
});

// ---------------------------------------------------------------------------
// Audio Capture Service
// ---------------------------------------------------------------------------

/// Provides the singleton [AudioCaptureService].
final audioCaptureServiceProvider = Provider<AudioCaptureService>((ref) {
  final ringBuffer = ref.watch(ringBufferProvider);
  final service = AudioCaptureService(ringBuffer: ringBuffer);

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// ---------------------------------------------------------------------------
// Capture State
// ---------------------------------------------------------------------------

/// Tracks the current [CaptureState] reactively.
///
/// UI widgets watch this to show start/stop controls and error states.
final captureStateProvider =
    StateNotifierProvider<CaptureStateNotifier, CaptureState>((ref) {
      final service = ref.watch(audioCaptureServiceProvider);
      final notifier = CaptureStateNotifier(service);

      // Apply an audio source change to a *running* session, so switching mics
      // from Settings mid-recording takes effect straight away instead of at
      // the next session. Harmless when nothing is capturing.
      ref.listen<AudioSourceSelection>(audioSourceProvider, (previous, next) {
        if (previous == next) return;
        notifier.switchSource(next);
      });

      return notifier;
    });

/// Notifier that mirrors [AudioCaptureService.state] and exposes
/// start / stop actions.
class CaptureStateNotifier extends StateNotifier<CaptureState> {
  CaptureStateNotifier(this._service) : super(CaptureState.stopped);

  final AudioCaptureService _service;
  StreamSubscription<int>? _dataSub;

  /// Start audio capture.
  Future<void> start({AudioSourceSelection? source}) async {
    await _service.start(source: source);
    state = _service.state;

    // Keep state in sync in case the stream ends or errors.
    _dataSub?.cancel();
    _dataSub = _service.onDataAvailable.listen(
      (_) {
        if (state != _service.state) {
          state = _service.state;
        }
      },
      onError: (_) {
        state = _service.state;
      },
      onDone: () {
        state = _service.state;
      },
    );
  }

  /// Switch the audio source, applying it live if capture is running.
  Future<void> switchSource(AudioSourceSelection source) async {
    await _service.switchSource(source);
    state = _service.state;
  }

  /// Stop audio capture.
  Future<void> stop() async {
    _dataSub?.cancel();
    _dataSub = null;
    await _service.stop();
    state = _service.state;
  }

  /// Toggle capture on/off.
  Future<void> toggle({AudioSourceSelection? source}) async {
    if (state == CaptureState.capturing) {
      await stop();
    } else {
      await start(source: source);
    }
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Input Devices
// ---------------------------------------------------------------------------

/// Lists available audio input devices.
final inputDevicesProvider = FutureProvider<List<InputDeviceInfo>>((ref) async {
  final service = ref.watch(audioCaptureServiceProvider);
  final devices = await service.listInputDevices();
  return devices.map((d) => InputDeviceInfo(id: d.id, label: d.label)).toList();
});

/// Currently selected audio source — which device to record from, and how
/// much OS processing to allow (see [AudioSourceSelection]).
///
/// Persisted across launches via [SharedPreferences] so a field setup only
/// has to be dialled in once. The device and the profile live in separate
/// keys, so an existing install that had picked a USB mic keeps it.
final audioSourceProvider =
    StateNotifierProvider<_AudioSourceNotifier, AudioSourceSelection>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return _AudioSourceNotifier(prefs);
    });

class _AudioSourceNotifier extends StateNotifier<AudioSourceSelection> {
  _AudioSourceNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static AudioSourceSelection _read(SharedPreferences prefs) {
    final deviceId = prefs.getString(PrefKeys.micDeviceId) ?? '';
    // Coerce the profile away on platforms that can't honour it. Prefs outlive
    // the platform they were written on (a restored backup, a shared codebase),
    // and a profile we silently ignore would still show up on the tile — the
    // app would claim "Unprocessed" while changing nothing.
    final profile = audioSourceProfilesSupported
        ? AudioSourceProfile.fromName(
            prefs.getString(PrefKeys.audioSourceProfile),
          )
        : AudioSourceProfile.systemDefault;

    return AudioSourceSelection(
      deviceId: deviceId.isEmpty ? null : deviceId,
      profile: profile,
    );
  }

  @override
  set state(AudioSourceSelection value) {
    super.state = value;
    _prefs.setString(PrefKeys.micDeviceId, value.deviceId ?? '');
    _prefs.setString(PrefKeys.audioSourceProfile, value.profile.name);
  }
}

/// Simple data class for input device info (avoids leaking `record`
/// types into the UI layer).
class InputDeviceInfo {
  const InputDeviceInfo({required this.id, required this.label});

  final String id;
  final String label;

  @override
  String toString() => 'InputDeviceInfo($id, $label)';
}
