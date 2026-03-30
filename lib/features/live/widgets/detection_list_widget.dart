// =============================================================================
// Detection List Widget — Real-time species detection display
// =============================================================================
//
// Shows the accumulated detections from the current live session.  Each
// detection is displayed as a card with:
//
//   • Thumbnail image (4:3)
//   • Common name (full row, not truncated)
//   • Scientific name + confidence bar
//
// Tapping a detection opens the species info overlay.
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/settings_providers.dart';
import '../../../shared/services/taxonomy_service.dart';
import '../../explore/explore_providers.dart';
import '../live_session.dart';

/// Displays a scrollable list of species detections.
///
/// Pass an empty list to show an appropriate empty-state message.
class DetectionList extends StatelessWidget {
  const DetectionList({
    super.key,
    required this.detections,
    required this.isActive,
    this.onDetectionTap,
  });

  /// Detections to display (newest first).
  final List<DetectionRecord> detections;

  /// Whether the session is actively running.
  final bool isActive;

  /// Called when a detection tile is tapped.
  final void Function(DetectionRecord detection)? onDetectionTap;

  @override
  Widget build(BuildContext context) {
    if (detections.isEmpty) {
      return _EmptyState(isActive: isActive);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: detections.length,
      itemBuilder: (context, index) {
        return DetectionTile(
          detection: detections[index],
          onTap: onDetectionTap != null
              ? () => onDetectionTap!(detections[index])
              : null,
        );
      },
    );
  }
}

/// A single detection entry in the list.
class DetectionTile extends ConsumerWidget {
  const DetectionTile({
    super.key,
    required this.detection,
    this.onTap,
  });

  final DetectionRecord detection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomyAsync = ref.watch(taxonomyServiceProvider);

    // Resolve localized common name, falling back to English inference name.
    final displayName = taxonomyAsync.valueOrNull
            ?.lookup(detection.scientificName)
            ?.commonNameForLocale(speciesLocale) ??
        detection.commonName;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Thumbnail (4:3) ───────────────────────────────
            SizedBox(
              width: 60,
              height: 45,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: TaxonomyService.thumbUrl(
                    detection.scientificName,
                  ),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.flutter_dash,
                      size: 20,
                      color: theme.colorScheme.onSurface.withAlpha(60),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ── Name + sci name + confidence ──────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Common name — full width, wraps if needed
                  Text(
                    displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Scientific name + confidence on one row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          detection.scientificName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        detection.confidencePercent,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _confidenceColor(
                            detection.confidence,
                            theme,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Confidence bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: detection.confidence,
                      minHeight: 3,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _confidenceColor(detection.confidence, theme),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Chevron ───────────────────────────────────────
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurface.withAlpha(80),
            ),
          ],
        ),
      ),
    );
  }

  /// Map confidence to a colour: red → amber → green.
  Color _confidenceColor(double confidence, ThemeData theme) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.4) return Colors.amber;
    return Colors.red;
  }
}

/// Empty state shown when no detections are available.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? Icons.hearing : Icons.list_alt,
            size: 40,
            color: theme.colorScheme.onSurface.withAlpha(77),
          ),
          const SizedBox(height: 8),
          Text(
            isActive ? 'Listening…' : 'Detections',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
          ),
          Text(
            isActive
                ? 'Species will appear here when detected'
                : 'Start a session to identify species',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(77),
            ),
          ),
        ],
      ),
    );
  }
}
