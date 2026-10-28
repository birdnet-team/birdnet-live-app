// =============================================================================
// ShareExportConfig — what one share hands to the export pipeline
// =============================================================================
//
// Every Share button in the app used to read the five export preferences
// (formats, audio, WAV conversion, HTML report, app metadata) straight from
// Settings. The share options dialog lets the user override the two coarse
// choices — Audio and Metadata — for a single share without touching the
// saved preferences. This class carries the resolved result so every share
// entry point (session, multi-session, single detection) feeds the pipeline
// the same way.
//
// Resolution rules (see `withChoices`):
//   • Audio off   → `includeAudio = false`; the WAV preference is kept so a
//                   later "Audio on" in the same dialog still honors it.
//   • Metadata off → no formats, no HTML report, no app metadata side-file.
//                   With audio on this is the audio-only path: the raw
//                   recording / clip is shared without a ZIP.
//   • Metadata on with nothing enabled in Settings → fall back to a Raven
//                   selection table, so ticking the box never produces an
//                   empty share.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/settings_providers.dart';
import '../../live/live_session.dart';

/// Export format tokens in the order they are listed in Settings.
const List<String> shareExportFormatOrder = ['raven', 'csv', 'json', 'gpx'];

/// Display labels for the export format tokens. These are technical terms
/// and stay in English across locales, matching the Settings checklist.
const Map<String, String> shareExportFormatLabels = {
  'raven': 'Raven Selection Table',
  'csv': 'CSV',
  'json': 'JSON',
  'gpx': 'GPX',
};

/// Immutable snapshot of the export options used for one share.
class ShareExportConfig {
  const ShareExportConfig({
    required this.formats,
    required this.includeAudio,
    this.shareAudioAsWav = false,
    this.includeHtmlReport = false,
    this.includeAppMetadata = false,
  });

  /// Format used when the user ticks Metadata although every metadata
  /// option is disabled in Settings. Mirrors the new-install default of
  /// [ExportSelectionNotifier].
  static const Set<String> fallbackFormats = {'raven'};

  final Set<String> formats;
  final bool includeAudio;
  final bool shareAudioAsWav;
  final bool includeHtmlReport;
  final bool includeAppMetadata;

  /// True when at least one metadata artifact (table, report, side-file)
  /// would be written. This is what the dialog's Metadata box reflects.
  /// Persisted with queued uploads so a job survives a restart unchanged.
  Map<String, dynamic> toJson() => {
    'formats': formats.toList()..sort(),
    'includeAudio': includeAudio,
    'shareAudioAsWav': shareAudioAsWav,
    'includeHtmlReport': includeHtmlReport,
    'includeAppMetadata': includeAppMetadata,
  };

  factory ShareExportConfig.fromJson(Map<String, dynamic> json) {
    return ShareExportConfig(
      formats: {
        for (final f in (json['formats'] as List<dynamic>? ?? const []))
          f as String,
      },
      includeAudio: json['includeAudio'] as bool? ?? false,
      shareAudioAsWav: json['shareAudioAsWav'] as bool? ?? false,
      includeHtmlReport: json['includeHtmlReport'] as bool? ?? false,
      includeAppMetadata: json['includeAppMetadata'] as bool? ?? false,
    );
  }

  bool get includesMetadata =>
      formats.isNotEmpty || includeHtmlReport || includeAppMetadata;

  /// True when the share would produce nothing at all.
  bool get isEmpty => !includeAudio && !includesMetadata;

  /// Applies the dialog's two choices to this configuration.
  ShareExportConfig withChoices({required bool audio, required bool metadata}) {
    if (!metadata) {
      return ShareExportConfig(
        formats: const {},
        includeAudio: audio,
        shareAudioAsWav: shareAudioAsWav,
      );
    }
    return ShareExportConfig(
      formats: includesMetadata ? formats : fallbackFormats,
      includeAudio: audio,
      shareAudioAsWav: shareAudioAsWav,
      includeHtmlReport: includeHtmlReport,
      includeAppMetadata: includeAppMetadata,
    );
  }

  /// The metadata artifacts that would be included if Metadata is ticked,
  /// as format tokens in Settings order followed by `html` and `app` when
  /// those options are on. Falls back to [fallbackFormats] when nothing is
  /// enabled so callers can describe what a ticked box will produce.
  List<String> get metadataTokens {
    final effective = includesMetadata ? formats : fallbackFormats;
    return [
      for (final token in shareExportFormatOrder)
        if (effective.contains(token)) token,
      if (includeHtmlReport) 'html',
      if (includeAppMetadata) 'app',
    ];
  }
}

/// Reads the saved export preferences into a [ShareExportConfig].
ShareExportConfig readShareExportConfig(WidgetRef ref) {
  return ShareExportConfig(
    formats: ref.read(exportSelectionProvider),
    includeAudio: ref.read(includeAudioProvider),
    shareAudioAsWav: ref.read(shareAudioAsWavProvider),
    includeHtmlReport: ref.read(exportHtmlReportProvider),
    includeAppMetadata: ref.read(includeAppMetadataProvider),
  );
}

/// Cheap, synchronous guess whether [session] has any audio to share: a
/// full recording, at least one detection clip, or ARU cycle recordings.
/// File existence is not checked here — the export pipeline does that —
/// so this only ever errs toward "available".
bool sessionMayHaveAudio(LiveSession session) {
  if (session.recordingPath != null || session.aruMetadata != null) {
    return true;
  }
  return session.detections.any(
    (d) => d.audioClipPath != null && d.audioClipPath!.isNotEmpty,
  );
}

/// Same guess for sharing one [detection]: the session recording it can be
/// cut from, or the detection's own retained clip.
bool detectionMayHaveAudio(DetectionRecord detection, LiveSession? session) {
  if (session?.recordingPath != null) return true;
  final clip = detection.audioClipPath;
  return clip != null && clip.isNotEmpty;
}
