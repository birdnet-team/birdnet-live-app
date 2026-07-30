// =============================================================================
// Survey Stats Bar — Glanceable row of survey statistics
// =============================================================================
//
// Displays distance walked, detection count, and unique species
// count in a compact horizontal row.  Designed for the survey live screen
// top-of-screen overlay.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_semantic_colors.dart';
import '../../../shared/utils/app_icons.dart';
import '../../../shared/widgets/stat_chip.dart';

enum _AudioQuality { lost, bad, marginal, good }

/// Compact statistics bar for an active survey.
class SurveyStatsBar extends StatelessWidget {
  const SurveyStatsBar({
    super.key,
    required this.distanceMeters,
    required this.detectionCount,
    required this.speciesCount,
    this.audioLevel = 0,
    this.peakLevel = 0,
    this.micLost = false,
  });

  /// Distance walked in meters.
  final double distanceMeters;

  /// Total detection count (after sampling).
  final int detectionCount;

  /// Unique species count.
  final int speciesCount;

  /// Current RMS audio level (0.0 – 1.0).
  final double audioLevel;

  /// Current peak audio level (0.0 – 1.0).
  final double peakLevel;

  /// Whether the microphone is currently held by another app (or otherwise
  /// unavailable). Overrides the level-based assessment with a clear
  /// "mic lost" state (crossed-out mic, no bars) so the surveyor sees at a
  /// glance that audio isn't being captured right now.
  final bool micLost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Audio quality assessment:
    //   green  = good ambient signal (typical birdsong environment)
    //   amber  = marginal (very quiet or moderately loud)
    //   red    = bad (silence / no signal, or clipping / wind noise)
    //   red X  = mic lost (another app grabbed it)
    final semanticColors = AppSemanticColors.of(context);
    final _AudioQuality quality;
    if (micLost) {
      // Another app owns the mic — no capture is happening.
      quality = _AudioQuality.lost;
    } else if (audioLevel < 0.0005) {
      // Silence or mic not working.
      quality = _AudioQuality.bad;
    } else if (peakLevel > 0.95) {
      // Clipping — wind, handling noise, or mic overload.
      quality = _AudioQuality.bad;
    } else if (audioLevel > 0.15) {
      // Very loud sustained noise (wind, traffic).
      quality = _AudioQuality.bad;
    } else if (audioLevel < 0.001 || audioLevel > 0.08) {
      // Marginal: too quiet or somewhat loud.
      quality = _AudioQuality.marginal;
    } else {
      // Good range for birdsong detection (RMS ~0.001–0.08).
      quality = _AudioQuality.good;
    }

    final levelColor = switch (quality) {
      _AudioQuality.lost => theme.colorScheme.error,
      _AudioQuality.bad => theme.colorScheme.error,
      _AudioQuality.marginal => theme.colorScheme.tertiary,
      _AudioQuality.good => semanticColors.success,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AudioLevelChip(
            level: audioLevel,
            quality: quality,
            color: levelColor,
            style: style,
          ),
          StatChip(
            icon: AppIcons.straighten,
            value: _formatDistance(distanceMeters),
            style: style,
          ),
          StatChip(
            icon: AppIcons.detections,
            value: '$detectionCount',
            style: style,
          ),
          StatChip(
            icon: AppIcons.species,
            value: '$speciesCount',
            style: style,
          ),
        ],
      ),
    );
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}

/// Audio signal-strength bars (1–3 filled bars) colored by quality.
///
///   3 green bars = good ambient signal (typical birdsong environment)
///   2 amber bars = marginal (very quiet or moderately loud)
///   1 red bar    = bad (silence / no signal, or clipping / wind noise)
class _AudioLevelChip extends StatelessWidget {
  const _AudioLevelChip({
    required this.level,
    required this.quality,
    required this.color,
    this.style,
  });

  final double level;
  final _AudioQuality quality;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withAlpha(40);

    // Mic lost: crossed-out mic and no filled bars — an unmistakable "audio
    // is not being captured" indicator distinct from a merely quiet signal.
    if (quality == _AudioQuality.lost) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(AppIcons.micOff, size: 16, color: color),
          const SizedBox(width: 3),
          for (int i = 0; i < 3; i++)
            Container(
              width: 4,
              height: 6.0 + i * 4,
              margin: const EdgeInsets.only(right: 1.5),
              decoration: BoxDecoration(
                color: muted,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      );
    }

    final int filledBars;
    if (quality == _AudioQuality.good) {
      filledBars = 3;
    } else if (quality == _AudioQuality.marginal) {
      filledBars = 2;
    } else {
      filledBars = 1;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(AppIcons.mic, size: 16, color: color),
        const SizedBox(width: 3),
        for (int i = 0; i < 3; i++)
          Container(
            width: 4,
            height: 6.0 + i * 4, // 6, 10, 14
            margin: const EdgeInsets.only(right: 1.5),
            decoration: BoxDecoration(
              color: i < filledBars ? color : muted,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}
