// =============================================================================
// Upload Status Widgets — the library line, the review action, the sheet
// =============================================================================
//
// [UploadStatusLine] is the first metadata line of a session tile and says
// what happened to the session's uploads: a spinner while one is running,
// "Queued" or "Waiting for Wi-Fi" while pending, "Uploaded <date>" when done,
// or a failure sentence that names the fix. [UploadStatusAction] is the same
// state as an app-bar icon on Session Review. Both only appear while at
// least one destination the session was queued for still exists in
// Settings: once the user removes a destination, "uploaded" is no longer a
// fact about any destination they have. Tapping either opens
// [UploadStatusSheet], which lists every destination the session was queued
// for with its state, the last error in one sentence, and Retry / Remove.
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

/// The one-line summary of a session's uploads, or null when there is
/// nothing to say: no jobs, or none whose destination still exists.
class UploadStatusSummary {
  const UploadStatusSummary({
    required this.icon,
    required this.text,
    required this.color,
    required this.busy,
  });

  final IconData icon;
  final String text;
  final Color color;

  /// An upload is running right now; show a spinner instead of [icon].
  final bool busy;

  static UploadStatusSummary? of(
    BuildContext context,
    List<UploadJob> jobs,
    Iterable<String> existingDestinationIds,
  ) {
    final ids = existingDestinationIds.toSet();
    final live = [
      for (final j in jobs)
        if (ids.contains(j.destinationId)) j,
    ];
    if (live.isEmpty) return null;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final uploading = live.where((j) => j.state == UploadJobState.uploading);
    final failed = live.where((j) => j.state == UploadJobState.failed);
    final pending = live.where((j) => j.isPending);
    if (uploading.isNotEmpty) {
      return UploadStatusSummary(
        icon: AppIcons.cloudUpload,
        text: l10n.uploadStatusUploading,
        color: scheme.primary,
        busy: true,
      );
    }
    if (failed.isNotEmpty) {
      return UploadStatusSummary(
        icon: AppIcons.errorOutline,
        text: uploadStateLabel(l10n, failed.first),
        color: scheme.error,
        busy: false,
      );
    }
    if (pending.isNotEmpty) {
      return UploadStatusSummary(
        icon: AppIcons.cloudUpload,
        text: uploadStateLabel(l10n, pending.first),
        color: scheme.onSurfaceVariant,
        busy: false,
      );
    }
    // All done: the newest upload date.
    UploadJob newest = live.first;
    for (final j in live) {
      final a = j.finishedAt, b = newest.finishedAt;
      if (b == null || (a != null && a.isAfter(b))) newest = j;
    }
    return UploadStatusSummary(
      icon: AppIcons.cloudDone,
      text: uploadStateLabel(l10n, newest),
      color: scheme.primary,
      busy: false,
    );
  }
}

/// Builds [child] from the session's upload summary; renders nothing when
/// there is no summary. Shared by the line and the action.
class _UploadStatusBuilder extends ConsumerWidget {
  const _UploadStatusBuilder({required this.sessionId, required this.builder});

  final String sessionId;
  final Widget Function(BuildContext context, UploadStatusSummary summary)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(uploadServiceProvider);
    unawaited(service.ensureLoaded());
    final destinations =
        ref.watch(uploadDestinationsProvider).value ?? const [];
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final summary = UploadStatusSummary.of(
          context,
          service.jobsForSession(sessionId),
          destinations.map((d) => d.id),
        );
        if (summary == null) return const SizedBox.shrink();
        return builder(context, summary);
      },
    );
  }
}

/// Metadata line for a session tile: icon plus one sentence, tappable.
class UploadStatusLine extends StatelessWidget {
  const UploadStatusLine({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return _UploadStatusBuilder(
      sessionId: sessionId,
      builder: (context, summary) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => showUploadStatusSheet(context, sessionId),
            child: Row(
              children: [
                summary.busy
                    ? SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: summary.color,
                        ),
                      )
                    : Icon(summary.icon, size: 14, color: summary.color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    summary.text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: summary.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// App-bar icon for Session Review; the tooltip carries the sentence.
class UploadStatusAction extends StatelessWidget {
  const UploadStatusAction({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return _UploadStatusBuilder(
      sessionId: sessionId,
      builder: (context, summary) => IconButton(
        icon: summary.busy
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: summary.color,
                ),
              )
            : Icon(summary.icon, color: summary.color),
        tooltip: summary.text,
        onPressed: () => showUploadStatusSheet(context, sessionId),
      ),
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
      title: Text(destinationName),
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
      // Errors the server stated will not go away with a retry; point at
      // the destination's settings instead of promising one.
      switch (job.lastError) {
        case UploadErrorCode.unauthorized:
        case UploadErrorCode.forbidden:
        case UploadErrorCode.destinationMissing:
        case UploadErrorCode.secretMissing:
          return l10n.uploadStatusFailedCheckDestination;
      }
      return job.gaveUp ? l10n.uploadStatusGaveUp : l10n.uploadStatusFailed;
  }
}

/// Confirms that [count] sessions were queued, when any were.
void showUploadQueuedSnackBar(BuildContext context, int count) {
  if (count <= 0) return;
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(l10n.uploadQueuedSnack(count))));
}
