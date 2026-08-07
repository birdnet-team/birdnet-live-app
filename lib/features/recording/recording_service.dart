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
//   full.wav                        ← continuous recording (if mode = full)
//   clip_<timestamp>_<species>.wav  ← detection clips (if detectionsOnly)
// ```
//
// ### Peak-window clips
//
// A merged detection spans every consecutive inference window in which the
// species stayed above threshold — often far more than the single analyzed
// window a clip holds. Rather than keep the *first* window (which is usually
// the weakest, since birds enter near the confidence floor and peak later),
// callers re-cut the clip whenever the detection reaches a new confidence
// peak: see [DetectionClipPeakTracker] and [kClipPeakImprovementDelta]. The
// replacement is published before [RecordingService.deleteClip] removes the
// old file. The clip a session ends up with
// therefore comes from the strongest window of the detection, matching the
// confidence stored on the record.
//
// Clip file names embed the species so each record owns exactly one file —
// re-cutting or evicting one detection's clip can never delete audio another
// record still points at.
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../audio/ring_buffer.dart';
import 'audio_file_writer.dart';
import 'flac_encoder.dart';
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

/// Minimum confidence gain required before a detection's clip is re-cut at a
/// stronger analysis window.
///
/// A merged detection's confidence is the running maximum over its windows,
/// so without a margin every marginal uptick near the peak would rewrite the
/// clip file. At 0.05 a re-cut only happens for a meaningfully better window,
/// which in practice means a handful of writes per detection at most.
const double kClipPeakImprovementDelta = 0.05;

/// Tracks the confidence represented by each detection's clip on disk, and
/// decides when a detection wants a clip cut.
///
/// This is the single peak-retention rule for the whole app: Live, Survey and
/// ARU each own an instance and ask it the same question every round, so the
/// same bird produces the same clip whichever mode heard it. Only the
/// *subsampling* that runs afterwards — which clips survive to the end of a
/// session — is deliberately per-mode.
///
/// A detection record's confidence is updated for every stronger inference
/// window, including improvements too small to justify an immediate re-cut.
/// Comparing a future score to the record would therefore lose cumulative
/// gains (for example 0.50 -> 0.53 -> 0.56). This tracker keeps the clip's
/// actual baseline separate from the record's running maximum.
class DetectionClipPeakTracker {
  DetectionClipPeakTracker({this.improvementDelta = kClipPeakImprovementDelta})
    : assert(improvementDelta >= 0);

  final double improvementDelta;
  final Map<String, double> _savedConfidenceByKey = {};

  /// Whether a clip should be cut for [key] from the audio available now.
  ///
  /// A detection that has no clip yet gets one — on arrival ([isNew]), or on
  /// any later improvement if the earlier attempt produced no file. A
  /// detection that already has a clip only replaces it once it beats the
  /// confidence that clip actually represents by [improvementDelta].
  ///
  /// [currentConfidence] is the detection record's running maximum. Requiring
  /// a genuinely newer peak prevents a failed save from retrying every round
  /// while the score is unchanged.
  bool needsClip({
    required String key,
    required double candidateConfidence,
    required double currentConfidence,
    required bool hasClip,
    required bool isNew,
  }) {
    if (!candidateConfidence.isFinite) return false;
    if (!hasClip) return isNew || candidateConfidence > currentConfidence;
    // An arriving detection that already carries a clip keeps it; re-cutting
    // is for detections we have watched improve.
    if (isNew || candidateConfidence <= currentConfidence) return false;

    final savedConfidence = _savedConfidenceByKey[key] ?? currentConfidence;
    // Absorb binary floating-point noise at exact boundaries such as
    // 0.60 - 0.55, which is slightly less than 0.05 on some runtimes.
    const epsilon = 1e-12;
    return candidateConfidence - savedConfidence + epsilon >= improvementDelta;
  }

  /// Record a successful clip save at [confidence].
  void recordSaved(String key, double confidence) {
    if (confidence.isFinite) _savedConfidenceByKey[key] = confidence;
  }

  /// Stop tracking a closed detection.
  void forget(String key) => _savedConfidenceByKey.remove(key);

  /// Reset all state at a session boundary.
  void clear() => _savedConfidenceByKey.clear();
}

/// Builds a unique clip file name for a detection of [scientificName].
///
/// The species is slugged into the name so every record owns its own file:
/// two species detected in the same inference cycle get distinct clips, and
/// re-cutting one detection's clip never touches another's. [savedAt] and
/// [sequence] keep successive re-cuts of the same species distinct so the new
/// file is written before the old one is deleted.
String detectionClipName(
  String scientificName,
  DateTime savedAt, {
  int sequence = 0,
}) {
  final slug = scientificName.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  return 'clip_${savedAt.microsecondsSinceEpoch}_${sequence}_$slug';
}

/// Cut one detection clip per entry in [items], all from the same audio.
///
/// Live, Survey and ARU all reach the same point in a round: several
/// detections want a clip of the window that just played. Cutting them
/// together costs one post-roll wait for the round instead of one per
/// detection, and — more importantly for consistency — anchors every clip in
/// the round to the same moment. Cutting them one at a time makes each clip
/// after the first read the ring buffer later than the window that earned the
/// score, so the same bird would land on a different window depending on how
/// many other species happened to peak alongside it.
///
/// [speciesOf] supplies the scientific name that goes into each file name.
/// [windowEndSample] anchors the clip to the analysis window that earned the
/// score; see [RecordingService.saveDetectionClips].
/// Returns the written path per item; items whose clip could not be written
/// are absent from the map.
Future<Map<T, String>> saveDetectionClipsFor<T>({
  required RecordingService recordingService,
  required List<T> items,
  required String Function(T item) speciesOf,
  int? windowEndSample,
}) async {
  if (items.isEmpty) return const {};

  final namesByItem = {
    for (final item in items)
      item: recordingService.nextDetectionClipName(speciesOf(item)),
  };
  final written = await recordingService.saveDetectionClips(
    clipNames: namesByItem.values.toList(),
    windowEndSample: windowEndSample,
  );

  return {
    for (final entry in namesByItem.entries)
      if (written[entry.value] != null) entry.key: written[entry.value]!,
  };
}

/// Parses a [RecordingMode] from its string name.
///
/// Returns [RecordingMode.off] for unrecognized values.
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
    this.clipContextSeconds = 1,
    int windowSeconds = 3,
  }) : _windowSeconds = windowSeconds;

  /// The shared ring buffer to read audio from.
  final RingBuffer ringBuffer;

  /// Audio sample rate in Hz.
  final int sampleRate;

  /// Seconds of audio captured before AND after each detection window.
  ///
  /// A clip is `windowSeconds + 2 * clipContextSeconds` long, centered on
  /// the analyzed audio window that triggered the detection.
  final int clipContextSeconds;

  /// Length of the inference window in seconds (typically 3).
  ///
  /// Used together with [clipContextSeconds] to compute the total clip
  /// length saved per detection, so a clip covers the whole window the model
  /// scored rather than just its tail. Live, Point Count and Survey let the
  /// user pick 3, 5 or 10 seconds per session, so this follows the session
  /// (see [setWindowSeconds]) instead of being fixed at construction.
  int get windowSeconds => _windowSeconds;
  int _windowSeconds;

  /// Match the clip length to the analysis window of the session starting now.
  ///
  /// Ignored while a recording is open: the clip length has to stay put for
  /// the lifetime of a session, or clips cut before and after the change would
  /// describe different spans of audio under the same [clipTimestamp] rule.
  void setWindowSeconds(int value) {
    if (_isRecording || value <= 0) return;
    _windowSeconds = value;
  }

  AudioFileWriter? _writer;
  Timer? _flushTimer;
  String? _sessionDir;
  RecordingMode _mode = RecordingMode.off;
  String _format = 'flac';
  bool _isRecording = false;
  bool _flushing = false;
  int _lastFlushPosition = 0;
  int _nextClipSequence = 0;
  int _recordingGeneration = 0;

  /// Whether a recording is currently in progress.
  bool get isRecording => _isRecording;

  /// Current recording mode.
  RecordingMode get mode => _mode;

  /// Current audio file format ('wav' or 'flac').
  String get format => _format;

  /// Path to the session recording directory.
  String? get sessionDir => _sessionDir;

  /// Return a collision-resistant name for the next detection clip.
  ///
  /// The per-service sequence disambiguates saves that share the same system
  /// clock tick and species name. This matters for replacement safety: a
  /// re-cut must never overwrite the old file before the new one is complete.
  String nextDetectionClipName(String scientificName, {DateTime? savedAt}) {
    return detectionClipName(
      scientificName,
      savedAt ?? DateTime.now(),
      sequence: _nextClipSequence++,
    );
  }

  /// Start recording for the given session.
  ///
  /// [sessionId] is used to create the output directory.
  /// [mode] determines the recording behavior.
  Future<String?> startRecording({
    required String sessionId,
    required RecordingMode mode,
    String format = 'flac',
  }) async {
    if (mode == RecordingMode.off) return null;
    if (_isRecording) return _sessionDir;

    _mode = mode;
    _format = format;
    _isRecording = true;
    _recordingGeneration++;

    final appDir = await getApplicationDocumentsDirectory();
    _sessionDir = '${appDir.path}/recordings/$sessionId';
    await Directory(_sessionDir!).create(recursive: true);

    if (mode == RecordingMode.full) {
      final ext = format == 'flac' ? 'flac' : 'wav';
      final filePath = '$_sessionDir/full.$ext';
      _writer =
          format == 'flac'
              ? FlacEncoder(filePath: filePath, sampleRate: sampleRate)
              : WavWriter(filePath: filePath, sampleRate: sampleRate);
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
  /// The detection callback fires at the end of an inference window, so the
  /// last [windowSeconds] of audio represent the analyzed chunk. To capture
  /// genuine "context" on both sides we (a) wait [clipContextSeconds] for
  /// post-roll audio to land in the ring buffer, then (b) read the most
  /// recent `windowSeconds + 2 * clipContextSeconds` seconds. The result
  /// is a clip of `[pre-context | analyzed window | post-context]`.
  ///
  /// Returns the file path of the saved clip, or `null` if not recording.
  Future<String?> saveDetectionClip({required String clipName}) async {
    final saved = await saveDetectionClips(clipNames: [clipName]);
    return saved[clipName];
  }

  /// Save one clip per entry in [clipNames], all cut from the same audio.
  ///
  /// Several species commonly hit a new confidence peak in the same inference
  /// cycle, and they all want the *same* stretch of audio. Waiting for
  /// post-roll and reading the ring buffer once — then writing N files from
  /// that one snapshot — keeps a busy cycle to a single
  /// [clipContextSeconds] delay instead of one per species.
  ///
  /// [windowEndSample] is the analysis window's exclusive end on the ring
  /// buffer's absolute sample timeline ([RingBuffer.totalWritten]). Passing it
  /// pins the clip to the audio the model actually scored instead of to
  /// whatever is newest when the write runs. The two coincide while inference
  /// keeps up with capture; they diverge when it falls behind, and then only
  /// the anchored read still holds the sound that earned the confidence.
  /// Callers with no window to point at (ARU's end-of-cycle clip pass) omit it
  /// and get the newest audio. An anchored read whose range has been
  /// overwritten is skipped rather than mislabeled as the requested window.
  ///
  /// Returns a map of clip name → written file path. Names whose clip could
  /// not be written (not recording, or silent audio) are absent from the map.
  Future<Map<String, String>> saveDetectionClips({
    required List<String> clipNames,
    int? windowEndSample,
  }) async {
    if (clipNames.isEmpty) return const {};
    if (!_isRecording || _sessionDir == null) return const {};
    final generation = _recordingGeneration;

    if (clipContextSeconds > 0) {
      await Future<void>.delayed(Duration(seconds: clipContextSeconds));
      // Recording may have been stopped while we were waiting for post-roll.
      if (!_isRecording ||
          _sessionDir == null ||
          generation != _recordingGeneration) {
        return const {};
      }
    }

    final sessionDir = _sessionDir!;
    final format = _format;
    final totalSeconds = windowSeconds + 2 * clipContextSeconds;
    final totalSamples = totalSeconds * sampleRate;
    final samples = _readClipAudio(totalSamples, windowEndSample);

    // The anchored audio is gone, so no file here could hold what the caller
    // is about to say it holds. The detection keeps its score and simply has
    // no clip; a later, stronger window will ask again.
    if (samples == null) {
      debugPrint(
        '[RecordingService] window ending at $windowEndSample is no longer '
        'available; skipping ${clipNames.length} clip(s)',
      );
      return const {};
    }

    // Skip silent clips (all zeros = no audio captured yet).
    if (_isAllSilent(samples)) return const {};

    final ext = format == 'flac' ? 'flac' : 'wav';
    final written = <String, String>{};
    for (final clipName in clipNames.toSet()) {
      final filePath = '$sessionDir/$clipName.$ext';
      try {
        if (format == 'flac') {
          await FlacEncoder.writeFile(
            filePath: filePath,
            samples: samples,
            sampleRate: sampleRate,
          );
        } else {
          await WavWriter.writeFile(
            filePath: filePath,
            samples: samples,
            sampleRate: sampleRate,
          );
        }
        written[clipName] = filePath;
      } catch (e, st) {
        debugPrint(
          '[RecordingService] failed to save clip "$clipName": $e\n$st',
        );
        await deleteClip(filePath);
      }
    }

    return written;
  }

  /// Read the [totalSamples] a clip should contain.
  ///
  /// With a [windowEndSample] the clip ends [clipContextSeconds] of post-roll
  /// after the analysis window, which puts the same audio in the file whether
  /// the write ran promptly or the buffer moved on in the meantime.
  ///
  /// Returns null when that audio can no longer be read — the post-roll has
  /// not been captured (capture stalled, e.g. another app took the mic), or
  /// the range has already been overwritten. Substituting the newest audio
  /// there would write a file the caller then dates as the analysis window,
  /// which is the mismatch the anchor exists to prevent.
  ///
  /// Without an anchor the newest audio *is* the answer: [saveDetectionClip]
  /// and ARU's end-of-cycle pass have no particular window in mind.
  Float32List? _readClipAudio(int totalSamples, int? windowEndSample) {
    if (windowEndSample == null) return ringBuffer.readLast(totalSamples);

    final endSample = windowEndSample + clipContextSeconds * sampleRate;
    final startSample = endSample - totalSamples;
    final oldestRetained = ringBuffer.totalWritten - ringBuffer.available;
    if (endSample > ringBuffer.totalWritten) {
      return null;
    }

    if (startSample < oldestRetained) {
      // The first analysis window can legitimately ask for pre-roll before
      // sample zero. That audio never existed, so zero-padding it preserves
      // the complete analyzed window and post-roll without substituting any
      // later sound. Once the buffer has wrapped, however, the missing prefix
      // was overwritten and the requested clip must be skipped.
      if (startSample >= 0 || oldestRetained != 0) return null;

      final availableSamples = ringBuffer.readEndingAt(endSample, endSample);
      final padded = Float32List(totalSamples);
      padded.setRange(-startSample, totalSamples, availableSamples);
      return padded;
    }
    return ringBuffer.readEndingAt(totalSamples, endSample);
  }

  /// Delete a detection clip file, swallowing and logging I/O errors.
  Future<void> deleteClip(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[RecordingService] failed to delete clip: $e');
    }
  }

  /// Stop the ongoing recording and finalize any open files.
  ///
  /// Returns the path to the full recording file (if mode was `full`)
  /// or the session directory (if mode was `detectionsOnly`).
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _isRecording = false;
    _recordingGeneration++;
    _flushTimer?.cancel();
    _flushTimer = null;

    // Wait for any in-progress flush to finish before the final one.
    while (_flushing) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    if (_mode == RecordingMode.full && _writer != null) {
      // Final flush (timer is canceled, no concurrency risk).
      await _flushBuffer();
      await _writer!.close();
      final path = _writer!.filePath;

      int samples = 0;
      final writer = _writer;
      if (writer is FlacEncoder) {
        samples = writer.totalSamples;
      } else if (writer is WavWriter) {
        samples = writer.samplesWritten;
      }

      _writer = null;
      _sessionDir = null;
      _mode = RecordingMode.off;

      if (samples == 0) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            await file.delete();
          }
        } catch (_) {}
        return null;
      }

      return path;
    }

    final dir = _sessionDir;
    _sessionDir = null;
    _mode = RecordingMode.off;
    return dir;
  }

  /// Dispose of all resources.
  void dispose() {
    _isRecording = false;
    _recordingGeneration++;
    _flushTimer?.cancel();
    if (_writer?.isOpen == true) {
      _writer!.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Flush new audio data from the ring buffer into the file writer.
  ///
  /// Guarded by [_flushing] to prevent concurrent calls — the periodic
  /// timer can fire while a previous flush (FLAC encoding + I/O) is still
  /// running.  Without this guard, overlapping flushes corrupt the
  /// encoder's internal buffer and cause unbounded memory growth.
  Future<void> _flushBuffer() async {
    if (_flushing) return;
    if (_writer == null || !_writer!.isOpen) return;

    _flushing = true;
    try {
      final currentTotal = ringBuffer.totalWritten;
      final newSamples = currentTotal - _lastFlushPosition;

      if (newSamples <= 0) return;

      // Read only the new samples since last flush.
      final samplesToRead =
          newSamples > ringBuffer.capacity ? ringBuffer.capacity : newSamples;
      final samples = ringBuffer.readLast(samplesToRead);

      await _writer!.writeSamples(samples);
      _lastFlushPosition = currentTotal;
    } finally {
      _flushing = false;
    }
  }

  /// Check if all samples in the buffer are zero (silent).
  static bool _isAllSilent(Float32List samples) {
    for (var i = 0; i < samples.length; i++) {
      if (samples[i] != 0.0) return false;
    }
    return true;
  }
}
