// =============================================================================
// session_audio_trim.dart
// =============================================================================
// Turns a session's trim range into real audio.
//
// Trimming stays reversible while the user is reviewing — Apply only records
// `LiveSession.trimStartSec` / `trimEndSec` so undo, redo and Reset all work
// — and becomes permanent when the session is saved: [commitSessionTrim] cuts
// the recording on disk, reclaims the storage and rebases the session's
// timeline onto what is left.
//
//   • [commitSessionTrim] — the destructive commit, via a staged file and a
//     rename so an interrupted cut can't lose the recording.
//   • [writeTrimmedAudioFile] — materializes the trimmed extent of a WAV or
//     FLAC recording into a new file, streaming so an hour-long source never
//     lands in memory all at once.
//   • [SessionTrimTimeline] — the trim-aware view of the session's recorded
//     timeline. Still needed after the fact: sessions saved before the commit
//     existed, and recordings in containers the slicer can't cut, keep their
//     trim as metadata, and exports rebase their offsets from it.
//
// The cut is lossless for the containers the recorder produces: WAV is copied
// frame-for-frame (preserving channel count and bit depth), FLAC is decoded
// and re-encoded through the integer PCM path with no float round-trip.
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../live/live_session.dart';
import '../../recording/audio_decoder.dart';
import '../../recording/flac_encoder.dart';
import '../../recording/wav_writer.dart';
import 'audio_share_extension.dart';

/// Shortest trim that is treated as a real trim rather than a rounding
/// artifact. Mirrors the trim editor's own floor.
const double kMinTrimSeconds = 0.25;

/// Maximum recorder tail that may be mapped past the final session segment.
///
/// Audio finalization and the wall-clock stop do not happen on the same
/// sample, so the file can legitimately outlast the session clock slightly.
const double _kMaxRecorderClockTailSeconds = 5.0;

/// The trim-aware view of a session's recorded audio timeline.
///
/// All offsets are in seconds along the *recorded* timeline — the gap-removed
/// concatenation of the session's segments that `absoluteToRelative` produces
/// — with zero at the start of the trimmed audio.
extension SessionTrimTimeline on LiveSession {
  /// Whether a usable trim range is stored on this session.
  bool get hasAudioTrim {
    if (trimStartSec == null && trimEndSec == null) return false;
    final start = math.max(0.0, trimStartSec ?? 0.0);
    final end = trimEndSec;
    if (end == null) return start > 0;
    return end - start >= kMinTrimSeconds;
  }

  /// Offset of the trimmed audio's first sample within the original
  /// recording. Zero when the session is untrimmed.
  double get trimStartSeconds =>
      hasAudioTrim ? math.max(0.0, trimStartSec ?? 0.0) : 0.0;

  /// Offset of the trimmed audio's last sample within the original
  /// recording, or null when the trim runs to the end of the recording.
  double? get trimEndSeconds => hasAudioTrim ? trimEndSec : null;

  /// Length of the audio timeline as the user sees it: the trimmed extent
  /// when a trim is set, otherwise the full recorded timeline.
  double get trimmedTimelineSeconds {
    final full =
        segments.isNotEmpty
            ? absoluteToRelative(endTime ?? DateTime.now())
            : duration.inMicroseconds / 1e6;
    if (!hasAudioTrim) return full;
    // The trim handles are placed against the *audio file*, which can run
    // slightly past the session's own clock, so the stored end is the more
    // accurate bound of the two — don't clamp it back to `full`.
    return math.max(0.0, (trimEndSec ?? full) - trimStartSeconds);
  }

  /// Offset of [timestamp] within the trimmed audio.
  ///
  /// Equivalent to `absoluteToRelative(timestamp)` on an untrimmed session;
  /// on a trimmed one the trim start is subtracted so the value indexes the
  /// exported audio file. Never negative.
  double trimmedRelative(DateTime timestamp) {
    final relative = absoluteToRelative(timestamp) - trimStartSeconds;
    return relative < 0 ? 0.0 : relative;
  }
}

/// Returns the detections whose recorded-audio intervals overlap
/// `[startSec, endSec)`.
///
/// Detection timestamps are real capture times, so trimming audio must not
/// rewrite them. Export and playback code clamp their derived audio offsets
/// to the retained range instead.
List<DetectionRecord> detectionsOverlappingTrim({
  required LiveSession session,
  required Iterable<DetectionRecord> detections,
  required double startSec,
  required double endSec,
}) {
  final windowSec = session.settings.windowDuration.toDouble();
  return [
    for (final detection in detections)
      if (() {
        final detectionStart = _absoluteToTrimRelative(
          session,
          detection.timestamp,
          endSec,
        );
        final detectionEnd =
            detection.endTimestamp == null
                ? detectionStart + windowSec
                : _absoluteToTrimRelative(
                  session,
                  detection.endTimestamp!,
                  endSec,
                );
        return detectionEnd > startSec && detectionStart < endSec;
      }())
        detection,
  ];
}

double _absoluteToTrimRelative(
  LiveSession session,
  DateTime timestamp,
  double trimEndSec,
) {
  final segments = session.segments;
  if (segments.isEmpty) return session.absoluteToRelative(timestamp);

  final ends = <DateTime>[];
  var timelineSeconds = 0.0;
  for (final segment in segments) {
    final end = segment.endTime ?? session.endTime ?? DateTime.now();
    ends.add(end);
    final length = end.difference(segment.startTime).inMicroseconds / 1e6;
    if (length > 0) timelineSeconds += length;
  }

  final tailSeconds = trimEndSec - timelineSeconds;
  if (tailSeconds > 0 && tailSeconds <= _kMaxRecorderClockTailSeconds) {
    ends[ends.length - 1] = ends.last.add(
      Duration(microseconds: (tailSeconds * 1e6).round()),
    );
  }

  var offsetMicros = 0;
  for (var i = 0; i < segments.length; i++) {
    final start = segments[i].startTime;
    final end = ends[i];
    if (timestamp.isBefore(start)) break;
    if (!timestamp.isAfter(end)) {
      offsetMicros += timestamp.difference(start).inMicroseconds;
      break;
    }
    offsetMicros += end.difference(start).inMicroseconds;
  }
  return offsetMicros / 1e6;
}

/// Resolves a session's `recordingPath` to the continuous recording file on
/// disk, or null when there isn't one.
///
/// Handles both shapes used by the app: a finalized file path (including a
/// compressed File Analysis source) or a session directory holding `full.*`.
Future<String?> resolveSessionRecordingFile(String? recordingPath) async {
  if (recordingPath == null || recordingPath.isEmpty) return null;

  if (FileSystemEntity.typeSync(recordingPath) ==
      FileSystemEntityType.notFound) {
    await _restoreInterruptedSwap(recordingPath);
  }
  if (FileSystemEntity.isFileSync(recordingPath)) {
    return recordingPath;
  }

  if (FileSystemEntity.isDirectorySync(recordingPath)) {
    const fullRecordingNames = [
      'full.flac',
      'full.wav',
      'full.wave',
      'full.mp3',
      'full.ogg',
      'full.oga',
      'full.opus',
      'full.m4a',
      'full.aac',
      'full.mp4',
      'full.wma',
      'full.amr',
    ];
    for (final name in fullRecordingNames) {
      final candidate = File(p.join(recordingPath, name));
      if (name == 'full.flac' || name == 'full.wav') {
        if (!candidate.existsSync()) {
          await _restoreInterruptedSwap(candidate.path);
        }
      }
      if (candidate.existsSync()) return candidate.path;
    }
  }
  return null;
}

/// Restores the original side of an interrupted destructive swap.
///
/// The process can stop after `source -> previous` but before
/// `trimming -> source`. In that state the audio bytes are safe but the path
/// stored by the session is missing. Reconnect the backup on the next resolve.
///
/// Both suffixes are always tried: [commitSessionTrim] names its artifacts
/// from the container it *sniffed*, which need not agree with the recording's
/// filename (a mislabeled import), and guessing from the name alone would
/// strand the only copy of the audio.
Future<void> _restoreInterruptedSwap(String sourcePath) async {
  const extensions = ['.wav', '.flac'];
  var restored = false;
  for (final extension in extensions) {
    final backup = File('$sourcePath.previous$extension');
    if (!await backup.exists()) continue;
    try {
      await backup.rename(sourcePath);
      restored = true;
      break;
    } catch (_) {
      // Leave the backup untouched for a later recovery attempt.
    }
  }
  if (!restored) return;
  // The staged cut from the interrupted commit is worthless now that the
  // original is back — and nothing else would ever clean it up.
  for (final extension in extensions) {
    await _deleteQuietly(File('$sourcePath.trimming$extension'));
  }
}

/// Outcome of [commitSessionTrim].
enum SessionTrimCommit {
  /// The session had no trim to commit.
  notNeeded,

  /// The recording was cut and the session's timeline rebased.
  applied,

  /// There is a trim, but its audio can't be cut here — no reachable
  /// recording, or a container the pure-Dart slicer doesn't handle. The trim
  /// stays as metadata and exports keep honouring it.
  unsupported,

  /// The cut was written but couldn't replace the original, most often
  /// because a player still holds the file open. The recording is intact and
  /// the trim stays as metadata.
  failed,
}

/// Cuts a session's recording down to its stored trim range, in place.
///
/// This is what makes trimming destructive: the audio outside the range is
/// gone from disk afterwards and the storage it used is reclaimed. The
/// replacement goes through a temporary file and a rename, with the original
/// held aside until the swap succeeds, so an interrupted commit can never
/// leave the session without a recording.
///
/// On success the session's timeline is rebased via
/// [LiveSession.applyDestructiveTrim] and its trim fields are cleared, so the
/// caller only has to persist the session afterwards.
///
/// Callers must release any player holding the recording first — on Windows
/// an open handle makes the swap fail outright ([SessionTrimCommit.failed]).
Future<SessionTrimCommit> commitSessionTrim(LiveSession session) async {
  if (!session.hasAudioTrim) return SessionTrimCommit.notNeeded;

  final sourcePath = await resolveSessionRecordingFile(session.recordingPath);
  if (sourcePath == null) return SessionTrimCommit.unsupported;

  final startSec = session.trimStartSeconds;
  final endSec = session.trimEndSeconds;
  final source = File(sourcePath);
  final ext = await sourceAudioExtensionForFile(source);
  final stagedPath = '$sourcePath.trimming$ext';
  final backupPath = '$sourcePath.previous$ext';

  final written = await writeTrimmedAudioFile(
    sourcePath: sourcePath,
    destPath: stagedPath,
    startSec: startSec,
    endSec: endSec,
    // Keep the recording in its original container: this replaces the file
    // the session points at, so its extension must stay honest.
    asWav: ext == '.wav',
  );
  if (written == null) return SessionTrimCommit.unsupported;

  final backup = File(backupPath);
  try {
    if (await backup.exists()) await backup.delete();
    await source.rename(backupPath);
  } catch (_) {
    // Couldn't move the original out of the way — most likely still open.
    await _deleteQuietly(written.file);
    return SessionTrimCommit.failed;
  }

  try {
    await written.file.rename(sourcePath);
  } catch (_) {
    // Put the original back so the session keeps its audio.
    try {
      await backup.rename(sourcePath);
    } catch (_) {
      // Nothing more we can do; the recording is still at [backupPath].
    }
    await _deleteQuietly(written.file);
    return SessionTrimCommit.failed;
  }

  await _deleteQuietly(backup);

  // Rebase against what was actually written, not what was requested: a
  // recording that ended early yields a shorter clip than the trim asked for.
  session.applyDestructiveTrim(
    startSec: startSec,
    endSec: startSec + written.durationSeconds,
  );
  return SessionTrimCommit.applied;
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Best-effort cleanup of a staging artifact.
  }
}

/// Result of a successful [writeTrimmedAudioFile] call.
class TrimmedAudioFile {
  const TrimmedAudioFile({
    required this.file,
    required this.durationSeconds,
    required this.extension,
  });

  final File file;

  /// Length of the written audio, which may be shorter than the requested
  /// range when the recording ends early (a truncated session).
  final double durationSeconds;

  /// Container extension of the written file, `.wav` or `.flac`.
  final String extension;
}

/// Frames copied per iteration when slicing a WAV payload (~2 MB at 16-bit
/// mono 32 kHz). Bounds peak memory without making the copy syscall-bound.
const int _kWavCopyFrames = 1 << 20;

/// Writes `[startSec, endSec)` of [sourcePath] to [destPath].
///
/// Supports the containers the recorder writes (WAV and FLAC) plus WAV files
/// imported through File Analysis. [asWav] forces WAV output for a FLAC
/// source; a WAV source always stays WAV.
///
/// Returns null when the source can't be sliced (unsupported container,
/// unreadable header, or a range that lands outside the audio), leaving it
/// to the caller to fall back to the untrimmed file.
Future<TrimmedAudioFile?> writeTrimmedAudioFile({
  required String sourcePath,
  required String destPath,
  required double startSec,
  double? endSec,
  bool asWav = false,
}) async {
  // Every supported writer opens [destPath] in truncating mode. Refuse an
  // accidental in-place call before touching either path; commit/export use
  // separate staged files, but this public helper should be safe on its own.
  if (p.equals(p.absolute(sourcePath), p.absolute(destPath))) return null;

  final source = File(sourcePath);
  if (!await source.exists()) return null;
  if (startSec < 0) startSec = 0;
  if (endSec != null && endSec <= startSec) return null;

  final dest = File(destPath);
  await dest.parent.create(recursive: true);
  if (await dest.exists()) {
    try {
      await dest.delete();
    } catch (_) {
      // A stale export artifact we can't remove — writing over it below
      // still truncates, so this is not fatal.
    }
  }

  TrimmedAudioFile? result;
  try {
    if (await AudioDecoder.isWav(sourcePath)) {
      result = await _trimWav(
        source: source,
        dest: dest,
        startSec: startSec,
        endSec: endSec,
      );
    } else if (await AudioDecoder.canDecodeDart(sourcePath)) {
      result = await _trimFlac(
        sourcePath: sourcePath,
        dest: dest,
        startSec: startSec,
        endSec: endSec,
        asWav: asWav,
      );
    }
  } on FormatException {
    // Header we can't parse — caller falls back to the untrimmed file.
  } on FileSystemException {
    // Source vanished or the destination isn't writable.
  }
  if (result == null) await _deleteQuietly(dest);
  return result;
}

/// Copies the requested frame range out of a WAV payload verbatim.
///
/// The copy is byte-exact, so an imported stereo or 24-bit file keeps its
/// format instead of being flattened to the app's mono 16-bit recording
/// shape. Only the RIFF header is rewritten.
Future<TrimmedAudioFile?> _trimWav({
  required File source,
  required File dest,
  required double startSec,
  double? endSec,
}) async {
  final layout = await AudioDecoder.inspectWavLayout(source.path);
  final frameSize = layout.frameSize;
  final totalFrames = layout.totalFrames;
  if (frameSize <= 0 || totalFrames <= 0 || layout.sampleRate <= 0) return null;

  final startFrame = (startSec * layout.sampleRate).floor().clamp(
    0,
    totalFrames,
  );
  final endFrame = (endSec == null
          ? totalFrames
          : (endSec * layout.sampleRate).round().clamp(0, totalFrames))
      .clamp(startFrame, totalFrames);
  final frameCount = endFrame - startFrame;
  if (frameCount <= 0) return null;

  final input = await source.open();
  final output = await dest.open(mode: FileMode.write);
  try {
    await output.writeFrom(
      _wavHeader(layout: layout, dataSize: frameCount * frameSize),
    );
    await input.setPosition(layout.dataOffset + startFrame * frameSize);
    var remaining = frameCount;
    while (remaining > 0) {
      final chunkFrames = math.min(remaining, _kWavCopyFrames);
      final bytes = await input.read(chunkFrames * frameSize);
      // A short read means the file ends before the requested range (a
      // truncated recording); stop and report the honest length below. Drop
      // any partial trailing frame rather than writing bytes the rewritten
      // `data` size wouldn't cover.
      final framesRead = bytes.length ~/ frameSize;
      if (framesRead <= 0) break;
      await output.writeFrom(
        framesRead * frameSize == bytes.length
            ? bytes
            : Uint8List.sublistView(bytes, 0, framesRead * frameSize),
      );
      remaining -= framesRead;
      if (framesRead < chunkFrames) break;
    }
    final written = frameCount - remaining;
    if (written <= 0) {
      await output.truncate(0);
      return null;
    }
    if (written != frameCount) {
      // Rewrite the header with what actually made it to disk.
      await output.setPosition(0);
      await output.writeFrom(
        _wavHeader(layout: layout, dataSize: written * frameSize),
      );
    }
    await output.flush();
    return TrimmedAudioFile(
      file: dest,
      durationSeconds: written / layout.sampleRate,
      extension: '.wav',
    );
  } finally {
    await input.close();
    await output.close();
  }
}

/// Canonical 44-byte RIFF header for [layout]'s format and [dataSize] bytes
/// of payload.
Uint8List _wavHeader({required WavLayout layout, required int dataSize}) {
  final bytes = Uint8List(44);
  final view = ByteData.sublistView(bytes);
  final byteRate =
      layout.sampleRate * layout.channels * (layout.bitsPerSample ~/ 8);

  bytes.setRange(0, 4, const [0x52, 0x49, 0x46, 0x46]); // 'RIFF'
  view.setUint32(4, 36 + dataSize, Endian.little);
  bytes.setRange(8, 12, const [0x57, 0x41, 0x56, 0x45]); // 'WAVE'
  bytes.setRange(12, 16, const [0x66, 0x6D, 0x74, 0x20]); // 'fmt '
  view.setUint32(16, 16, Endian.little);
  view.setUint16(
    20,
    layout.audioFormat == 0 ? 1 : layout.audioFormat,
    Endian.little,
  );
  view.setUint16(22, layout.channels, Endian.little);
  view.setUint32(24, layout.sampleRate, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, layout.frameSize, Endian.little);
  view.setUint16(34, layout.bitsPerSample, Endian.little);
  bytes.setRange(36, 40, const [0x64, 0x61, 0x74, 0x61]); // 'data'
  view.setUint32(40, dataSize, Endian.little);
  return bytes;
}

/// Streams the requested sample range out of a FLAC file, re-encoding it as
/// FLAC (or writing it as WAV when [asWav] is set).
///
/// Decoding is a single forward pass over the source, frame by frame, so
/// memory stays flat regardless of how long the recording is.
Future<TrimmedAudioFile?> _trimFlac({
  required String sourcePath,
  required File dest,
  required double startSec,
  double? endSec,
  required bool asWav,
}) async {
  final sampleRate = await AudioDecoder.flacSampleRate(sourcePath);
  if (sampleRate <= 0) return null;

  final startSample = math.max(0, (startSec * sampleRate).floor());
  final endSample =
      endSec == null
          ? null
          : math.max(startSample, (endSec * sampleRate).round());
  if (endSample != null && endSample <= startSample) return null;

  final wavWriter =
      asWav ? WavWriter(filePath: dest.path, sampleRate: sampleRate) : null;
  final flacEncoder =
      asWav ? null : FlacEncoder(filePath: dest.path, sampleRate: sampleRate);
  await (wavWriter?.open() ?? flacEncoder!.open());

  // A trim that starts well into the recording would otherwise bit-decode
  // everything before it just to throw it away — ~19 s for a cut an hour in.
  // The index costs one linear scan (~0.6 s for an hour), so only reach for
  // it when there is meaningfully more than that to skip; exports that start
  // at zero, which is most of them, take the untouched path.
  final seekIndex =
      startSample > sampleRate * 60
          ? await AudioDecoder.buildFlacSeekIndex(sourcePath)
          : null;

  var written = 0;
  var failed = false;
  try {
    await AudioDecoder.decodeFlacFrames(
      sourcePath,
      seekIndex: seekIndex,
      fromSample: startSample,
      onFrame: (frameStart, samples) async {
        final frameEnd = frameStart + samples.length;
        if (frameEnd <= startSample) return true; // Before the range.
        if (endSample != null && frameStart >= endSample) return false; // Past.

        final from = math.max(0, startSample - frameStart);
        final to =
            endSample == null
                ? samples.length
                : math.min(samples.length, endSample - frameStart);
        if (to <= from) return endSample == null || frameEnd < endSample;

        final slice =
            (from == 0 && to == samples.length)
                ? samples
                : Int16List.sublistView(samples, from, to);
        if (wavWriter != null) {
          await wavWriter.writeSamplesPcm16(slice);
        } else {
          await flacEncoder!.writeSamplesPcm16(slice);
        }
        written += slice.length;
        return endSample == null || frameEnd < endSample;
      },
    );
  } catch (_) {
    failed = true;
  } finally {
    await (wavWriter?.close() ?? flacEncoder!.close());
  }

  if (failed || written <= 0) {
    try {
      if (await dest.exists()) await dest.delete();
    } catch (_) {
      // Best-effort cleanup of a partial artifact.
    }
    return null;
  }

  return TrimmedAudioFile(
    file: dest,
    durationSeconds: written / sampleRate,
    extension: asWav ? '.wav' : '.flac',
  );
}
