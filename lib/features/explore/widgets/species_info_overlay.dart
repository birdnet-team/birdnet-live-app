// =============================================================================
// Species Info Overlay — Detailed species information bottom sheet
// =============================================================================
//
// A modal bottom sheet showing detailed species information:
//   • Medium image (480x320 WebP, 3:2)
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/score_colors.dart';
import '../../../shared/models/taxonomy_species.dart';
import '../../../shared/providers/settings_providers.dart';
import '../../../shared/services/link_launcher.dart';
import '../../../shared/utils/app_icons.dart';
import '../explore_providers.dart';
import '../explore_tier.dart';
import '../../inference/geo_model.dart';
import '../../history/global_species_history.dart';
import '../../live/live_providers.dart';
import 'pick_wikipedia_url.dart';

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
      builder:
          (_) => _SpeciesInfoSheet(
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
  String? _description;
  bool _loading = true;
  bool _fetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetched) {
      _fetched = true;
      _loadBundledData();
    }
  }

  Future<void> _loadBundledData() async {
    try {
      final locale = ref.read(effectiveSpeciesLocaleProvider);
      final taxonomyService = await ref.read(taxonomyServiceProvider.future);
      final descService = ref.read(speciesDescriptionServiceProvider);

      final detail = taxonomyService.lookup(widget.scientificName);
      final description = await descService.getDescription(
        widget.scientificName,
        locale,
      );

      if (mounted) {
        setState(() {
          _detail = detail;
          _description = description;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[SpeciesInfoOverlay] loadBundledData error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Pick the best Wikipedia URL for the active locale.
  ///
  /// Delegates to [pickWikipediaUrl] with the current effective locale.
  String _pickWikipediaUrl(TaxonomySpecies detail) {
    final locale = ref.read(effectiveSpeciesLocaleProvider);
    return pickWikipediaUrl(
      scientificName: widget.scientificName,
      bundledUrls: detail.wikipediaUrls,
      locale: locale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = AppTheme.isHighContrastTheme(theme);
    final l10n = AppLocalizations.of(context)!;

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
              // Bundled species photos are 360×240 (3:2); using a 3:2
              // aspect ratio with BoxFit.contain shows the full photo
              // without vertical cropping or sideways distortion.
              AspectRatio(
                aspectRatio: 3 / 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      _detail?.assetImagePath ??
                          'assets/images/dummy_species.png',
                      fit: BoxFit.contain,
                      errorBuilder:
                          (a, b, c) => Image.asset(
                            'assets/images/dummy_species.png',
                            fit: BoxFit.contain,
                          ),
                    ),
                    if (ref
                        .watch(detectedSpeciesSetProvider)
                        .contains(widget.scientificName))
                      const Positioned(
                        top: 12,
                        right: 12,
                        child: _OverlayDetectedBadge(),
                      ),
                  ],
                ),
              ),

              // ── Image credit (below photo) ────────────────────
              if (_detail?.imageAuthor != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(
                    '${l10n.speciesPhotoCreditLabel}: ${_detail!.imageAuthor}'
                    '${_detail!.imageSource != null ? ' — ${_detail!.imageSource}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          highContrast
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                ),

              // ── Names ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  _detail?.commonNameForLocale(
                        ref.watch(effectiveSpeciesLocaleProvider),
                      ) ??
                      widget.commonName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child:
                    ref.watch(showSciNamesProvider)
                        ? Text(
                          _detail?.displayScientificName ??
                              widget.scientificName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withAlpha(170),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),

              // ── Listen on eBird ─────────────────────────────────
              // Prominent, clearly-external call-to-action placed above the
              // detection-stats box. Shown only when the taxonomy carries an
              // eBird code; opens the public eBird / Macaulay Library audio
              // catalog in the browser. (The species page's own "Listen" player
              // is a click-only JavaScript modal with no deep-link, so it can't
              // be triggered from an external URL.) Tonal button colors resolve
              // to secondaryContainer/onSecondaryContainer, which every app
              // theme defines with strong contrast (incl. high-contrast).
              if (_detail?.ebirdListenUrl != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed:
                          () => openExternalUrl(
                            context,
                            _detail!.ebirdListenUrl!,
                          ),
                      icon: const Icon(AppIcons.volumeUpRounded),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(l10n.speciesListenOnEbird)),
                          const SizedBox(width: 8),
                          Icon(
                            AppIcons.openInNew,
                            size: 16,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Personal detection stats ─────────────────────
              // Aggregated from the user's saved sessions so they can see
              // at a glance how often (and when last) they have logged
              // this species. Skipped entirely when the species has never
              // been detected — there's nothing useful to show.
              _DetectionStatsTile(scientificName: widget.scientificName),

              // ── Loading skeleton (shimmer placeholder for the bio paragraph) ─
              if (_loading)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _BioSkeleton(),
                ),

              // ── Description ─────────────────────────────────
              if (!_loading) ...[
                if (_description != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      _description!,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                  if (_detail?.descriptionSource != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        AppLocalizations.of(context)!.speciesDescriptionSource(
                          _detail!.descriptionSource!,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(100),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],

                // ── 48-Week Probability Chart ──────────────────────────────
                _WeeklyProbabilityChart(scientificName: widget.scientificName),

                // ── External links ───────────────────────────────
                if (_detail != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      AppLocalizations.of(context)!.speciesLearnMore,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_detail!.ebirdUrl != null)
                          _LinkChip(
                            label: 'eBird',
                            iconAsset: 'assets/images/icon-ebird.png',
                            url: _detail!.ebirdUrl!,
                          ),
                        if (_detail!.inatUrl != null)
                          _LinkChip(
                            label: 'iNaturalist',
                            iconAsset: 'assets/images/icon-inat.png',
                            url: _detail!.inatUrl!,
                          ),
                        _LinkChip(
                          label: 'Wikipedia',
                          iconAsset: 'assets/images/icon-wikipedia.png',
                          url: _pickWikipediaUrl(_detail!),
                        ),
                      ],
                    ),
                  ),
                ],
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
// Loading skeleton (shimmer placeholder for the bio paragraph)
// ---------------------------------------------------------------------------

/// Animated grey lines that fade in and out to indicate loading.
///
/// Cheaper than a true shimmer (no shader work) and matches the app's
/// understated visual language.
class _BioSkeleton extends StatefulWidget {
  const _BioSkeleton();

  @override
  State<_BioSkeleton> createState() => _BioSkeletonState();
}

class _BioSkeletonState extends State<_BioSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _line(double widthFactor, Color baseColor) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (a, b) {
          final t = Curves.easeInOut.transform(_controller.value);
          final alpha = (40 + (t * 80)).round().clamp(0, 255);
          return Container(
            height: 12,
            decoration: BoxDecoration(
              color: baseColor.withAlpha(alpha),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(1.0, base),
        const SizedBox(height: 8),
        _line(0.96, base),
        const SizedBox(height: 8),
        _line(0.86, base),
        const SizedBox(height: 8),
        _line(0.62, base),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Link chip widget
// ---------------------------------------------------------------------------

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.label,
    required this.iconAsset,
    required this.url,
  });

  final String label;
  final String iconAsset;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ActionChip(
      avatar: Image.asset(
        iconAsset,
        width: 18,
        height: 18,
        fit: BoxFit.contain,
        errorBuilder: (a, b, c) => const Icon(AppIcons.public, size: 18),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Icon(
            AppIcons.openInNew,
            size: 12,
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
        ],
      ),
      labelStyle: theme.textTheme.bodySmall,
      onPressed: () => openExternalUrl(context, url),
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
    final highContrast = AppTheme.isHighContrastTheme(theme);
    final l10n = AppLocalizations.of(context)!;
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
              l10n.speciesChartNoData,
              style: theme.textTheme.bodySmall,
            ),
          );
        }

        final currentWeekIndex = GeoModel.dateTimeToWeek(DateTime.now()) - 1;
        final currentScore = probs[currentWeekIndex];
        // Use the distribution-adaptive tier from the explore list so the
        // overlay label and color match the compact card chip.
        final tier = match.isNotEmpty ? match.first.tier : null;
        final category =
            tier != null
                ? exploreTierLabel(l10n, tier)
                : _localizedProbabilityCategory(l10n, currentScore);
        final categoryColor =
            tier != null
                ? exploreTierColor(ScoreColors.of(context), tier)
                : probabilityCategoryColor(context, currentScore);

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
                    l10n.speciesExpectedFrequency,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
                l10n.speciesExpectedFrequencySubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      highContrast
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withAlpha(180),
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
                        score > 0 || isCurrentWeek
                            ? (normalized * 80).clamp(2.0, 80.0)
                            : 0.0;

                    final baseColor = theme.colorScheme.primary;
                    final activeColor =
                        highContrast
                            ? theme.colorScheme.surface
                            : theme.colorScheme.tertiary;

                    return Expanded(
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          height: barHeight,
                          decoration: BoxDecoration(
                            color:
                                isCurrentWeek
                                    ? activeColor
                                    : highContrast
                                    ? baseColor
                                    : baseColor.withAlpha(
                                      (50 + (normalized * 150)).toInt().clamp(
                                        0,
                                        255,
                                      ),
                                    ),
                            borderRadius: BorderRadius.circular(2),
                            border:
                                isCurrentWeek
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
                children: [
                  Text(
                    l10n.monthJanShort,
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    l10n.monthAprShort,
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    l10n.monthJulShort,
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    l10n.monthOctShort,
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    l10n.monthDecShort,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading:
          () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      error:
          (a, b) => Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text(l10n.speciesChartLoadFailed)),
          ),
    );
  }
}

String _localizedProbabilityCategory(AppLocalizations l10n, double score) {
  if (score >= 80) return l10n.speciesFrequencyAbundant;
  if (score >= 60) return l10n.speciesFrequencyCommon;
  if (score >= 40) return l10n.speciesFrequencyUncommon;
  if (score >= 20) return l10n.speciesFrequencyOccasional;
  return l10n.speciesFrequencyRare;
}

/// Larger version of the corner badge used over the bird photo in the
/// species info overlay. Uses the same primary-color check icon as the
/// thumbnail badge, scaled up so it remains visible against busy photos.
class _OverlayDetectedBadge extends StatelessWidget {
  const _OverlayDetectedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = AppTheme.isHighContrastTheme(theme);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        // Brand blue "earned" marker; high-contrast themes use black with a
        // white check for maximum separation.
        color: highContrast ? Colors.black : theme.colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(80),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        AppIcons.check,
        size: 18,
        color: highContrast ? Colors.white : theme.colorScheme.onPrimary,
      ),
    );
  }
}

/// Aggregates the user's saved sessions to surface "you have detected this
/// species N times, last on …" inside the species info overlay. Hidden
/// entirely when the species has never been logged so the overlay stays
/// uncluttered for unfamiliar birds the user is exploring for the first
/// time.
class _DetectionStatsTile extends ConsumerWidget {
  const _DetectionStatsTile({required this.scientificName});

  final String scientificName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final highContrast = AppTheme.isHighContrastTheme(theme);
    final l10n = AppLocalizations.of(context)!;
    final asyncSessions = ref.watch(sessionListProvider);

    return asyncSessions.when(
      loading: () => const SizedBox.shrink(),
      error: (a, b) => const SizedBox.shrink(),
      data: (sessions) {
        // Walk every session once. We aggregate three numbers in one pass
        // so that opening the overlay never depends on session count: total
        // detections, distinct sessions that contain this species, and the
        // newest detection timestamp.
        var totalDetections = 0;
        var sessionCount = 0;
        DateTime? lastSeen;
        for (final session in sessions) {
          var inThisSession = 0;
          for (final d in session.detections) {
            if (d.scientificName != scientificName) continue;
            inThisSession++;
            // DetectionRecord.timestamp is already an absolute wall-clock
            // time so we can compare directly across sessions.
            final ts = d.timestamp;
            if (lastSeen == null || ts.isAfter(lastSeen)) {
              lastSeen = ts;
            }
          }
          if (inThisSession > 0) {
            sessionCount++;
            totalDetections += inThisSession;
          }
        }

        if (totalDetections == 0) return const SizedBox.shrink();

        final lastSeenText =
            lastSeen != null ? _formatLastSeen(context, lastSeen) : '—';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  highContrast
                      ? Colors.white
                      : theme.colorScheme.primaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(10),
              border:
                  highContrast
                      ? Border.all(color: Colors.black, width: 1.5)
                      : null,
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.checkCircle,
                  size: 20,
                  // Black keeps maximum contrast against the white
                  // high-contrast panel; normal themes use the vibrant
                  // brand-blue primary.
                  color:
                      highContrast ? Colors.black : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.speciesYouHaveDetected(
                          totalDetections,
                          sessionCount,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: highContrast ? Colors.black : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.speciesLastSeen(lastSeenText),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              highContrast
                                  ? Colors.black
                                  : theme.colorScheme.onSurface.withAlpha(170),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatLastSeen(BuildContext context, DateTime dt) {
    final locale = Localizations.localeOf(context).toString();
    return MaterialLocalizations.of(
          context,
        ).formatMediumDate(dt.toLocal()).toString().isNotEmpty
        // Fall through to a stable yyyy-MM-dd if the platform localization
        // is unavailable for the active locale (rare on supported devices).
        ? MaterialLocalizations.of(context).formatMediumDate(dt.toLocal())
        : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ($locale)';
  }
}
