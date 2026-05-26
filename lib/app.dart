import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import 'core/theme/app_theme.dart';
import 'shared/providers/app_providers.dart';
import 'features/announcements/accessibility_default_applier.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'shared/widgets/app_launch_target_coordinator.dart';

/// Resolve the UI locale from the platform/app preference list.
///
/// Flutter's generated locale list is alphabetized, so relying on the default
/// fallback can land unsupported languages on Czech because `cs` is first.
/// Prefer an exact language match from the user's locale list, otherwise fall
/// back to English explicitly.
Locale resolveAppLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  final supported = supportedLocales.toList();
  for (final preferred in preferredLocales ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == preferred.languageCode) return candidate;
    }
  }

  return supported.firstWhere(
    (locale) => locale.languageCode == 'en',
    orElse: () => supported.first,
  );
}

/// Root application widget.
///
/// Configures theme, localization, and the initial route based on
/// whether onboarding and terms acceptance have been completed.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final useDynamicColor = ref.watch(dynamicColorProvider);
    final locale = ref.watch(localeProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Use the platform's dynamic palette when the user has opted in
        // and the OS provides one. Otherwise fall back to the brand theme.
        final ThemeData lightTheme;
        final ThemeData darkTheme;

        if (useDynamicColor && lightDynamic != null && darkDynamic != null) {
          lightTheme = AppTheme.fromColorScheme(lightDynamic.harmonized());
          darkTheme = AppTheme.fromColorScheme(darkDynamic.harmonized());
        } else {
          lightTheme = AppTheme.light();
          darkTheme = AppTheme.dark();
        }

        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,

          // Theme
          theme: lightTheme,
          darkTheme: darkTheme,
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
          localeListResolutionCallback: resolveAppLocale,
          localeResolutionCallback:
              (locale, supportedLocales) => resolveAppLocale(
                locale == null ? null : <Locale>[locale],
                supportedLocales,
              ),

          // Initial screen based on app state
          home: const AppLaunchTargetCoordinator(
            child: AnnouncementsAccessibilityDefaultApplier(child: _AppGate()),
          ),
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
