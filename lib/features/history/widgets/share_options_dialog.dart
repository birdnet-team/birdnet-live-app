// =============================================================================
// Share Options Dialog — pick what one share includes and where it goes
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
// HTML report, and so on.
//
// Session shares add a second tab, "Send to", listing the platform share
// sheet and every configured upload destination (#284). The dialog keeps
// one fixed height whatever the number of destinations: the list scrolls
// inside its tab, and a badge on the tab counts the ticked destinations so
// the choice stays visible from the Content tab. Audio and Metadata govern
// both; the primary button reads Share, Upload, or Share and upload
// depending on what is ticked. The destinations ticked last time are ticked
// again so a repeat contribution is two taps. With no destination configured
// the tab offers to add one. Detection shares show no tabs.
//
// `pickShareExportConfig` is the one call share entry points make. It reads
// the preferences, shows the dialog, and returns the resolved
// [ShareExportConfig] — or null when the user backed out.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:birdnet_live/l10n/app_localizations.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/utils/app_icons.dart';
import '../../../shared/utils/locale_time_format.dart';
import '../../settings/settings_screen.dart' show SettingHelpTitle;
import '../../upload/join_destination_screen.dart';
import '../../upload/secret_store.dart';
import '../../upload/upload_destination.dart';
import '../../upload/upload_job.dart';
import '../../upload/upload_messages.dart';
import '../../upload/upload_providers.dart';
import '../../upload/webdav_client.dart';
import '../../upload/webdav_probe.dart';
import '../services/share_export_config.dart';

/// Reads the saved export preferences, lets the user adjust Audio and
/// Metadata for this share, and returns the configuration to export with.
/// Returns null when the dialog is dismissed.
///
/// [audioAvailable] greys out the Audio box when the caller already knows
/// there is no recording or clip to share (see `sessionMayHaveAudio`).
///
/// [uploadable] shows the "Send to" tab with the configured upload
/// destinations; pass the ids of the sessions being shared so the tab can
/// say which destinations already have them. Detection shares leave it null.
Future<ShareExportConfig?> pickShareExportConfig(
  BuildContext context,
  WidgetRef ref, {
  bool audioAvailable = true,
  List<String>? uploadable,
}) async {
  final initial = readShareExportConfig(ref);
  var destinations = const <UploadDestination>[];
  var remembered = const <String>{};
  var uploadedTo = const <String, DateTime>{};
  if (uploadable != null) {
    destinations = await ref.read(uploadDestinationsProvider.future);
    final prefs = ref.read(sharedPreferencesProvider);
    remembered = {
      ...?prefs.getStringList(PrefKeys.shareLastUploadDestinations),
    };
    final service = ref.read(uploadServiceProvider);
    await service.ensureLoaded();
    final dates = <String, DateTime>{};
    for (final sessionId in uploadable) {
      for (final job in service.jobsForSession(sessionId)) {
        final at = job.finishedAt;
        if (job.state != UploadJobState.uploaded || at == null) continue;
        final previous = dates[job.destinationId];
        if (previous == null || at.isAfter(previous)) {
          dates[job.destinationId] = at;
        }
      }
    }
    uploadedTo = dates;
  }
  if (!context.mounted) return null;
  final probe = ref.read(webDavProbeProvider);
  final notifier = ref.read(uploadDestinationsProvider.notifier);
  final result = await showDialog<ShareExportConfig>(
    context: context,
    builder: (_) => ShareOptionsDialog(
      initial: initial,
      audioAvailable: audioAvailable,
      showSendTo: uploadable != null,
      destinations: destinations,
      initialDestinationIds: remembered,
      uploadedTo: uploadedTo,
      checkReachable: (destination) async {
        final String? secret;
        try {
          secret = await notifier.secretFor(destination);
        } on SecretStoreException {
          // A locked keychain is a device problem, not a destination one;
          // the upload itself will report it.
          return null;
        }
        if (secret == null) return ProbeFailure.unauthorized;
        return probe.reachability(
          destination.url,
          WebDavClient.basicAuth(destination.username, secret),
        );
      },
      onAddDestination: () {
        Navigator.of(context).push(
          MaterialPageRoute<UploadDestination>(
            builder: (_) => const JoinDestinationScreen(),
          ),
        );
      },
    ),
  );
  if (result != null && uploadable != null) {
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(
          PrefKeys.shareLastUploadDestinations,
          result.uploadDestinationIds.toList()..sort(),
        );
  }
  return result;
}

class ShareOptionsDialog extends StatefulWidget {
  const ShareOptionsDialog({
    super.key,
    required this.initial,
    this.audioAvailable = true,
    this.showSendTo = false,
    this.destinations = const [],
    this.initialDestinationIds = const {},
    this.uploadedTo = const {},
    this.checkReachable,
    this.onAddDestination,
  });

  /// The saved export preferences this share starts from.
  final ShareExportConfig initial;

  /// False when the share has no audio to offer; the Audio box is then
  /// shown unticked and disabled with an explanatory subtitle.
  final bool audioAvailable;

  /// Whether the "Send to" tab (share sheet + upload destinations) is
  /// shown. Session shares pass true; detection shares keep it false.
  final bool showSendTo;

  final List<UploadDestination> destinations;

  /// Destinations ticked when the dialog opens (the previous choice).
  final Set<String> initialDestinationIds;

  /// Most recent successful upload of the shared session(s) per destination.
  /// Such destinations start unticked and show the date, so a repeat
  /// upload is a deliberate tick.
  final Map<String, DateTime> uploadedTo;

  /// Quick background check whether a destination would refuse the upload
  /// (see `WebDavProbe.reachability`). A stated failure is shown on the row;
  /// an inconclusive result (offline, timeout) shows nothing.
  final Future<ProbeFailure?> Function(UploadDestination destination)?
  checkReachable;

  /// Opens the join flow; the dialog closes without a result first.
  final VoidCallback? onAddDestination;

  @override
  State<ShareOptionsDialog> createState() => _ShareOptionsDialogState();
}

class _ShareOptionsDialogState extends State<ShareOptionsDialog> {
  late bool _audio = widget.audioAvailable && widget.initial.includeAudio;
  late bool _metadata = widget.initial.includesMetadata;
  bool _shareSheet = true;
  late final Set<String> _destinations = {
    for (final d in widget.destinations)
      if (widget.initialDestinationIds.contains(d.id) &&
          !widget.uploadedTo.containsKey(d.id))
        d.id,
  };
  final Map<String, ProbeFailure> _unreachable = {};

  @override
  void initState() {
    super.initState();
    final check = widget.checkReachable;
    if (check == null) return;
    for (final destination in widget.destinations) {
      unawaited(
        check(destination).then((failure) {
          if (!mounted || failure == null) return;
          setState(() => _unreachable[destination.id] = failure);
        }),
      );
    }
  }

  bool get _hasContent => _audio || _metadata;
  bool get _hasTarget =>
      !widget.showSendTo || _shareSheet || _destinations.isNotEmpty;
  bool get _canShare => _hasContent && _hasTarget;

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

  String _confirmLabel(AppLocalizations l10n) {
    if (!widget.showSendTo || _shareSheet && _destinations.isEmpty) {
      return l10n.shareOptionsConfirm;
    }
    if (_shareSheet) return l10n.shareOptionsShareAndUpload;
    return l10n.shareOptionsUpload;
  }

  IconData get _confirmIcon =>
      widget.showSendTo && !_shareSheet && _destinations.isNotEmpty
      ? AppIcons.cloudUpload
      : AppIcons.share;

  Widget _contentBoxes(AppLocalizations l10n) {
    return Column(
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
    );
  }

  /// The "Send to" list. Scrolls inside the tab so twenty destinations take
  /// no more room than two.
  Widget _sendToList(AppLocalizations l10n) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        CheckboxListTile(
          secondary: const Icon(AppIcons.share),
          title: Text(l10n.shareOptionsShareSheet),
          subtitle: Text(l10n.shareOptionsShareSheetSubtitle),
          value: _shareSheet,
          onChanged: (v) => setState(() => _shareSheet = v ?? false),
        ),
        for (final destination in widget.destinations)
          CheckboxListTile(
            secondary: _destinationIcon(destination),
            title: Text(destination.name),
            subtitle: _destinationSubtitle(l10n, destination),
            isThreeLine:
                widget.uploadedTo.containsKey(destination.id) ||
                _unreachable.containsKey(destination.id),
            value: _destinations.contains(destination.id),
            onChanged: (v) => setState(() {
              if (v ?? false) {
                _destinations.add(destination.id);
              } else {
                _destinations.remove(destination.id);
              }
            }),
          ),
        if (widget.destinations.isEmpty)
          ListTile(
            leading: const Icon(AppIcons.add),
            title: Text(l10n.uploadAddDestination),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () {
              Navigator.of(context).pop();
              widget.onAddDestination?.call();
            },
          ),
      ],
    );
  }

  Widget _destinationIcon(UploadDestination destination) {
    final scheme = Theme.of(context).colorScheme;
    if (_unreachable.containsKey(destination.id)) {
      return Icon(AppIcons.errorOutline, color: scheme.error);
    }
    if (widget.uploadedTo.containsKey(destination.id)) {
      return Icon(AppIcons.cloudDone, color: scheme.primary);
    }
    return const Icon(AppIcons.cloudUpload);
  }

  Widget _destinationSubtitle(
    AppLocalizations l10n,
    UploadDestination destination,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final failure = _unreachable[destination.id];
    if (failure != null) {
      return Text(
        '${destination.host}\n'
        '${l10n.shareOptionsDestinationUnreachable(probeFailureMessage(l10n, ProbeResult.failed(failure, resolvedUrl: destination.url)))}',
        style: TextStyle(color: scheme.error),
      );
    }
    final at = widget.uploadedTo[destination.id];
    if (at != null) {
      return Text(
        '${l10n.uploadStatusUploaded(formatLocaleDate(at, l10n.localeName))}\n'
        '${l10n.shareOptionsTickToUploadAgain}',
      );
    }
    return Text(destination.host);
  }

  /// Tabs for session shares. The pane height is fixed from the screen
  /// height so the dialog never grows with the destination list.
  Widget _tabbed(BuildContext context, AppLocalizations l10n) {
    final paneHeight = (MediaQuery.sizeOf(context).height * 0.4).clamp(
      200.0,
      360.0,
    );
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.shareOptionsTabContent),
              Tab(
                child: Badge.count(
                  count: _destinations.length,
                  isLabelVisible: _destinations.isNotEmpty,
                  // A count, not an alert: the default badge red reads as an
                  // error on a tab.
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  textColor: Theme.of(context).colorScheme.onPrimary,
                  offset: const Offset(14, -6),
                  child: Text(l10n.shareOptionsSendTo),
                ),
              ),
            ],
          ),
          SizedBox(
            height: paneHeight,
            child: TabBarView(
              children: [
                SingleChildScrollView(child: _contentBoxes(l10n)),
                _sendToList(l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      // Same title + "?" pairing as a Settings row; the help sheet explains
      // where the pre-ticked state comes from and that it is per share.
      title: SettingHelpTitle(
        title: l10n.shareOptionsTitle,
        helpBody: widget.showSendTo
            ? '${l10n.shareOptionsHelpDialog}\n\n${l10n.shareOptionsHelpSendTo}'
            : l10n.shareOptionsHelpDialog,
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.showSendTo
            ? _tabbed(context, l10n)
            : SingleChildScrollView(child: _contentBoxes(l10n)),
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
                    shareLocally: !widget.showSendTo || _shareSheet,
                    uploadDestinationIds: widget.showSendTo
                        ? Set.unmodifiable(_destinations)
                        : const {},
                  ),
                )
              : null,
          icon: Icon(_confirmIcon, size: 18),
          label: Text(_confirmLabel(l10n)),
        ),
      ],
    );
  }
}
