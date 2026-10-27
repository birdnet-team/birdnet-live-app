// =============================================================================
// Species Card — Compact species tile with thumbnail
// =============================================================================
//
// Displays a species entry with:
//   • Bundled asset thumbnail (3:2 aspect ratio, 480x320 WebP)
//   • Common name + optional scientific name (controlled by setting)
//   • Optional geo-score indicator
//   • Center-aligned 48-week mini bar chart with month labels
//
// Used in both the Explore screen and the live detection list.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/score_colors.dart';
import '../../../shared/utils/app_icons.dart';
import '../../inference/geo_model.dart';
import '../explore_providers.dart';
import '../explore_tier.dart';

/// A compact species card with a 3:2 thumbnail.
class SpeciesCard extends StatelessWidget {
  const SpeciesCard({
    super.key,
    required this.scientificName,
    required this.commonName,
    required this.showScientificName,
    required this.detected,
    this.assetImagePath,
    this.geoScore,
    this.confidence,
    this.tier,
    this.weeklyScores,
    this.onTap,
  });

  /// Scientific name — used to generate the thumbnail URL.
  final String scientificName;

  /// Common name to display.
  final String commonName;

  /// Whether to display the scientific name under the common name.
  final bool showScientificName;

  /// Whether this species has already appeared in the user's saved sessions.
  final bool detected;

  /// Bundled thumbnail asset path, if known by the parent list.
  final String? assetImagePath;

  /// Optional geo-model score (0–100) shown as a subtle indicator.
  final double? geoScore;

  /// Optional audio confidence (0–1) shown when used in detections.
  final double? confidence;

  /// Optional distribution-adaptive abundance tier. When provided, the compact
  /// tier chip (fill circle + letter) is shown instead of a percentage.
  final ExploreTier? tier;

  /// Optional 48-week probability array for drawing a mini chart.
  final List<double>? weeklyScores;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final highContrast = AppTheme.isHighContrastTheme(theme);
    final cardHeight = weeklyScores == null
        ? (showScientificName ? 78.0 : 68.0)
        : (showScientificName ? 96.0 : 88.0);

    return Material(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withAlpha(120)
          : theme.colorScheme.surfaceContainerHighest.withAlpha(180),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: cardHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _SpeciesImage(assetImagePath: assetImagePath),
                    if (detected)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: _DetectedBadge(),
                      ),
                  ],
                ),
              ),
              // ── Names and Details ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
                          if (tier != null) ...[
                            const SizedBox(width: 8),
                            ExploreTierChip(tier: tier!),
                          ] else if (confidence != null ||
                              geoScore != null) ...[
                            const SizedBox(width: 8),
                            Semantics(
                              label: confidence != null
                                  ? AppLocalizations.of(context)!
                                        .a11yConfidencePercent(
                                          (confidence! * 100).round(),
                                        )
                                  : AppLocalizations.of(
                                      context,
                                    )!.a11yLikelihoodPercent(geoScore!.round()),
                              excludeSemantics: true,
                              child: Builder(
                                builder: (context) {
                                  final pillScore =
                                      geoScore ??
                                      (confidence != null
                                          ? confidence! * 100
                                          : 0);
                                  final pillColor = probabilityCategoryColor(
                                    context,
                                    pillScore.toDouble(),
                                  );
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: pillColor.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: pillColor.withAlpha(120),
                                      ),
                                    ),
                                    child: Text(
                                      confidence != null
                                          ? '${(confidence! * 100).toStringAsFixed(0)}%'
                                          : '${geoScore!.toStringAsFixed(0)}%',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontSize: 10,
                                            color: pillColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Row 2: Scientific name (optional)
                      if (showScientificName)
                        Text(
                          scientificName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: highContrast
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withAlpha(150),
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
      ),
    );
  }
}

/// Compact abundance-tier chip: a fill circle (1/6 ... 6/6) plus the tier's first
/// letter, tinted by the tier's color from the shared [ScoreColors] ramp. The
/// full localized tier name is exposed only to screen readers, not on screen.
///
/// Set [showFullLabel] to render the full localized tier name next to the
/// circle instead of the single letter - used by the Explore help legend.
class ExploreTierChip extends StatelessWidget {
  const ExploreTierChip({
    super.key,
    required this.tier,
    this.showFullLabel = false,
  });

  final ExploreTier tier;
  final bool showFullLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final color = exploreTierColor(ScoreColors.of(context), tier);
    final label = exploreTierLabel(l10n, tier);
    final letter = exploreTierLetter(l10n, tier);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(11, 11),
            painter: _TierFillPainter(
              fraction: tier.fillFraction,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            showFullLabel ? label : letter,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    // The legend already shows the full label, so no tooltip/semantics dupe.
    if (showFullLabel) return chip;

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Tooltip(message: label, child: chip),
    );
  }
}

/// Paints a circular gauge: a faint full-circle track with a [fraction]-filled
/// pie wedge sweeping clockwise from the top, encoding the abundance tier
/// ordinally so it reads without relying on color.
class _TierFillPainter extends CustomPainter {
  const _TierFillPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  static const double _pi = 3.141592653589793;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final track = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withAlpha(38);
    canvas.drawCircle(center, radius, track);

    if (fraction > 0) {
      final wedge = Paint()
        ..style = PaintingStyle.fill
        ..color = color;
      if (fraction >= 1.0) {
        // A full 360 degree arc is degenerate (start and end coincide) and would
        // paint nothing, so draw a solid disc for the top tier.
        canvas.drawCircle(center, radius, wedge);
      } else {
        final rect = Rect.fromCircle(center: center, radius: radius);
        const startAngle = -_pi / 2; // top
        final sweep = fraction.clamp(0.0, 1.0).toDouble() * 2 * _pi;
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..arcTo(rect, startAngle, sweep, false)
          ..close();
        canvas.drawPath(path, wedge);
      }
    }

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color;
    canvas.drawCircle(center, radius - 0.5, outline);
  }

  @override
  bool shouldRepaint(_TierFillPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

/// Species thumbnail loaded from bundled assets.
class _SpeciesImage extends StatelessWidget {
  const _SpeciesImage({required this.assetImagePath});

  final String? assetImagePath;

  @override
  Widget build(BuildContext context) {
    final path = assetImagePath ?? 'assets/images/dummy_species.png';

    return Image.asset(
      path,
      fit: BoxFit.cover,
      cacheWidth: 360,
      cacheHeight: 240,
      filterQuality: FilterQuality.low,
      errorBuilder: (a, b, c) => Image.asset(
        'assets/images/dummy_species.png',
        fit: BoxFit.cover,
        cacheWidth: 360,
        cacheHeight: 240,
        filterQuality: FilterQuality.low,
      ),
    );
  }
}

/// Center-aligned 48-week bar chart with month labels.
///
/// Bars are normalized to 100 (= the #1 species peak) so that the chart
/// scale is consistent across all species cards.  A minimum bar height
/// ensures small values remain visible.
class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.weeklyScores});

  final List<double> weeklyScores;

  static const double _chartHeight = 24.0;
  static const double _minBarHeight = 2.0;

  @override
  Widget build(BuildContext context) {
    if (weeklyScores.every((p) => p == 0)) return const SizedBox();

    final theme = Theme.of(context);
    final highContrast = AppTheme.isHighContrastTheme(theme);
    final l10n = AppLocalizations.of(context)!;
    final currentWeekIndex = GeoModel.dateTimeToWeek(DateTime.now()) - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _chartHeight,
          width: double.infinity,
          child: CustomPaint(
            size: const Size.fromHeight(_chartHeight),
            painter: _MiniChartBarsPainter(
              weeklyScores: weeklyScores,
              currentWeekIndex: currentWeekIndex,
              highContrast: highContrast,
              baseColor: theme.colorScheme.primary,
              activeColor: highContrast
                  ? theme.colorScheme.surface
                  : theme.colorScheme.tertiary,
              borderColor: theme.colorScheme.onSurface,
            ),
          ),
        ),
        // ── Month labels ──
        SizedBox(
          height: 10,
          child: Row(
            children: _monthLabels(l10n).map((label) {
              return Expanded(
                flex: 4,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 7,
                    height: 1.0,
                    color: highContrast
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static List<String> _monthLabels(AppLocalizations l10n) => [
    l10n.monthJ,
    l10n.monthF,
    l10n.monthM,
    l10n.monthA,
    l10n.monthMay,
    l10n.monthJun,
    l10n.monthJul,
    l10n.monthAug,
    l10n.monthS,
    l10n.monthO,
    l10n.monthN,
    l10n.monthD,
  ];
}

class _MiniChartBarsPainter extends CustomPainter {
  const _MiniChartBarsPainter({
    required this.weeklyScores,
    required this.currentWeekIndex,
    required this.highContrast,
    required this.baseColor,
    required this.activeColor,
    required this.borderColor,
  });

  final List<double> weeklyScores;
  final int currentWeekIndex;
  final bool highContrast;
  final Color baseColor;
  final Color activeColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final weekWidth = size.width / weeklyScores.length;
    final barWidth = (weekWidth * 0.65).clamp(1.0, weekWidth);
    final radius = Radius.circular(barWidth < 2 ? 0.5 : 1.0);
    final fillPaint = Paint();
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = borderColor;

    for (var index = 0; index < weeklyScores.length; index++) {
      final score = weeklyScores[index];
      final isCurrentWeek = index == currentWeekIndex;
      if (score <= 0 && !isCurrentWeek) continue;

      final normalized = (score / 100.0).clamp(0.0, 1.0);
      final barHeight = (normalized * _MiniChart._chartHeight).clamp(
        _MiniChart._minBarHeight,
        size.height,
      );
      final left = index * weekWidth + (weekWidth - barWidth) / 2;
      final top = (size.height - barHeight) / 2;
      final rect = Rect.fromLTWH(left, top, barWidth, barHeight);
      final rrect = RRect.fromRectAndRadius(rect, radius);

      fillPaint.color = isCurrentWeek
          ? activeColor
          : highContrast
          ? baseColor
          : baseColor.withAlpha(
              (50 + (normalized * 150)).toInt().clamp(0, 255),
            );
      canvas.drawRRect(rrect, fillPaint);
      if (isCurrentWeek) canvas.drawRRect(rrect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniChartBarsPainter oldDelegate) {
    return weeklyScores != oldDelegate.weeklyScores ||
        currentWeekIndex != oldDelegate.currentWeekIndex ||
        highContrast != oldDelegate.highContrast ||
        baseColor != oldDelegate.baseColor ||
        activeColor != oldDelegate.activeColor ||
        borderColor != oldDelegate.borderColor;
  }
}

/// Small overlay badge that flags a species as previously detected by the
/// user. Rendered in the corner of the species thumbnail in the Explore
/// screen and the species info overlay so users can spot at a glance which
/// species they have already added to their personal life list.
class _DetectedBadge extends StatelessWidget {
  const _DetectedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = AppTheme.isHighContrastTheme(theme);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        // Solid background so the icon stays legible over both bright and
        // dark areas of the bird photo. Brand blue marks it as an "earned"
        // badge; high-contrast themes use black with a white check for maximum
        // separation.
        color: highContrast ? Colors.black : theme.colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(60),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        AppIcons.check,
        size: 12,
        color: highContrast ? Colors.white : theme.colorScheme.onPrimary,
      ),
    );
  }
}
