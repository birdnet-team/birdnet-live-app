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
    this.onTap,
  });

  /// Scientific name — used to generate the thumbnail URL.
  final String scientificName;

  /// Common name to display.
  final String commonName;

  /// Optional geo-model score (0–1) shown as a subtle indicator.
  final double? geoScore;

  /// Optional audio confidence (0–1) shown when used in detections.
  final double? confidence;

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
          children: [
            // ── Thumbnail (4:3) ───────────────────────────────
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
            // ── Names ─────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      commonName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scientificName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(130),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // ── Score indicator ───────────────────────────────
            if (confidence != null || geoScore != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: probabilityCategoryColor(geoScore ?? confidence ?? 0)
                        .withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          probabilityCategoryColor(geoScore ?? confidence ?? 0)
                              .withAlpha(120),
                    ),
                  ),
                  child: Text(
                    confidence != null
                        ? '${(confidence! * 100).toStringAsFixed(0)}%'
                        : probabilityCategory(geoScore!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          probabilityCategoryColor(geoScore ?? confidence ?? 0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
