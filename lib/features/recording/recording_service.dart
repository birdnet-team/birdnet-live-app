// =============================================================================
// Recording Service — Manages audio recording during live sessions
// =============================================================================
//
// Supports three recording modes:
//
//   • **off** — no recording.
//   • **full** — continuous recording of all captured audio.
//   • **detectionsOnly** — saves audio clips around detections.
//
// For continuous recording, the service periodically reads from the ring
// buffer and appends to a streaming WAV writer.  For detection-only mode,
// it saves a clip (pre-buffer + post-buffer) around each detection event.
//
// ### File layout
//
// Recordings are stored under the app's documents directory:
//
// ```
// <appDir>/recordings/<sessionId>/
//   full.wav              ← continuous recording (if mode = full)
//   clip_<timestamp>.wav  ← detection clips (if mode = detectionsOnly)
// ```
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../audio/ring_buffer.dart';
import 'wav_writer.dart';

/// Recording mode for live sessions.
enum RecordingMode {
  /// No recording.
  off,

  /// Continuous recording of all audio.
  full,

  /// Save clips around detected species only.
  detectionsOnly,
}

/// Parses a [RecordingMode] from its string name.
///
/// Returns [RecordingMode.off] for unrecognised values.
RecordingMode recordingModeFromString(String value) {
  switch (value) {
    case 'full':
      return RecordingMode.full;
    case 'detections':
    case 'detectionsOnly':
      return RecordingMode.detectionsOnly;
    default:
      return RecordingMode.off;
  }
}

/// Manages audio recording during a live identification session.
///
/// Lifecycle: [startRecording] → [saveDetectionClip] / periodic flush →
/// [stopRecording].
class RecordingService {
  RecordingService({
    required this.ringBuffer,
    this.sampleRate = 32000,
    this.preBufferSeconds = 5,
    this.postBufferSeconds = 5,
  });

  /// The shared ring buffer to read audio from.
  final RingBuffer ringBuffer;

  /// Audio sample rate in Hz.
  final int sampleRate;

  /// Seconds of audio to include before a detection.
  final int preBufferSeconds;

  /// Seconds of audio to include after a detection.
  final int postBufferSeconds;

  WavWriter? _writer;
  Timer? _flushTimer;
  String? _sessionDir;
  RecordingMode _mode = RecordingMode.off;
  bool _isRecording = false;
  int _lastFlushPosition = 0;

  /// Whether a recording is currently in progress.
  bool get isRecording => _isRecording;

  /// Current recording mode.
  RecordingMode get mode => _mode;

  /// Path to the session recording directory.
  String? get sessionDir => _sessionDir;

  /// Start recording for the given session.
  ///
  /// [sessionId] is used to create the output directory.
  /// [mode] determines the recording behaviour.
  Future<String?> startRecording({
    required String sessionId,
    required RecordingMode mode,
  }) async {
    if (mode == RecordingMode.off) return null;
    if (_isRecording) return _sessionDir;

    _mode = mode;
    _isRecording = true;

    final appDir = await getApplicationDocumentsDirectory();
    _sessionDir = '${appDir.path}/recordings/$sessionId';
    await Directory(_sessionDir!).create(recursive: true);

    if (mode == RecordingMode.full) {
      final filePath = '$_sessionDir/full.wav';
      _writer = WavWriter(filePath: filePath, sampleRate: sampleRate);
      await _writer!.open();
      _lastFlushPosition = ringBuffer.totalWritten;

      // Periodically flush ring buffer to file (every 1 second).
      _flushTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _flushBuffer(),
      );
    }

    return _sessionDir;
  }

  /// Save an audio clip around a detection.
  ///
  /// Reads `preBufferSeconds + postBufferSeconds` of audio from the ring
  /// buffer centred on the current write position (i.e., the detection
  /// just happened).
  ///
  /// Returns the file path of the saved clip, or `null` if not recording.
  Future<String?> saveDetectionClip({
    required String clipName,
  }) async {
    if (!_isRecording || _sessionDir == null) return null;

    final totalSamples = (preBufferSeconds + postBufferSeconds) * sampleRate;
    final samples = ringBuffer.readLast(totalSamples);

    // Skip silent clips (all zeros = no audio captured yet).
    if (_isAllSilent(samples)) return null;

    final filePath = '$_sessionDir/$clipName.wav';
    await WavWriter.writeFile(
      filePath: filePath,
      samples: samples,
      sampleRate: sampleRate,
    );

    return filePath;
  }

  /// Stop the ongoing recording and finalise any open files.
  ///
  /// Returns the path to the full recording file (if mode was `full`)
  /// or the session directory (if mode was `detectionsOnly`).
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _isRecording = false;
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_mode == RecordingMode.full && _writer != null) {
      // Final flush.
      await _flushBuffer();
      await _writer!.close();
      final path = _writer!.filePath;
      _writer = null;
      return path;
    }

    final dir = _sessionDir;
    _sessionDir = null;
    _mode = RecordingMode.off;
    return dir;
  }

  /// Dispose of all resources.
  void dispose() {
    _flushTimer?.cancel();
    if (_writer?.isOpen == true) {
      _writer!.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Flush new audio data from the ring buffer into the WAV writer.
  Future<void> _flushBuffer() async {
    if (_writer == null || !_writer!.isOpen) return;

    final currentTotal = ringBuffer.totalWritten;
    final newSamples = currentTotal - _lastFlushPosition;

    if (newSamples <= 0) return;

    // Read only the new samples since last flush.
    final samplesToRead =
        newSamples > ringBuffer.capacity ? ringBuffer.capacity : newSamples;
    final samples = ringBuffer.readLast(samplesToRead);

    await _writer!.writeSamples(samples);
    _lastFlushPosition = currentTotal;
  }

  /// Check if all samples in the buffer are zero (silent).
  static bool _isAllSilent(Float32List samples) {
    for (var i = 0; i < samples.length; i++) {
      if (samples[i] != 0.0) return false;
    }
    return true;
  }
}
