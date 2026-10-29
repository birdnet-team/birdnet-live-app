// =============================================================================
// Export Options Screens — the two groups behind Settings › Export & Sync
// =============================================================================
//
// Export & Sync used to be one long checkbox list. It is now three entries,
// each summarizing its choices in a subtitle: Formats (which tables go into
// a share), Content (what rides along with them: audio, HTML report, app
// metadata), and Upload destinations. The first two open the screens in this
// file; every box keeps its help text, and the pipeline behind them is
// unchanged (see buildSessionExport).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../history/services/share_export_config.dart';
import 'settings_screen.dart' show SettingHelpTitle;

/// Subtitle of the Formats entry: the ticked formats in Settings order, or
/// "None" when a share carries no table.
String exportFormatsSummary(AppLocalizations l10n, Set<String> selection) {
  final labels = [
    for (final token in shareExportFormatOrder)
      if (selection.contains(token)) shareExportFormatLabels[token]!,
  ];
  return labels.isEmpty ? l10n.settingsExportFormatsNone : labels.join(', ');
}

/// Subtitle of the Content entry: what rides along with the tables.
String exportContentSummary(
  AppLocalizations l10n, {
  required bool includeAudio,
  required bool audioAsWav,
  required bool htmlReport,
  required bool appMetadata,
}) {
  final parts = <String>[
    if (includeAudio)
      audioAsWav ? '${l10n.shareOptionsAudio} (WAV)' : l10n.shareOptionsAudio,
    if (htmlReport) l10n.shareOptionsHtmlReport,
    if (appMetadata) l10n.shareOptionsAppMetadata,
  ];
  return parts.isEmpty ? l10n.settingsExportContentNone : parts.join(', ');
}

/// Which tables a share bundles: any combination of Raven, CSV, JSON, GPX.
class ExportFormatsScreen extends ConsumerWidget {
  const ExportFormatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selection = ref.watch(exportSelectionProvider);
    // (token, display label, per-format help). Labels stay in English as
    // technical terms; only the help bodies are localized.
    final formats = <(String, String, String)>[
      ('raven', 'Raven Selection Table', l10n.settingsHelpExportRaven),
      ('csv', 'CSV', l10n.settingsHelpExportCsv),
      ('json', 'JSON', l10n.settingsHelpExportJson),
      ('gpx', 'GPX (track + waypoints)', l10n.settingsHelpExportGpx),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsExportFormatsTitle)),
      body: ContentWidthConstraint(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SettingHelpTitle(
                title: l10n.settingsExportFormat,
                helpBody: l10n.settingsHelpExportFormat,
              ),
            ),
            for (final fmt in formats)
              CheckboxListTile(
                title: SettingHelpTitle(title: fmt.$2, helpBody: fmt.$3),
                value: selection.contains(fmt.$1),
                onChanged: (v) => ref
                    .read(exportSelectionProvider.notifier)
                    .toggle(fmt.$1, v ?? false),
              ),
          ],
        ),
      ),
    );
  }
}

/// What a share carries besides the tables: audio (and its container), the
/// HTML report, and the app metadata side-file.
class ExportContentScreen extends ConsumerWidget {
  const ExportContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final includeAudio = ref.watch(includeAudioProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsExportContentTitle)),
      body: ContentWidthConstraint(
        child: ListView(
          children: [
            CheckboxListTile(
              title: SettingHelpTitle(
                title: l10n.settingsIncludeAudioFiles,
                helpBody: l10n.settingsHelpIncludeAudioFiles,
              ),
              value: includeAudio,
              onChanged: (v) =>
                  ref.read(includeAudioProvider.notifier).set(v ?? false),
            ),
            if (includeAudio)
              CheckboxListTile(
                title: SettingHelpTitle(
                  title: l10n.settingsShareAudioAsWav,
                  helpBody: l10n.settingsHelpShareAudioAsWav,
                ),
                value: ref.watch(shareAudioAsWavProvider),
                onChanged: (v) =>
                    ref.read(shareAudioAsWavProvider.notifier).set(v ?? false),
              ),
            CheckboxListTile(
              title: SettingHelpTitle(
                title: l10n.settingsExportHtmlReport,
                helpBody: l10n.settingsHelpExportHtmlReport,
              ),
              value: ref.watch(exportHtmlReportProvider),
              onChanged: (v) =>
                  ref.read(exportHtmlReportProvider.notifier).set(v ?? false),
            ),
            CheckboxListTile(
              title: SettingHelpTitle(
                title: l10n.settingsExportAppMetadata,
                helpBody: l10n.settingsHelpExportAppMetadata,
              ),
              value: ref.watch(includeAppMetadataProvider),
              onChanged: (v) =>
                  ref.read(includeAppMetadataProvider.notifier).set(v ?? false),
            ),
          ],
        ),
      ),
    );
  }
}
