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
//      — slice the detection's full timestamp span, including configured
//      context padding, out of the file and ship that. Both WAV and FLAC full
//      recordings are supported; the slice is shipped in the same container as
//      the source (WAV in, WAV out; FLAC in, FLAC out) so the recipient gets a
//      file whose extension matches its bytes. This is what makes "share" work
//      mid-survey when the user opted for a single continuous recording instead
//      of per-detection clips.
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
import '../../recording/wav_writer.dart';
import 'audio_export_normalizer.dart';
import 'audio_share_extension.dart';
import 'detection_audio_window.dart';
import 'share_file_params.dart';

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
  bool shareAudioAsWav = false,
}) async {
  final body = _buildBody(detection);
  final subject = _buildSubject(detection);

  // 1) Per-detection clip wins when present — it was recorded with the
  //    correct context padding at the moment of detection.
  final clipPath = detection.audioClipPath;
  if (clipPath != null && File(clipPath).existsSync()) {
    final staged = await _stageClipForShare(
      File(clipPath),
      detection,
      shareAudioAsWav: shareAudioAsWav,
    );
    return SharePlus.instance.share(_shareParamsForAudioFile(staged));
  }

  // 2) Try to slice from the session's full recording. Both WAV and
  //    FLAC continuous recordings are supported; the slice ships in
  //    the same container as the source (or WAV if shareAudioAsWav).
  if (session != null) {
    final extracted = await _extractClipFromFullAudio(
      session,
      detection,
      shareAudioAsWav: shareAudioAsWav,
    );
    if (extracted != null) {
      return SharePlus.instance.share(_shareParamsForAudioFile(extracted));
    }
  }

  // 3) No audio available — share text only. The body still carries
  //    location + timestamp so the recipient gets the full picture.
  return SharePlus.instance.share(ShareParams(text: body, subject: subject));
}

ShareParams _shareParamsForAudioFile(File file) =>
    shareParamsForFile(file.path);

/// Copies [clip] into the temp dir under the export-style filename so the
/// share sheet exposes a friendly name. Reuses an existing staged file when
/// the names already match to avoid extra IO on repeat shares.
Future<File> _stageClipForShare(
  File clip,
  DetectionRecord d, {
  bool shareAudioAsWav = false,
}) async {
  final srcExt = await sourceAudioExtensionForFile(clip);
  final outExt = sharedAudioExtensionForSource(
    srcExt,
    shareAudioAsWav: shareAudioAsWav,
  );
  final name = _exportClipName(d, outExt);
  final tmp = await getTemporaryDirectory();
  final shareDir = Directory(p.join(tmp.path, 'shared_clips'));
  if (!shareDir.existsSync()) shareDir.createSync(recursive: true);
  final target = File(p.join(shareDir.path, name));

  if (shareAudioAsWav && srcExt == '.flac') {
    final decoded = await AudioDecoder.decodeFile(clip.path);
    await WavWriter.writePcm16File(
      filePath: target.path,
      samples: decoded.samples,
      sampleRate: decoded.sampleRate,
    );
  } else {
    await clip.copy(target.path);
  }
  await AudioExportNormalizer.normalizeFileInPlace(target, outExt);
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
/// recipient gets a file whose extension matches its bytes. The slice spans
/// [DetectionRecord.timestamp] to [DetectionRecord.endTimestamp] when present
/// and falls back to one inference window for legacy records, with the
/// session's configured pre/post context added around that span.
@visibleForTesting
Future<File?> extractClipFromFullAudio(
  LiveSession session,
  DetectionRecord detection, {
  bool shareAudioAsWav = false,
}) => _extractClipFromFullAudio(
  session,
  detection,
  shareAudioAsWav: shareAudioAsWav,
);

Future<File?> _extractClipFromFullAudio(
  LiveSession session,
  DetectionRecord detection, {
  bool shareAudioAsWav = false,
}) async {
  final fullPath = await _resolveFullAudioPath(session.recordingPath);
  if (fullPath == null) return null;
  final src = File(fullPath);
  if (!src.existsSync()) return null;

  // Mid-recording the writer's flushed length lags slightly behind the
  // current sample position. We accept that and clamp at the file end
  // — a fractionally short clip is better than nothing.
  final timing = detectionAudioWindow(
    session,
    detection,
    clipContextSeconds: session.settings.clipContextSeconds.toDouble(),
    referencesDetectionClip: false,
  );

  final ext = await sourceAudioExtensionForFile(src);
  if (ext != '.wav' && ext != '.flac') return null;

  final outExt = sharedAudioExtensionForSource(
    ext,
    shareAudioAsWav: shareAudioAsWav,
  );
  final tmp = await getTemporaryDirectory();
  final shareDir = Directory(p.join(tmp.path, 'shared_clips'));
  if (!shareDir.existsSync()) shareDir.createSync(recursive: true);
  final target = File(
    p.join(shareDir.path, _exportClipName(detection, outExt)),
  );

  try {
    if (ext == '.wav') {
      final sliceBytes = await _sliceWav(
        src,
        startSec: timing.clipStartSec,
        durationSec: timing.clipDurationSec,
      );
      if (sliceBytes == null || sliceBytes.isEmpty) return null;
      await target.writeAsBytes(sliceBytes, flush: true);
    } else if (shareAudioAsWav) {
      final wrote = await _sliceFlacToWavFile(
        src,
        target,
        startSec: timing.clipStartSec,
        durationSec: timing.clipDurationSec,
      );
      if (!wrote) return null;
    } else {
      final wrote = await _sliceFlacToFile(
        src,
        target,
        startSec: timing.clipStartSec,
        durationSec: timing.clipDurationSec,
      );
      if (!wrote) return null;
    }
    await AudioExportNormalizer.normalizeFileInPlace(target, outExt);
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
Future<String?> _resolveFullAudioPath(String? recordingPath) async {
  if (recordingPath == null) return null;
  // Direct file reference (post-stop in full mode).
  if (FileSystemEntity.isFileSync(recordingPath)) {
    final ext = await sourceAudioExtensionForFile(File(recordingPath));
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

/// Like [_sliceFlacToFile] but writes the decoded PCM as WAV instead of FLAC.
Future<bool> _sliceFlacToWavFile(
  File src,
  File target, {
  required double startSec,
  required double durationSec,
}) async {
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

  await WavWriter.writePcm16File(
    filePath: target.path,
    samples: decoded.samples,
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
  // Heard / seen, when the user recorded it on a manual entry. Plain
  // English like the 'Confirmed' line below — the share body is a
  // machine-friendly payload, not localized UI.
  final evidence = d.evidence;
  if (evidence != null) {
    lines.add(switch (evidence) {
      DetectionEvidence.heard => 'Heard',
      DetectionEvidence.seen => 'Seen',
      DetectionEvidence.heardAndSeen => 'Heard and seen',
    });
  }
  if (d.isConfirmed) {
    lines.add('Confirmed');
  }
  return lines.join('\n');
}
