// =============================================================================
// Upload Destinations Screen — the configured destinations, from Settings
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import '../../shared/utils/app_icons.dart';
import '../../shared/utils/locale_time_format.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../../shared/widgets/text_prompt_dialog.dart';
import 'join_destination_screen.dart';
import 'upload_destination.dart';
import 'upload_destination_detail_screen.dart';
import 'upload_providers.dart';

class UploadDestinationsScreen extends ConsumerWidget {
  const UploadDestinationsScreen({super.key});

  Future<void> _add(BuildContext context) {
    return Navigator.of(context).push<UploadDestination>(
      MaterialPageRoute<UploadDestination>(
        builder: (_) => const JoinDestinationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final destinations = ref.watch(uploadDestinationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.uploadDestinations)),
      floatingActionButton: destinations.value?.isNotEmpty ?? false
          ? FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.uploadAddDestination),
            )
          : null,
      body: ContentWidthConstraint(
        child: destinations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (list) => list.isEmpty
              ? _EmptyState(onAdd: () => _add(context))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    const _DeviceCodeTile(),
                    const Divider(),
                    for (final destination in list)
                      _DestinationTile(destination: destination),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The device code that names this device's folder at every destination,
/// with the optional participant identifier that travels in the metadata.
class _DeviceCodeTile extends ConsumerWidget {
  const _DeviceCodeTile();

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final value = await showTextPromptDialog(
      context,
      title: l10n.uploadParticipantLabel,
      initialText: ref.read(uploadParticipantProvider),
      helperText: l10n.uploadParticipantHelp,
      textCapitalization: TextCapitalization.none,
    );
    if (value == null) return;
    await ref.read(uploadParticipantProvider.notifier).set(value.trim());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final code = ref.watch(uploadDeviceCodeProvider);
    final participant = ref.watch(uploadParticipantProvider);
    return ListTile(
      leading: const Icon(AppIcons.cloudUpload),
      title: Text(l10n.uploadDeviceCodeTitle),
      subtitle: Text(participant.isEmpty ? code : '$code · $participant'),
      trailing: const Icon(AppIcons.edit),
      onTap: () => _edit(context, ref),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.cloudUpload,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.uploadDestinationsEmptyTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.uploadDestinationsEmptyBody,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(AppIcons.add),
              label: Text(l10n.uploadAddDestination),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination});

  final UploadDestination destination;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lastUpload = destination.lastUploadAt;
    final hasWarning =
        destination.canReadRemote || destination.shareWithoutPassword;
    return ListTile(
      leading: Icon(
        hasWarning ? AppIcons.warningAmberRounded : AppIcons.cloud,
        color: hasWarning ? theme.colorScheme.tertiary : null,
      ),
      title: Text(destination.name),
      subtitle: Text(
        '${destination.host}\n'
        '${lastUpload == null ? l10n.uploadDestinationNeverUploaded : l10n.uploadDestinationLastUpload(formatLocaleDate(lastUpload, l10n.localeName))}',
      ),
      isThreeLine: true,
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                UploadDestinationDetailScreen(destinationId: destination.id),
          ),
        );
      },
    );
  }
}
