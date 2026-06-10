// =============================================================================
// LoadingView — shared centered loading placeholder
// =============================================================================
//
// Use anywhere a screen or panel needs to show "work in progress" while
// content is fetched, decoded, or generated. Replaces bare
// `CircularProgressIndicator()` calls and ad-hoc loading layouts.
//
// Design rationale (see dev/STYLE_GUIDE.md → "Loading States"):
//   • A loading state should always have a visible placement and a label.
//   • Stroke width 2.5 for default, 2.0 for inline contexts.
//   • Label is required unless the spinner is < 24 dp inline. Pass `null`
//     only when there is genuinely no useful copy.
//
// For determinate progress (e.g. analysis pipelines) prefer a
// `LinearProgressIndicator` paired with a current/total label instead of
// this widget.
// =============================================================================

import 'package:flutter/material.dart';

/// Centered loading placeholder with an optional descriptive label.
///
/// Example:
/// ```dart
/// LoadingView(label: l10n.loadingSpecies)
/// ```
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label, this.compact = false, this.color});

  /// Localized label shown beneath the spinner. Pass `null` to render only
  /// the spinner — only do that when the spinner appears inline next to
  /// other widgets that already provide context.
  final String? label;

  /// When `true`, uses a smaller spinner suitable for inline placement
  /// (e.g. in a list row or a status bar).
  final bool compact;

  /// Optional override for the spinner color. Defaults to
  /// `colorScheme.primary`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spinnerColor = color ?? theme.colorScheme.primary;
    final spinnerSize = compact ? 20.0 : 32.0;
    final stroke = compact ? 2.0 : 2.5;

    final spinner = SizedBox(
      width: spinnerSize,
      height: spinnerSize,
      child: CircularProgressIndicator(
        strokeWidth: stroke,
        valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
      ),
    );

    if (label == null) {
      return Center(child: spinner);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            spinner,
            const SizedBox(height: 12),
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
