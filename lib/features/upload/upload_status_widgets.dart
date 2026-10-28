// =============================================================================
// Upload Status Widgets — the library chip and the per-session sheet
// =============================================================================
//
// [UploadStatusChip] sits among a session tile's stat chips and shows one
// icon for the session's uploads: a spinner while one is running, an
// outlined cloud while any is pending, a check when all are done, an error
// mark when one failed. Tapping it opens [UploadStatusSheet], which lists
// every destination the session was queued for with its state, the last
// error in one sentence, and Retry / Remove actions.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import '../../shared/utils/app_icons.dart';
import '../../shared/utils/locale_time_format.dart';
import 'upload_job.dart';
import 'upload_messages.dart';
import 'upload_providers.dart';
import 'upload_service.dart';

class UploadStatusChip extends ConsumerWidget {
  const UploadStatusChip({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(uploadServiceProvider);
    unawaited(service.ensureLoaded());
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final jobs = service.jobsForSession(sessionId);
        if (jobs.isEmpty) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final uploading = jobs.any((j) => j.state == UploadJobState.uploading);
        final failed = jobs.any(
          (j) => j.state == UploadJobState.failed && j.lastError != null,
        );
        final pending = jobs.any((j) => j.isPending);
        final Widget avatar;
        Color? color;
        if (uploading) {
          avatar = const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else if (failed) {
          color = theme.colorScheme.error;
          avatar = Icon(AppIcons.errorOutline, size: 16, color: color);
        } else if (pending) {
          avatar = const Icon(AppIcons.cloudUpload, size: 16);
        } else {
          color = theme.colorScheme.primary;
          avatar = Icon(AppIcons.checkCircle, size: 16, color: color);
        }
        return ActionChip(
          avatar: avatar,
          label: Text(l10n.uploadChipLabel(jobs.length)),
          labelStyle: theme.textTheme.labelSmall?.copyWith(color: color),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: () => showUploadStatusSheet(context, sessionId),
        );
      },
    );
  }
}

Future<void> showUploadStatusSheet(BuildContext context, String sessionId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => UploadStatusSheet(sessionId: sessionId),
  );
}

class UploadStatusSheet extends ConsumerWidget {
  const UploadStatusSheet({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final service = ref.watch(uploadServiceProvider);
    final destinations =
        ref.watch(uploadDestinationsProvider).value ?? const [];
    String nameOf(String id) {
      for (final d in destinations) {
        if (d.id == id) return d.name;
      }
      return l10n.uploadDestinationUnknown;
    }

    return SafeArea(
      child: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final jobs = service.jobsForSession(sessionId);
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  l10n.uploadStatusTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              for (final job in jobs)
                _JobTile(job: job, destinationName: nameOf(job.destinationId)),
            ],
          );
        },
      ),
    );
  }
}

class _JobTile extends ConsumerWidget {
  const _JobTile({required this.job, required this.destinationName});

  final UploadJob job;
  final String destinationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final service = ref.read(uploadServiceProvider);
    final error = job.lastError;
    final detail = error == null ? null : uploadErrorMessage(l10n, error);
    final failed = job.state == UploadJobState.failed;
    final IconData icon;
    Color? color;
    switch (job.state) {
      case UploadJobState.uploaded:
        icon = AppIcons.checkCircle;
        color = theme.colorScheme.primary;
      case UploadJobState.failed:
        icon = AppIcons.errorOutline;
        color = theme.colorScheme.error;
      case UploadJobState.uploading:
      case UploadJobState.queued:
        icon = AppIcons.cloudUpload;
    }
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        job.version > 1
            ? '$destinationName (v${job.version})'
            : destinationName,
      ),
      subtitle: Text(
        [
          uploadStateLabel(l10n, job),
          if (detail != null && failed) detail,
        ].join('\n'),
      ),
      isThreeLine: detail != null && failed,
      trailing: job.state == UploadJobState.uploaded
          ? null
          : PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'retry':
                    service.retryNow(job.id);
                  case 'cancel':
                    service.cancel(job.id);
                }
              },
              itemBuilder: (context) => [
                if (failed)
                  PopupMenuItem(
                    value: 'retry',
                    child: Text(l10n.uploadRetryNow),
                  ),
                PopupMenuItem(
                  value: 'cancel',
                  child: Text(
                    l10n.uploadCancel,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
    );
  }
}

/// One line for a job's state, with the upload date when it finished.
String uploadStateLabel(AppLocalizations l10n, UploadJob job) {
  switch (job.state) {
    case UploadJobState.queued:
      return switch (job.lastError) {
        UploadErrorCode.waitingForWifi => l10n.uploadStatusWaitingForWifi,
        UploadErrorCode.offline => l10n.uploadStatusOffline,
        _ => l10n.uploadStatusQueued,
      };
    case UploadJobState.uploading:
      return l10n.uploadStatusUploading;
    case UploadJobState.uploaded:
      final at = job.finishedAt;
      return at == null
          ? l10n.uploadJoinSuccess
          : l10n.uploadStatusUploaded(formatLocaleDate(at, l10n.localeName));
    case UploadJobState.failed:
      return job.gaveUp ? l10n.uploadStatusGaveUp : l10n.uploadStatusFailed;
  }
}
