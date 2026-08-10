// =============================================================================
// Session Export
// =============================================================================
//
// Generates export artifacts for a live session:
//
//   • **Raven selection table** (.selections.txt): Tab-delimited annotation
//     file compatible with Raven Pro / Raven Lite.  Includes a `Begin File`
//     column so Raven can resolve audio references in both single-file and
//     multi-clip bundles.
//
//   • **CSV Export** (.csv): Standard comma-separated values with a `File`
//     column for audio reference.
//
//   • **JSON Export** (.json): Machine-readable JSON structured data.
//
//   • **ZIP bundle** (.zip): Optionally archives audio (full recording or
//     individual detection clips) together with the export document.
//
// Naming convention:
//   Prefix:     BirdNET_Live_YYYY-MM-DD_HH-MM-SS[_#N][_Custom_Name]
//   Full audio: <prefix>.flac / .wav
//   Clips:      <prefix>_clip_001_Species_Name.flac, …
//   Table:      <prefix>.selections.txt / .csv / .json / .gpx
//   Bundle:     <prefix>.zip
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../shared/services/taxonomy_service.dart';
import '../live/live_session.dart';
import '../recording/audio_decoder.dart';
import '../recording/native_audio_decoder.dart';
import '../recording/wav_writer.dart';
import 'html_report.dart';
import 'services/audio_share_extension.dart';
import 'services/detection_audio_window.dart';
import 'services/session_audio_trim.dart';

/// Upper frequency bound for Raven annotations (Nyquist of 32 kHz).
const int _highFreqHz = 16000;

/// How long a staged trim is left alone before it counts as garbage.
///
/// The audio-only share path hands its staged file straight to the share
/// sheet and cannot delete it afterwards — the receiving app may still be
/// reading it, on Android through a content URI that outlives our `share()`
/// call. So the *next* export sweeps it instead, and this grace period keeps
/// that sweep from pulling a file out of a sheet the user still has open.
const Duration _kExportTrimStagingTtl = Duration(hours: 1);

/// Directory holding trimmed audio staged for an export.
Directory _exportTrimStagingDir() =>
    Directory(p.join(Directory.systemTemp.path, 'birdnet_export_trim'));

/// Best-effort removal of staged trims left behind by earlier exports.
///
/// Each entry is a full trimmed recording, so without this they accumulate
/// one per trimmed session ever shared as bare audio.
Future<void> _sweepExportTrimStaging() async {
  try {
    final dir = _exportTrimStagingDir();
    if (!await dir.exists()) return;
    final cutoff = DateTime.now().subtract(_kExportTrimStagingTtl);
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        if ((await entity.stat()).modified.isAfter(cutoff)) continue;
        await entity.delete();
      } catch (_) {
        // Locked or vanished — the next export tries again.
      }
    }
  } catch (_) {
    // Housekeeping must never fail an export.
  }
}

/// Rebases an offset on the *recorded* timeline onto the exported audio.
///
/// Exports of a trimmed session ship the trimmed recording, so every time
/// column has to move with it — otherwise Raven and the CSV would point
/// past the end of the file they reference (see issue #177). Untrimmed
/// sessions pass through unchanged.
double _exportTimelineOffset(LiveSession session, double relativeSec) {
  if (!session.hasAudioTrim) return relativeSec;
  final rebased = relativeSec - session.trimStartSeconds;
  if (rebased <= 0) return 0.0;
  final limit = session.trimmedTimelineSeconds;
  return limit > 0 && rebased > limit ? limit : rebased;
}

double? _exportAnnotationOffset(LiveSession session, double? sourceOffsetSec) {
  if (sourceOffsetSec == null) return null;
  if (!session.hasAudioTrim) return sourceOffsetSec;
  final end = session.trimEndSeconds;
  if (sourceOffsetSec < session.trimStartSeconds ||
      (end != null && sourceOffsetSec >= end)) {
    return null;
  }
  return sourceOffsetSec - session.trimStartSeconds;
}

/// Decodes a FLAC file and returns the bytes of an equivalent PCM WAV.
/// Returns null if decoding fails (caller should fall back to original file).
Future<Uint8List?> _flacToWavBytes(String flacPath) async {
  try {
    if (!await AudioDecoder.canDecodeDart(flacPath)) return null;
    final decoded = await AudioDecoder.decodeFile(flacPath);
    return WavWriter.toBytesFromPcm16(
      samples: decoded.samples,
      sampleRate: decoded.sampleRate,
    );
  } catch (_) {
    return null;
  }
}

/// Builds the `BirdNET_Live_…` export prefix from a session's start time,
/// optional session number, and optional user-assigned name.
///
/// Examples:
///   `BirdNET_Live_2026-04-15_08-00-00_#3`
///   `BirdNET_Live_2026-04-15_08-00-00_Morning_walk`
String _exportPrefix(LiveSession session) {
  final dt = DateFormat(
    'yyyy-MM-dd_HH-mm-ss',
  ).format(session.startTime.toLocal());
  final suffix =
      session.sessionNumber != null ? '_#${session.sessionNumber}' : '';
  final name =
      session.customName != null && session.customName!.isNotEmpty
          ? '_${_sanitizeFilename(session.customName!)}'
          : '';
  return 'BirdNET_Live_$dt$suffix$name';
}

/// Replaces characters that are illegal in filenames with underscores and
/// collapses runs of whitespace / underscores.
String _sanitizeFilename(String input) {
  return input
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

/// CSV-quotes [value] when it contains a comma, double quote, or newline.
/// Internal double quotes are doubled per RFC 4180.
String _csvField(String value) {
  if (value.isEmpty) return '';
  final needsQuoting =
      value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuoting) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// Resolves the locale-appropriate common name for a detection.
///
/// Falls back to the detection's stored common name (English label from the
/// classifier) when no taxonomy is supplied or no translation is available.
String _localizedCommon(
  DetectionRecord d, {
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
}) {
  if (taxonomy == null) return d.commonName;
  final sp = taxonomy.lookup(d.scientificName);
  if (sp == null) return d.commonName;
  final localized = sp.commonNameForLocale(speciesLocale);
  return localized.isNotEmpty ? localized : d.commonName;
}

/// Stable, machine-readable value for the `Evidence` export column.
///
/// Deliberately English and lower-case regardless of the user's locale — it
/// mirrors the persisted [DetectionEvidence] name so a downstream pipeline
/// can match on it. Empty for detections with no evidence recorded, which
/// must be read as "not specified", not "neither heard nor seen".
String _evidenceField(DetectionRecord d) => switch (d.evidence) {
  DetectionEvidence.heard => 'heard',
  DetectionEvidence.seen => 'seen',
  DetectionEvidence.heardAndSeen => 'heard+seen',
  null => '',
};

/// Resolves the canonical (taxonomy-current) scientific name for a detection.
///
/// Falls back to the detection's stored model-label scientific name when no
/// taxonomy is supplied or the species does not resolve.
String _displaySci(DetectionRecord d, {TaxonomyService? taxonomy}) =>
    taxonomy?.displayScientificName(d.scientificName) ?? d.scientificName;

/// Generates a Raven Pro-compatible selection table from session detections.
///
/// When [audioFileName] is provided every row references that single file.
/// When [clipFileMap] is provided (detection index → clip filename), rows with
/// a clip reference that file; rows without a clip get an empty `Begin File`.
///
/// Time semantics:
///   • For rows referencing a per-detection **clip**, `Begin/End Time` are
///     offsets *within the clip*. With pre/post context of
///     [SessionSettings.clipContextSeconds] seconds, the detection starts
///     after the available pre-roll and ends at [DetectionRecord.endTimestamp]
///     when present, otherwise after one inference window.
///   • For rows referencing the **full recording** (or no audio), `Begin/End
///     Time` are session-relative offsets.
///   • A `Survey Time` column is always appended so analysts can recover the
///     timeline of every detection regardless of file layout. By default this
///     is `Survey Time (s)` (seconds since session start). When
///     [useAbsoluteSurveyTime] is true the column becomes `Survey Time (UTC)`
///     and carries the detection's wall-clock timestamp as an ISO-8601 UTC
///     string — useful when correlating across surveys, devices, or external
///     data sources that work in absolute time.
///
/// Common Name is rendered in the user's species locale when [taxonomy] is
/// supplied; Scientific Name is always emitted regardless of any UI toggle
/// so the export remains scientifically authoritative.
///
/// Latitude / Longitude columns are included when any detection has
/// coordinates (typical for surveys).
String buildRavenSelectionTable(
  LiveSession session, {
  String? audioFileName,
  Map<int, String>? clipFileMap,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
  int? clipContextSecondsOverride,
  bool useAbsoluteSurveyTime = false,
}) {
  final buf = StringBuffer();
  final hasCoords = session.detections.any(
    (d) => d.latitude != null && d.longitude != null,
  );
  final hasNotes = session.detections.any((d) => d.hasNote);
  final hasEvidence = session.detections.any((d) => d.evidence != null);
  // Prefer the per-session value, but allow callers to override (e.g. legacy
  // sessions persisted before [SessionSettings.clipContextSeconds] existed,
  // where the field defaults to 0 and would falsely place every detection at
  // the very start of every clip).
  final clipContext =
      (clipContextSecondsOverride ?? session.settings.clipContextSeconds)
          .toDouble();

  // Header row — 'Begin File' is a standard Raven column for multi-file
  // selection tables. 'Survey Time' is non-standard but harmless to Raven
  // (extra columns are ignored on import) and lets analysts cross-reference
  // detections back to the survey timeline. We always emit it: when no clips
  // are involved it duplicates Begin Time, but having a stable column name
  // makes downstream tooling simpler than conditionally including it.
  // 'Review Status' / 'Reviewed At (UTC)' are likewise always emitted so the
  // schema is stable regardless of whether the session has any reviewed
  // detections; unreviewed rows carry an empty 'Reviewed At'.
  final surveyTimeHeader =
      useAbsoluteSurveyTime ? 'Survey Time (UTC)' : 'Survey Time (s)';
  buf.writeln(
    'Selection\tView\tChannel\tBegin File\t'
    'Begin Time (s)\tEnd Time (s)\t'
    'Low Freq (Hz)\tHigh Freq (Hz)\t'
    'Common Name\tScientific Name\tConfidence'
    '\t$surveyTimeHeader'
    '\tReview Status\tReviewed At (UTC)'
    '${hasCoords ? '\tLatitude\tLongitude' : ''}'
    '${hasEvidence ? '\tEvidence' : ''}'
    '${hasNotes ? '\tNote' : ''}',
  );

  // Length of the recorded audio timeline, used as the end offset for
  // whole-session (global) clips. Segment-backed sessions use their exact
  // gap-removed timeline so resumed sessions don't include stopped time.
  final sessionDurationSec = _recordedTimelineDurationSeconds(session);

  for (var i = 0; i < session.detections.length; i++) {
    final d = session.detections[i];
    final isGlobal = d.source == DetectionSource.manualGlobal;

    // File reference: clip name (if available) > full recording > empty.
    final clipName = clipFileMap?[i];
    final beginFile = clipName ?? audioFileName ?? '';
    final referencesClip = clipName != null;

    final timing = detectionAudioWindow(
      session,
      d,
      clipContextSeconds: clipContext,
      referencesDetectionClip: referencesClip,
    );
    // Session-relative offset (always computed; used for either Begin Time
    // or the auxiliary Survey Time column), rebased onto the exported
    // (possibly trimmed) audio so it indexes the file the row references.
    final surveySec =
        isGlobal
            ? 0.0
            : _exportTimelineOffset(session, timing.detectionStartSec);

    // Begin/End times depend on whether the row references a clip file.
    final double beginSec;
    final double endSec;
    if (referencesClip) {
      // Inside the clip: detection sits after the pre-roll context.
      beginSec = timing.clipDetectionStartSec;
      endSec = timing.clipDetectionEndSec;
    } else if (isGlobal) {
      beginSec = 0.0;
      endSec = sessionDurationSec;
    } else {
      beginSec = surveySec;
      endSec = _exportTimelineOffset(session, timing.detectionEndSec);
    }

    final commonName = _localizedCommon(
      d,
      taxonomy: taxonomy,
      speciesLocale: speciesLocale,
    );

    final surveyTimeValue =
        useAbsoluteSurveyTime
            ? d.timestamp.toUtc().toIso8601String()
            : surveySec.toStringAsFixed(3);
    final surveyTimeSuffix = '\t$surveyTimeValue';
    final reviewSuffix =
        '\t${d.reviewStatus.name}'
        '\t${d.reviewedAt?.toUtc().toIso8601String() ?? ''}';
    final coordSuffix =
        hasCoords
            ? '\t${d.latitude?.toStringAsFixed(6) ?? ''}'
                '\t${d.longitude?.toStringAsFixed(6) ?? ''}'
            : '';
    final evidenceSuffix = hasEvidence ? '\t${_evidenceField(d)}' : '';
    // Raven selection tables are tab-separated, so collapse any embedded
    // tabs/newlines from a free-form note to spaces to keep one row per
    // detection. Notes longer than ~200 chars are not truncated; Raven
    // tolerates wide cells.
    final noteSuffix =
        hasNotes
            ? '\t${(d.note ?? '').replaceAll(RegExp(r"[\t\r\n]+"), ' ').trim()}'
            : '';

    buf.writeln(
      '${i + 1}\t'
      'Spectrogram 1\t'
      '1\t'
      '$beginFile\t'
      '${beginSec.toStringAsFixed(3)}\t'
      '${endSec.toStringAsFixed(3)}\t'
      '0\t'
      '$_highFreqHz\t'
      '$commonName\t'
      '${_displaySci(d, taxonomy: taxonomy)}\t'
      '${d.confidence.toStringAsFixed(4)}'
      '$surveyTimeSuffix'
      '$reviewSuffix'
      '$coordSuffix'
      '$evidenceSuffix'
      '$noteSuffix',
    );
  }

  return buf.toString();
}

/// Generates a standard CSV representation of session detections.
///
/// When [audioFileName] or [clipFileMap] are provided, a `File` column is
/// included referencing the audio source. For rows referencing a clip, the
/// `Begin/End Time (s)` columns describe the detection's offset *within the
/// clip* (after the pre-roll context); a separate `Survey Time (s)` column
/// is added with the session-relative offset.
///
/// Common Name is rendered in the user's species locale when [taxonomy] is
/// supplied; Scientific Name is always emitted.
///
/// Latitude / Longitude columns are included when any detection has
/// coordinates.
String buildCsvExport(
  LiveSession session, {
  String? audioFileName,
  Map<int, String>? clipFileMap,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
  int? clipContextSecondsOverride,
  bool useAbsoluteSurveyTime = false,
}) {
  final buf = StringBuffer();
  final hasFileRefs = audioFileName != null || clipFileMap != null;
  final hasCoords = session.detections.any(
    (d) => d.latitude != null && d.longitude != null,
  );
  final hasNotes = session.detections.any((d) => d.hasNote);
  final hasMemos = session.detections.any((d) => d.hasVoiceMemo);
  final hasEvidence = session.detections.any((d) => d.evidence != null);
  final clipContext =
      (clipContextSecondsOverride ?? session.settings.clipContextSeconds)
          .toDouble();

  // Survey Time is always included (see [buildRavenSelectionTable] for the
  // rationale). When [useAbsoluteSurveyTime] is true the column becomes
  // 'Survey Time (UTC)' and carries an ISO-8601 wall-clock timestamp.
  // 'Review Status' / 'Reviewed At (UTC)' are always emitted so downstream
  // pipelines see a stable schema; unreviewed rows carry an empty
  // 'Reviewed At'.
  final surveyTimeHeader =
      useAbsoluteSurveyTime ? 'Survey Time (UTC)' : 'Survey Time (s)';
  buf.writeln(
    'Timestamp (UTC),Begin Time (s),End Time (s),'
    'Common Name,Scientific Name,Confidence'
    '${hasFileRefs ? ',File' : ''}'
    ',$surveyTimeHeader'
    ',Review Status,Reviewed At (UTC)'
    '${hasCoords ? ',Latitude,Longitude' : ''}'
    '${hasEvidence ? ',Evidence' : ''}'
    '${hasNotes ? ',Note' : ''}'
    '${hasMemos ? ',Voice Memo' : ''}',
  );

  // Length of the recorded audio timeline, used as the end offset for
  // whole-session (global) clips. Segment-backed sessions use their exact
  // gap-removed timeline so resumed sessions don't include stopped time.
  final sessionDurationSec = _recordedTimelineDurationSeconds(session);

  for (var i = 0; i < session.detections.length; i++) {
    final d = session.detections[i];
    final isGlobal = d.source == DetectionSource.manualGlobal;

    final clipName = clipFileMap?[i];
    final referencesClip = clipName != null;

    final timing = detectionAudioWindow(
      session,
      d,
      clipContextSeconds: clipContext,
      referencesDetectionClip: referencesClip,
    );
    // Session-relative offset, rebased onto the exported (possibly trimmed)
    // audio so it indexes the file the row references.
    final surveySec =
        isGlobal
            ? 0.0
            : _exportTimelineOffset(session, timing.detectionStartSec);

    final double beginSec;
    final double endSec;
    if (referencesClip) {
      beginSec = timing.clipDetectionStartSec;
      endSec = timing.clipDetectionEndSec;
    } else if (isGlobal) {
      beginSec = 0.0;
      endSec = sessionDurationSec;
    } else {
      beginSec = surveySec;
      endSec = _exportTimelineOffset(session, timing.detectionEndSec);
    }

    final localizedCommon = _localizedCommon(
      d,
      taxonomy: taxonomy,
      speciesLocale: speciesLocale,
    );
    final commonName =
        localizedCommon.contains(',') ? '"$localizedCommon"' : localizedCommon;
    final displaySci = _displaySci(d, taxonomy: taxonomy);
    final sciName = displaySci.contains(',') ? '"$displaySci"' : displaySci;

    final fileRef = hasFileRefs ? ',${clipName ?? audioFileName ?? ''}' : '';
    final surveyTimeValue =
        useAbsoluteSurveyTime
            ? d.timestamp.toUtc().toIso8601String()
            : surveySec.toStringAsFixed(3);
    final surveyTimeRef = ',$surveyTimeValue';
    final reviewRef =
        ',${d.reviewStatus.name}'
        ',${d.reviewedAt?.toUtc().toIso8601String() ?? ''}';
    final coordRef =
        hasCoords
            ? ',${d.latitude?.toStringAsFixed(6) ?? ''}'
                ',${d.longitude?.toStringAsFixed(6) ?? ''}'
            : '';
    final evidenceRef = hasEvidence ? ',${_evidenceField(d)}' : '';
    final noteRef = hasNotes ? ',${_csvField(d.note ?? '')}' : '';
    final memoRef =
        hasMemos
            ? ',${d.hasVoiceMemo ? 'memos/${p.basename(d.voiceMemoPath!)}' : ''}'
            : '';

    buf.writeln(
      '${d.timestamp.toUtc().toIso8601String()},'
      '${beginSec.toStringAsFixed(3)},'
      '${endSec.toStringAsFixed(3)},'
      '$commonName,'
      '$sciName,'
      '${d.confidence.toStringAsFixed(4)}'
      '$fileRef'
      '$surveyTimeRef'
      '$reviewRef'
      '$coordRef'
      '$evidenceRef'
      '$noteRef'
      '$memoRef',
    );
  }

  return buf.toString();
}

/// Builds the provenance metadata block embedded in JSON exports and
/// written to `<prefix>.metadata.json` inside ZIP bundles.
///
/// The block records *what produced this export* so an analyst opening it
/// months later can answer: which app version, which model, which user
/// settings. All fields are optional — callers pass whatever they have.
///
/// `prefs` should be a flat map of relevant SharedPreferences key/value pairs
/// that are not already persisted on the session itself. The export module has
/// no Riverpod / SharedPrefs dependency on purpose. `audioModel` typically
/// contains `name`, `version`, `description`, `speciesCount`, `sampleRate` from
/// `model_config.json`.
Map<String, dynamic> buildExportMetadata({
  String? appVersion,
  String? appBuildNumber,
  String? appPackageName,
  Map<String, dynamic>? audioModel,
  Map<String, dynamic>? geoModel,
  Map<String, dynamic>? prefs,
  String? speciesLocale,
  LiveSession? session,
}) {
  // Slim the model blocks to *what produced these detections* — model
  // identity, not the bundled defaults. The defaults under
  // audioModel.inference and geoModel.defaultThreshold are confusing
  // here because they're overridden at runtime by the user; the actual
  // applied values live in `appliedSettings` below.
  Map<String, dynamic>? slimAudioModel;
  if (audioModel != null) {
    slimAudioModel =
        Map<String, dynamic>.from(audioModel)
          ..remove('inference')
          ..remove('onnx')
          ..remove('labels');
  }
  Map<String, dynamic>? slimGeoModel;
  if (geoModel != null) {
    slimGeoModel = Map<String, dynamic>.from(geoModel)
      ..remove('defaultThreshold');
  }

  final sessionMetadata =
      session == null ? null : _commonSessionExportMetadata(session);
  final typeMetadata =
      session == null ? null : _typeSpecificExportMetadata(session);
  final settingsMetadata = _settingsExportMetadata(session, prefs);

  return {
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'app': {
      'name': 'BirdNET Live',
      if (appVersion != null) 'version': appVersion,
      if (appBuildNumber != null) 'buildNumber': appBuildNumber,
      if (appPackageName != null) 'packageName': appPackageName,
    },
    if (sessionMetadata != null) 'session': sessionMetadata,
    if (typeMetadata != null && typeMetadata.isNotEmpty)
      'typeMetadata': typeMetadata,
    if (slimAudioModel != null) 'audioModel': slimAudioModel,
    if (slimGeoModel != null) 'geoModel': slimGeoModel,
    if (speciesLocale != null) 'speciesLocale': speciesLocale,
    if (settingsMetadata.isNotEmpty) 'settings': settingsMetadata,
  };
}

Map<String, dynamic> _settingsExportMetadata(
  LiveSession? session,
  Map<String, dynamic>? prefs,
) {
  final settings = <String, dynamic>{};

  if (session != null) {
    final s = session.settings;
    settings['analysis'] = <String, dynamic>{
      'windowDurationSeconds': s.windowDuration,
      'confidenceThresholdPercent': s.confidenceThreshold,
      'inferenceRateHz': s.inferenceRate,
      'speciesFilterMode': s.speciesFilterMode,
      if (s.sensitivity != null) 'sensitivity': s.sensitivity,
      if (s.poolingMode != null) 'poolingMode': s.poolingMode,
      if (s.poolingWindows != null) 'poolingWindows': s.poolingWindows,
      if (s.poolingMaxAgeSeconds != null)
        'poolingMaxAgeSeconds': s.poolingMaxAgeSeconds,
      if (s.poolingAlpha != null) 'poolingAlpha': s.poolingAlpha,
      if (s.poolingMinSupportWindows != null)
        'poolingMinSupportWindows': s.poolingMinSupportWindows,
      if (s.poolingSupportThresholdFraction != null)
        'poolingSupportThresholdFraction': s.poolingSupportThresholdFraction,
      if (s.poolingSupportThresholdFloor != null)
        'poolingSupportThresholdFloor': s.poolingSupportThresholdFloor,
      if (s.poolingVeryHighImmediateThreshold != null)
        'poolingVeryHighImmediateThreshold':
            s.poolingVeryHighImmediateThreshold,
    };

    final audio = <String, dynamic>{
      if (s.gainLinear != null) 'gainLinear': s.gainLinear,
      if (s.highPassHz != null) 'highPassHz': s.highPassHz,
      'clipContextSeconds': s.clipContextSeconds,
    };
    if (audio.isNotEmpty) settings['audio'] = audio;

    final capture = <String, dynamic>{
      if (s.recordingMode != null) 'recordingMode': s.recordingMode,
      if (s.recordingFormat != null) 'recordingFormat': s.recordingFormat,
    };
    if (capture.isNotEmpty) settings['capture'] = capture;

    final protocol = <String, dynamic>{
      if (s.detectionSamplingMode != null)
        'detectionSamplingMode': s.detectionSamplingMode,
      if (s.topNPerSpecies != null) 'topNPerSpecies': s.topNPerSpecies,
      if (s.gpsIntervalSeconds != null)
        'gpsIntervalSeconds': s.gpsIntervalSeconds,
      if (s.maxDurationHours != null) 'maxDurationHours': s.maxDurationHours,
      if (s.targetDurationSeconds != null)
        'targetDurationSeconds': s.targetDurationSeconds,
      if (s.autoStopBatteryPercent != null)
        'autoStopBatteryPercent': s.autoStopBatteryPercent,
      if (s.backgroundGps != null) 'backgroundGps': s.backgroundGps,
      if (session.type == SessionType.survey) ...{
        'alertMode': s.alertMode,
        'alertRareThreshold': s.alertRareThreshold,
        'alertWatchlistName': s.alertWatchlistName,
        'alertMinConfidence': s.alertMinConfidence,
        'alertStartupGraceSeconds': s.alertStartupGraceSeconds,
        'alertMinIntervalSeconds': s.alertMinIntervalSeconds,
        'alertMaxPerMinute': s.alertMaxPerMinute,
        'alertCoalesce': s.alertCoalesce,
      },
    };
    if (protocol.isNotEmpty) settings['protocol'] = protocol;
  }

  final export = _pickPrefs(prefs, const [
    PrefKeys.exportHtmlReport,
    PrefKeys.exportSelection,
    PrefKeys.includeAudio,
    PrefKeys.timestampDisplayMode,
    PrefKeys.timestampShowSeconds,
  ]);
  if (export.isNotEmpty) settings['exportPreferences'] = export;

  return settings;
}

Map<String, dynamic> _pickPrefs(
  Map<String, dynamic>? prefs,
  List<String> keys,
) {
  if (prefs == null || prefs.isEmpty) return const {};
  return {
    for (final key in keys)
      if (prefs.containsKey(key)) key: prefs[key],
  };
}

Map<String, dynamic> _commonSessionExportMetadata(LiveSession session) {
  final endTime = session.endTime;
  final durationSeconds =
      endTime == null
          ? null
          : endTime.difference(session.startTime).inMilliseconds / 1000.0;
  return {
    'id': session.id,
    'type': session.type.name,
    'displayName': session.displayName,
    'startTime': session.startTime.toUtc().toIso8601String(),
    if (endTime != null) 'endTime': endTime.toUtc().toIso8601String(),
    if (durationSeconds != null)
      'durationSeconds': num.parse(durationSeconds.toStringAsFixed(3)),
    if (session.recordedDurationSeconds != null)
      'recordedDurationSeconds': session.recordedDurationSeconds,
    if (session.customName != null && session.customName!.isNotEmpty)
      'customName': session.customName,
    if (session.sessionNumber != null) 'sessionNumber': session.sessionNumber,
    if (session.observerName != null && session.observerName!.isNotEmpty)
      'observerName': session.observerName,
    if (session.latitude != null) 'latitude': session.latitude,
    if (session.longitude != null) 'longitude': session.longitude,
    if (session.locationName != null && session.locationName!.isNotEmpty)
      'locationName': session.locationName,
    if (session.stopReason != null) 'stopReason': session.stopReason!.name,
    if (session.stopReasonValue != null)
      'stopReasonValue': session.stopReasonValue,
    if (session.weather != null) 'weather': session.weather!.toJson(),
    'detectionCount': session.detections.length,
    'uniqueSpeciesCount': session.uniqueSpeciesCount,
    'annotationCount': session.annotations.length,
    'segmentCount': session.segments.length,
    'hasRecording': session.recordingPath != null,
  };
}

Map<String, dynamic>? _typeSpecificExportMetadata(LiveSession session) {
  return switch (session.type) {
    SessionType.aru => _aruExportMetadata(session),
    SessionType.survey => _surveyExportMetadata(session),
    SessionType.pointCount => _pointCountExportMetadata(session),
    SessionType.fileUpload => _fileUploadExportMetadata(session),
    SessionType.batchAnalysis => _batchAnalysisExportMetadata(session),
    SessionType.live => null,
  };
}

Map<String, dynamic>? _aruExportMetadata(LiveSession session) {
  final aru = session.aruMetadata;
  if (aru == null) return null;
  return {'aru': aru.toJson()};
}

Map<String, dynamic>? _surveyExportMetadata(LiveSession session) {
  if (session.transectId == null &&
      session.distanceMeters == null &&
      session.gpsTrack.isEmpty) {
    return null;
  }
  return {
    if (session.transectId != null && session.transectId!.isNotEmpty)
      'transectId': session.transectId,
    if (session.distanceMeters != null)
      'distanceMeters': session.distanceMeters,
    'gpsPointCount': session.gpsTrack.length,
    if (session.gpsTrack.isNotEmpty)
      'gpsTrack': session.gpsTrack.map((p) => p.toJson()).toList(),
  };
}

Map<String, dynamic> _pointCountExportMetadata(LiveSession session) {
  final endTime = session.endTime;
  final durationSeconds =
      endTime == null
          ? null
          : endTime.difference(session.startTime).inMilliseconds / 1000.0;
  return {
    if (durationSeconds != null)
      'countDurationSeconds': num.parse(durationSeconds.toStringAsFixed(3)),
  };
}

Map<String, dynamic>? _fileUploadExportMetadata(LiveSession session) {
  if (session.trimStartSec == null &&
      session.trimEndSec == null &&
      session.recordingPath == null) {
    return null;
  }
  return {
    if (session.recordingPath != null)
      'sourceFileName': p.basename(session.recordingPath!),
    if (session.trimStartSec != null) 'trimStartSec': session.trimStartSec,
    if (session.trimEndSec != null) 'trimEndSec': session.trimEndSec,
  };
}

Map<String, dynamic>? _batchAnalysisExportMetadata(LiveSession session) {
  if (session.recordingPath == null) return null;
  return {'sourceFileName': p.basename(session.recordingPath!)};
}

/// Generates a JSON representation of the session and its detections.
///
/// When [metadata] is provided it is embedded under a top-level `meta` key.
String buildJsonExport(
  LiveSession session, {
  Map<String, dynamic>? metadata,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
}) {
  final map = {
    if (metadata != null) 'meta': metadata,
    'session': session.displayName,
    if (session.customName != null && session.customName!.isNotEmpty)
      'customName': session.customName,
    if (session.sessionNumber != null) 'sessionNumber': session.sessionNumber,
    if (session.type != SessionType.live) 'type': session.type.name,
    'startTime': session.startTime.toUtc().toIso8601String(),
    'endTime': session.endTime?.toUtc().toIso8601String(),
    if (session.observerName != null && session.observerName!.isNotEmpty)
      'observerName': session.observerName,
    if (session.transectId != null && session.transectId!.isNotEmpty)
      'transectId': session.transectId,
    if (session.latitude != null) 'latitude': session.latitude,
    if (session.longitude != null) 'longitude': session.longitude,
    if (session.locationName != null) 'locationName': session.locationName,
    if (session.distanceMeters != null)
      'distanceMeters': session.distanceMeters,
    if (session.stopReason != null) 'stopReason': session.stopReason!.name,
    if (session.stopReasonValue != null)
      'stopReasonValue': session.stopReasonValue,
    if (session.weather != null) 'weather': session.weather!.toJson(),
    'recordingPath': session.recordingPath,
    'settings': session.settings.toJson(),
    if (session.trimStartSec != null) 'trimStartSec': session.trimStartSec,
    if (session.trimEndSec != null) 'trimEndSec': session.trimEndSec,
    // Exports of a trimmed session ship the trimmed audio, so record how
    // long that is — `trimStartSec`/`trimEndSec` describe where it was cut
    // from the *original* recording, `beginTimeSec` indexes the export.
    if (session.hasAudioTrim)
      'trimmedDurationSec': num.parse(
        session.trimmedTimelineSeconds.toStringAsFixed(3),
      ),
    if (session.segments.isNotEmpty)
      'segments': session.segments.map((s) => s.toJson()).toList(),
    if (session.aruMetadata != null) 'aru': session.aruMetadata!.toJson(),
    'detections':
        session.detections.map((d) {
          // Gap-removed offset into the recorded audio (see
          // absoluteToRelative), rebased onto the trimmed extent when the
          // session was trimmed; keeps resumed sessions aligned.
          final beginSec = session.trimmedRelative(d.timestamp);
          return {
            'timestamp': d.timestamp.toUtc().toIso8601String(),
            'beginTimeSec': num.parse(beginSec.toStringAsFixed(3)),
            'commonName': _localizedCommon(
              d,
              taxonomy: taxonomy,
              speciesLocale: speciesLocale,
            ),
            'scientificName': _displaySci(d, taxonomy: taxonomy),
            'confidence': num.parse(d.confidence.toStringAsFixed(4)),
            if (d.latitude != null) 'latitude': d.latitude,
            if (d.longitude != null) 'longitude': d.longitude,
            if (d.source != DetectionSource.auto) 'source': d.source.name,
            if (d.evidence != null) 'evidence': d.evidence!.name,
            // Always emitted so the schema is stable, and three-valued so an
            // untouched detection reads as 'unreviewed' rather than claiming
            // a reviewer judged the identification wrong.
            'reviewStatus': d.reviewStatus.name,
            if (d.reviewedAt != null)
              'reviewedAt': d.reviewedAt!.toUtc().toIso8601String(),
            if (d.hasNote) 'note': d.note,
            if (d.hasVoiceMemo)
              'voiceMemo': 'memos/${p.basename(d.voiceMemoPath!)}',
          };
        }).toList(),
    if (session.annotations.isNotEmpty)
      'annotations':
          session.annotations.map((annotation) {
            final json = annotation.toJson();
            final offset = _exportAnnotationOffset(
              session,
              annotation.offsetInRecording,
            );
            if (offset == null) {
              json.remove('offsetInRecording');
            } else {
              json['offsetInRecording'] = offset;
            }
            return json;
          }).toList(),
  };

  return const JsonEncoder.withIndent('  ').convert(map);
}

Future<Map<String, dynamic>?> _withAudioIntegrityMetadata(
  LiveSession session,
  Map<String, dynamic>? metadata,
  String? audioPath,
) async {
  if (audioPath == null) return metadata;

  try {
    final canDart = await AudioDecoder.canDecodeDart(audioPath);
    final audio =
        canDart
            ? await AudioDecoder.inspectFile(audioPath)
            : await NativeAudioDecoder.inspectFile(
              audioPath,
              _formatLabelForPath(audioPath),
            );
    final audioSec = audio.duration.inMicroseconds / 1e6;
    final expectedSec = session.expectedRecordedAudioSeconds;
    if (expectedSec <= 0 || audioSec + 5 >= expectedSec) return metadata;

    final enriched = <String, dynamic>{...?metadata};
    enriched['audioIntegrity'] = {
      'warning': 'recording_shorter_than_session',
      'audioDurationSeconds': audioSec,
      'expectedSessionSeconds': expectedSec,
      'message':
          'The audio file ends before the latest session event. Detection rows '
          'may refer to timestamps beyond the available recording.',
    };
    return enriched;
  } catch (_) {
    return metadata;
  }
}

/// Length of the audio timeline the export describes.
///
/// Segment-backed sessions use their exact gap-removed timeline so resumed
/// sessions don't include stopped time, and a trimmed session reports the
/// trimmed extent — that is the audio the bundle actually ships.
double _recordedTimelineDurationSeconds(LiveSession session) =>
    session.trimmedTimelineSeconds;

Map<String, dynamic> _withAruCycleExportFiles(
  Map<String, dynamic>? metadata,
  Map<int, ({File file, String name})> cycleAudioEntries,
) {
  final enriched = <String, dynamic>{...?metadata};
  enriched['aruCycleAudioFiles'] = {
    for (final entry in cycleAudioEntries.entries)
      entry.key.toString(): entry.value.name,
  };
  return enriched;
}

String _formatLabelForPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mp3')) return 'MP3';
  if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'OGG';
  if (lower.endsWith('.opus')) return 'OPUS';
  if (lower.endsWith('.m4a') || lower.endsWith('.aac')) return 'AAC';
  if (lower.endsWith('.mp4')) return 'AAC';
  if (lower.endsWith('.wma')) return 'WMA';
  if (lower.endsWith('.amr')) return 'AMR';
  return 'AUDIO';
}

/// Creates an export bundle containing the session data and optionally audio.
///
/// All exported files use the `BirdNET_Live_…` prefix regardless of the
/// session's display name.  When [includeAudio] is true and audio exists
/// (full recording or detection clips), or when more than one format is
/// requested, returns a `.zip` path. Otherwise returns the path to the
/// raw document file for the single requested format.
///
/// [formats] is a set of format tokens drawn from `raven`, `csv`, `json`,
/// `gpx`. Each enabled format produces its own document inside the ZIP.
/// When [formats] is empty and the user also disabled the HTML report
/// and [includeAppMetadata], the function returns the raw audio file (no
/// ZIP) for full-recording sessions, so it can be shared directly into
/// other apps such as iNaturalist.
Future<String?> buildSessionExport(
  LiveSession session, {
  required Set<String> formats,
  required bool includeAudio,
  bool shareAudioAsWav = false,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
  int? clipContextSecondsOverride,
  Map<String, dynamic>? metadata,
  bool useAbsoluteSurveyTime = false,
  bool includeHtmlReport = false,
  bool includeAppMetadata = true,
}) async {
  // Resolve the active format set; tokens outside the known list are
  // ignored. An empty result is now allowed so users can share the raw
  // audio file without any companion documents.
  const allFormats = {'raven', 'csv', 'json', 'gpx'};
  final selected = formats.where(allFormats.contains).toSet();

  final prefix = _exportPrefix(session);
  final fullRecordingPath = await _resolveFullRecordingPath(
    session.recordingPath,
  );
  final recordingPath = session.recordingPath;
  if (includeAudio &&
      session.hasAudioTrim &&
      fullRecordingPath == null &&
      recordingPath != null &&
      FileSystemEntity.typeSync(recordingPath) !=
          FileSystemEntityType.notFound) {
    // A playable recording exists, but the trim slicer cannot materialize
    // its container. Returning a document-only export would silently ignore
    // the user's explicit request to include the trimmed audio.
    return null;
  }

  // Full recording: single finalized file, or a session directory containing
  // the finalized `full.wav` / `full.flac` recording.
  final hasFullRecording = fullRecordingPath != null;
  final fullRecordingFile =
      fullRecordingPath == null ? null : File(fullRecordingPath);
  final fullRecordingSourceExt =
      fullRecordingFile == null
          ? ''
          : await sourceAudioExtensionForFile(fullRecordingFile);
  final fullRecordingExportExt = sharedAudioExtensionForSource(
    fullRecordingSourceExt,
    shareAudioAsWav: shareAudioAsWav,
  );
  final baseMetadata =
      metadata ??
      (session.aruMetadata != null
          ? buildExportMetadata(session: session, speciesLocale: speciesLocale)
          : null);
  var exportMetadata = await _withAudioIntegrityMetadata(
    session,
    baseMetadata,
    fullRecordingPath,
  );

  // Detection clips: collect per-detection audio files that exist on disk,
  // indexed by detection position so we can build a clip-file map.
  final clipEntries = <int, File>{};
  final clipAudioExts = <int, String>{};
  if (!hasFullRecording) {
    for (var i = 0; i < session.detections.length; i++) {
      final clip = session.detections[i].audioClipPath;
      if (clip != null) {
        final f = File(clip);
        if (f.existsSync()) {
          clipEntries[i] = f;
          clipAudioExts[i] = await sharedAudioExtensionForFile(
            f,
            shareAudioAsWav: shareAudioAsWav,
          );
        }
      }
    }
  }
  final hasClips = clipEntries.isNotEmpty;
  final hasAnyAudio = hasFullRecording || hasClips;

  // ── Build export clip names (sequential, 1-indexed, zero-padded) ────
  final audioExt =
      hasFullRecording
          ? fullRecordingExportExt
          : (hasClips
              ? clipAudioExts[clipEntries.keys.first] ??
                  fallbackAudioShareExtension
              : fallbackAudioShareExtension);
  final audioFileName = '$prefix$audioExt';

  // ── Apply the session's trim to the exported audio ────────────────
  // Trimming in Session Review only stores a range; the recording on disk
  // stays whole so the trim can be widened or reset later. The export is
  // where that range has to become real audio — without this the bundle
  // ships the full recording while every time column has already been
  // rebased onto the trimmed extent (issue #177).
  // Clear out staged trims from earlier exports before adding another.
  await _sweepExportTrimStaging();

  TrimmedAudioFile? trimmedRecording;
  if (includeAudio && hasFullRecording && session.hasAudioTrim) {
    trimmedRecording = await writeTrimmedAudioFile(
      sourcePath: fullRecordingPath,
      destPath: p.join(_exportTrimStagingDir().path, audioFileName),
      startSec: session.trimStartSeconds,
      endSec: session.trimEndSeconds,
      asWav: shareAudioAsWav || fullRecordingSourceExt == '.wav',
    );
    // Never pair the full source with trim-rebased timestamps. A caller may
    // retry without audio, but an apparently successful mismatched export is
    // not a valid fallback.
    if (trimmedRecording == null) return null;
  }

  // Map detection index → export clip filename.
  Map<int, String>? clipFileMap;
  final clipExportNames = <int, String>{};
  if (hasClips) {
    final pad = clipEntries.length.toString().length.clamp(3, 6);
    var seq = 1;
    for (final i in clipEntries.keys.toList()..sort()) {
      final localized = _localizedCommon(
        session.detections[i],
        taxonomy: taxonomy,
        speciesLocale: speciesLocale,
      );
      final species = _sanitizeFilename(localized);
      final clipAudioExt = clipAudioExts[i] ?? audioExt;
      final name =
          '${prefix}_clip_${seq.toString().padLeft(pad, '0')}_$species$clipAudioExt';
      clipExportNames[i] = name;
      seq++;
    }
    clipFileMap = clipExportNames;
  }

  final aruCycleAudioEntries = <int, ({File file, String name})>{};
  final aruCycles = session.aruMetadata?.cycles ?? const <AruCycleMetadata>[];
  for (final cycle in aruCycles) {
    final path = cycle.recordingPath;
    if (path == null || path.isEmpty) continue;
    final file = File(path);
    if (!file.existsSync()) continue;
    final cycleExt = await sharedAudioExtensionForFile(
      file,
      shareAudioAsWav: shareAudioAsWav,
    );
    final cycleName =
        'aru_cycles/${prefix}_cycle_${cycle.index.toString().padLeft(3, '0')}$cycleExt';
    aruCycleAudioEntries[cycle.index] = (file: file, name: cycleName);
  }
  final hasAruCycleAudio = aruCycleAudioEntries.isNotEmpty;
  if (hasAruCycleAudio) {
    exportMetadata = _withAruCycleExportFiles(
      exportMetadata,
      aruCycleAudioEntries,
    );
  }

  // ── Generate document content for every selected format ──────────
  // Map: format token → (extension, content). The order in
  // `formatPriority` chooses the "primary" file when only one format is
  // selected and no audio is present (the function returns that one
  // file directly instead of zipping).
  const formatPriority = ['raven', 'csv', 'json', 'gpx'];
  final docs = <String, ({String extension, String content})>{};
  for (final fmt in formatPriority) {
    if (!selected.contains(fmt)) continue;
    switch (fmt) {
      case 'csv':
        docs[fmt] = (
          extension: '.csv',
          content: buildCsvExport(
            session,
            audioFileName: hasFullRecording ? audioFileName : null,
            clipFileMap: clipFileMap,
            taxonomy: taxonomy,
            speciesLocale: speciesLocale,
            clipContextSecondsOverride: clipContextSecondsOverride,
            useAbsoluteSurveyTime: useAbsoluteSurveyTime,
          ),
        );
        break;
      case 'json':
        docs[fmt] = (
          extension: '.json',
          content: buildJsonExport(
            session,
            metadata: exportMetadata,
            taxonomy: taxonomy,
            speciesLocale: speciesLocale,
          ),
        );
        break;
      case 'gpx':
        docs[fmt] = (
          extension: '.gpx',
          content: buildGpxExport(
            session,
            taxonomy: taxonomy,
            speciesLocale: speciesLocale,
          ),
        );
        break;
      case 'raven':
      default:
        docs[fmt] = (
          extension: '.selections.txt',
          content: buildRavenSelectionTable(
            session,
            audioFileName: hasFullRecording ? audioFileName : null,
            clipFileMap: clipFileMap,
            taxonomy: taxonomy,
            speciesLocale: speciesLocale,
            clipContextSecondsOverride: clipContextSecondsOverride,
            useAbsoluteSurveyTime: useAbsoluteSurveyTime,
          ),
        );
        break;
    }
  }

  // Decide whether to ZIP. We zip when any of:
  //   • the user wants audio bundled and we have more than one audio
  //     file (clips) or any companion document/asset would join it,
  //   • more than one format is selected (multiple docs need a container),
  //   • the user enabled the HTML report,
  //   • the user kept the app metadata side-file enabled and we have
  //     metadata to write (carries weather snapshot, audio integrity
  //     warning, model identity, …).
  final hasCompanion =
      docs.isNotEmpty ||
      includeHtmlReport ||
      (includeAppMetadata && exportMetadata != null) ||
      session.annotations.isNotEmpty;
  final hasMemos = session.detections.any((d) => d.hasVoiceMemo);
  final mustZip =
      (includeAudio && hasAruCycleAudio) ||
      (includeAudio && hasClips) ||
      (includeAudio && hasFullRecording && hasCompanion) ||
      docs.length > 1 ||
      includeHtmlReport ||
      (includeAppMetadata && exportMetadata != null) ||
      // Session annotations and detection voice memos each produce companion
      // files (annotations.txt, memos/) that only exist inside a ZIP bundle.
      // Force ZIP whenever either is present alongside at least one document
      // so these files are never silently dropped from the export.
      (docs.isNotEmpty && session.annotations.isNotEmpty) ||
      (docs.isNotEmpty && hasMemos);

  // Audio-only mode: the user unchecked every companion (no formats,
  // no HTML, no app metadata). For full-recording sessions we share the
  // raw audio file (converted to WAV if requested), renamed to the
  // BirdNET_Live_… prefix so the receiving app shows a sensible filename.
  if (!mustZip && includeAudio && hasFullRecording && !hasCompanion) {
    // The trimmed file was written under the export filename already, in
    // the requested container — hand it straight to the share sheet.
    if (trimmedRecording != null) return trimmedRecording.file.path;

    if (shareAudioAsWav && fullRecordingSourceExt == '.flac') {
      final wavBytes = await _flacToWavBytes(fullRecordingPath);
      if (wavBytes != null) {
        final dest = p.join(p.dirname(fullRecordingPath), audioFileName);
        final destFile = File(dest);
        if (await destFile.exists()) {
          try {
            await destFile.delete();
          } catch (_) {}
        }
        await destFile.writeAsBytes(wavBytes);
        return dest;
      }
    }

    final fallbackName =
        shareAudioAsWav && fullRecordingSourceExt == '.flac'
            ? '$prefix$fullRecordingSourceExt'
            : audioFileName;
    final dest = p.join(p.dirname(fullRecordingPath), fallbackName);
    final destFile = File(dest);
    if (await destFile.exists()) {
      try {
        await destFile.delete();
      } catch (_) {}
    }
    if (dest != fullRecordingPath) await File(fullRecordingPath).copy(dest);
    return dest;
  }

  // Nothing selected at all — surface a null so the caller can no-op.
  if (!mustZip && docs.isEmpty) return null;

  // ── Bundle into ZIP ───────────────────────────────────────────────
  if (mustZip) {
    final archive = Archive();

    Future<Uint8List> audioBytes(String path) async {
      final sourceExt = await sourceAudioExtensionForFile(File(path));
      if (shareAudioAsWav && sourceExt == '.flac') {
        final bytes = await _flacToWavBytes(path);
        if (bytes == null) {
          throw FormatException('Could not convert FLAC to WAV: $path');
        }
        return bytes;
      }
      return File(path).readAsBytes();
    }

    if (includeAudio && hasAnyAudio) {
      if (hasFullRecording) {
        // A materialized trim is already in the requested container.
        final bytes =
            trimmedRecording != null
                ? await trimmedRecording.file.readAsBytes()
                : await audioBytes(fullRecordingPath);
        archive.addFile(ArchiveFile(audioFileName, bytes.length, bytes));
        if (trimmedRecording != null) {
          // The bytes are in the archive now; don't leave a second copy of
          // the recording sitting in the temp directory.
          try {
            await trimmedRecording.file.delete();
          } catch (_) {
            // Best-effort cleanup.
          }
        }
      } else {
        for (final entry in clipExportNames.entries) {
          final bytes = await audioBytes(clipEntries[entry.key]!.path);
          archive.addFile(ArchiveFile(entry.value, bytes.length, bytes));
        }
      }
    }

    if (includeAudio && hasAruCycleAudio) {
      for (final entry in aruCycleAudioEntries.values) {
        final bytes = await audioBytes(entry.file.path);
        archive.addFile(ArchiveFile(entry.name, bytes.length, bytes));
      }
    }

    // Drop every selected document into the ZIP root.
    for (final entry in docs.entries) {
      final docBytes = Uint8List.fromList(utf8.encode(entry.value.content));
      archive.addFile(
        ArchiveFile(
          '$prefix${entry.value.extension}',
          docBytes.length,
          docBytes,
        ),
      );
    }

    // Bundle voice memos under a memos/ folder so the CSV's "Voice
    // Memo" column (relative path: memos/<basename>) resolves inside
    // the archive. Best-effort: skip any memo whose file is missing.
    for (final d in session.detections) {
      final memoPath = d.voiceMemoPath;
      if (memoPath == null) continue;
      final memoFile = File(memoPath);
      if (!await memoFile.exists()) continue;
      final memoBytes = await memoFile.readAsBytes();
      archive.addFile(
        ArchiveFile(
          'memos/${p.basename(memoPath)}',
          memoBytes.length,
          memoBytes,
        ),
      );
    }

    // Same treatment for session-level annotation memos.
    for (final a in session.annotations) {
      final memoPath = a.voiceMemoPath;
      if (memoPath == null) continue;
      final memoFile = File(memoPath);
      if (!await memoFile.exists()) continue;
      final memoBytes = await memoFile.readAsBytes();
      archive.addFile(
        ArchiveFile(
          'memos/${p.basename(memoPath)}',
          memoBytes.length,
          memoBytes,
        ),
      );
    }

    // Always drop a metadata side-file when the caller provided one and
    // the user kept app metadata enabled, so the provenance information
    // travels with the bundle regardless of which document format the
    // user picked.
    if (includeAppMetadata && exportMetadata != null) {
      final metaJson = const JsonEncoder.withIndent(
        '  ',
      ).convert(exportMetadata);
      final metaBytes = Uint8List.fromList(utf8.encode(metaJson));
      archive.addFile(
        ArchiveFile('$prefix.metadata.json', metaBytes.length, metaBytes),
      );
    }

    if (session.annotations.isNotEmpty) {
      final annotationsTxt = _buildAnnotationsText(session);
      final annotationsBytes = Uint8List.fromList(utf8.encode(annotationsTxt));
      archive.addFile(
        ArchiveFile(
          '$prefix.annotations.txt',
          annotationsBytes.length,
          annotationsBytes,
        ),
      );
    }

    // Auto-include GPX for surveys when GPX wasn't already a selected
    // document — the track is intrinsic to the survey artifact. Skipped
    // when the user opted into the audio-only mode (no documents at
    // all) so we don't sneak files into an intentionally bare export.
    if (session.type == SessionType.survey &&
        !selected.contains('gpx') &&
        docs.isNotEmpty) {
      final gpxContent = buildGpxExport(
        session,
        taxonomy: taxonomy,
        speciesLocale: speciesLocale,
      );
      final gpxBytes = Uint8List.fromList(utf8.encode(gpxContent));
      archive.addFile(ArchiveFile('$prefix.gpx', gpxBytes.length, gpxBytes));
    }

    // Pragmatic, single-file HTML report at the ZIP root. Lives next to
    // the audio so its relative `<audio src="...">` references resolve
    // once the user unzips. Species images come from the BirdNET
    // taxonomy API at view time — keeps the report tiny but means the
    // thumbnails need internet (graceful fallback to a placeholder when
    // offline).
    if (includeHtmlReport) {
      final reportHtml = buildHtmlReport(
        session,
        clipFileMap: clipFileMap,
        audioFileName: hasFullRecording ? audioFileName : null,
        taxonomy: taxonomy,
        speciesLocale: speciesLocale,
        metadata: exportMetadata,
      );
      final reportBytes = Uint8List.fromList(utf8.encode(reportHtml));
      archive.addFile(
        ArchiveFile('${prefix}_report.html', reportBytes.length, reportBytes),
      );
    }

    final zipBytes = ZipEncoder().encode(archive);
    final zipDir =
        hasFullRecording
            ? p.dirname(fullRecordingPath)
            : (hasClips
                ? p.dirname(clipEntries.values.first.path)
                : (hasAruCycleAudio
                    ? p.dirname(aruCycleAudioEntries.values.first.file.path)
                    : Directory.systemTemp.path));
    final zipPath = p.join(zipDir, '$prefix.zip');
    await File(zipPath).writeAsBytes(zipBytes);

    return zipPath;
  } else {
    // Single-document, no audio, no HTML, no ZIP.
    final entry = docs.values.first;
    final dir =
        hasFullRecording
            ? p.dirname(fullRecordingPath)
            : (hasClips
                ? p.dirname(clipEntries.values.first.path)
                : Directory.systemTemp.path);
    final filePath = p.join(dir, '$prefix${entry.extension}');
    await File(
      filePath,
    ).writeAsBytes(Uint8List.fromList(utf8.encode(entry.content)));
    return filePath;
  }
}

/// Resolves [recordingPath] to a continuous session audio file on disk.
///
/// Most completed sessions store the finalized file path directly. Active or
/// crash-recovered sessions may still point at the session recording directory;
/// support that shape as well so export does not silently drop available audio.
Future<String?> _resolveFullRecordingPath(String? recordingPath) =>
    resolveSessionRecordingFile(recordingPath);

/// Builds a human-readable text file of session annotations.
String _buildAnnotationsText(LiveSession session) {
  final buf = StringBuffer();
  buf.writeln('# Annotations for ${session.displayName}');
  buf.writeln('# Session: ${session.startTime.toUtc().toIso8601String()}');
  buf.writeln();

  for (final a in session.annotations) {
    final offset = _exportAnnotationOffset(session, a.offsetInRecording);
    if (offset != null) {
      final m = offset ~/ 60;
      final s = (offset % 60).toInt();
      buf.write(
        '[${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}] ',
      );
    } else {
      buf.write('[Global] ');
    }
    // Optional title is prefixed in bold-ish "Title: " form so the
    // exported text mirrors what the user sees on the chip.
    if (a.title.trim().isNotEmpty) {
      buf.write('${a.title.trim()}: ');
    }
    if (a.text.trim().isNotEmpty) {
      buf.write(a.text);
      if (a.hasVoiceMemo) {
        buf.write(' (voice memo: memos/${p.basename(a.voiceMemoPath!)})');
      }
      buf.writeln();
    } else if (a.hasVoiceMemo) {
      buf.writeln('(voice memo: memos/${p.basename(a.voiceMemoPath!)})');
    } else {
      buf.writeln();
    }
  }

  return buf.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// GPX Export — GPS track + detection waypoints
// ─────────────────────────────────────────────────────────────────────────────

/// Generates a GPX 1.1 document from a survey session.
///
/// Contains:
///   • `<trk>` with `<trkseg>` of GPS track points
///   • `<wpt>` for each detection with lat/lon coordinates
String buildGpxExport(
  LiveSession session, {
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
}) {
  final buf = StringBuffer();

  buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buf.writeln('<gpx version="1.1" creator="BirdNET Live"');
  buf.writeln('  xmlns="http://www.topografix.com/GPX/1/1"');
  buf.writeln('  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"');
  buf.writeln(
    '  xsi:schemaLocation="http://www.topografix.com/GPX/1/1 '
    'http://www.topografix.com/GPX/1/1/gpx.xsd">',
  );

  // Metadata.
  buf.writeln('  <metadata>');
  buf.writeln('    <name>${_xmlEscape(session.displayName)}</name>');
  buf.writeln(
    '    <time>${session.startTime.toUtc().toIso8601String()}</time>',
  );
  if (session.observerName != null && session.observerName!.isNotEmpty) {
    buf.writeln(
      '    <author><name>${_xmlEscape(session.observerName!)}</name></author>',
    );
  }
  buf.writeln('  </metadata>');

  // Detection waypoints.
  for (final d in session.detections) {
    if (d.latitude == null || d.longitude == null) continue;
    buf.writeln('  <wpt lat="${d.latitude}" lon="${d.longitude}">');
    buf.writeln('    <time>${d.timestamp.toUtc().toIso8601String()}</time>');
    final commonName = _localizedCommon(
      d,
      taxonomy: taxonomy,
      speciesLocale: speciesLocale,
    );
    buf.writeln('    <name>${_xmlEscape(commonName)}</name>');
    buf.writeln(
      '    <desc>${_xmlEscape(_displaySci(d, taxonomy: taxonomy))} (${(d.confidence * 100).toStringAsFixed(1)}%)</desc>',
    );
    if (d.isReviewed) {
      // GPX <sym> is a free-form symbol hint; downstream tools (QGIS,
      // GPSBabel, Garmin BaseCamp) treat unknown values as a tag rather
      // than failing to load the waypoint, so the status here doubles as
      // a filterable attribute. The <cmt> note carries the review
      // timestamp so the audit trail survives the export. Unreviewed
      // waypoints get neither tag — absence is the honest encoding of
      // "nobody has judged this".
      final verb = d.isConfirmed ? 'Confirmed' : 'Rejected';
      buf.writeln('    <sym>${d.reviewStatus.name}</sym>');
      if (d.reviewedAt != null) {
        buf.writeln(
          '    <cmt>$verb at ${d.reviewedAt!.toUtc().toIso8601String()}</cmt>',
        );
      }
    }
    buf.writeln('  </wpt>');
  }

  // GPS track.
  if (session.gpsTrack.isNotEmpty) {
    final trackName = session.transectId ?? session.displayName;
    buf.writeln('  <trk>');
    buf.writeln('    <name>${_xmlEscape(trackName)}</name>');
    buf.writeln('    <trkseg>');
    for (final pt in session.gpsTrack) {
      buf.write('      <trkpt lat="${pt.latitude}" lon="${pt.longitude}">');
      if (pt.altitude != null) {
        buf.write('<ele>${pt.altitude!.toStringAsFixed(1)}</ele>');
      }
      buf.write('<time>${pt.timestamp.toUtc().toIso8601String()}</time>');
      buf.writeln('</trkpt>');
    }
    buf.writeln('    </trkseg>');
    buf.writeln('  </trk>');
  }

  buf.writeln('</gpx>');
  return buf.toString();
}

/// XML-safe escaping for attribute and text content.
String _xmlEscape(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// Builds a bulk export bundle containing multiple sessions.
///
/// If [sessions] is empty, returns null.
/// Under selection mode, we export all selected sessions using the user's
/// chosen export configuration (formats, includeAudio, taxonomy, speciesLocale,
/// metadata, etc.), collect all generated single files / zip bundles, and zip
/// them up into a single file named:
/// `BirdNET_Live_Bulk_Export_YYYY-MM-DD_HH-mm-ss.zip`
Future<String?> buildMultiSessionExport(
  List<LiveSession> sessions, {
  required Set<String> formats,
  required bool includeAudio,
  bool shareAudioAsWav = false,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
  int? clipContextSecondsOverride,
  Future<Map<String, dynamic>?> Function(LiveSession)? metadataProvider,
  bool useAbsoluteSurveyTime = false,
  bool includeHtmlReport = false,
  bool includeAppMetadata = true,
}) async {
  if (sessions.isEmpty) return null;

  final archive = Archive();
  final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
  final bulkPrefix = 'BirdNET_Live_Bulk_Export_$timestamp';

  for (final session in sessions) {
    Map<String, dynamic>? metadata;
    if (metadataProvider != null) {
      metadata = await metadataProvider(session);
    }
    var path = await buildSessionExport(
      session,
      formats: formats,
      includeAudio: includeAudio,
      shareAudioAsWav: shareAudioAsWav,
      taxonomy: taxonomy,
      speciesLocale: speciesLocale,
      clipContextSecondsOverride: clipContextSecondsOverride,
      metadata: metadata,
      useAbsoluteSurveyTime: useAbsoluteSurveyTime,
      includeHtmlReport: includeHtmlReport,
      includeAppMetadata: includeAppMetadata,
    );
    // A trimmed recording in a container the slicer can't cut fails the whole
    // session rather than shipping audio that disagrees with its timestamps.
    // In a bulk export that would silently drop the session's documents too,
    // so fall back to a document-only bundle for that one session.
    if (path == null && includeAudio && formats.isNotEmpty) {
      path = await buildSessionExport(
        session,
        formats: formats,
        includeAudio: false,
        shareAudioAsWav: shareAudioAsWav,
        taxonomy: taxonomy,
        speciesLocale: speciesLocale,
        clipContextSecondsOverride: clipContextSecondsOverride,
        metadata: metadata,
        useAbsoluteSurveyTime: useAbsoluteSurveyTime,
        includeHtmlReport: includeHtmlReport,
        includeAppMetadata: includeAppMetadata,
      );
    }
    if (path == null) continue;

    final file = File(path);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      final filename = p.basename(path);
      archive.addFile(ArchiveFile(filename, bytes.length, bytes));
    }
  }

  if (archive.isEmpty) return null;

  final zipBytes = ZipEncoder().encode(archive);
  final tempDir = Directory.systemTemp.path;
  final zipPath = p.join(tempDir, '$bulkPrefix.zip');
  await File(zipPath).writeAsBytes(zipBytes);
  return zipPath;
}
