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
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/taxonomy_service.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/utils/locale_time_format.dart';
import '../../shared/utils/session_type_visuals.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/confirm_destructive.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../../shared/widgets/empty_view.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/stat_chip.dart';
import '../aru/aru_setup_screen.dart';
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
import 'services/session_audio_trim.dart';
import 'services/share_file_params.dart';

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

  /// Active bulk selection set. Holds the ids of selected sessions.
  final Set<String> _selectedSessions = <String>{};

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
              // These icons match the meaning of each help section. The
              // toolbar collapses view and filter controls behind one options
              // button, so the sheet-level concepts read clearer than a
              // strict AppBar icon mirror here.
              AppHelpSection(
                icon: AppIcons.search,
                body: l10n.sessionLibraryHelpSearch,
              ),
              AppHelpSection(
                icon: AppIcons.filterList,
                body: l10n.sessionLibraryHelpFilter,
              ),
              AppHelpSection(
                icon: AppIcons.expandMore,
                body: l10n.sessionLibraryHelpView,
              ),
              AppHelpSection(
                icon: AppIcons.moreVert,
                body: l10n.sessionLibraryHelpSort,
              ),
              AppHelpSection(
                icon: AppIcons.arrowDropUpRounded,
                body: l10n.sessionLibraryHelpOpen,
              ),
            ],
          ),
    );
  }

  /// Returns `true` if [session] matches the current search query.
  bool _matchesQuery(
    LiveSession session,
    String query,
    AppLocalizations l10n,
    TaxonomyService? taxonomy,
    String speciesLocale,
  ) {
    final q = _searchFold(query);

    bool matches(String? value) {
      if (value == null || value.trim().isEmpty) return false;
      return _searchFold(value).contains(q);
    }

    final localStart = session.startTime.toLocal();
    final localEnd = session.endTime?.toLocal();
    final dateFormat = DateFormat.yMMMd(l10n.localeName).add_Hm();
    final dateOnlyFormat = DateFormat.yMMMd(l10n.localeName);

    final sessionText = <String?>[
      session.displayName,
      _sessionCardTitle(l10n, session),
      session.customName,
      _sessionTypeLabel(l10n, session.type),
      dateFormat.format(localStart),
      dateOnlyFormat.format(localStart),
      DateFormat('yyyy-MM-dd HH:mm').format(localStart),
      DateFormat('yyyy-MM-dd').format(localStart),
      if (localEnd != null) dateFormat.format(localEnd),
      session.locationName,
      session.transectId,
      session.observerName,
      session.aruMetadata?.deploymentName,
      session.aruMetadata?.stationId,
      for (final annotation in session.annotations) annotation.title,
      for (final annotation in session.annotations) annotation.text,
    ];

    if (session.latitude != null && session.longitude != null) {
      sessionText.addAll([
        '${session.latitude!.toStringAsFixed(4)}, '
            '${session.longitude!.toStringAsFixed(4)}',
        session.latitude!.toStringAsFixed(4),
        session.longitude!.toStringAsFixed(4),
      ]);
    }

    if (sessionText.any(matches)) return true;

    for (final cycle
        in session.aruMetadata?.cycles ?? const <AruCycleMetadata>[]) {
      if (matches(cycle.note) ||
          matches(cycle.status.name) ||
          matches(dateFormat.format(cycle.plannedStart.toLocal())) ||
          matches(
            DateFormat('yyyy-MM-dd HH:mm').format(cycle.plannedStart.toLocal()),
          )) {
        return true;
      }
    }

    for (final d in session.detections) {
      final taxon = taxonomy?.lookup(d.scientificName);
      final speciesText = <String?>[
        d.commonName,
        d.scientificName,
        taxon?.displayScientificName,
        taxon?.commonName,
        taxon?.commonNameAlt,
        taxon?.commonNameForLocale(speciesLocale),
        if (taxon?.commonNames != null) ...taxon!.commonNames!.values,
        d.note,
        d.source.name,
        dateFormat.format(d.timestamp.toLocal()),
        DateFormat('yyyy-MM-dd HH:mm').format(d.timestamp.toLocal()),
      ];
      if (speciesText.any(matches)) return true;
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
                          (
                            SessionType.batchAnalysis,
                            l10n.sessionTypeBatchAnalysis,
                          ),
                          (SessionType.aru, l10n.sessionTypeAru),
                        ],
                        onToggle: (t) {
                          if (!_typeFilters.add(t)) _typeFilters.remove(t);
                          update(() {});
                        },
                        onClear:
                            _typeFilters.isEmpty
                                ? null
                                : () {
                                  _typeFilters.clear();
                                  update(() {});
                                },
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
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);

    // Pre-calculate matching/filtered lists so they're accessible to state and appBar
    final sessions = sessionsAsync.value ?? const <LiveSession>[];
    final query = _searchController.text.trim();
    final matched =
        sessions.where((s) {
          if (_typeFilters.isNotEmpty && !_typeFilters.contains(s.type)) {
            return false;
          }
          if (query.isEmpty) return true;
          return _matchesQuery(s, query, l10n, taxonomy, speciesLocale);
        }).toList();
    final filtered = _applySorting(matched);

    final isSelectMode = _selectedSessions.isNotEmpty;
    final allSelected =
        filtered.isNotEmpty &&
        filtered.every((s) => _selectedSessions.contains(s.id));

    return Scaffold(
      appBar:
          isSelectMode
              ? AppBar(
                leading: IconButton(
                  icon: const Icon(AppIcons.close),
                  tooltip: l10n.cancel,
                  onPressed: _clearSelection,
                ),
                title: Text(
                  l10n.sessionLibrarySelectedCount(_selectedSessions.length),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      allSelected ? AppIcons.deselect : AppIcons.selectAll,
                    ),
                    tooltip:
                        allSelected
                            ? l10n.sessionLibraryDeselectAll
                            : l10n.sessionLibrarySelectAll,
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          for (final s in filtered) {
                            _selectedSessions.remove(s.id);
                          }
                        } else {
                          for (final s in filtered) {
                            _selectedSessions.add(s.id);
                          }
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.share),
                    tooltip: l10n.sessionLibraryRowShare,
                    onPressed: () => _exportSelected(filtered),
                  ),
                  IconButton(
                    icon: Icon(
                      AppIcons.deleteOutline,
                      color: theme.colorScheme.error,
                    ),
                    tooltip: l10n.sessionLibraryRowDelete,
                    onPressed: () => _deleteSelected(filtered),
                  ),
                ],
              )
              : AppBar(
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
                      icon: const Icon(AppIcons.close),
                      tooltip: l10n.tooltipClearSearch,
                      onPressed:
                          () => setState(() {
                            _searchController.clear();
                            _showSearch = false;
                          }),
                    )
                  else ...[
                    IconButton(
                      icon: const Icon(AppIcons.search),
                      tooltip: l10n.tooltipSearch,
                      onPressed: () => setState(() => _showSearch = true),
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.helpOutlineRounded),
                      tooltip: l10n.sessionLibraryHelpTitle,
                      onPressed: _showHelp,
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.filterList),
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
                icon: AppIcons.libraryMusic,
                title: l10n.sessionLibraryEmpty,
              );
            }

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
                final isSelected = _selectedSessions.contains(session.id);
                final tile =
                    _viewMode == _ViewMode.compact
                        ? _CompactSessionTile(
                          session: session,
                          expanded: _expandedCompactCards.contains(session.id),
                          isSelected: isSelected,
                          selectionMode: isSelectMode,
                          onTap: () {
                            if (isSelectMode) {
                              setState(() {
                                if (!_selectedSessions.remove(session.id)) {
                                  _selectedSessions.add(session.id);
                                }
                              });
                            } else {
                              _openReview(session);
                            }
                          },
                          onShare: () => _shareSession(session),
                          onDelete: () => _confirmDelete(session),
                          onLongPress: () {
                            setState(() {
                              if (!_selectedSessions.remove(session.id)) {
                                _selectedSessions.add(session.id);
                              }
                            });
                          },
                          onToggleExpanded:
                              () => _toggleCompactExpanded(session.id),
                        )
                        : _SessionTile(
                          session: session,
                          isSelected: isSelected,
                          selectionMode: isSelectMode,
                          onTap: () {
                            if (isSelectMode) {
                              setState(() {
                                if (!_selectedSessions.remove(session.id)) {
                                  _selectedSessions.add(session.id);
                                }
                              });
                            } else {
                              _openReview(session);
                            }
                          },
                          onShare: () => _shareSession(session),
                          onDelete: () => _confirmDelete(session),
                          onLongPress: () {
                            setState(() {
                              if (!_selectedSessions.remove(session.id)) {
                                _selectedSessions.add(session.id);
                              }
                            });
                          },
                        );
                return _SwipeToDeleteSession(
                  key: ValueKey('swipe-${session.id}'),
                  session: session,
                  enabled: !isSelectMode,
                  onConfirmDelete: () async {
                    final l10n = AppLocalizations.of(context)!;
                    final confirmed = await confirmDestructive(
                      context,
                      title: l10n.tooltipDeleteSession,
                      body: l10n.sessionDiscardMessage,
                      confirmLabel: l10n.tooltipDeleteSession,
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
      SessionType.aru => MaterialPageRoute<void>(
        builder: (_) => const AruSetupScreen(),
      ),
      SessionType.batchAnalysis => throw UnsupportedError('Coming soon'),
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
      _ModeOption(
        type: SessionType.aru,
        label: l10n.aruMode,
        description: l10n.aruModeDescription,
      ),
    ];

    final picked = await showModalBottomSheet<SessionType>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
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
                      color: sessionTypeAccentColor(theme, m.type),
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
                              AppIcons.checkRounded,
                              color: theme.colorScheme.primary,
                            )
                            : null,
                    onTap: () => Navigator.of(sheetCtx).pop(m.type),
                  ),
                const SizedBox(height: 4),
              ],
            ),
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
      title: l10n.tooltipDeleteSession,
      body: l10n.sessionDiscardMessage,
      confirmLabel: l10n.tooltipDeleteSession,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed) return;
    await ref.read(sessionRepositoryProvider).delete(session.id);
    ref.invalidate(sessionListProvider);
  }

  /// Opens the platform share sheet with the session exported using the
  /// user's saved export-format and include-audio preferences. Returns
  /// silently if the export couldn't be built (e.g. no audio for an
  /// audio-only export of a metadata-only session) — except for a trimmed
  /// recording the app can't cut, which is reported so the share button
  /// doesn't just appear to do nothing.
  Future<void> _shareSession(LiveSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final exportFormats = ref.read(exportSelectionProvider);
    final includeAudio = ref.read(includeAudioProvider);
    final shareAudioAsWav = ref.read(shareAudioAsWavProvider);
    final includeHtmlReport = ref.read(exportHtmlReportProvider);
    final includeAppMetadata = ref.read(includeAppMetadataProvider);
    final taxonomy = ref.read(taxonomyServiceProvider).value;
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
      shareAudioAsWav: shareAudioAsWav,
      taxonomy: taxonomy,
      speciesLocale: speciesLocale,
      metadata: metadata,
      useAbsoluteSurveyTime: useAbsoluteSurveyTime,
      includeHtmlReport: includeHtmlReport,
      includeAppMetadata: includeAppMetadata,
    );
    if (exportPath == null) {
      if (mounted && includeAudio && session.hasAudioTrim) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.sessionTrimExportFailed)));
      }
      return;
    }
    await SharePlus.instance.share(shareParamsForFile(exportPath));
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

  void _clearSelection() {
    setState(() {
      _selectedSessions.clear();
    });
  }

  Future<void> _deleteSelected(List<LiveSession> filtered) async {
    final l10n = AppLocalizations.of(context)!;
    final count = _selectedSessions.length;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.sessionLibraryDeleteSelectedTitle,
      body: l10n.sessionLibraryDeleteSelectedMessage(count),
      confirmLabel: l10n.sessionLibraryRowDelete,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed) return;

    final repo = ref.read(sessionRepositoryProvider);
    for (final id in List.of(_selectedSessions)) {
      await repo.delete(id);
    }
    setState(() {
      _selectedSessions.clear();
    });
    ref.invalidate(sessionListProvider);
  }

  Future<void> _exportSelected(List<LiveSession> filtered) async {
    final l10n = AppLocalizations.of(context)!;
    final selectedList =
        filtered.where((s) => _selectedSessions.contains(s.id)).toList();
    if (selectedList.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 24),
                Expanded(child: Text(l10n.sessionLibraryPreparingExport)),
              ],
            ),
          ),
        );
      },
    );

    try {
      final exportFormats = ref.read(exportSelectionProvider);
      final includeAudio = ref.read(includeAudioProvider);
      final shareAudioAsWav = ref.read(shareAudioAsWavProvider);
      final includeHtmlReport = ref.read(exportHtmlReportProvider);
      final includeAppMetadata = ref.read(includeAppMetadataProvider);
      final taxonomy = ref.read(taxonomyServiceProvider).value;
      final speciesLocale = ref.read(effectiveSpeciesLocaleProvider);
      final useAbsoluteSurveyTime =
          ref.read(timestampDisplayModeProvider) == 'absolute';

      final zipPath = await buildMultiSessionExport(
        selectedList,
        formats: exportFormats,
        includeAudio: includeAudio,
        shareAudioAsWav: shareAudioAsWav,
        taxonomy: taxonomy,
        speciesLocale: speciesLocale,
        useAbsoluteSurveyTime: useAbsoluteSurveyTime,
        includeHtmlReport: includeHtmlReport,
        includeAppMetadata: includeAppMetadata,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (zipPath == null) {
        return;
      }

      await SharePlus.instance.share(shareParamsForFile(zipPath));
      if (mounted) {
        _clearSelection();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        showDialog<void>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(l10n.statusError),
                content: Text(e.toString()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
        );
      }
    }
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
    required this.onLongPress,
    this.isSelected = false,
    this.selectionMode = false,
    this.trailingExpandToggle,
  });

  final LiveSession session;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;
  final bool isSelected;
  final bool selectionMode;

  /// Optional collapse affordance rendered on the far right, after the
  /// overflow popup menu. Used when this tile is shown inside a
  /// compact-view row that the user has expanded — keeping the collapse
  /// arrow anchored to the same trailing slot the expand arrow lives in
  /// when the row is collapsed, so the visual target doesn't move.
  final Widget? trailingExpandToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final highContrast = AppTheme.isHighContrastTheme(theme);
    final l10n = AppLocalizations.of(context)!;
    final dateStr = DateFormat.yMMMd().format(session.startTime.toLocal());
    final timeStr = formatLocaleTime(
      session.startTime,
      l10n.localeName,
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );

    final duration = session.duration;
    final speciesCount = session.uniqueSpeciesCount;
    final detectionCount = session.detections.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: highContrast ? 0 : 2,
      color: highContrast ? theme.colorScheme.surface : null,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(highContrast ? 8 : 16),
        side:
            highContrast
                ? BorderSide(color: theme.colorScheme.outline)
                : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode) ...[
                    Checkbox(value: isSelected, onChanged: (_) => onTap()),
                    const SizedBox(width: 12),
                  ],
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: sessionTypeContainerColor(theme, session.type),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      sessionTypeIcon(session.type),
                      color: sessionTypeAccentColor(theme, session.type),
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
                              AppIcons.calendarToday,
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
                                  ? AppIcons.locationOn
                                  : AppIcons.locationOff,
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
                  children: () {
                    final speciesLocale = ref.watch(
                      effectiveSpeciesLocaleProvider,
                    );
                    final taxonomy = ref.watch(taxonomyServiceProvider).value;
                    final entries =
                        _topSpeciesSci(session).map((entry) {
                            final displayName =
                                taxonomy
                                    ?.lookup(entry.key)
                                    ?.commonNameForLocale(speciesLocale) ??
                                entry.value;
                            return displayName;
                          }).toList()
                          ..sort((a, b) => a.compareTo(b));
                    return entries
                        .map(
                          (name) => Chip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              name,
                              style: theme.textTheme.labelSmall,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        )
                        .toList();
                  }(),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatChip(
                    icon: AppIcons.timerOutlined,
                    value: _formatDuration(duration),
                    variant: StatChipVariant.badge,
                  ),
                  StatChip(
                    icon: AppIcons.species,
                    value: '$speciesCount spp.',
                    variant: StatChipVariant.badge,
                  ),
                  StatChip(
                    icon: AppIcons.detections,
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
    required this.onLongPress,
    required this.onToggleExpanded,
    this.isSelected = false,
    this.selectionMode = false,
  });

  final LiveSession session;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;
  final VoidCallback onToggleExpanded;
  final bool isSelected;
  final bool selectionMode;

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
        onLongPress: onLongPress,
        isSelected: isSelected,
        selectionMode: selectionMode,
        trailingExpandToggle: IconButton(
          icon: const Icon(AppIcons.expandLess),
          tooltip: l10n.sessionLibraryCollapse,
          onPressed: onToggleExpanded,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      );
    }

    return ListTile(
      leading:
          selectionMode
              ? Checkbox(value: isSelected, onChanged: (_) => onTap())
              : Icon(
                sessionTypeIcon(session.type),
                color: sessionTypeAccentColor(theme, session.type),
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
        icon: const Icon(AppIcons.expandMore, size: 22),
        tooltip: l10n.sessionLibraryExpand,
        onPressed: onToggleExpanded,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
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
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
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

    // Free-text species filter. Match every bundled common-name locale so
    // typed translated names work even when another display locale is active.
    Iterable<_SpeciesGroup> visible = speciesMap.values;
    final q = _searchFold(speciesQuery);
    if (q.isNotEmpty) {
      visible = visible.where((g) {
        final taxon = taxonomy?.lookup(g.scientificName);
        final searchable = <String?>[
          displayNameOf(g),
          g.commonName,
          g.scientificName,
          taxon?.displayScientificName,
          taxon?.commonName,
          taxon?.commonNameAlt,
          if (taxon?.commonNames != null) ...taxon!.commonNames!.values,
        ];
        return searchable.any((value) => _searchFold(value ?? '').contains(q));
      });
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
        const imageWidth = 88.0;
        const imageHeight = 58.0;
        return ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 6),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: imageWidth,
              height: imageHeight,
              child:
                  taxon != null
                      ? Image.asset(
                        taxon.assetImagePath,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (a, b, c) => ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                AppIcons.brokenImage,
                                size: 24,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                      )
                      : ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          AppIcons.brokenImage,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
            ),
          ),
          title: Text(
            displayName,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            showSciNames
                ? '${taxon?.displayScientificName ?? group.scientificName} · ${l10n.sessionSpeciesSessionCount(sessionCount)}'
                : l10n.sessionSpeciesSessionCount(sessionCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
                  color: sessionTypeAccentColor(theme, session.type),
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

String _searchFold(String value) {
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final codePoint in lower.runes) {
    final char = String.fromCharCode(codePoint);
    buffer.write(_searchCharFold[char] ?? char);
  }
  return buffer.toString();
}

const Map<String, String> _searchCharFold = {
  '\u00e0': 'a',
  '\u00e1': 'a',
  '\u00e2': 'a',
  '\u00e3': 'a',
  '\u00e4': 'a',
  '\u00e5': 'a',
  '\u0101': 'a',
  '\u0103': 'a',
  '\u0105': 'a',
  '\u00e6': 'ae',
  '\u0107': 'c',
  '\u010d': 'c',
  '\u00e7': 'c',
  '\u010f': 'd',
  '\u00e8': 'e',
  '\u00e9': 'e',
  '\u00ea': 'e',
  '\u00eb': 'e',
  '\u011b': 'e',
  '\u0119': 'e',
  '\u00ec': 'i',
  '\u00ed': 'i',
  '\u00ee': 'i',
  '\u00ef': 'i',
  '\u0142': 'l',
  '\u00f1': 'n',
  '\u0144': 'n',
  '\u0148': 'n',
  '\u00f2': 'o',
  '\u00f3': 'o',
  '\u00f4': 'o',
  '\u00f5': 'o',
  '\u00f6': 'o',
  '\u0153': 'oe',
  '\u0159': 'r',
  '\u015b': 's',
  '\u0161': 's',
  '\u00df': 'ss',
  '\u0165': 't',
  '\u00f9': 'u',
  '\u00fa': 'u',
  '\u00fb': 'u',
  '\u00fc': 'u',
  '\u016f': 'u',
  '\u00fd': 'y',
  '\u00ff': 'y',
  '\u017a': 'z',
  '\u017c': 'z',
  '\u017e': 'z',
};

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
    final modeColor = sessionTypeAccentColor(theme, mode);
    final modeOnColor = sessionTypeOnAccentColor(theme, mode);
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
                          color: modeOnColor,
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
                  child: Icon(AppIcons.arrowDropUpRounded, size: 28, color: fg),
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
    //    Saving a trimmed session cuts the recording down for real, so its
    //    file length is already the truth. A trim range still on the session
    //    means the cut hasn't happened (or couldn't) — the user nevertheless
    //    only hears, shares and exports the trimmed extent, so scale the raw
    //    length by the trim ratio for those.
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
            icon: AppIcons.sdStorage,
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
          icon: AppIcons.sdStorage,
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
    case SessionType.batchAnalysis:
      return l10n.sessionTypeBatchAnalysis;
    case SessionType.aru:
      return l10n.sessionTypeAru;
  }
}

/// Returns the top 5 species by best confidence score as
/// (scientificName, commonName) pairs. The common name is the raw English
/// fallback — callers should translate via [TaxonomyService] if available.
/// Order is unspecified; callers should sort for display.
List<MapEntry<String, String>> _topSpeciesSci(LiveSession session) {
  final bestScore = <String, double>{};
  final names = <String, String>{};
  for (final d in session.detections) {
    final prev = bestScore[d.scientificName] ?? 0.0;
    if (d.confidence > prev) bestScore[d.scientificName] = d.confidence;
    names.putIfAbsent(d.scientificName, () => d.commonName);
  }
  final sorted =
      bestScore.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
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
    case SessionType.batchAnalysis:
      return l10n.sessionCardBatchAnalysisNum(n);
    case SessionType.aru:
      return l10n.sessionCardAruNum(n);
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
      icon: const Icon(AppIcons.moreVert),
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
                leading: const Icon(AppIcons.openInNew),
                title: Text(l10n.sessionLibraryRowOpen),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _SessionRowAction.share,
              child: ListTile(
                leading: const Icon(AppIcons.share),
                title: Text(l10n.sessionLibraryRowShare),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _SessionRowAction.delete,
              child: ListTile(
                leading: Icon(
                  AppIcons.deleteOutline,
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
    this.enabled = true,
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
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss-${session.id}'),
      direction: enabled ? DismissDirection.horizontal : DismissDirection.none,
      background: _swipeBackground(context, alignLeft: true),
      secondaryBackground: _swipeBackground(context, alignLeft: false),
      confirmDismiss: enabled ? (_) => onConfirmDelete() : null,
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
          Icon(AppIcons.deleteSweep, color: theme.colorScheme.onErrorContainer),
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
