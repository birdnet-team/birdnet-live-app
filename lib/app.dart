import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'core/theme/app_theme.dart';
import 'shared/providers/app_providers.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/terms_gate_screen.dart';
import 'features/home/home_screen.dart';

/// Root application widget.
///
/// Configures theme, localization, and the initial route based on
/// whether onboarding and terms acceptance have been completed.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'BirdNET Live',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,

      // Localization
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,

      // Initial screen based on app state
      home: const _AppGate(),
    );
  }
}

/// Gate widget that routes to onboarding, terms, or home screen.
class _AppGate extends ConsumerWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingComplete = ref.watch(onboardingCompleteProvider);
    final termsAccepted = ref.watch(termsAcceptedProvider);

    if (!onboardingComplete) {
      return const OnboardingScreen();
    }

    if (!termsAccepted) {
      return const TermsGateScreen();
    }

    return const HomeScreen();
  }
}
