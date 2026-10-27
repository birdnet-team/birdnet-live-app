// =============================================================================
// Share Options Dialog — pick what one share includes
// =============================================================================
//
// Shown after the user taps Share on a session, a multi-session selection,
// or a single detection. Two coarse boxes — Audio and Metadata — start out
// mirroring the export preferences in Settings › Export & Sync and apply to
// this share only; the saved preferences are never touched.
//
// Each box carries a "?" help button (the same affordance as Settings) and
// a one-line subtitle naming exactly what a ticked box will add, so the user
// can tell at a glance whether this share carries a WAV, a Raven table, an
// HTML report, and so on. The Share button stays disabled while both boxes
// are off: an empty share is never handed to the platform sheet.
//
// `pickShareExportConfig` is the one call share entry points make. It reads
// the preferences, shows the dialog, and returns the resolved
// [ShareExportConfig] — or null when the user backed out.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:birdnet_live/l10n/app_localizations.dart';

import '../../../shared/utils/app_icons.dart';
import '../../settings/settings_screen.dart' show SettingHelpTitle;
import '../services/share_export_config.dart';

/// Reads the saved export preferences, lets the user adjust Audio and
/// Metadata for this share, and returns the configuration to export with.
/// Returns null when the dialog is dismissed.
///
/// [audioAvailable] greys out the Audio box when the caller already knows
/// there is no recording or clip to share (see `sessionMayHaveAudio`).
Future<ShareExportConfig?> pickShareExportConfig(
  BuildContext context,
  WidgetRef ref, {
  bool audioAvailable = true,
}) {
  final initial = readShareExportConfig(ref);
  return showDialog<ShareExportConfig>(
    context: context,
    builder: (_) =>
        ShareOptionsDialog(initial: initial, audioAvailable: audioAvailable),
  );
}

class ShareOptionsDialog extends StatefulWidget {
  const ShareOptionsDialog({
    super.key,
    required this.initial,
    this.audioAvailable = true,
  });

  /// The saved export preferences this share starts from.
  final ShareExportConfig initial;

  /// False when the share has no audio to offer; the Audio box is then
  /// shown unticked and disabled with an explanatory subtitle.
  final bool audioAvailable;

  @override
  State<ShareOptionsDialog> createState() => _ShareOptionsDialogState();
}

class _ShareOptionsDialogState extends State<ShareOptionsDialog> {
  late bool _audio = widget.audioAvailable && widget.initial.includeAudio;
  late bool _metadata = widget.initial.includesMetadata;

  bool get _canShare => _audio || _metadata;

  String _audioSubtitle(AppLocalizations l10n) {
    if (!widget.audioAvailable) return l10n.shareOptionsAudioUnavailable;
    return widget.initial.shareAudioAsWav
        ? l10n.shareOptionsAudioAsWav
        : l10n.shareOptionsAudioOriginal;
  }

  String _metadataSubtitle(AppLocalizations l10n) {
    final labels = <String>[
      for (final token in widget.initial.metadataTokens)
        switch (token) {
          'html' => l10n.shareOptionsHtmlReport,
          'app' => l10n.shareOptionsAppMetadata,
          _ => shareExportFormatLabels[token] ?? token,
        },
    ];
    return labels.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      // Same title + "?" pairing as a Settings row; the help sheet explains
      // where the pre-ticked state comes from and that it is per share.
      title: SettingHelpTitle(
        title: l10n.shareOptionsTitle,
        helpBody: l10n.shareOptionsHelpDialog,
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              secondary: const Icon(AppIcons.audioFileOutlined),
              title: SettingHelpTitle(
                title: l10n.shareOptionsAudio,
                helpBody: l10n.shareOptionsHelpAudio,
              ),
              subtitle: Text(_audioSubtitle(l10n)),
              value: _audio,
              onChanged: widget.audioAvailable
                  ? (v) => setState(() => _audio = v ?? false)
                  : null,
            ),
            CheckboxListTile(
              secondary: const Icon(AppIcons.listAlt),
              title: SettingHelpTitle(
                title: l10n.shareOptionsMetadata,
                helpBody: l10n.shareOptionsHelpMetadata,
              ),
              subtitle: Text(_metadataSubtitle(l10n)),
              value: _metadata,
              onChanged: (v) => setState(() => _metadata = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _canShare
              ? () => Navigator.of(context).pop(
                  widget.initial.withChoices(
                    audio: _audio,
                    metadata: _metadata,
                  ),
                )
              : null,
          icon: const Icon(AppIcons.share, size: 18),
          label: Text(l10n.shareOptionsConfirm),
        ),
      ],
    );
  }
}
