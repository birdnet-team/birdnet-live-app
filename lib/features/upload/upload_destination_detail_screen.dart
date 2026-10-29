// =============================================================================
// Upload Destination Detail — rename, toggles, test, remove
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../shared/utils/app_icons.dart';
import '../../shared/utils/locale_time_format.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../../shared/widgets/text_prompt_dialog.dart';
import 'join_code_dialog.dart';
import 'join_link.dart';
import 'upload_destination.dart';
import 'upload_messages.dart';
import 'upload_providers.dart';
import 'webdav_probe.dart';

class UploadDestinationDetailScreen extends ConsumerStatefulWidget {
  const UploadDestinationDetailScreen({super.key, required this.destinationId});

  final String destinationId;

  @override
  ConsumerState<UploadDestinationDetailScreen> createState() =>
      _UploadDestinationDetailScreenState();
}

class _UploadDestinationDetailScreenState
    extends ConsumerState<UploadDestinationDetailScreen> {
  bool _testing = false;
  ProbeResult? _lastTest;
  bool _secretMissing = false;

  UploadDestination? _find(List<UploadDestination>? list) {
    if (list == null) return null;
    for (final d in list) {
      if (d.id == widget.destinationId) return d;
    }
    return null;
  }

  Future<void> _rename(UploadDestination destination) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showTextPromptDialog(
      context,
      title: l10n.uploadDestinationRename,
      initialText: destination.name,
      labelText: l10n.uploadDestinationName,
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == destination.name) {
      return;
    }
    await ref
        .read(uploadDestinationsProvider.notifier)
        .replace(destination.copyWith(name: trimmed));
  }

  Future<void> _test(UploadDestination destination) async {
    setState(() {
      _testing = true;
      _lastTest = null;
      _secretMissing = false;
    });
    final notifier = ref.read(uploadDestinationsProvider.notifier);
    final secret = await notifier.secretFor(destination);
    if (secret == null) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _secretMissing = true;
      });
      return;
    }
    final deviceId = ref.read(uploadDeviceIdProvider);
    final info = await PackageInfo.fromPlatform();
    final result = await ref
        .read(webDavProbeProvider)
        .run(
          JoinRequest(
            url: destination.url,
            username: destination.username,
            secret: secret,
            // A share keeps its endpoint fallbacks and File Drop rules; any
            // other saved URL is tested exactly as stored.
            source: JoinLinkParser.publicShareToken(destination.url) != null
                ? JoinLinkSource.nextcloudShare
                : JoinLinkSource.joinLink,
          ),
          folder: ref.read(uploadDeviceCodeProvider),
          knownFlatLayout: destination.flatLayout,
          registration: joinRegistrationRecord(
            deviceId: deviceId,
            appVersion: info.version,
            participant: ref.read(uploadParticipantProvider),
          ),
        );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _lastTest = result;
    });
  }

  /// Shows the join link as a QR code so another phone can scan it with its
  /// camera, plus a copy button. The code carries the secret by design; the
  /// dialog says so.
  Future<void> _showJoinCode(UploadDestination destination) async {
    final l10n = AppLocalizations.of(context)!;
    final secret = await ref
        .read(uploadDestinationsProvider.notifier)
        .secretFor(destination);
    if (!mounted) return;
    if (secret == null) {
      setState(() => _secretMissing = true);
      return;
    }
    final link = JoinLinkParser.build(
      url: destination.url,
      username: destination.username,
      secret: secret,
      name: destination.name,
      wifiOnly: destination.wifiOnly,
    );
    await showDialog<void>(
      context: context,
      builder: (_) => JoinCodeDialog(
        link: link,
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: link));
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.uploadJoinQrCopied)));
        },
      ),
    );
  }

  Future<void> _remove(UploadDestination destination) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.uploadDestinationRemove),
        content: Text(l10n.uploadDestinationRemoveConfirm(destination.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.uploadDestinationRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(uploadDestinationsProvider.notifier).remove(destination.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final destination = _find(ref.watch(uploadDestinationsProvider).value);
    if (destination == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final notifier = ref.read(uploadDestinationsProvider.notifier);
    final lastUpload = destination.lastUploadAt;
    final lastTest = _lastTest;

    return Scaffold(
      appBar: AppBar(
        title: Text(destination.name),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.edit),
            tooltip: l10n.uploadDestinationRename,
            onPressed: () => _rename(destination),
          ),
        ],
      ),
      body: ContentWidthConstraint(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(AppIcons.storage),
              title: Text(l10n.uploadDestinationServer),
              subtitle: Text(destination.url),
            ),
            // A public share's "user name" is the share token, which the
            // project lead minted; it says nothing about this device.
            if (destination.username.isNotEmpty &&
                JoinLinkParser.publicShareToken(destination.url) == null)
              ListTile(
                leading: const Icon(AppIcons.key),
                title: Text(l10n.uploadDestinationUser),
                subtitle: Text(destination.username),
              ),
            ListTile(
              leading: const Icon(AppIcons.cloudUpload),
              title: Text(
                lastUpload == null
                    ? l10n.uploadDestinationNeverUploaded
                    : l10n.uploadDestinationLastUpload(
                        formatLocaleDate(lastUpload, l10n.localeName),
                      ),
              ),
              subtitle: Text(
                l10n.uploadDestinationAdded(
                  formatLocaleDate(destination.createdAt, l10n.localeName),
                ),
              ),
            ),
            const Divider(),
            SwitchListTile(
              title: Text(l10n.uploadDestinationWifiOnly),
              value: destination.wifiOnly,
              onChanged: (v) =>
                  notifier.replace(destination.copyWith(wifiOnly: v)),
            ),
            SwitchListTile(
              title: Text(l10n.uploadDestinationAutoAru),
              subtitle: Text(l10n.uploadDestinationAutoAruSubtitle),
              value: destination.autoUploadAru,
              onChanged: (v) =>
                  notifier.replace(destination.copyWith(autoUploadAru: v)),
            ),
            if (destination.canReadRemote ||
                destination.shareWithoutPassword ||
                destination.flatLayout)
              const Divider(),
            if (destination.canReadRemote)
              _NoteTile(
                icon: AppIcons.warningAmberRounded,
                color: theme.colorScheme.tertiary,
                text: probeWarningMessage(l10n, ProbeWarning.canReadRemote),
              ),
            if (destination.shareWithoutPassword)
              _NoteTile(
                icon: AppIcons.warningAmberRounded,
                color: theme.colorScheme.tertiary,
                text: probeWarningMessage(
                  l10n,
                  ProbeWarning.shareWithoutPassword,
                ),
              ),
            if (destination.flatLayout)
              _NoteTile(
                icon: AppIcons.infoOutline,
                text: l10n.uploadDestinationFlatLayout,
              ),
            const Divider(),
            ListTile(
              leading: const Icon(AppIcons.qrCode),
              title: Text(l10n.uploadDestinationShareQr),
              subtitle: Text(l10n.uploadDestinationShareQrSubtitle),
              onTap: () => _showJoinCode(destination),
            ),
            ListTile(
              leading: _testing
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.refresh),
              title: Text(
                _testing ? l10n.uploadJoinTesting : l10n.uploadDestinationTest,
              ),
              enabled: !_testing,
              onTap: () => _test(destination),
            ),
            if (_secretMissing)
              _NoteTile(
                icon: AppIcons.errorOutline,
                color: theme.colorScheme.error,
                text: l10n.uploadDestinationSecretMissing,
              ),
            if (lastTest != null)
              _NoteTile(
                icon: lastTest.ok
                    ? AppIcons.checkCircle
                    : AppIcons.errorOutline,
                color: lastTest.ok
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
                text: lastTest.ok
                    ? l10n.uploadJoinSuccess
                    : probeFailureMessage(l10n, lastTest),
              ),
            const Divider(),
            ListTile(
              leading: Icon(
                AppIcons.deleteOutline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                l10n.uploadDestinationRemove,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () => _remove(destination),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
