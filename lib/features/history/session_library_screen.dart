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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/session_type_visuals.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/confirm_destructive.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../../shared/widgets/empty_view.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/stat_chip.dart';
import '../explore/explore_providers.dart';
import '../file_analysis/file_analysis_screen.dart';
import '../live/live_providers.dart';
import '../live/live_screen.dart';
import '../live/live_session.dart';
import '../point_count/point_count_setup_screen.dart';
import '../survey/survey_setup_screen.dart';
import 'export_metadata_helper.dart';
import 'session_export.dart';
import 'session_review_screen.dart';

/// How sessions are ordered in the library.
enum _SortMode {
  dateDesc,
  dateAsc,
  nameAsc,
  nameDesc,
  durationDesc,
  durationAsc,
}

/// Actions exposed by the per-row overflow menu in the session library.
enum _SessionRowAction { open, share, delete }

/// How sessions are presented in the library.
enum _ViewMode { detailed, compact, bySpecies }

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
  _ViewMode _viewMode = _ViewMode.detailed;

  /// Active session-type filters. Empty means "all types". Multiple
  /// selections combine as a logical OR (e.g. Live + Survey shows both).
  final Set<SessionType> _typeFilters = <SessionType>{};

  /// Mode the "new session" FAB will start when tapped. Persisted across
  /// app launches so the FAB remembers the user's last pick.
  SessionType _newSessionMode = SessionType.live;

  /// Session ids whose compact-view rows are currently expanded to show
  /// the full detailed card body. Not persisted — collapses on rebuild.
  final Set<String> _expandedCompactCards = <String>{};

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    _loadNewSessionMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(PrefKeys.sessionLibraryViewMode);
    if (stored == null || !mounted) return;
    final mode = _ViewMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => _ViewMode.detailed,
    );
    if (mode != _viewMode) setState(() => _viewMode = mode);
  }

  Future<void> _loadNewSessionMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(PrefKeys.sessionLibraryNewMode);
    if (stored == null || !mounted) return;
    final mode = SessionType.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => SessionType.live,
    );
    if (mode != _newSessionMode) setState(() => _newSessionMode = mode);
  }

  Future<void> _persistNewSessionMode(SessionType mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.sessionLibraryNewMode, mode.name);
  }

  /// Persists the view mode without touching widget state — the caller is
  /// responsible for already having updated [_viewMode] inside a
  /// [setState]/`StatefulBuilder` callback so the chip highlight updates
  /// in the same frame as the tap.
  Future<void> _persistViewMode(_ViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.sessionLibraryViewMode, mode.name);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => AppHelpBottomSheet(
            title: l10n.sessionLibraryHelpTitle,
            sections: [
              // Icons here intentionally mirror the actual AppBar buttons so
              // users can map each help section to a tap target on screen.
              AppHelpSection(
                icon: Icons.search,
                body: l10n.sessionLibraryHelpSearch,
              ),
              AppHelpSection(
                icon: Icons.filter_list_outlined,
                body: l10n.sessionLibraryHelpView,
              ),
              AppHelpSection(
                icon: Icons.sort,
                body: l10n.sessionLibraryHelpSort,
              ),
              AppHelpSection(
                icon: Icons.category_outlined,
                body: l10n.sessionLibraryHelpFilter,
              ),
              AppHelpSection(
                icon: Icons.touch_app_outlined,
                body: l10n.sessionLibraryHelpOpen,
              ),
            ],
          ),
    );
  }

  /// Returns `true` if [session] matches the current search query.
  ///
  /// Matches against: session name, date string, session type label, location name,
  /// lat/lon coordinates, and all detection species (common + scientific).
  bool _matchesQuery(LiveSession session, String query, AppLocalizations l10n) {
    final q = query.toLowerCase();

    // Session display name.
    if (session.displayName.toLowerCase().contains(q)) return true;

    // Date / time.
    final dateStr =
        DateFormat.yMMMd()
            .add_Hm()
            .format(session.startTime.toLocal())
            .toLowerCase();
    if (dateStr.contains(q)) return true;

    // Session type label.
    if (_sessionTypeLabel(l10n, session.type).toLowerCase().contains(q)) {
      return true;
    }

    // Location name or coordinates.
    final loc = session.locationName?.toLowerCase();
    if (loc != null && loc.contains(q)) return true;
    if (session.latitude != null && session.longitude != null) {
      final coords =
          '${session.latitude!.toStringAsFixed(4)}, '
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

  void _showOptionsSheet() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              void update(VoidCallback fn) {
                setSheetState(fn);
                setState(fn);
              }

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sheetSectionHeader(l10n.sessionLibrarySortTooltip),
                      _sheetChips<_SortMode>(
                        current: _sortMode,
                        options: [
                          (_SortMode.dateDesc, l10n.sessionSortDateNewest),
                          (_SortMode.dateAsc, l10n.sessionSortDateOldest),
                          (_SortMode.nameAsc, l10n.sessionSortNameAZ),
                          (_SortMode.nameDesc, l10n.sessionSortNameZA),
                          (
                            _SortMode.durationDesc,
                            l10n.sessionSortDurationLongest,
                          ),
                          (
                            _SortMode.durationAsc,
                            l10n.sessionSortDurationShortest,
                          ),
                        ],
                        onSelected: (m) => update(() => _sortMode = m),
                      ),
                      const SizedBox(height: 16),
                      _sheetSectionHeader(l10n.sessionViewTooltip),
                      _sheetChips<_ViewMode>(
                        current: _viewMode,
                        options: [
                          (_ViewMode.detailed, l10n.sessionViewDetailed),
                          (_ViewMode.compact, l10n.sessionViewCompact),
                          (_ViewMode.bySpecies, l10n.sessionViewBySpecies),
                        ],
                        // Update the local sheet state AND the screen state
                        // in the same frame so the chip highlight reflects
                        // the new selection immediately. The async prefs
                        // write is fire-and-forget — UI must not wait for
                        // disk I/O before redrawing the chip row.
                        onSelected: (m) {
                          update(() => _viewMode = m);
                          unawaited(_persistViewMode(m));
                        },
                      ),
                      const SizedBox(height: 16),
                      _sheetSectionHeader(l10n.sessionLibraryFilterTooltip),
                      _sheetMultiChips<SessionType>(
                        current: _typeFilters,
                        options: [
                          (SessionType.live, l10n.sessionTypeLive),
                          (SessionType.pointCount, l10n.sessionTypePointCount),
                          (SessionType.fileUpload, l10n.sessionTypeFileUpload),
                          (SessionType.survey, l10n.sessionTypeSurvey),
                        ],
                        onToggle:
                            (t) => update(() {
                              if (!_typeFilters.add(t)) _typeFilters.remove(t);
                            }),
                        onClear:
                            _typeFilters.isEmpty
                                ? null
                                : () => update(_typeFilters.clear),
                        clearLabel: l10n.exploreFilterAll,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _sheetSectionHeader(String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _sheetChips<T>({
    required T current,
    required List<(T, String)> options,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: current == value,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }

  /// Multi-select chip row. Selections combine as a logical OR; a leading
  /// chip clears the selection ("All").
  Widget _sheetMultiChips<T>({
    required Set<T> current,
    required List<(T, String)> options,
    required ValueChanged<T> onToggle,
    required VoidCallback? onClear,
    required String clearLabel,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text(clearLabel),
          selected: current.isEmpty,
          onSelected: (_) => onClear?.call(),
        ),
        for (final (value, label) in options)
          FilterChip(
            label: Text(label),
            selected: current.contains(value),
            onSelected: (_) => onToggle(value),
          ),
      ],
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
        sorted.sort(
          (a, b) =>
              _sessionCardTitle(l10n, a).compareTo(_sessionCardTitle(l10n, b)),
        );
      case _SortMode.nameDesc:
        sorted.sort(
          (a, b) =>
              _sessionCardTitle(l10n, b).compareTo(_sessionCardTitle(l10n, a)),
        );
      case _SortMode.durationDesc:
        sorted.sort((a, b) => b.duration.compareTo(a.duration));
      case _SortMode.durationAsc:
        sorted.sort((a, b) => a.duration.compareTo(b.duration));
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
        title:
            _showSearch
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
              tooltip: l10n.tooltipClearSearch,
              onPressed:
                  () => setState(() {
                    _searchController.clear();
                    _showSearch = false;
                  }),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.tooltipSearch,
              onPressed: () => setState(() => _showSearch = true),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: l10n.sessionLibraryHelpTitle,
              onPressed: _showHelp,
            ),
            IconButton(
              icon: const Icon(Icons.filter_list_outlined),
              tooltip: l10n.settings,
              onPressed: _showOptionsSheet,
            ),
          ],
        ],
      ),
      body: ContentWidthConstraint(
        child: sessionsAsync.when(
          loading: () => const LoadingView(),
          error:
              (e, _) => ErrorView(
                title: l10n.statusError,
                message: e.toString(),
                onRetry: () => ref.invalidate(sessionListProvider),
                retryLabel: l10n.retry,
              ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return EmptyView(
                icon: Icons.library_music_outlined,
                title: l10n.sessionLibraryEmpty,
              );
            }

            final query = _searchController.text.trim();
            final matched =
                sessions.where((s) {
                  if (_typeFilters.isNotEmpty &&
                      !_typeFilters.contains(s.type)) {
                    return false;
                  }
                  if (query.isEmpty) return true;
                  return _matchesQuery(s, query, l10n);
                }).toList();
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

            if (_viewMode == _ViewMode.bySpecies) {
              return _SpeciesGroupedView(
                sessions: filtered,
                speciesQuery: query,
                sortMode: _sortMode,
                onTap: _openReview,
                onDelete: _confirmDelete,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final session = filtered[index];
                final tile =
                    _viewMode == _ViewMode.compact
                        ? _CompactSessionTile(
                          session: session,
                          expanded: _expandedCompactCards.contains(session.id),
                          onTap: () => _openReview(session),
                          onShare: () => _shareSession(session),
                          onDelete: () => _confirmDelete(session),
                          onToggleExpanded:
                              () => _toggleCompactExpanded(session.id),
                        )
                        : _SessionTile(
                          session: session,
                          onTap: () => _openReview(session),
                          onShare: () => _shareSession(session),
                          onDelete: () => _confirmDelete(session),
                        );
                return _SwipeToDeleteSession(
                  key: ValueKey('swipe-${session.id}'),
                  session: session,
                  onConfirmDelete: () async {
                    final l10n = AppLocalizations.of(context)!;
                    final confirmed = await confirmDestructive(
                      context,
                      title: l10n.sessionDiscardTitle,
                      body: l10n.sessionDiscardMessage,
                      confirmLabel: l10n.sessionDiscard,
                      cancelLabel: l10n.cancel,
                    );
                    if (!confirmed) return false;
                    // Delete + invalidate BEFORE returning true so the
                    // list rebuilds without this session in the same
                    // frame Dismissible removes the row. Otherwise
                    // Flutter throws "A dismissed Dismissible widget
                    // is still part of the tree" because the provider
                    // hadn't refreshed yet when onDismissed fired.
                    await ref
                        .read(sessionRepositoryProvider)
                        .delete(session.id);
                    ref.invalidate(sessionListProvider);
                    return true;
                  },
                  child: tile,
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: _NewSessionFab(
        mode: _newSessionMode,
        onStart: () => _startNewSession(_newSessionMode),
        onChooseMode: _showNewSessionPicker,
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

  /// Replace this Session Library route with the entry screen for [mode].
  /// Using `pushReplacement` keeps the back stack tidy: tapping back from
  /// the new session lands on whatever was below the library (typically
  /// the home screen) rather than this same library list.
  void _startNewSession(SessionType mode) {
    final navigator = Navigator.of(context);
    final route = switch (mode) {
      SessionType.live => MaterialPageRoute<void>(
        builder: (_) => const LiveScreen(),
      ),
      SessionType.pointCount => MaterialPageRoute<void>(
        builder: (_) => const PointCountSetupScreen(),
      ),
      SessionType.survey => MaterialPageRoute<void>(
        builder: (_) => const SurveySetupScreen(),
      ),
      SessionType.fileUpload => MaterialPageRoute<void>(
        builder: (_) => const FileAnalysisScreen(),
      ),
    };
    navigator.pushReplacement(route);
  }

  /// Show a bottom sheet with the four session-type options. Tapping a
  /// row both updates the FAB's default mode (persisted) and immediately
  /// starts that mode — saves the user the second tap.
  Future<void> _showNewSessionPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final modes = <_ModeOption>[
      _ModeOption(
        type: SessionType.live,
        label: l10n.liveMode,
        description: l10n.liveModeDescription,
      ),
      _ModeOption(
        type: SessionType.pointCount,
        label: l10n.pointCountMode,
        description: l10n.pointCountModeDescription,
      ),
      _ModeOption(
        type: SessionType.survey,
        label: l10n.surveyMode,
        description: l10n.surveyModeDescription,
      ),
      _ModeOption(
        type: SessionType.fileUpload,
        label: l10n.fileAnalysisMode,
        description: l10n.fileAnalysisModeDescription,
      ),
    ];

    final picked = await showModalBottomSheet<SessionType>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  l10n.sessionLibraryNewSessionSheetTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              for (final m in modes)
                ListTile(
                  leading: Icon(
                    sessionTypeIcon(m.type),
                    color: sessionTypeIconColor(m.type),
                  ),
                  title: Text(m.label),
                  subtitle: Text(
                    m.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing:
                      m.type == _newSessionMode
                          ? Icon(
                            Icons.check_rounded,
                            color: theme.colorScheme.primary,
                          )
                          : null,
                  onTap: () => Navigator.of(sheetCtx).pop(m.type),
                ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() => _newSessionMode = picked);
    await _persistNewSessionMode(picked);
    if (mounted) _startNewSession(picked);
  }

  Future<void> _confirmDelete(LiveSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.sessionDiscardTitle,
      body: l10n.sessionDiscardMessage,
      confirmLabel: l10n.sessionDiscard,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed) return;
    await ref.read(sessionRepositoryProvider).delete(session.id);
    ref.invalidate(sessionListProvider);
  }

  /// Opens the platform share sheet with the session exported using the
  /// user's saved export-format and include-audio preferences. Returns
  /// silently if the export couldn't be built (e.g. no audio for an
  /// audio-only export of a metadata-only session).
  Future<void> _shareSession(LiveSession session) async {
    final exportFormats = ref.read(exportSelectionProvider);
    final includeAudio = ref.read(includeAudioProvider);
    final includeHtmlReport = ref.read(exportHtmlReportProvider);
    final taxonomy = ref.read(taxonomyServiceProvider).valueOrNull;
    final speciesLocale = ref.read(effectiveSpeciesLocaleProvider);
    final useAbsoluteSurveyTime =
        ref.read(timestampDisplayModeProvider) == 'absolute';
    final metadata = await buildSessionExportMetadata(
      session,
      speciesLocale: speciesLocale,
    );
    final exportPath = await buildSessionExport(
      session,
      formats: exportFormats,
      includeAudio: includeAudio,
      taxonomy: taxonomy,
      speciesLocale: speciesLocale,
      metadata: metadata,
      useAbsoluteSurveyTime: useAbsoluteSurveyTime,
      includeHtmlReport: includeHtmlReport,
    );
    if (exportPath == null) return;
    await Share.shareXFiles([XFile(exportPath)]);
  }

  /// Toggles whether a compact-view row is expanded to show the full
  /// detailed card body. Keyed by session id so each row remembers its
  /// own state independently within the lifetime of this screen.
  void _toggleCompactExpanded(String sessionId) {
    setState(() {
      if (!_expandedCompactCards.add(sessionId)) {
        _expandedCompactCards.remove(sessionId);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SessionTile extends ConsumerWidget {
  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.onShare,
    required this.onDelete,
    this.trailingExpandToggle,
  });

  final LiveSession session;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  /// Optional collapse affordance rendered on the far right, after the
  /// overflow popup menu. Used when this tile is shown inside a
  /// compact-view row that the user has expanded — keeping the collapse
  /// arrow anchored to the same trailing slot the expand arrow lives in
  /// when the row is collapsed, so the visual target doesn't move.
  final Widget? trailingExpandToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateStr = DateFormat.yMMMd().format(session.startTime.toLocal());
    final timeStr = DateFormat.jm().format(session.startTime.toLocal());

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
                      color: sessionTypeIconColor(session.type).withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      sessionTypeIcon(session.type),
                      color: sessionTypeIconColor(session.type),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sessionCardTitle(
                            AppLocalizations.of(context)!,
                            session,
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$dateStr at $timeStr',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
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
                                        : AppLocalizations.of(
                                          context,
                                        )!.sessionNoLocation),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _SessionRowMenu(
                    onOpen: onTap,
                    onShare: onShare,
                    onDelete: onDelete,
                  ),
                  if (trailingExpandToggle != null) trailingExpandToggle!,
                ],
              ),
              if (_topSpeciesSci(session).isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      _topSpeciesSci(session).map((entry) {
                        final speciesLocale = ref.watch(
                          effectiveSpeciesLocaleProvider,
                        );
                        final taxonomy =
                            ref.watch(taxonomyServiceProvider).valueOrNull;
                        final displayName =
                            taxonomy
                                ?.lookup(entry.key)
                                ?.commonNameForLocale(speciesLocale) ??
                            entry.value;
                        return Chip(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            displayName,
                            style: theme.textTheme.labelSmall,
                          ),
                          padding: EdgeInsets.zero,
                        );
                      }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatChip(
                    icon: Icons.timer_outlined,
                    value: _formatDuration(duration),
                    variant: StatChipVariant.badge,
                  ),
                  StatChip(
                    icon: MdiIcons.feather,
                    value: '$speciesCount spp.',
                    variant: StatChipVariant.badge,
                  ),
                  StatChip(
                    icon: Icons.music_note_outlined,
                    value: '$detectionCount det.',
                    variant: StatChipVariant.badge,
                  ),
                  _SessionSizeChip(session: session),
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

// ─────────────────────────────────────────────────────────────────────────────
// Compact Session Tile
// ─────────────────────────────────────────────────────────────────────────────

class _CompactSessionTile extends ConsumerWidget {
  const _CompactSessionTile({
    required this.session,
    required this.expanded,
    required this.onTap,
    required this.onShare,
    required this.onDelete,
    required this.onToggleExpanded,
  });

  final LiveSession session;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dateStr = DateFormat.yMMMd().format(session.startTime.toLocal());

    final duration = session.duration;
    final speciesCount = session.uniqueSpeciesCount;

    // When the row is expanded, swap to the full-detail card body so users
    // get the same level of information as the detailed view without
    // leaving the compact list. A trailing collapse button lets them
    // close it again without scrolling away.
    if (expanded) {
      return _SessionTile(
        session: session,
        onTap: onTap,
        onShare: onShare,
        onDelete: onDelete,
        trailingExpandToggle: IconButton(
          icon: const Icon(Icons.expand_less),
          tooltip: l10n.sessionLibraryCollapse,
          onPressed: onToggleExpanded,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      );
    }

    return ListTile(
      leading: Icon(
        sessionTypeIcon(session.type),
        color: sessionTypeIconColor(session.type),
      ),
      title: Text(
        _sessionCardTitle(l10n, session),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$dateStr · ${_formatCompactDuration(duration)} · $speciesCount spp.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.expand_more, size: 22),
        tooltip: l10n.sessionLibraryExpand,
        onPressed: onToggleExpanded,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      onTap: onTap,
    );
  }

  String _formatCompactDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Species-Grouped View
// ─────────────────────────────────────────────────────────────────────────────

class _SpeciesGroupedView extends ConsumerWidget {
  const _SpeciesGroupedView({
    required this.sessions,
    required this.speciesQuery,
    required this.sortMode,
    required this.onTap,
    required this.onDelete,
  });

  final List<LiveSession> sessions;

  /// Active free-text search. When non-empty, only species whose common or
  /// scientific name contains the query are shown.
  final String speciesQuery;

  /// Active sort mode. [_SortMode.nameAsc] / [_SortMode.nameDesc] sort the
  /// species names alphabetically; date sorts fall back to most-detected
  /// first (the previous default), since species don't have a single date.
  final _SortMode sortMode;

  final void Function(LiveSession) onTap;
  final void Function(LiveSession) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).valueOrNull;
    final showSciNames = ref.watch(showSciNamesProvider);

    // Group: scientificName → set of sessions containing it.
    final speciesMap = <String, _SpeciesGroup>{};
    for (final session in sessions) {
      for (final d in session.detections) {
        final group = speciesMap.putIfAbsent(
          d.scientificName,
          () => _SpeciesGroup(
            scientificName: d.scientificName,
            commonName: d.commonName,
          ),
        );
        group.sessionIds.add(session.id);
      }
    }

    // Resolve the localized display name once per species so search and
    // sort operate on the same string the user actually sees.
    String displayNameOf(_SpeciesGroup g) =>
        taxonomy
            ?.lookup(g.scientificName)
            ?.commonNameForLocale(speciesLocale) ??
        g.commonName;

    // Free-text species filter (matches localized common name OR sci name).
    Iterable<_SpeciesGroup> visible = speciesMap.values;
    final q = speciesQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      visible = visible.where(
        (g) =>
            displayNameOf(g).toLowerCase().contains(q) ||
            g.scientificName.toLowerCase().contains(q),
      );
    }

    final sorted = visible.toList();
    switch (sortMode) {
      case _SortMode.nameAsc:
        sorted.sort(
          (a, b) => displayNameOf(
            a,
          ).toLowerCase().compareTo(displayNameOf(b).toLowerCase()),
        );
      case _SortMode.nameDesc:
        sorted.sort(
          (a, b) => displayNameOf(
            b,
          ).toLowerCase().compareTo(displayNameOf(a).toLowerCase()),
        );
      case _SortMode.dateAsc:
      case _SortMode.dateDesc:
      case _SortMode.durationAsc:
      case _SortMode.durationDesc:
        // Species don't have a single date or duration — keep the
        // historical most-detected-first order, then alphabetical as a
        // tie-break.
        sorted.sort((a, b) {
          final cmp = b.sessionIds.length.compareTo(a.sessionIds.length);
          if (cmp != 0) return cmp;
          return displayNameOf(a).compareTo(displayNameOf(b));
        });
    }

    if (sorted.isEmpty && q.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.sessionLibraryNoResults,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final group = sorted[index];
        final taxon = taxonomy?.lookup(group.scientificName);
        final displayName =
            taxon?.commonNameForLocale(speciesLocale) ?? group.commonName;
        final sessionCount = group.sessionIds.length;
        return ExpansionTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 42,
              height: 28,
              child:
                  taxon != null
                      ? Image.asset(
                        taxon.assetImagePath,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                MdiIcons.bird,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                      )
                      : ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          MdiIcons.bird,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
            ),
          ),
          title: Text(displayName, style: theme.textTheme.titleSmall),
          subtitle: Text(
            showSciNames
                ? '${group.scientificName} · ${l10n.sessionSpeciesSessionCount(sessionCount)}'
                : l10n.sessionSpeciesSessionCount(sessionCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            for (final session in sessions.where(
              (s) => group.sessionIds.contains(s.id),
            ))
              ListTile(
                dense: true,
                leading: Icon(
                  sessionTypeIcon(session.type),
                  size: 20,
                  color: sessionTypeIconColor(session.type),
                ),
                title: Text(
                  _sessionCardTitle(l10n, session),
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  DateFormat.yMMMd().format(session.startTime.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => onTap(session),
              ),
          ],
        );
      },
    );
  }
}

class _SpeciesGroup {
  _SpeciesGroup({required this.scientificName, required this.commonName});
  final String scientificName;
  final String commonName;
  final Set<String> sessionIds = {};
}

/// Bottom-sheet row data for the new-session mode picker.
class _ModeOption {
  const _ModeOption({
    required this.type,
    required this.label,
    required this.description,
  });
  final SessionType type;
  final String label;
  final String description;
}

// ─────────────────────────────────────────────────────────────────────────────
// New Session FAB — split extended FAB
//
// Design:
//   • Primary tappable area (icon + label) starts the currently-selected
//     mode. The icon and label reflect that mode so the user always sees
//     what a tap will do.
//   • A trailing chevron (▾) opens a bottom sheet of the four available
//     modes. Picking a mode both updates the FAB's default and starts
//     that mode immediately.
//   • Long-press on the primary area also opens the mode picker — a
//     hidden shortcut for power users who learned the affordance.
//
// We build the split shape manually rather than wrapping
// `FloatingActionButton.extended` because Flutter's FAB doesn't support
// two independent tap targets. A custom Material pill with two InkWells
// gives the same elevation, shape, and ripple semantics.
// ─────────────────────────────────────────────────────────────────────────────

class _NewSessionFab extends StatelessWidget {
  const _NewSessionFab({
    required this.mode,
    required this.onStart,
    required this.onChooseMode,
  });

  final SessionType mode;
  final VoidCallback onStart;
  final VoidCallback onChooseMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final modeLabel = _sessionTypeLabel(l10n, mode);
    final modeColor = sessionTypeIconColor(mode);
    // Use the surface-tinted FAB color so the white mode glyph (live red,
    // survey green, etc.) reads cleanly without competing with the app's
    // primary brand color. Keep elevation/shape consistent with FAB.
    final bg = theme.colorScheme.primaryContainer;
    final fg = theme.colorScheme.onPrimaryContainer;

    return Material(
      color: bg,
      elevation: 6,
      shadowColor: theme.shadowColor,
      shape: const StadiumBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary action — start currently-selected mode.
            Tooltip(
              message: l10n.sessionLibraryNewSessionTooltip(modeLabel),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onStart,
                onLongPress: onChooseMode,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mode-colored circular badge so the active mode is
                      // unmistakable at a glance.
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: modeColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          sessionTypeIcon(mode),
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.sessionLibraryNewSession,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Vertical divider separating primary action from chevron.
            Container(width: 1, height: 28, color: fg.withAlpha(40)),
            // Secondary action — open mode picker.
            Tooltip(
              message: l10n.sessionLibraryChangeNewSessionMode,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onChooseMode,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 16, 12),
                  child: Icon(Icons.arrow_drop_up_rounded, size: 28, color: fg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session size chip — shows total on-disk size of the recording or all
// per-detection clips for this session. Computed off the UI thread via
// [File.stat]; renders a placeholder while the future resolves and
// silently omits the chip when the session has no audio on disk.
// ─────────────────────────────────────────────────────────────────────────────

class _SessionSizeChip extends StatelessWidget {
  const _SessionSizeChip({required this.session});

  final LiveSession session;

  Future<int> _computeSize() async {
    var total = 0;
    // 1) Continuous session recording (live, point count, file analysis).
    //    When the user trimmed the recording in session review the file
    //    on disk is intentionally left untouched (so trim is reversible),
    //    but the *effective* on-disk usage from the user's point of view
    //    is the trimmed extent — that's what they hear back, share, and
    //    export. Scale the raw file length by the trim ratio so the
    //    library chip reflects the trim immediately.
    final rec = session.recordingPath;
    if (rec != null) {
      try {
        final f = File(rec);
        if (await f.exists()) {
          final raw = await f.length();
          total += _scaleForTrim(raw);
        }
      } catch (_) {
        /* ignore */
      }
    }
    // 2) Per-detection clips (survey, or any session that kept clips
    //    instead of a full recording). Iterate in parallel-friendly
    //    chunks rather than all at once to avoid spamming the I/O pool.
    for (final d in session.detections) {
      final p = d.audioClipPath;
      if (p == null) continue;
      try {
        final f = File(p);
        if (await f.exists()) total += await f.length();
      } catch (_) {
        /* ignore */
      }
    }
    return total;
  }

  /// Scale a raw recording byte-count by the trim ratio so the displayed
  /// size matches the trimmed extent. Returns [raw] unchanged when the
  /// session has no trim or when the full duration is unknown.
  int _scaleForTrim(int raw) {
    final fullDuration = session.duration.inSeconds.toDouble();
    if (fullDuration <= 0) return raw;
    final start = session.trimStartSec ?? 0.0;
    final end = session.trimEndSec ?? fullDuration;
    final clipped = (end - start).clamp(0.0, fullDuration);
    if (clipped >= fullDuration) return raw;
    // PCM WAV size scales linearly with sample count; the 44-byte header
    // is negligible compared to the audio payload, so a simple ratio is
    // accurate enough for a UI chip.
    return (raw * (clipped / fullDuration)).round();
  }

  String _format(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(0)}KB';
    final mb = kb / 1024.0;
    if (mb < 10) return '${mb.toStringAsFixed(1)}MB';
    if (mb < 1024) return '${mb.toStringAsFixed(0)}MB';
    final gb = mb / 1024.0;
    return '${gb.toStringAsFixed(1)}GB';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _computeSize(),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          // Reserve a fixed slot so the row layout doesn't shift when
          // the future resolves. Show a neutral placeholder.
          return const StatChip(
            icon: Icons.sd_storage_outlined,
            value: '…',
            variant: StatChipVariant.badge,
          );
        }
        if (bytes == 0) {
          // Don't bother showing 0B — saves a slot for sessions with
          // no on-disk audio (manual annotations only, or clips were
          // evicted by the survey sampler).
          return const SizedBox.shrink();
        }
        return StatChip(
          icon: Icons.sd_storage_outlined,
          value: _format(bytes),
          variant: StatChipVariant.badge,
        );
      },
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

/// Returns the top 5 most-detected species as (scientificName, commonName)
/// pairs, ordered by detection count.  The common name is the raw English
/// fallback — callers should translate via [TaxonomyService] if available.
List<MapEntry<String, String>> _topSpeciesSci(LiveSession session) {
  final counts = <String, int>{};
  final names = <String, String>{};
  for (final d in session.detections) {
    counts[d.scientificName] = (counts[d.scientificName] ?? 0) + 1;
    names.putIfAbsent(d.scientificName, () => d.commonName);
  }
  final sorted =
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(5).map((e) => MapEntry(e.key, names[e.key]!)).toList();
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

// ─────────────────────────────────────────────────────────────────────────────
// Per-row overflow menu (Open / Share / Delete)
// ─────────────────────────────────────────────────────────────────────────────

/// Three-dot overflow menu attached to each session card. Replaces the
/// previous bare trash icon so users can also re-open the review screen
/// or kick off a share without leaving the library.
class _SessionRowMenu extends StatelessWidget {
  const _SessionRowMenu({
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<_SessionRowAction>(
      tooltip: l10n.sessionLibraryRowMenuTooltip,
      icon: const Icon(Icons.more_vert),
      padding: EdgeInsets.zero,
      onSelected: (action) {
        switch (action) {
          case _SessionRowAction.open:
            onOpen();
          case _SessionRowAction.share:
            onShare();
          case _SessionRowAction.delete:
            onDelete();
        }
      },
      itemBuilder:
          (_) => [
            PopupMenuItem(
              value: _SessionRowAction.open,
              child: ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(l10n.sessionLibraryRowOpen),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _SessionRowAction.share,
              child: ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(l10n.sessionLibraryRowShare),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _SessionRowAction.delete,
              child: ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  l10n.sessionLibraryRowDelete,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipe-to-delete wrapper
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a session card with [Dismissible] so users can swipe in either
/// direction to delete the session. Both swipe directions show the same
/// red trash background and route through the same destructive
/// confirmation dialog as the overflow menu's Delete action.
class _SwipeToDeleteSession extends StatelessWidget {
  const _SwipeToDeleteSession({
    super.key,
    required this.session,
    required this.onConfirmDelete,
    required this.child,
  });

  final LiveSession session;

  /// Returns true once the session has been deleted (and the underlying
  /// list provider invalidated). Returning true tells [Dismissible] to
  /// finish its exit animation; returning false keeps the row in place.
  /// The actual delete must happen here — not in [Dismissible.onDismissed]
  /// — so the list rebuilds before the dismissed widget would otherwise
  /// remain in the tree for one extra frame.
  final Future<bool> Function() onConfirmDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss-${session.id}'),
      direction: DismissDirection.horizontal,
      background: _swipeBackground(context, alignLeft: true),
      secondaryBackground: _swipeBackground(context, alignLeft: false),
      confirmDismiss: (_) => onConfirmDelete(),
      child: child,
    );
  }

  Widget _swipeBackground(BuildContext context, {required bool alignLeft}) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisAlignment:
            alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Icon(
            Icons.delete_sweep_outlined,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.tooltipDeleteSession,
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
