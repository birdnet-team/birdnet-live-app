import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../core/constants/app_constants.dart';
import 'ring_buffer.dart';

// =============================================================================
// Audio Capture Service
// =============================================================================
//
// Wraps the `record` package to stream raw PCM audio from the device
// microphone into the shared [RingBuffer].
//
// ### Data flow
//
// ```
// Microphone (Oboe / AVAudioEngine)
//   → Uint8List (PCM16 little-endian, 32 kHz mono)
//   → _pcm16ToFloat32 (normalized −1.0 … 1.0)
//   → RingBuffer.write
//   → downstream consumers (spectrogram, inference, recording)
// ```
//
// ### Level metering
//
// A periodic [Timer] (~15 Hz) reads the ring buffer's RMS and pushes it
// onto [levelStream] for the UI level meter.  This avoids per-sample
// stream events which would be expensive at 32 kHz.
//
// ### Error handling
//
// Errors during `start()` or from the audio stream are captured in
// [lastError] and the state moves to [CaptureState.error].  The UI can
// read both via the corresponding Riverpod providers.
// =============================================================================

/// State of the audio capture pipeline.
enum CaptureState {
  /// Not started or fully stopped.
  stopped,

  /// Capture is active and streaming audio data.
  capturing,

  /// An error occurred (see [AudioCaptureService.lastError]).
  error,
}

/// Audio capture service wrapping the `record` package.
///
/// Captures mono audio at [AppConstants.sampleRate] Hz and pushes
/// float32 samples into a [RingBuffer].  Exposes a [levelStream] for
/// UI level metering and an [onWindowReady] callback for downstream
/// consumers (inference, spectrogram).
class AudioCaptureService {
  AudioCaptureService({
    RingBuffer? ringBuffer,
  }) : _ringBuffer = ringBuffer ?? RingBuffer();

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  AudioRecorder? _recorder;

  /// Lazily create the recorder to avoid platform channel calls at
  /// construction time (breaks unit tests).
  AudioRecorder get _rec => _recorder ??= AudioRecorder();

  final RingBuffer _ringBuffer;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  CaptureState _state = CaptureState.stopped;
  CaptureState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  /// The ring buffer receiving all captured samples.
  RingBuffer get ringBuffer => _ringBuffer;

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Emits RMS audio level (0.0 – 1.0) at ~15 Hz for the level meter.
  Stream<double> get levelStream => _levelController.stream;
  final _levelController = StreamController<double>.broadcast();

  /// Emits events whenever a new chunk of audio data has been written
  /// to the ring buffer.
  Stream<int> get onDataAvailable => _dataController.stream;
  final _dataController = StreamController<int>.broadcast();

  StreamSubscription<Uint8List>? _streamSub;
  Timer? _levelTimer;

  // ---------------------------------------------------------------------------
  // Device enumeration
  // ---------------------------------------------------------------------------

  /// List available audio input devices.
  Future<List<InputDevice>> listInputDevices() async {
    try {
      return await _rec.listInputDevices();
    } catch (e) {
      debugPrint('Failed to list input devices: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Capture lifecycle
  // ---------------------------------------------------------------------------

  /// Start capturing audio.
  ///
  /// [deviceId] — optional specific input device.
  Future<void> start({String? deviceId}) async {
    if (_state == CaptureState.capturing) return;

    try {
      final hasPermission = await _rec.hasPermission();
      if (!hasPermission) {
        _state = CaptureState.error;
        _lastError = 'Microphone permission not granted';
        return;
      }

      // Configure for raw PCM streaming at 32 kHz mono 16-bit.
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        device: deviceId != null ? InputDevice(id: deviceId, label: '') : null,
      );

      final stream = await _rec.startStream(config);

      _streamSub = stream.listen(
        _onAudioData,
        onError: _onStreamError,
        onDone: _onStreamDone,
      );

      // Periodic level metering (~15 Hz).
      _levelTimer = Timer.periodic(
        const Duration(milliseconds: 67),
        (_) => _emitLevel(),
      );

      _state = CaptureState.capturing;
      _lastError = null;
      debugPrint('Audio capture started @ ${AppConstants.sampleRate} Hz');
    } catch (e, st) {
      _state = CaptureState.error;
      _lastError = e.toString();
      debugPrint('Audio capture start failed: $e\n$st');
    }
  }

  /// Stop capturing audio.
  Future<void> stop() async {
    _levelTimer?.cancel();
    _levelTimer = null;

    await _streamSub?.cancel();
    _streamSub = null;

    try {
      if (_recorder != null) await _rec.stop();
    } catch (_) {
      // Recorder may already be stopped.
    }

    _state = CaptureState.stopped;
    debugPrint('Audio capture stopped');
  }

  /// Release all resources.  Call when the service is no longer needed.
  Future<void> dispose() async {
    await stop();
    await _levelController.close();
    await _dataController.close();
    _recorder?.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  int _audioChunkCount = 0;

  /// Process incoming PCM16 audio data.
  void _onAudioData(Uint8List bytes) {
    // Convert signed 16-bit PCM (little-endian) → float32 [-1.0, 1.0].
    final samples = _pcm16ToFloat32(bytes);
    _ringBuffer.write(samples);
    _dataController.add(samples.length);

    _audioChunkCount++;
    if (_audioChunkCount % 50 == 1) {
      debugPrint('[AudioCapture] chunk #$_audioChunkCount: '
          '${samples.length} samples, '
          'totalWritten=${_ringBuffer.totalWritten}');
    }
  }

  void _onStreamError(Object error) {
    debugPrint('Audio stream error: $error');
    _state = CaptureState.error;
    _lastError = error.toString();
  }

  void _onStreamDone() {
    debugPrint('Audio stream ended');
    if (_state == CaptureState.capturing) {
      _state = CaptureState.stopped;
    }
  }

  void _emitLevel() {
    if (_state != CaptureState.capturing) return;
    final rms = _ringBuffer.rmsLevel(windowSize: 2048);
    _levelController.add(rms);
  }

  /// Convert signed 16-bit little-endian PCM bytes to Float32List [-1, 1].
  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    final result = Float32List(sampleCount);
    final byteData = ByteData.sublistView(bytes);

    for (var i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      result[i] = sample / 32768.0;
    }

    return result;
  }
}
