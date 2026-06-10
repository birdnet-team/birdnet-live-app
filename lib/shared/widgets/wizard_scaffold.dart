// =============================================================================
// WizardScaffold — Shared chrome for multi-step setup wizards
// =============================================================================
//
// Reusable scaffold for the Point Count, Survey, and File Analysis setup
// wizards.  Provides:
//
//   • A standard `AppBar` with title and caller-supplied actions.
//   • A 4 dp segmented step indicator (active = primary, inactive =
//     `surfaceContainerHighest`) wrapped in a `Semantics` node announcing
//     "Step X of Y" for screen readers.
//   • A `ContentWidthConstraint` + `SafeArea` body region for the active
//     step's content.
//   • A footer row with a back `TextButton` and a primary `FilledButton`
//     (icon variant when [nextIcon] is provided).
//
// Callers retain ownership of the step content and any inter-step
// transition (`AnimatedSwitcher`, `PageView`, etc.); this widget only
// owns the wrapping chrome.
//
// `onBack` and `onNext` may be null to disable the corresponding button
// (e.g. while validation fails). Set [showFooter] to false to hide the
// nav row entirely (used by File Analysis during in-progress runs).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import 'content_width_constraint.dart';

/// Standard chrome for the app's setup wizards.
class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.title,
    required this.step,
    required this.totalSteps,
    required this.child,
    this.actions,
    this.leading,
    this.onBack,
    this.onNext,
    required this.backLabel,
    required this.nextLabel,
    this.nextIcon,
    this.showFooter = true,
  });

  /// AppBar title.
  final String title;

  /// AppBar trailing actions (help, settings, etc.).
  final List<Widget>? actions;

  /// Optional AppBar leading widget. When null, the platform default
  /// (back arrow when poppable) is used.
  final Widget? leading;

  /// Zero-based index of the currently visible step.
  final int step;

  /// Total number of steps in the wizard.
  final int totalSteps;

  /// Active step content. Receives the remaining vertical space.
  final Widget child;

  /// Tap handler for the back/cancel button. `null` disables it.
  final VoidCallback? onBack;

  /// Tap handler for the next/start button. `null` disables it.
  final VoidCallback? onNext;

  /// Localized label for the back/cancel button.
  final String backLabel;

  /// Localized label for the next/start button.
  final String nextLabel;

  /// Optional leading icon for the next button (e.g. `AppIcons.playArrow`
  /// on the final "Start" step).
  final IconData? nextIcon;

  /// When false, hides the entire footer row.
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(title), leading: leading, actions: actions),
      body: SafeArea(
        child: ContentWidthConstraint(
          child: Column(
            children: [
              _StepIndicator(
                step: step,
                totalSteps: totalSteps,
                semanticsLabel: l10n.wizardStepLabel(step + 1, totalSteps),
              ),
              Expanded(child: child),
              if (showFooter)
                _WizardFooter(
                  onBack: onBack,
                  onNext: onNext,
                  backLabel: backLabel,
                  nextLabel: nextLabel,
                  nextIcon: nextIcon,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.step,
    required this.totalSteps,
    required this.semanticsLabel,
  });

  final int step;
  final int totalSteps;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: List.generate(totalSteps, (i) {
            final isActive = i <= step;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < totalSteps - 1 ? 8 : 0),
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.onBack,
    required this.onNext,
    required this.backLabel,
    required this.nextLabel,
    required this.nextIcon,
  });

  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String backLabel;
  final String nextLabel;
  final IconData? nextIcon;

  void _haptic() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottomPadding),
      child: Row(
        children: [
          TextButton(
            onPressed:
                onBack == null
                    ? null
                    : () {
                      _haptic();
                      onBack!();
                    },
            child: Text(backLabel),
          ),
          const Spacer(),
          if (nextIcon != null)
            FilledButton.icon(
              onPressed:
                  onNext == null
                      ? null
                      : () {
                        _haptic();
                        onNext!();
                      },
              icon: Icon(nextIcon),
              label: Text(nextLabel),
            )
          else
            FilledButton(
              onPressed:
                  onNext == null
                      ? null
                      : () {
                        _haptic();
                        onNext!();
                      },
              child: Text(nextLabel),
            ),
        ],
      ),
    );
  }
}
