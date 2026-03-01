import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_capture_service.dart';
import 'ring_buffer.dart';

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
//   [inputDevicesProvider]    ← UI watches for device dropdown
//   [selectedDeviceProvider]  ← UI writes selected device ID
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
  return CaptureStateNotifier(service);
});

/// Notifier that mirrors [AudioCaptureService.state] and exposes
/// start / stop actions.
class CaptureStateNotifier extends StateNotifier<CaptureState> {
  CaptureStateNotifier(this._service) : super(CaptureState.stopped);

  final AudioCaptureService _service;
  StreamSubscription<int>? _dataSub;

  /// Start audio capture.
  Future<void> start({String? deviceId}) async {
    await _service.start(deviceId: deviceId);
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

  /// Stop audio capture.
  Future<void> stop() async {
    _dataSub?.cancel();
    _dataSub = null;
    await _service.stop();
    state = _service.state;
  }

  /// Toggle capture on/off.
  Future<void> toggle({String? deviceId}) async {
    if (state == CaptureState.capturing) {
      await stop();
    } else {
      await start(deviceId: deviceId);
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

/// Currently selected input device ID (null = system default).
final selectedDeviceProvider = StateProvider<String?>((ref) => null);

/// Simple data class for input device info (avoids leaking `record`
/// types into the UI layer).
class InputDeviceInfo {
  const InputDeviceInfo({required this.id, required this.label});

  final String id;
  final String label;

  @override
  String toString() => 'InputDeviceInfo($id, $label)';
}
