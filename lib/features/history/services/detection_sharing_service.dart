// =============================================================================
// detection_sharing_service.dart
// =============================================================================
// Builds a share payload for a single [DetectionRecord] and hands it to
// `share_plus`. The payload is intentionally terse and field-tool friendly:
//
//   BirdNET Live — Eurasian Wren (Troglodytes troglodytes)
//   87% · 2026-05-06T13:45:22Z
//   geo:50.7374,7.0982
//
// Lat/lon are emitted as a `geo:` URI so any maps app on the receiving device
// can open them directly. Coordinates are clamped to 4 decimal places (~11 m
// precision) to avoid leaking sub-meter device fingerprints when the
// recipient might re-share publicly. Timestamp is UTC (ISO 8601) — recipients
// in other timezones never have to guess what "13:45" means.
//
// Audio attachment cascade (best → worst):
//
//   1. The detection has a kept per-detection clip on disk — stage and ship.
//   2. The host passed an in-progress [LiveSession] with a full recording
//      — slice the relevant `windowDuration + 2 × clipContextSeconds` window
//      out of the file and ship that. Both WAV and FLAC full recordings are
//      supported; the slice is shipped in the same container as the source
//      (WAV in, WAV out; FLAC in, FLAC out) so the recipient gets a file
//      whose extension matches its bytes. This is what makes "share" work
//      mid-survey when the user opted for a single continuous recording
//      instead of per-detection clips.
//   3. No audio at all (recording mode = off, or the full recording is in
//      a container we don't know how to slice) — share text only. Location
//      + timestamp still land in the payload via [_buildBody].
//
// Both audio paths use the same human-readable subject so threaded chat apps
// group them sensibly.
//
// This is a thin wrapper, not a stateful service — exposed as a top-level
// function so callers don't need a provider just to share one detection.
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../live/live_session.dart';
import '../../recording/audio_decoder.dart';
import '../../recording/flac_encoder.dart';

/// Share a single [detection] using the platform share sheet.
///
/// When [session] is provided and the detection has no per-detection clip
/// of its own, the function will try to slice the relevant audio window
/// out of the session's full recording (WAV or FLAC). The slice ships in
/// the same container as the source. Falls back to text-only sharing
/// when no audio is available.
///
/// Returns the [ShareResult] from `share_plus` so callers can react to
/// dismissal vs. successful share if they want — most callers can ignore it.
Future<ShareResult> shareDetection(
  DetectionRecord detection, {
  LiveSession? session,
}) async {
  final body = _buildBody(detection);
  final subject = _buildSubject(detection);

  // 1) Per-detection clip wins when present — it was recorded with the
  //    correct context padding at the moment of detection.
  final clipPath = detection.audioClipPath;
  if (clipPath != null && File(clipPath).existsSync()) {
    final staged = await _stageClipForShare(File(clipPath), detection);
    return SharePlus.instance.share(
      ShareParams(files: [XFile(staged.path)], text: body, subject: subject),
    );
  }

  // 2) Try to slice from the session's full recording. Both WAV and
  //    FLAC continuous recordings are supported; the slice ships in
  //    the same container as the source.
  if (session != null) {
    final extracted = await _extractClipFromFullAudio(session, detection);
    if (extracted != null) {
      return SharePlus.instance.share(
        ShareParams(
          files: [XFile(extracted.path)],
          text: body,
          subject: subject,
        ),
      );
    }
  }

  // 3) No audio available — share text only. The body still carries
  //    location + timestamp so the recipient gets the full picture.
  return SharePlus.instance.share(ShareParams(text: body, subject: subject));
}

/// Copies [clip] into the temp dir under the export-style filename so the
/// share sheet exposes a friendly name. Reuses an existing staged file when
/// the names already match to avoid extra IO on repeat shares.
Future<File> _stageClipForShare(File clip, DetectionRecord d) async {
  final ext = p.extension(clip.path);
  final name = _exportClipName(d, ext);
  final tmp = await getTemporaryDirectory();
  final shareDir = Directory(p.join(tmp.path, 'shared_clips'));
  if (!shareDir.existsSync()) shareDir.createSync(recursive: true);
  final target = File(p.join(shareDir.path, name));
  // Always overwrite: the source clip may have been re-encoded since
  // the previous share and the cost is a single small file copy.
  await clip.copy(target.path);
  return target;
}

/// Builds the share filename for a single detection clip.
///
/// Mirrors the ZIP export scheme (`BirdNET_Live_<dt>_clip_NNN_<species>.<ext>`)
/// but drops the per-session sequence number since a single share has no
/// containing collection. The detection's own timestamp anchors the name.
String _exportClipName(DetectionRecord d, String ext) {
  final dt = DateFormat('yyyy-MM-dd_HH-mm-ss').format(d.timestamp.toLocal());
  final species = _sanitizeFilename(
    d.commonName.trim().isNotEmpty ? d.commonName : d.scientificName,
  );
  return 'BirdNET_Live_${dt}_$species$ext';
}

/// Replaces filesystem-illegal characters with underscores and collapses
/// runs of whitespace/underscores. Kept in sync with the equivalent helper
/// in `session_export.dart` so shared clips and exported clips match.
String _sanitizeFilename(String input) {
  return input
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

/// Locates the full-audio file for [session] and slices the audio window
/// around [detection] into a fresh file in temp storage.
///
/// Returns `null` when no usable full recording is found (no
/// `recordingPath`, missing file, unsupported container) so the caller
/// can fall back to text sharing. Both WAV and FLAC full recordings are
/// supported, and the output container matches the source so the
/// recipient gets a file whose extension matches its bytes. The slice
/// spans `windowDuration + 2 × clipContextSeconds`, centered on the
/// detection's analysis window, to match the per-detection clip layout
/// used elsewhere.
@visibleForTesting
Future<File?> extractClipFromFullAudio(
  LiveSession session,
  DetectionRecord detection,
) => _extractClipFromFullAudio(session, detection);

Future<File?> _extractClipFromFullAudio(
  LiveSession session,
  DetectionRecord detection,
) async {
  final fullPath = _resolveFullAudioPath(session.recordingPath);
  if (fullPath == null) return null;
  final src = File(fullPath);
  if (!src.existsSync()) return null;

  final settings = session.settings;
  // Mid-recording the writer's flushed length lags slightly behind the
  // current sample position. We accept that and clamp at the file end
  // — a fractionally short clip is better than nothing.
  final clipDurationSec =
      settings.windowDuration + 2 * settings.clipContextSeconds;
  final detOffsetSec =
      detection.timestamp.difference(session.startTime).inMicroseconds /
      Duration.microsecondsPerSecond;
  final startSec = (detOffsetSec - settings.clipContextSeconds).clamp(
    0.0,
    double.infinity,
  );

  final ext = p.extension(fullPath).toLowerCase();
  if (ext != '.wav' && ext != '.flac') return null;

  final tmp = await getTemporaryDirectory();
  final shareDir = Directory(p.join(tmp.path, 'shared_clips'));
  if (!shareDir.existsSync()) shareDir.createSync(recursive: true);
  final target = File(p.join(shareDir.path, _exportClipName(detection, ext)));

  try {
    if (ext == '.wav') {
      final sliceBytes = await _sliceWav(
        src,
        startSec: startSec,
        durationSec: clipDurationSec.toDouble(),
      );
      if (sliceBytes == null || sliceBytes.isEmpty) return null;
      await target.writeAsBytes(sliceBytes, flush: true);
    } else {
      final wrote = await _sliceFlacToFile(
        src,
        target,
        startSec: startSec,
        durationSec: clipDurationSec.toDouble(),
      );
      if (!wrote) return null;
    }
  } on FormatException {
    // Header truncated or unsupported — caller falls back to text.
    return null;
  }
  return target;
}

/// Resolves [recordingPath] to a full-recording file on disk, or returns
/// `null` when none is reachable. Handles both shapes set by the
/// recording service: a session directory (live, mid-recording) or a
/// finalized file path (post-stop). WAV and FLAC are both supported.
String? _resolveFullAudioPath(String? recordingPath) {
  if (recordingPath == null) return null;
  // Direct file reference (post-stop in full mode).
  if (FileSystemEntity.isFileSync(recordingPath)) {
    final ext = p.extension(recordingPath).toLowerCase();
    return (ext == '.wav' || ext == '.flac') ? recordingPath : null;
  }
  // Directory reference (live mode while recording is in progress).
  if (FileSystemEntity.isDirectorySync(recordingPath)) {
    final wav = File(p.join(recordingPath, 'full.wav'));
    if (wav.existsSync()) return wav.path;
    final flac = File(p.join(recordingPath, 'full.flac'));
    if (flac.existsSync()) return flac.path;
  }
  return null;
}

/// Slices `[startSec, startSec+durationSec)` out of [src] (a 16-bit PCM
/// WAV) and returns a self-contained WAV file as bytes.
///
/// Tolerant of files written by the streaming [WavWriter]: the source
/// header's data-size field may still be a placeholder mid-recording, so
/// we trust the actual file length on disk for clamping.
Future<Uint8List?> _sliceWav(
  File src, {
  required double startSec,
  required double durationSec,
}) async {
  final raf = await src.open();
  try {
    final fileLen = await raf.length();
    if (fileLen < 44) {
      throw const FormatException('WAV header too short');
    }
    final headerBytes = await raf.read(44);
    final header = ByteData.sublistView(headerBytes);
    // Sanity check 'RIFF' / 'WAVE' / 'fmt ' / 'data' tags.
    final riff = String.fromCharCodes(headerBytes.sublist(0, 4));
    final wave = String.fromCharCodes(headerBytes.sublist(8, 12));
    final fmt = String.fromCharCodes(headerBytes.sublist(12, 16));
    final data = String.fromCharCodes(headerBytes.sublist(36, 40));
    if (riff != 'RIFF' || wave != 'WAVE' || fmt != 'fmt ' || data != 'data') {
      throw const FormatException('Unsupported WAV layout');
    }
    final channels = header.getUint16(22, Endian.little);
    final sampleRate = header.getUint32(24, Endian.little);
    final bitsPerSample = header.getUint16(34, Endian.little);
    if (bitsPerSample != 16) {
      // We only emit 16-bit PCM; refuse anything exotic to keep the
      // slicer trivially correct.
      throw const FormatException('Only 16-bit PCM WAV is supported');
    }
    final bytesPerSample = bitsPerSample ~/ 8;
    final blockAlign = channels * bytesPerSample;

    // Snap the slice to whole sample frames so mid-frame reads can't
    // shear the PCM stream.
    var startByte = (startSec * sampleRate).floor() * blockAlign;
    var lenByte = (durationSec * sampleRate).floor() * blockAlign;
    final dataMaxByte = fileLen - 44;
    if (startByte >= dataMaxByte) return null;
    if (startByte + lenByte > dataMaxByte) {
      lenByte = dataMaxByte - startByte;
    }
    if (lenByte <= 0) return null;

    await raf.setPosition(44 + startByte);
    final pcm = await raf.read(lenByte);

    return _wrapPcmInWav(
      pcm,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );
  } finally {
    await raf.close();
  }
}

/// Slices `[startSec, startSec+durationSec)` out of [src] (a 16-bit FLAC
/// file as written by [FlacEncoder]) and re-encodes the slice as a fresh
/// FLAC file at [target]. Returns `true` on success.
///
/// Tolerant of unfinalized FLAC files: when STREAMINFO's `totalSamples`
/// is still 0 (mid-recording) the underlying decoder walks frames until
/// EOF instead of trusting the header. Re-encoding (rather than copying
/// raw frames) keeps the shared file a fully self-contained FLAC with
/// honest STREAMINFO metadata, so receiving apps can seek and report
/// duration without surprises.
Future<bool> _sliceFlacToFile(
  File src,
  File target, {
  required double startSec,
  required double durationSec,
}) async {
  // The recording pipeline always captures at BirdNET's native 32 kHz,
  // so we can size the requested range accordingly without parsing the
  // STREAMINFO ahead of time. The decoder still reports the file's
  // actual sample rate back via [DecodedAudio.sampleRate] and we use
  // that when re-encoding the slice.
  const assumedRate = 32000;
  final startSample = (startSec * assumedRate).floor();
  final count = (durationSec * assumedRate).ceil();
  if (count <= 0 || startSample < 0) return false;

  final decoded = await AudioDecoder.decodeFlacRange(
    src.path,
    startSample: startSample,
    count: count,
  );
  if (decoded.totalSamples == 0) return false;

  // Re-encode as FLAC. FlacEncoder takes Float32 in [-1.0, 1.0]; convert
  // back from the decoder's Int16 samples. A 7 s @ 32 kHz buffer is only
  // ~896 KB so the one-shot path is safe here.
  final floats = Float32List(decoded.totalSamples);
  for (var i = 0; i < decoded.totalSamples; i++) {
    floats[i] = decoded.samples[i] / 32768.0;
  }
  await FlacEncoder.writeFile(
    filePath: target.path,
    samples: floats,
    sampleRate: decoded.sampleRate,
  );
  return true;
}

/// Wraps an existing PCM byte buffer in a complete WAV file (44-byte
/// header + data). Mirrors `WavWriter.toBytes` but skips the
/// float→PCM conversion since the input is already PCM.
Uint8List _wrapPcmInWav(
  Uint8List pcm, {
  required int sampleRate,
  required int channels,
  required int bitsPerSample,
}) {
  final dataSize = pcm.length;
  final fileSize = 44 + dataSize;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;

  final out = Uint8List(fileSize);
  final view = ByteData.sublistView(out);
  // RIFF chunk descriptor.
  out.setRange(0, 4, const [0x52, 0x49, 0x46, 0x46]); // 'RIFF'
  view.setUint32(4, fileSize - 8, Endian.little);
  out.setRange(8, 12, const [0x57, 0x41, 0x56, 0x45]); // 'WAVE'
  // fmt sub-chunk.
  out.setRange(12, 16, const [0x66, 0x6D, 0x74, 0x20]); // 'fmt '
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little); // PCM
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, blockAlign, Endian.little);
  view.setUint16(34, bitsPerSample, Endian.little);
  // data sub-chunk.
  out.setRange(36, 40, const [0x64, 0x61, 0x74, 0x61]); // 'data'
  view.setUint32(40, dataSize, Endian.little);
  out.setRange(44, fileSize, pcm);
  return out;
}

String _buildSubject(DetectionRecord d) {
  // Prefer the common name in the subject so the receiving app's preview
  // stays human-friendly; fall back to the scientific name if the common
  // name is empty (e.g. unknown species).
  final name = d.commonName.trim().isNotEmpty ? d.commonName : d.scientificName;
  return 'BirdNET Live: $name';
}

String _buildBody(DetectionRecord d) {
  final pct = (d.confidence * 100).round();
  final ts = d.timestamp.toUtc().toIso8601String();
  final lines = <String>[
    'BirdNET Live \u2014 ${d.commonName} (${d.scientificName})',
    '$pct% \u00b7 $ts',
  ];
  if (d.latitude != null && d.longitude != null) {
    lines.add(
      'geo:${d.latitude!.toStringAsFixed(4)},${d.longitude!.toStringAsFixed(4)}',
    );
  }
  if (d.isConfirmed) {
    lines.add('Confirmed');
  }
  return lines.join('\n');
}
