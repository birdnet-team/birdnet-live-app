// =============================================================================
// Species Card — Compact species tile with thumbnail
// =============================================================================
//
// Displays a species entry with:
//   • CachedNetworkImage thumbnail (4:3 aspect ratio, 150×100 WebP)
//   • Common name + scientific name
//   • Optional geo-score indicator
//
// Used in both the Explore screen and the live detection list.
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../inference/geo_model.dart';
import '../../../shared/services/taxonomy_service.dart';
import '../explore_providers.dart';

/// A compact species card with a 4:3 thumbnail.
class SpeciesCard extends StatelessWidget {
  const SpeciesCard({
    super.key,
    required this.scientificName,
    required this.commonName,
    this.geoScore,
    this.confidence,
    this.weeklyScores,
    this.onTap,
  });

  /// Scientific name — used to generate the thumbnail URL.
  final String scientificName;

  /// Common name to display.
  final String commonName;

  /// Optional geo-model score (0–100) shown as a subtle indicator.
  final double? geoScore;

  /// Optional audio confidence (0–1) shown when used in detections.
  final double? confidence;

  /// Optional 48-week probability array for drawing a mini chart.
  final List<double>? weeklyScores;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withAlpha(120)
          : theme.colorScheme.surfaceContainerHighest.withAlpha(180),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail (4:3) ──
            SizedBox(
              width: 80,
              height: 60,
              child: CachedNetworkImage(
                imageUrl: TaxonomyService.thumbUrl(scientificName),
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
            // ── Names and Details ──
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Row 1: Common name & Score indicator
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            commonName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (confidence != null || geoScore != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: probabilityCategoryColor(geoScore ??
                                      (confidence != null
                                          ? confidence! * 100
                                          : 0))
                                  .withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: probabilityCategoryColor(geoScore ??
                                        (confidence != null
                                            ? confidence! * 100
                                            : 0))
                                    .withAlpha(120),
                              ),
                            ),
                            child: Text(
                              confidence != null
                                  ? '${(confidence! * 100).toStringAsFixed(0)}%'
                                  : '${geoScore!.toStringAsFixed(0)}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: probabilityCategoryColor(geoScore ??
                                    (confidence != null
                                        ? confidence! * 100
                                        : 0)),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Row 2: Scientific name
                    Text(
                      scientificName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                        fontStyle: FontStyle.italic,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Row 3: Bar chart
                    if (weeklyScores != null)
                      _MiniChart(weeklyScores: weeklyScores!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.weeklyScores});

  final List<double> weeklyScores;

  @override
  Widget build(BuildContext context) {
    if (weeklyScores.every((p) => p == 0)) return const SizedBox();

    final theme = Theme.of(context);
    final currentWeekIndex = GeoModel.dateTimeToWeek(DateTime.now()) - 1;

    // Use full 0-100 max scale since arrays are already normalized up to 100.
    var maxProb = 0.0;
    for (final p in weeklyScores) {
      if (p > maxProb) maxProb = p;
    }
    if (maxProb == 0) maxProb = 1.0;

    return SizedBox(
      height: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(48, (index) {
          final score = weeklyScores[index];
          final normalized = score / maxProb;
          final isCurrentWeek = index == currentWeekIndex;

          final baseColor = theme.colorScheme.primary;
          final activeColor = theme.colorScheme.tertiary;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              height: (normalized * 18).clamp(1.0, 18.0),
              decoration: BoxDecoration(
                color: isCurrentWeek
                    ? activeColor
                    : baseColor.withAlpha(
                        (50 + (normalized * 150)).toInt().clamp(0, 255)),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(1)),
                border: isCurrentWeek
                    ? Border.all(
                        color: theme.colorScheme.onSurface,
                        width: 0.5,
                      )
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
