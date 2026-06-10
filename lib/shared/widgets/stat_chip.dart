// =============================================================================
// StatChip — shared stat display widget
// =============================================================================
//
// Replaces the trio of private `_StatChip`, `_StatBadge`, and `_StatCard`
// implementations that grew across the app. One widget, three variants:
//
//   • StatChipVariant.chip   — inline icon + label (default)
//   • StatChipVariant.badge  — inline icon + bold label, for session cards
//   • StatChipVariant.card   — boxed icon-over-value-over-label, for
//                              dashboards and analysis summaries
//
// Design rationale (see dev/STYLE_GUIDE.md → "Stat Displays"):
//   Picking a variant: chip for compact stat rows next to other inline
//   text, badge when the stat is the row (e.g. session library tile),
//   card when the stat deserves its own box on a summary screen.
// =============================================================================

import 'package:flutter/material.dart';

/// Visual variant of a [StatChip].
enum StatChipVariant {
  /// Inline icon + label using `bodyMedium` text and `onSurface` color.
  /// Use for compact stat rows next to other inline text.
  chip,

  /// Inline icon + bold label using `bodyMedium` text. Use when the stat
  /// is the row, e.g. on session library tiles.
  badge,

  /// Boxed `Card` with icon, large value, and small label stacked
  /// vertically. Use for summary dashboards (analysis results, surveys).
  card,
}

/// Single stat indicator (icon + value, optional label).
///
/// Examples:
/// ```dart
/// // Inline chip in a session-review header
/// StatChip(icon: AppIcons.timerOutlined, value: '2:34')
///
/// // Card in the analysis results dashboard
/// StatChip(
///   icon: AppIcons.barChart,
///   value: '142',
///   label: l10n.fileAnalysisDetections,
///   variant: StatChipVariant.card,
/// )
/// ```
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.variant = StatChipVariant.chip,
    this.style,
  });

  /// Leading icon. Sized 18 dp for inline variants and the default
  /// 24 dp inside the card variant.
  final IconData icon;

  /// The stat value (e.g. "12 km", "0:42", "150"). Use formatted text;
  /// this widget does not localize numbers.
  final String value;

  /// Optional descriptor shown beneath the value in the card variant.
  /// Ignored for inline variants.
  final String? label;

  /// Which visual variant to render.
  final StatChipVariant variant;

  /// Optional override for the value text style. When `null`, the variant
  /// picks a sensible default (`bodyMedium` inline, `headlineSmall` for
  /// the card variant). Useful when the surrounding row sets tabular
  /// figures or a custom color.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (variant) {
      case StatChipVariant.chip:
        return _inline(theme, bold: false);
      case StatChipVariant.badge:
        return _inline(theme, bold: true);
      case StatChipVariant.card:
        return _card(theme);
    }
  }

  Widget _inline(ThemeData theme, {required bool bold}) {
    final textStyle =
        style ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        );
    final iconSize = bold ? 16.0 : 18.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(value, style: textStyle),
      ],
    );
  }

  Widget _card(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            if (label != null)
              Text(
                label!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
