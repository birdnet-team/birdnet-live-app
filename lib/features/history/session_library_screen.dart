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

/// How sessions are ordered in the library.
enum _SortMode { dateDesc, dateAsc, nameAsc, nameDesc }

/// Displays a list of all saved sessions from the session repository.
class SessionLibraryScreen extends ConsumerStatefulWidget {
  const SessionLibraryScreen({super.key});

  @override
  ConsumerState<SessionLibraryScreen> createState() =>
      _SessionLibraryScreenState();
}

class _SessionLibraryScreenState extends ConsumerState<SessionLibraryScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  _SortMode _sortMode = _SortMode.dateDesc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Returns `true` if [session] matches the current search query.
  ///
  /// Matches against: date string, session type label, location name,
  /// lat/lon coordinates, and all detection species (common + scientific).
  bool _matchesQuery(LiveSession session, String query, AppLocalizations l10n) {
    final q = query.toLowerCase();

    // Date / time.
    final dateStr =
        DateFormat.yMMMd().add_Hm().format(session.startTime).toLowerCase();
    if (dateStr.contains(q)) return true;

    // Session type label.
    if (_sessionTypeLabel(l10n, session.type).toLowerCase().contains(q)) {
      return true;
    }

    // Location name or coordinates.
    final loc = session.locationName?.toLowerCase();
    if (loc != null && loc.contains(q)) return true;
    if (session.latitude != null && session.longitude != null) {
      final coords = '${session.latitude!.toStringAsFixed(4)}, '
          '${session.longitude!.toStringAsFixed(4)}';
      if (coords.contains(q)) return true;
    }

    // Species (common and scientific names).
    for (final d in session.detections) {
      if (d.commonName.toLowerCase().contains(q)) return true;
      if (d.scientificName.toLowerCase().contains(q)) return true;
    }

    return false;
  }

  PopupMenuItem<_SortMode> _sortMenuItem(
    _SortMode mode,
    String label,
    AppLocalizations l10n,
  ) {
    return PopupMenuItem<_SortMode>(
      value: mode,
      child: Row(
        children: [
          if (mode == _sortMode)
            Icon(Icons.check,
                size: 18, color: Theme.of(context).colorScheme.primary)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  List<LiveSession> _applySorting(List<LiveSession> sessions) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = List.of(sessions);
    switch (_sortMode) {
      case _SortMode.dateDesc:
        sorted.sort((a, b) => b.startTime.compareTo(a.startTime));
      case _SortMode.dateAsc:
        sorted.sort((a, b) => a.startTime.compareTo(b.startTime));
      case _SortMode.nameAsc:
        sorted.sort((a, b) =>
            _sessionCardTitle(l10n, a).compareTo(_sessionCardTitle(l10n, b)));
      case _SortMode.nameDesc:
        sorted.sort((a, b) =>
            _sessionCardTitle(l10n, b).compareTo(_sessionCardTitle(l10n, a)));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(sessionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.sessionLibrarySearchHint,
                  border: InputBorder.none,
                ),
                style: theme.textTheme.titleMedium,
                onChanged: (_) => setState(() {}),
              )
            : Text(l10n.sessionLibraryTitle),
        actions: [
          if (_showSearch)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _searchController.clear();
                _showSearch = false;
              }),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _showSearch = true),
            ),
            PopupMenuButton<_SortMode>(
              icon: const Icon(Icons.swap_vert),
              tooltip: l10n.sessionLibrarySortTooltip,
              onSelected: (mode) => setState(() => _sortMode = mode),
              itemBuilder: (_) => [
                _sortMenuItem(
                    _SortMode.dateDesc, l10n.sessionSortDateNewest, l10n),
                _sortMenuItem(
                    _SortMode.dateAsc, l10n.sessionSortDateOldest, l10n),
                _sortMenuItem(_SortMode.nameAsc, l10n.sessionSortNameAZ, l10n),
                _sortMenuItem(_SortMode.nameDesc, l10n.sessionSortNameZA, l10n),
              ],
            ),
          ],
        ],
      ),
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

          final query = _searchController.text.trim();
          final matched = query.isEmpty
              ? sessions
              : sessions.where((s) => _matchesQuery(s, query, l10n)).toList();
          final filtered = _applySorting(matched);

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                l10n.sessionLibraryNoResults,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final session = filtered[index];
              return _SessionTile(
                session: session,
                onTap: () => _openReview(session),
                onDelete: () => _confirmDelete(session),
              );
            },
          );
        },
      ),
    );
  }

  void _openReview(LiveSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionReviewScreen(session: session),
      ),
    );
  }

  Future<void> _confirmDelete(LiveSession session) async {
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
    final dateStr = DateFormat.yMMMd().format(session.startTime);
    final timeStr = DateFormat.jm().format(session.startTime);

    final duration = session.duration;
    final speciesCount = session.uniqueSpeciesCount;
    final detectionCount = session.detections.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _sessionTypeIcon(session.type),
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sessionCardTitle(
                              AppLocalizations.of(context)!, session),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '$dateStr at $timeStr',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              session.latitude != null
                                  ? Icons.location_on_outlined
                                  : Icons.location_off_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                session.locationName ??
                                    (session.latitude != null &&
                                            session.longitude != null
                                        ? '${session.latitude!.toStringAsFixed(4)}, '
                                            '${session.longitude!.toStringAsFixed(4)}'
                                        : AppLocalizations.of(context)!
                                            .sessionNoLocation),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              if (_topSpecies(session).isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _topSpecies(session)
                      .map((name) => Chip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            label:
                                Text(name, style: theme.textTheme.labelSmall),
                            padding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatBadge(
                    icon: Icons.timer_outlined,
                    label: _formatDuration(duration),
                  ),
                  _StatBadge(
                    icon: Icons.pets_outlined,
                    label: '$speciesCount spp.',
                  ),
                  _StatBadge(
                    icon: Icons.music_note_outlined,
                    label: '$detectionCount det.',
                  ),
                ],
              ),
            ],
          ),
        ),
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

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Returns a localized display label for the given [SessionType].
String _sessionTypeLabel(AppLocalizations l10n, SessionType type) {
  switch (type) {
    case SessionType.live:
      return l10n.sessionTypeLive;
    case SessionType.fileUpload:
      return l10n.sessionTypeFileUpload;
    case SessionType.pointCount:
      return l10n.sessionTypePointCount;
    case SessionType.survey:
      return l10n.sessionTypeSurvey;
  }
}

/// Returns the icon matching the session type used on the home screen.
IconData _sessionTypeIcon(SessionType type) {
  switch (type) {
    case SessionType.live:
      return Icons.mic_rounded;
    case SessionType.fileUpload:
      return Icons.audio_file_rounded;
    case SessionType.pointCount:
      return Icons.location_on_rounded;
    case SessionType.survey:
      return Icons.route_rounded;
  }
}

/// Returns the common names of the top 5 most-detected species.
List<String> _topSpecies(LiveSession session) {
  final counts = <String, int>{};
  for (final d in session.detections) {
    counts[d.commonName] = (counts[d.commonName] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(5).map((e) => e.key).toList();
}

/// Returns a numbered card title such as "Live Session #3".
///
/// Falls back to the plain type label for legacy sessions without a number.
String _sessionCardTitle(AppLocalizations l10n, LiveSession session) {
  if (session.customName != null && session.customName!.isNotEmpty) {
    return session.customName!;
  }
  final n = session.sessionNumber;
  if (n == null) return _sessionTypeLabel(l10n, session.type);
  switch (session.type) {
    case SessionType.live:
      return l10n.sessionCardLiveNum(n);
    case SessionType.fileUpload:
      return l10n.sessionCardFileUploadNum(n);
    case SessionType.pointCount:
      return l10n.sessionCardPointCountNum(n);
    case SessionType.survey:
      return l10n.sessionCardSurveyNum(n);
  }
}
