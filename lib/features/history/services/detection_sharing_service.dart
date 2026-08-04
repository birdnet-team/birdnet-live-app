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
//   1. The host passed a [LiveSession] with a full recording — slice the
//      detection's exact start-to-end timestamp span out of the file. WAV and
//      FLAC recordings are sliced in Dart. Compressed File Analysis sources
//      are range-decoded by the platform and shared as WAV.
//   2. The detection has a kept per-detection clip on disk — stage and ship.
//   3. No audio at all (recording mode = off) — share text only. Location +
//      timestamp still land in the payload via [_buildBody].
//
// When export companions are selected, the regular session export pipeline
// bundles only this detection's selected formats, HTML, app metadata, and
// audio. Audio-only settings still hand the raw clip to the share sheet.
//
// This is a thin wrapper, not a stateful service — exposed as a top-level
// function so callers don't need a provider just to share one detection.
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/services/taxonomy_service.dart';
import '../../live/live_session.dart';
import '../../recording/audio_decoder.dart';
import '../../recording/flac_encoder.dart';
import '../../recording/native_audio_decoder.dart';
import '../../recording/wav_writer.dart';
import '../export_metadata_helper.dart';
import '../session_export.dart';
import 'audio_export_normalizer.dart';
import 'audio_share_extension.dart';
import 'detection_audio_window.dart';
import 'session_audio_trim.dart';
import 'share_file_params.dart';

/// Share a single [detection] using the platform share sheet.
///
/// When [session] has a full recording, the function slices the detection's
/// exact start-to-end interval from it. Compressed File Analysis sources are
/// range-decoded as WAV. A retained detection clip is the fallback for
/// detection-only recording mode.
///
/// [formats], [includeAudio], [includeHtmlReport], and [includeAppMetadata]
/// mirror the app's export settings. Selected companion artifacts contain
/// only this detection and are packaged through [buildSessionExport].
///
/// [sharePositionOrigin] anchors the iPad popover; without it the iOS
/// plugin refuses to present the sheet. Callers should pass the rect of the
/// widget the user tapped — see `shareOriginFrom` in
/// `shared/utils/share_origin.dart`.
///
/// Returns the [ShareResult] from `share_plus` so callers can react to
/// dismissal vs. successful share if they want — most callers can ignore it.
Future<ShareResult> shareDetection(
  DetectionRecord detection, {
  LiveSession? session,
  Set<String> formats = const {},
  bool includeAudio = true,
  bool shareAudioAsWav = false,
  bool includeHtmlReport = false,
  bool includeAppMetadata = false,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
  bool useAbsoluteSurveyTime = false,
  Rect? sharePositionOrigin,
}) async {
  final body = _buildBody(detection);
  final subject = _buildSubject(detection);
  File? audioFile;
  var audioIsFullDetectionSpan = false;

  if (includeAudio && session != null) {
    final fullRecordingPath = await resolveSessionRecordingFile(
      session.recordingPath,
    );
    // The continuous recording can cover the detection's whole start-to-end
    // span. Do not add per-clip context: this share is the exact interval.
    if (fullRecordingPath != null) {
      audioFile = await _extractClipFromFullAudio(
        session,
        detection,
        shareAudioAsWav: shareAudioAsWav,
        clipContextSeconds: 0,
      );
      if (audioFile == null) {
        throw StateError('Could not extract the detection audio interval.');
      }
      audioIsFullDetectionSpan = true;
    } else if (session.settings.recordingMode == 'full' ||
        (session.settings.recordingMode == null &&
            session.recordingPath != null &&
            detection.audioClipPath == null)) {
      throw StateError('The Session full recording could not be found.');
    }
  }

  // Detection-only recording mode has no continuous source to slice. Its
  // retained analysis-window clip is the best available audio.
  if (includeAudio && audioFile == null) {
    final clipPath = detection.audioClipPath;
    if (clipPath != null && File(clipPath).existsSync()) {
      audioFile = await _stageClipForShare(
        File(clipPath),
        detection,
        shareAudioAsWav: shareAudioAsWav,
      );
    }
  }

  final hasCompanion =
      formats.isNotEmpty || includeHtmlReport || includeAppMetadata;

  // Preserve the audio-only setting: with every companion disabled, hand
  // the clip itself to the platform instead of wrapping it in a ZIP.
  if (audioFile != null && !hasCompanion) {
    return SharePlus.instance.share(
      _shareParamsForAudioFile(audioFile, sharePositionOrigin),
    );
  }

  // Use the regular export pipeline for the selected formats and metadata.
  // The synthetic session contains only this detection, so unrelated session
  // detections, annotations, track points, and audio cannot enter the bundle.
  if (session != null || formats.isNotEmpty || includeHtmlReport) {
    final exportSession = _singleDetectionSession(
      source: session,
      detection: detection,
      audioFile: audioFile,
      audioIsFullDetectionSpan: audioIsFullDetectionSpan,
    );
    final metadata = await buildSessionExportMetadata(
      exportSession,
      speciesLocale: speciesLocale,
    );
    final exportPath = await buildSessionExport(
      exportSession,
      formats: formats,
      includeAudio: includeAudio,
      shareAudioAsWav: shareAudioAsWav,
      taxonomy: taxonomy,
      speciesLocale: speciesLocale,
      metadata: metadata,
      useAbsoluteSurveyTime: useAbsoluteSurveyTime,
      includeHtmlReport: includeHtmlReport,
      includeAppMetadata: includeAppMetadata,
    );
    if (exportPath != null) {
      return SharePlus.instance.share(
        shareParamsForFile(
          exportPath,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    }
  }

  // No requested file could be built. Recording-off sessions still share a
  // useful text payload with species, time, and location.
  return SharePlus.instance.share(
    ShareParams(
      text: body,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}

LiveSession _singleDetectionSession({
  required LiveSession? source,
  required DetectionRecord detection,
  required File? audioFile,
  required bool audioIsFullDetectionSpan,
}) {
  final settings =
      source?.settings ??
      const SessionSettings(
        windowDuration: 3,
        confidenceThreshold: 25,
        inferenceRate: 1,
        speciesFilterMode: 'off',
      );
  final end =
      detection.endTimestamp != null &&
              detection.endTimestamp!.isAfter(detection.timestamp)
          ? detection.endTimestamp!
          : detection.timestamp.add(Duration(seconds: settings.windowDuration));
  final exportDetection = _copyDetection(
    detection,
    audioClipPath:
        audioFile != null && !audioIsFullDetectionSpan ? audioFile.path : null,
  );

  return LiveSession(
    id: source?.id ?? 'detection-${detection.timestamp.microsecondsSinceEpoch}',
    startTime: detection.timestamp,
    endTime: end,
    type: source?.type ?? SessionType.live,
    customName:
        detection.commonName.trim().isNotEmpty
            ? detection.commonName
            : detection.scientificName,
    detections: [exportDetection],
    recordingPath:
        audioFile != null && audioIsFullDetectionSpan ? audioFile.path : null,
    settings: settings,
    latitude: detection.latitude ?? source?.latitude,
    longitude: detection.longitude ?? source?.longitude,
    locationName: source?.locationName,
    observerName: source?.observerName,
    weather: source?.weather,
  );
}

DetectionRecord _copyDetection(
  DetectionRecord source, {
  required String? audioClipPath,
}) => DetectionRecord(
  scientificName: source.scientificName,
  commonName: source.commonName,
  confidence: source.confidence,
  timestamp: source.timestamp,
  endTimestamp: source.endTimestamp,
  audioClipPath: audioClipPath,
  clipTimestamp: audioClipPath == null ? null : source.clipTimestamp,
  source: source.source,
  evidence: source.evidence,
  latitude: source.latitude,
  longitude: source.longitude,
  confirmedAt: source.confirmedAt,
  note: source.note,
  voiceMemoPath: source.voiceMemoPath,
);

ShareParams _shareParamsForAudioFile(File file, Rect? sharePositionOrigin) =>
    shareParamsForFile(file.path, sharePositionOrigin: sharePositionOrigin);

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
/// Returns `null` when no usable full recording is found or decoded. WAV and
/// FLAC slices preserve their source container unless WAV export is selected;
/// compressed File Analysis sources are range-decoded to WAV. The slice spans
/// [DetectionRecord.timestamp] to [DetectionRecord.endTimestamp] when present
/// and falls back to one inference window for legacy records. Direct callers
/// use the session's configured pre/post context; [shareDetection] overrides
/// that context to zero so the shared full-recording slice is exact.
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
  double? clipContextSeconds,
}) async {
  final fullPath = await resolveSessionRecordingFile(session.recordingPath);
  if (fullPath == null) return null;
  final src = File(fullPath);
  if (!src.existsSync()) return null;

  // Mid-recording the writer's flushed length lags slightly behind the
  // current sample position. We accept that and clamp at the file end
  // — a fractionally short clip is better than nothing.
  final timing = detectionAudioWindow(
    session,
    detection,
    clipContextSeconds:
        clipContextSeconds ?? session.settings.clipContextSeconds.toDouble(),
    referencesDetectionClip: false,
  );
  var sliceStartSec = timing.clipStartSec;
  var sliceEndSec = timing.clipStartSec + timing.clipDurationSec;

  // The recorder begins asynchronously after the Session clock starts and
  // flushes its final samples just before the Session clock stops. On real
  // devices those clocks can differ by a few seconds, which can otherwise put
  // a valid detection just beyond EOF. Playback already clamps such seeks;
  // sharing additionally end-aligns the interval when the discrepancy is
  // within the same five-second recorder-tail tolerance used by integrity
  // checks.
  final canDecodeDart = await AudioDecoder.canDecodeDart(fullPath);
  AudioMetadata? sourceMetadata;
  try {
    sourceMetadata =
        canDecodeDart
            ? await AudioDecoder.inspectFile(fullPath)
            : await NativeAudioDecoder.inspectFile(
              fullPath,
              _audioFormatLabel(fullPath),
            );
    final sourceDurationSec = sourceMetadata.duration.inMicroseconds / 1e6;
    if (sourceDurationSec > 0) {
      final expectedDurationSec = session.expectedRecordedAudioSeconds;
      final clockDriftSec = expectedDurationSec - sourceDurationSec;
      if (clockDriftSec > 0 && clockDriftSec <= 5) {
        sliceStartSec = math.max(0, sliceStartSec - clockDriftSec);
        sliceEndSec = math.max(sliceStartSec, sliceEndSec - clockDriftSec);
      }
      if (sliceEndSec > sourceDurationSec) {
        final overflow = sliceEndSec - sourceDurationSec;
        if (sliceStartSec >= sourceDurationSec && overflow <= 5) {
          sliceStartSec = math.max(0, sliceStartSec - overflow);
        }
        sliceEndSec = sourceDurationSec;
      }
    }
  } catch (_) {
    // An active FLAC may not have final duration metadata yet. The streaming
    // slicer below still walks every available frame and clamps at EOF.
  }

  final ext =
      canDecodeDart
          ? (await AudioDecoder.isWav(fullPath) ? '.wav' : '.flac')
          : p.extension(fullPath).toLowerCase();
  // Native compressed formats are decoded only for the requested range and
  // written as WAV. Re-encoding MP3/AAC/OGG would require a second platform
  // encoder and would introduce another lossy generation.
  final outExt =
      canDecodeDart
          ? sharedAudioExtensionForSource(ext, shareAudioAsWav: shareAudioAsWav)
          : '.wav';
  final tmp = await getTemporaryDirectory();
  final shareDir = Directory(p.join(tmp.path, 'shared_clips'));
  if (!shareDir.existsSync()) shareDir.createSync(recursive: true);
  final targetPath = p.join(shareDir.path, _exportClipName(detection, outExt));

  if (!canDecodeDart) {
    try {
      sourceMetadata ??= await NativeAudioDecoder.inspectFile(
        fullPath,
        _audioFormatLabel(fullPath),
      );
      final sampleRate = sourceMetadata.sampleRate;
      final startSample = math.max(0, (sliceStartSec * sampleRate).floor());
      final sampleCount = math.max(
        0,
        ((sliceEndSec - sliceStartSec) * sampleRate).ceil(),
      );
      if (sampleRate <= 0 || sampleCount <= 0) return null;
      final decoded = await NativeAudioDecoder.decodeRange(
        fullPath,
        startSample: startSample,
        count: sampleCount,
        allowConcurrent: Platform.isAndroid,
      );
      if (decoded.totalSamples <= 0) return null;
      final target = File(targetPath);
      await WavWriter.writePcm16File(
        filePath: target.path,
        samples: decoded.samples,
        sampleRate: decoded.sampleRate,
      );
      await AudioExportNormalizer.normalizeFileInPlace(target, outExt);
      return target;
    } catch (error, stackTrace) {
      debugPrint(
        '[DetectionShare] native range extraction failed for $fullPath: '
        '$error\n$stackTrace',
      );
      return null;
    }
  }

  final written = await writeTrimmedAudioFile(
    sourcePath: fullPath,
    destPath: targetPath,
    startSec: sliceStartSec,
    endSec: sliceEndSec,
    asWav: outExt == '.wav',
  );
  if (written != null && await written.file.exists()) {
    await AudioExportNormalizer.normalizeFileInPlace(written.file, outExt);
    return written.file;
  }

  // Keep the original narrow slicer as a second chance for partially flushed
  // live recordings. Completed recordings should normally take the shared,
  // streaming trim path above.
  final target = File(targetPath);
  try {
    if (ext == '.wav') {
      final bytes = await _sliceWav(
        src,
        startSec: sliceStartSec,
        durationSec: sliceEndSec - sliceStartSec,
      );
      if (bytes == null || bytes.isEmpty) return null;
      await target.writeAsBytes(bytes, flush: true);
    } else if (shareAudioAsWav) {
      if (!await _sliceFlacToWavFile(
        src,
        target,
        startSec: sliceStartSec,
        durationSec: sliceEndSec - sliceStartSec,
      )) {
        return null;
      }
    } else if (!await _sliceFlacToFile(
      src,
      target,
      startSec: sliceStartSec,
      durationSec: sliceEndSec - sliceStartSec,
    )) {
      return null;
    }
    await AudioExportNormalizer.normalizeFileInPlace(target, outExt);
    return target;
  } on FormatException {
    return null;
  }
}

String _audioFormatLabel(String path) => switch (p
    .extension(path)
    .toLowerCase()) {
  '.wav' || '.wave' => 'WAV',
  '.flac' => 'FLAC',
  '.mp3' => 'MP3',
  '.ogg' || '.oga' => 'OGG',
  '.m4a' || '.aac' || '.mp4' => 'AAC',
  '.opus' => 'OPUS',
  '.wma' => 'WMA',
  '.amr' => 'AMR',
  final ext => ext.replaceFirst('.', '').toUpperCase(),
};

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
