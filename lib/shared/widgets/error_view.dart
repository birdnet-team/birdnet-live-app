// =============================================================================
// ErrorView — shared centered error placeholder
// =============================================================================
//
// Use when a screen-level operation fails (model load, network fetch,
// session save) and we want to give the user a clear path to retry.
//
// Design rationale (see dev/STYLE_GUIDE.md → "Error States"):
//   • Icon `AppIcons.errorOutline` at 64 dp in `colorScheme.error`.
//   • Title `bodyLarge`, message `bodySmall`.
//   • Retry uses `FilledButton.tonal` so it doesn't look like a primary
//     destination but still reads as actionable.
//   • For inline (non-fullscreen) errors, prefer a small banner directly
//     in context instead of this widget.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';

/// Centered error placeholder with an optional retry action.
///
/// Example:
/// ```dart
/// ErrorView(
///   title: l10n.modelLoadFailed,
///   message: l10n.modelLoadFailedHint,
///   onRetry: controller.retryLoad,
///   retryLabel: l10n.retry,
/// )
/// ```
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = AppIcons.errorOutline,
  });

  /// Primary line describing what failed.
  final String title;

  /// Optional secondary line with detail or a recovery hint.
  final String? message;

  /// Optional retry callback. When `null`, no retry button is shown.
  final VoidCallback? onRetry;

  /// Localized label for the retry button. Required when [onRetry] is set.
  final String? retryLabel;

  /// Icon to display. Defaults to `AppIcons.errorOutline`.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRetry = onRetry != null && retryLabel != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (hasRetry) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
