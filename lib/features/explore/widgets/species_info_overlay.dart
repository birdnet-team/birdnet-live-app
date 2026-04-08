// =============================================================================
// Species Info Overlay — Detailed species information bottom sheet
// =============================================================================
//
// A modal bottom sheet showing detailed species information:
//   • Medium image (480×320 WebP, 4:3)
//   • Common name + scientific name
//   • Wikipedia excerpt (if available from API)
//   • External links (eBird, iNaturalist)
//   • Image credit
//
// ### Usage
//
// ```dart
// SpeciesInfoOverlay.show(context, ref, scientificName: 'Parus major');
// ```
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/taxonomy_species.dart';
import '../../../shared/providers/settings_providers.dart';
import '../../../shared/services/taxonomy_service.dart';
import '../explore_providers.dart';
import '../../inference/geo_model.dart';

/// Shows a modal bottom sheet with detailed species information.
class SpeciesInfoOverlay {
  SpeciesInfoOverlay._();

  /// Show the species info overlay for the given [scientificName].
  static void show(
    BuildContext context,
    WidgetRef ref, {
    required String scientificName,
    required String commonName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SpeciesInfoSheet(
        scientificName: scientificName,
        commonName: commonName,
      ),
    );
  }
}

class _SpeciesInfoSheet extends ConsumerStatefulWidget {
  const _SpeciesInfoSheet({
    required this.scientificName,
    required this.commonName,
  });

  final String scientificName;
  final String commonName;

  @override
  ConsumerState<_SpeciesInfoSheet> createState() => _SpeciesInfoSheetState();
}

class _SpeciesInfoSheetState extends ConsumerState<_SpeciesInfoSheet> {
  TaxonomySpecies? _detail;
  bool _loading = true;
  bool _fetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetched) {
      _fetched = true;
      _fetchDetail();
    }
  }

  Future<void> _fetchDetail() async {
    try {
      final locale = ref.read(effectiveSpeciesLocaleProvider);
      final taxonomyService = await ref.read(taxonomyServiceProvider.future);

      // Try API with locale for descriptions, fall back to local CSV.
      final detail = await taxonomyService.fetchDetail(
        widget.scientificName,
        locale: locale,
      );

      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[SpeciesInfoOverlay] fetchDetail error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ──────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Image ────────────────────────────────────────
              AspectRatio(
                aspectRatio: 4 / 3,
                child: CachedNetworkImage(
                  imageUrl: TaxonomyService.mediumUrl(widget.scientificName),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Image.asset(
                    'assets/images/dummy_species.png',
                    fit: BoxFit.cover,
                  ),
                  errorWidget: (_, __, ___) => Image.asset(
                    'assets/images/dummy_species.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // ── Names ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  _detail?.commonNameForLocale(
                          ref.watch(effectiveSpeciesLocaleProvider)) ??
                      widget.commonName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ref.watch(showSciNamesProvider)
                    ? Text(
                        widget.scientificName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface.withAlpha(170),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Loading indicator ────────────────────────────
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),

              // ── Description / Wikipedia excerpt ──────────────
              if (!_loading && _detail != null) ...[
                if (_detail!.descriptionForLocale(
                        ref.watch(effectiveSpeciesLocaleProvider)) !=
                    null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      _detail!.descriptionForLocale(
                          ref.watch(effectiveSpeciesLocaleProvider))!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                    ),
                  ),

                // ── 48-Week Probability Chart ──────────────────────────────
                _WeeklyProbabilityChart(
                  scientificName: widget.scientificName,
                ),

                // ── External links ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_detail!.ebirdUrl != null)
                        _LinkChip(
                          label: 'eBird',
                          icon: Icons.public,
                          url: _detail!.ebirdUrl!,
                        ),
                      if (_detail!.inatUrl != null)
                        _LinkChip(
                          label: 'iNaturalist',
                          icon: Icons.nature_people,
                          url: _detail!.inatUrl!,
                        ),
                      if (_detail!.wikipediaUrls != null &&
                          _detail!.wikipediaUrls!.isNotEmpty)
                        _LinkChip(
                          label: 'Wikipedia',
                          icon: Icons.menu_book,
                          url: _detail!.wikipediaUrls!.values.first,
                        ),
                    ],
                  ),
                ),

                // ── Image credit ─────────────────────────────────
                if (_detail!.imageAuthor != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Photo: ${_detail!.imageAuthor}'
                      '${_detail!.imageLicense != null ? ' (${_detail!.imageLicense})' : ''}'
                      '${_detail!.imageSource != null ? ' — ${_detail!.imageSource}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(100),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Link chip widget
// ---------------------------------------------------------------------------

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.label,
    required this.icon,
    required this.url,
  });

  final String label;
  final IconData icon;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      labelStyle: theme.textTheme.bodySmall,
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 48-Week Probability Chart
// ---------------------------------------------------------------------------

class _WeeklyProbabilityChart extends ConsumerWidget {
  const _WeeklyProbabilityChart({required this.scientificName});

  final String scientificName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final speciesAsync = ref.watch(exploreSpeciesProvider);

    return speciesAsync.when(
      data: (speciesList) {
        // Find this species in the already-computed explore list.
        final match = speciesList.where(
          (s) => s.scientificName == scientificName,
        );
        final probs = match.isNotEmpty ? match.first.weeklyScores : null;

        if (probs == null || probs.every((p) => p == 0)) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No probability data for this location.',
              style: theme.textTheme.bodySmall,
            ),
          );
        }

        final currentWeekIndex = GeoModel.dateTimeToWeek(DateTime.now()) - 1;
        final currentScore = probs[currentWeekIndex];
        final category = probabilityCategory(currentScore);
        final categoryColor = probabilityCategoryColor(currentScore);

        // Normalize to 100 (= the #1 species peak from the provider).
        const maxProb = 100.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Expected Frequency',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: categoryColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: categoryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Predicted presence across 48 weeks based on your location.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(180),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(48, (index) {
                    final score = probs[index];
                    final normalized = (score / maxProb).clamp(0.0, 1.0);
                    final isCurrentWeek = index == currentWeekIndex;

                    final barHeight =
                        score > 0 ? (normalized * 80).clamp(2.0, 80.0) : 0.0;

                    final baseColor = theme.colorScheme.primary;
                    final activeColor = theme.colorScheme.tertiary;

                    return Expanded(
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isCurrentWeek
                                ? activeColor
                                : baseColor.withAlpha(
                                    (50 + (normalized * 150))
                                        .toInt()
                                        .clamp(0, 255),
                                  ),
                            borderRadius: BorderRadius.circular(2),
                            border: isCurrentWeek
                                ? Border.all(
                                    color: theme.colorScheme.onSurface,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            // Month labels
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Jan', style: TextStyle(fontSize: 10)),
                  Text('Apr', style: TextStyle(fontSize: 10)),
                  Text('Jul', style: TextStyle(fontSize: 10)),
                  Text('Oct', style: TextStyle(fontSize: 10)),
                  Text('Dec', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Failed to load chart')),
      ),
    );
  }
}
