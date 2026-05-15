// =============================================================================
// Explore Screen — Browse species in your area
// =============================================================================
//
// Shows a scrollable list of species. By default, the list is restricted to
// species that the geo-model predicts as likely present at the user's
// current location and time of year, ranked by probability.
//
// The user can:
//   • Filter by taxonomic group (Birds, Mammals, Amphibians, Insects).
//   • Search by common or scientific name. The search runs over the full
//     audio-model species list (not only the geo-filtered subset), so
//     species that do not occur at the current location can still be
//     opened. Local matches are shown first, with a separate "Other
//     species" section for distant matches.
//
// Each species is displayed as a [SpeciesCard]. Tapping a card opens the
// [SpeciesInfoOverlay] with detailed information.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import '../../core/services/reverse_geocoding_service.dart';
import '../../shared/models/taxonomy_species.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../../shared/widgets/empty_view.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../history/global_species_history.dart';
import 'explore_providers.dart';
import 'widgets/species_card.dart';
import 'widgets/species_info_overlay.dart';

/// Taxonomic group filter for the explore list. The `all` sentinel is no
/// longer used as an explicit selection — "no taxon-group filter" is
/// represented by an *empty* `Set<_TaxonGroup>` in the screen state, so
/// the filter bottom sheet can offer multi-select like the session
/// library does. The enum still defines a stable ordering for the chip
/// row.
enum _TaxonGroup {
  aves,
  mammalia,
  amphibia,
  insecta;

  /// Matches the `taxon_group` column in the bundled taxonomy CSV.
  String get csvValue => switch (this) {
    _TaxonGroup.aves => 'Aves',
    _TaxonGroup.mammalia => 'Mammalia',
    _TaxonGroup.amphibia => 'Amphibia',
    _TaxonGroup.insecta => 'Insecta',
  };

  String label(AppLocalizations l10n) => switch (this) {
    _TaxonGroup.aves => l10n.exploreFilterBirds,
    _TaxonGroup.mammalia => l10n.exploreFilterMammals,
    _TaxonGroup.amphibia => l10n.exploreFilterAmphibians,
    _TaxonGroup.insecta => l10n.exploreFilterInsects,
  };
}

/// Sort modes for the explore list.
enum _SortMode { geo, nameAsc, nameDesc }

/// Detection-state filter — narrows the list to species the user has or
/// has not yet logged in any saved session.
enum _DetectionFilter { all, detected, undetected }

/// The Explore screen — browse species expected in your area, with optional
/// search across the full species list.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';

  /// Selected taxon groups. Empty set means "all groups" — matching the
  /// session library's filter sheet semantics.
  final Set<_TaxonGroup> _groups = <_TaxonGroup>{};

  /// Active sort mode; defaults to geo probability so the most likely
  /// species in your area surface at the top.
  _SortMode _sortMode = _SortMode.geo;

  /// Active detection-state filter; defaults to no restriction.
  _DetectionFilter _detectionFilter = _DetectionFilter.all;

  /// Whether the inline search field is currently visible. Toggled by the
  /// search icon in the AppBar.
  bool _searchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value.trim());
  }

  void _toggleSearch() {
    setState(() {
      if (_searchVisible) {
        _searchVisible = false;
        _searchController.clear();
        _query = '';
      } else {
        _searchVisible = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _searchFocusNode.requestFocus(),
        );
      }
    });
  }

  /// Whether any non-default sort/filter is active — drives the badge
  /// dot on the AppBar filter button.
  bool get _filterActive =>
      _groups.isNotEmpty ||
      _sortMode != _SortMode.geo ||
      _detectionFilter != _DetectionFilter.all;

  void _showFilterSheet() {
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
                      _ExploreSheetHeader(label: l10n.exploreSortTooltip),
                      _ExploreSheetChoiceChips<_SortMode>(
                        current: _sortMode,
                        options: [
                          (_SortMode.geo, l10n.exploreSortGeo),
                          (_SortMode.nameAsc, l10n.sessionSortNameAZ),
                          (_SortMode.nameDesc, l10n.sessionSortNameZA),
                        ],
                        onSelected: (m) => update(() => _sortMode = m),
                      ),
                      const SizedBox(height: 16),
                      _ExploreSheetHeader(
                        label: l10n.exploreDetectionFilterTooltip,
                      ),
                      _ExploreSheetChoiceChips<_DetectionFilter>(
                        current: _detectionFilter,
                        options: [
                          (
                            _DetectionFilter.all,
                            l10n.exploreDetectionFilterAll,
                          ),
                          (
                            _DetectionFilter.detected,
                            l10n.exploreDetectionFilterDetected,
                          ),
                          (
                            _DetectionFilter.undetected,
                            l10n.exploreDetectionFilterUndetected,
                          ),
                        ],
                        onSelected: (m) => update(() => _detectionFilter = m),
                      ),
                      const SizedBox(height: 16),
                      _ExploreSheetHeader(label: l10n.exploreFilterTooltip),
                      _ExploreSheetMultiChips<_TaxonGroup>(
                        current: _groups,
                        options: [
                          for (final g in _TaxonGroup.values)
                            (g, g.label(l10n)),
                        ],
                        // Mutate the shared `_groups` set ONCE, then trigger
                        // both rebuilds with an empty `update(() {})`.
                        // Previously the mutation lived inside the closure
                        // passed to `update`, so it ran twice (once for the
                        // sheet's StatefulBuilder, once for the screen state)
                        // and the toggle silently no-op'd: add then remove.
                        onToggle: (g) {
                          if (!_groups.add(g)) _groups.remove(g);
                          update(() {});
                        },
                        onClear:
                            _groups.isEmpty
                                ? null
                                : () {
                                  _groups.clear();
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

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ExploreHelpSheet(),
    );
  }

  void _refresh() {
    ref.invalidate(currentLocationProvider);
    ref.invalidate(exploreSpeciesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final speciesAsync = ref.watch(exploreSpeciesProvider);
    final locationAsync = ref.watch(currentLocationProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exploreTitle),
        actions: [
          // Filter / sort overlay (badge dot when any non-default option is
          // active).
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_list_outlined),
                if (_filterActive)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: l10n.exploreFilterTooltip,
            onPressed: _showFilterSheet,
          ),
          // Search toggle.
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            tooltip:
                _searchVisible
                    ? l10n.tooltipClearSearch
                    : l10n.exploreSearchTooltip,
            onPressed: _toggleSearch,
          ),
          // Help (swapped with refresh — refresh now lives in the
          // location header next to the location indicator since that's
          // what it actually re-queries).
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: l10n.exploreHelpTitle,
            onPressed: _showHelp,
          ),
        ],
      ),
      body: ContentWidthConstraint(
        child: speciesAsync.when(
          loading: () => const LoadingView(),
          error:
              (error, _) => ErrorView(
                title: l10n.statusError,
                message: error.toString(),
                onRetry: _refresh,
                retryLabel: l10n.retry,
              ),
          data: (localSpecies) {
            return Column(
              children: [
                // ── Location & count header ─────────────────
                _LocationHeader(
                  speciesCount: localSpecies.length,
                  onRefresh: _refresh,
                ),
                const Divider(height: 1),

                // ── Collapsible search field ────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child:
                      _searchVisible
                          ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: _onQueryChanged,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: l10n.exploreSearchHint,
                                prefixIcon: const Icon(Icons.search, size: 20),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                suffixIcon:
                                    _query.isNotEmpty
                                        ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 20,
                                          ),
                                          tooltip: l10n.tooltipClearSearch,
                                          onPressed: () {
                                            _searchController.clear();
                                            _onQueryChanged('');
                                          },
                                        )
                                        : null,
                              ),
                            ),
                          )
                          : const SizedBox(width: double.infinity, height: 0),
                ),

                // ── Body: either geo list or search results ──
                Expanded(
                  child:
                      _query.isEmpty
                          ? _GeoList(
                            species: localSpecies,
                            groups: _groups,
                            sortMode: _sortMode,
                            detectionFilter: _detectionFilter,
                            locationAvailable:
                                locationAsync.valueOrNull != null,
                          )
                          : _SearchResults(
                            query: _query,
                            groups: _groups,
                            sortMode: _sortMode,
                            detectionFilter: _detectionFilter,
                            localSpecies: localSpecies,
                          ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter / sort bottom-sheet helpers
// ---------------------------------------------------------------------------

class _ExploreSheetHeader extends StatelessWidget {
  const _ExploreSheetHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
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
}

class _ExploreSheetChoiceChips<T> extends StatelessWidget {
  const _ExploreSheetChoiceChips({
    required this.current,
    required this.options,
    required this.onSelected,
  });

  final T current;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
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
}

class _ExploreSheetMultiChips<T> extends StatelessWidget {
  const _ExploreSheetMultiChips({
    required this.current,
    required this.options,
    required this.onToggle,
    required this.onClear,
    required this.clearLabel,
  });

  final Set<T> current;
  final List<(T, String)> options;
  final ValueChanged<T> onToggle;
  final VoidCallback? onClear;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
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
}

// ---------------------------------------------------------------------------
// (Old inline group filter chip bar removed — filtering now lives in the
// AppBar filter button's bottom sheet, alongside sort and detection-state
// options.)
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Geo list (no active search)
// ---------------------------------------------------------------------------

class _GeoList extends ConsumerWidget {
  const _GeoList({
    required this.species,
    required this.groups,
    required this.sortMode,
    required this.detectionFilter,
    required this.locationAvailable,
  });

  final List<ExploreSpecies> species;
  final Set<_TaxonGroup> groups;
  final _SortMode sortMode;
  final _DetectionFilter detectionFilter;
  final bool locationAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detected = ref.watch(detectedSpeciesSetProvider);

    final filtered =
        species.where((s) {
          if (groups.isNotEmpty) {
            final g = s.taxonomy?.taxonGroup;
            if (g == null || !groups.any((tg) => tg.csvValue == g)) {
              return false;
            }
          }
          switch (detectionFilter) {
            case _DetectionFilter.all:
              break;
            case _DetectionFilter.detected:
              if (!detected.contains(s.scientificName)) return false;
            case _DetectionFilter.undetected:
              if (detected.contains(s.scientificName)) return false;
          }
          return true;
        }).toList();

    switch (sortMode) {
      case _SortMode.geo:
        filtered.sort((a, b) => b.geoScore.compareTo(a.geoScore));
      case _SortMode.nameAsc:
        filtered.sort(
          (a, b) =>
              a.commonName.toLowerCase().compareTo(b.commonName.toLowerCase()),
        );
      case _SortMode.nameDesc:
        filtered.sort(
          (a, b) =>
              b.commonName.toLowerCase().compareTo(a.commonName.toLowerCase()),
        );
    }

    if (filtered.isEmpty) {
      return EmptyView(
        icon: locationAvailable ? Icons.search_off : Icons.location_off,
        title:
            locationAvailable ? l10n.exploreNoSpecies : l10n.exploreNoLocation,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final s = filtered[index];
        return SpeciesCard(
          scientificName: s.scientificName,
          commonName: s.commonName,
          geoScore: s.geoScore,
          weeklyScores: s.weeklyScores,
          onTap:
              () => SpeciesInfoOverlay.show(
                context,
                ref,
                scientificName: s.scientificName,
                commonName: s.commonName,
              ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Search results — runs over the full taxonomy, partitions by location
// ---------------------------------------------------------------------------

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.groups,
    required this.sortMode,
    required this.detectionFilter,
    required this.localSpecies,
  });

  final String query;
  final Set<_TaxonGroup> groups;
  final _SortMode sortMode;
  final _DetectionFilter detectionFilter;
  final List<ExploreSpecies> localSpecies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final taxonomyAsync = ref.watch(taxonomyServiceProvider);
    final audioLabelsAsync = ref.watch(audioLabelsSetProvider);
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final detected = ref.watch(detectedSpeciesSetProvider);

    final taxonomy = taxonomyAsync.valueOrNull;
    final audioLabels = audioLabelsAsync.valueOrNull;
    if (taxonomy == null || audioLabels == null) {
      return const LoadingView();
    }

    // Index local species by scientific name for fast lookup.
    final localByName = <String, ExploreSpecies>{
      for (final s in localSpecies) s.scientificName: s,
    };

    // Search across the entire taxonomy, then keep only species the audio
    // model knows about (so opening them is meaningful), and apply the
    // taxonomic-group + detection-state filters.
    final hits =
        taxonomy
            .search(query, limit: 200)
            .where((sp) => audioLabels.contains(sp.scientificName))
            .where(
              (sp) =>
                  groups.isEmpty ||
                  groups.any((g) => g.csvValue == sp.taxonGroup),
            )
            .where((sp) {
              switch (detectionFilter) {
                case _DetectionFilter.all:
                  return true;
                case _DetectionFilter.detected:
                  return detected.contains(sp.scientificName);
                case _DetectionFilter.undetected:
                  return !detected.contains(sp.scientificName);
              }
            })
            .toList();

    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.exploreNoResultsFor(query),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Partition into "at your location" and "other species" while
    // preserving search-relevance order within each bucket.
    final atLocation = <_SearchHit>[];
    final elsewhere = <_SearchHit>[];
    for (final sp in hits) {
      final local = localByName[sp.scientificName];
      final hit = _SearchHit(
        species: sp,
        local: local,
        speciesLocale: speciesLocale,
      );
      if (local != null) {
        atLocation.add(hit);
      } else {
        elsewhere.add(hit);
      }
    }
    // Apply the user's chosen sort to each bucket independently. Geo
    // probability is the default for the at-location bucket; the
    // alphabetical modes apply to both buckets symmetrically.
    int byNameAsc(_SearchHit a, _SearchHit b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    int byNameDesc(_SearchHit a, _SearchHit b) =>
        b.displayName.toLowerCase().compareTo(a.displayName.toLowerCase());
    switch (sortMode) {
      case _SortMode.geo:
        atLocation.sort(
          (a, b) => (b.local?.geoScore ?? 0).compareTo(a.local?.geoScore ?? 0),
        );
      case _SortMode.nameAsc:
        atLocation.sort(byNameAsc);
        elsewhere.sort(byNameAsc);
      case _SortMode.nameDesc:
        atLocation.sort(byNameDesc);
        elsewhere.sort(byNameDesc);
    }

    final items = <_ListEntry>[];
    if (atLocation.isNotEmpty) {
      items.add(
        _ListEntry.header(
          l10n.exploreSectionAtLocation(atLocation.length),
          Icons.location_on,
        ),
      );
      items.addAll(atLocation.map(_ListEntry.hit));
    }
    if (elsewhere.isNotEmpty) {
      items.add(
        _ListEntry.header(
          l10n.exploreSectionElsewhere(elsewhere.length),
          Icons.public,
        ),
      );
      items.addAll(elsewhere.map(_ListEntry.hit));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final entry = items[index];
        if (entry.isHeader) {
          return _SectionHeader(label: entry.label!, icon: entry.icon!);
        }
        final hit = entry.hit!;
        return SpeciesCard(
          scientificName: hit.species.scientificName,
          commonName: hit.displayName,
          geoScore: hit.local?.geoScore,
          weeklyScores: hit.local?.weeklyScores,
          onTap:
              () => SpeciesInfoOverlay.show(
                context,
                ref,
                scientificName: hit.species.scientificName,
                commonName: hit.species.commonName,
              ),
        );
      },
    );
  }
}

class _SearchHit {
  _SearchHit({
    required this.species,
    required this.local,
    required this.speciesLocale,
  });

  final TaxonomySpecies species;
  final ExploreSpecies? local;
  final String speciesLocale;

  String get displayName => species.commonNameForLocale(speciesLocale);
}

class _ListEntry {
  _ListEntry.header(this.label, this.icon) : isHeader = true, hit = null;
  _ListEntry.hit(this.hit) : isHeader = false, label = null, icon = null;

  final bool isHeader;
  final String? label;
  final IconData? icon;
  final _SearchHit? hit;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location header — shows coordinates and species count
// ---------------------------------------------------------------------------

class _LocationHeader extends ConsumerStatefulWidget {
  const _LocationHeader({required this.speciesCount, required this.onRefresh});

  final int speciesCount;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_LocationHeader> createState() => _LocationHeaderState();
}

class _LocationHeaderState extends ConsumerState<_LocationHeader> {
  String? _locationName;
  bool _geocoded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryGeocode();
  }

  Future<void> _tryGeocode() async {
    final loc = ref.read(currentLocationProvider).valueOrNull;
    if (loc == null || _geocoded) return;
    _geocoded = true;
    final name = await reverseGeocode(
      latitude: loc.latitude,
      longitude: loc.longitude,
    );
    if (mounted && name != null) {
      setState(() => _locationName = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locationAsync = ref.watch(currentLocationProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: locationAsync.when(
                  data: (loc) {
                    if (loc == null) {
                      return Text(
                        l10n.exploreNoLocation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      );
                    }
                    // Prefer the reverse-geocoded place name; fall back to
                    // raw lat/lon so we don't waste a second row showing
                    // both. While geocoding is in flight, show coordinates.
                    final label =
                        _locationName ??
                        '${loc.latitude.toStringAsFixed(4)}, '
                            '${loc.longitude.toStringAsFixed(4)}';
                    return Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    );
                  },
                  loading:
                      () => Text(
                        l10n.exploreLocating,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                  error:
                      (_, __) => Text(
                        l10n.exploreLocationError,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                ),
              ),
              IconButton(
                onPressed: widget.onRefresh,
                icon: Icon(
                  Icons.refresh,
                  size: 22,
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
                tooltip: l10n.exploreRefresh,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Help bottom sheet (matches session review style)
// ---------------------------------------------------------------------------

class _ExploreHelpSheet extends StatelessWidget {
  const _ExploreHelpSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppHelpBottomSheet(
      title: l10n.exploreHelpTitle,
      initialChildSize: 0.62,
      sections: [
        AppHelpSection(icon: Icons.info_outline, body: l10n.exploreHelpBody),
        AppHelpSection(icon: Icons.refresh, body: l10n.exploreHelpRefresh),
        AppHelpSection(
          icon: Icons.help_outline_rounded,
          body: l10n.exploreHelpLocation,
        ),
        AppHelpSection(icon: Icons.search_rounded, body: l10n.exploreHelpCards),
      ],
      footer: _ExploreHelpLink(label: l10n.exploreHelpLearnMore),
    );
  }
}

class _ExploreHelpLink extends StatelessWidget {
  const _ExploreHelpLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap:
          () => openExternalUrl(
            context,
            'https://birdnet-team.github.io/geomodel/',
          ),
      child: Row(
        children: [
          Icon(Icons.open_in_new, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
