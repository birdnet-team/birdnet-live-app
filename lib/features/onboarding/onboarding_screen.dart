import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../../shared/providers/app_providers.dart';

/// Onboarding carousel shown on first launch.
///
/// Introduces the app, features, permissions, and quick settings.
/// Can be re-shown from Settings > Reset Onboarding.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return IntroductionScreen(
      globalBackgroundColor: theme.scaffoldBackgroundColor,
      pages: [
        // 1. Welcome
        PageViewModel(
          title: l10n.onboardingWelcomeTitle,
          body: l10n.onboardingWelcomeBody,
          image: _buildIcon(Icons.flutter_dash, theme),
          decoration: _pageDecoration(theme),
        ),
        // 2. Features
        PageViewModel(
          title: l10n.onboardingFeaturesTitle,
          body: l10n.onboardingFeaturesBody,
          image: _buildIcon(Icons.grid_view_rounded, theme),
          decoration: _pageDecoration(theme),
        ),
        // 3. Permissions
        PageViewModel(
          title: l10n.onboardingPermissionsTitle,
          body: l10n.onboardingPermissionsBody,
          image: _buildIcon(Icons.security, theme),
          decoration: _pageDecoration(theme),
        ),
        // 4. Ready
        PageViewModel(
          title: l10n.onboardingReadyTitle,
          body: l10n.onboardingReadyBody,
          image: _buildIcon(Icons.check_circle_outline, theme),
          decoration: _pageDecoration(theme),
        ),
      ],
      showSkipButton: true,
      skip: Text(l10n.skip),
      next: Text(l10n.next),
      done: Text(
        l10n.getStarted,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onDone: () {
        ref.read(onboardingCompleteProvider.notifier).complete();
      },
      onSkip: () {
        ref.read(onboardingCompleteProvider.notifier).complete();
      },
      dotsDecorator: DotsDecorator(
        size: const Size(10, 10),
        activeSize: const Size(22, 10),
        activeColor: theme.colorScheme.primary,
        color: theme.colorScheme.outline,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      controlsPadding: const EdgeInsets.all(16),
    );
  }

  Widget _buildIcon(IconData icon, ThemeData theme) {
    return Center(
      child: Icon(
        icon,
        size: 120,
        color: theme.colorScheme.primary,
      ),
    );
  }

  PageDecoration _pageDecoration(ThemeData theme) {
    return PageDecoration(
      titleTextStyle: theme.textTheme.headlineMedium!.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      bodyTextStyle: theme.textTheme.bodyLarge!.copyWith(
        color: theme.colorScheme.onSurface.withAlpha(200),
      ),
      bodyPadding: const EdgeInsets.symmetric(horizontal: 24),
      imagePadding: const EdgeInsets.only(top: 80),
    );
  }
}
