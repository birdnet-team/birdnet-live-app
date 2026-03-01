// =============================================================================
// Detection List Widget — Real-time species detection display
// =============================================================================
//
// Shows the accumulated detections from the current live session.  Each
// detection is displayed as a tile with:
//
//   • Species common name (primary text).
//   • Scientific name (secondary text).
//   • Confidence bar + percentage.
//   • Timestamp (relative "time ago" format).
//   • Tap action to play back the detection audio clip (if available).
//
// The list auto-scrolls to show the newest detection at the top.
// =============================================================================

import 'package:flutter/material.dart';

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

  /// Called when a detection tile is tapped (for playback).
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
class DetectionTile extends StatelessWidget {
  const DetectionTile({
    super.key,
    required this.detection,
    this.onTap,
  });

  final DetectionRecord detection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasClip = detection.audioClipPath != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // ── Species info ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detection.commonName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detection.scientificName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ── Confidence bar + percentage ───────────────────
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: detection.confidence,
                      minHeight: 4,
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

            // ── Time + play icon ──────────────────────────────
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Text(
                    _formatTimeAgo(detection.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(128),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (hasClip)
                    Icon(
                      Icons.play_circle_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
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

  /// Format a timestamp as relative "time ago".
  static String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 5) return 'now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
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
