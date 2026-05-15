import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'core/theme/app_theme.dart';
import 'shared/providers/app_providers.dart';
import 'features/onboarding/onboarding_screen.dart';
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
    final useDynamicColors = ref.watch(dynamicColorsProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = useDynamicColors ? lightDynamic : null;
        final darkScheme = useDynamicColors ? darkDynamic : null;

        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,

          // Theme
          theme: AppTheme.light(colorScheme: lightScheme),
          darkTheme: AppTheme.dark(colorScheme: darkScheme),
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
      },
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

    // The onboarding flow now also captures Terms of Use acceptance, so a
    // completed onboarding implies accepted terms. We still gate on both
    // independently so a future settings reset of either flag re-shows the
    // onboarding flow (rather than navigating to a separate terms screen).
    if (!onboardingComplete || !termsAccepted) {
      return const OnboardingScreen();
    }

    return const HomeScreen();
  }
}
