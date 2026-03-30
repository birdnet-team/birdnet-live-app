// =============================================================================
// Session Library Screen — Browse saved live sessions
// =============================================================================
//
// Lists all completed sessions stored via [SessionRepository].  Each row
// shows the date, duration, species count, and detection count.  Tapping
// a session opens the [SessionReviewScreen] for playback and editing.
//
// Accessible from the Home screen footer.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../live/live_providers.dart';
import '../live/live_session.dart';
import 'session_review_screen.dart';

/// Displays a list of all saved sessions from the session repository.
class SessionLibraryScreen extends ConsumerWidget {
  const SessionLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(sessionListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sessionLibraryTitle)),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.library_music_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withAlpha(60),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.sessionLibraryEmpty,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _SessionTile(
                session: session,
                onTap: () => _openReview(context, ref, session),
                onDelete: () => _confirmDelete(context, ref, session),
              );
            },
          );
        },
      ),
    );
  }

  void _openReview(BuildContext context, WidgetRef ref, LiveSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionReviewScreen(session: session),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LiveSession session,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sessionDiscardTitle),
        content: Text(l10n.sessionDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.sessionDiscard),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(sessionRepositoryProvider).delete(session.id);
    ref.invalidate(sessionListProvider);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  final LiveSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dateStr = DateFormat.yMMMd().add_Hm().format(session.startTime);
    final duration = session.duration;
    final species = session.uniqueSpeciesCount;
    final detections = session.detections.length;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.mic,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(dateStr),
      subtitle: Text(
        '${_formatDuration(duration)} · '
        '${l10n.sessionSpeciesCount(species)} · '
        '${l10n.sessionDetectionCount(detections)}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: onDelete,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m ${seconds}s';
  }
}
