import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Provider for [SharedPreferences] instance.
///
/// Must be overridden in [ProviderScope] at app startup.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a real instance',
  ),
);

/// Provider for the current [ThemeMode].
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

/// Notifier for theme mode state backed by [SharedPreferences].
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_loadThemeMode(_prefs));

  final SharedPreferences _prefs;

  static ThemeMode _loadThemeMode(SharedPreferences prefs) {
    final value = prefs.getString(PrefKeys.themeMode);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark, // Default to dark for field use
    };
  }

  /// Update the theme mode and persist to preferences.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(PrefKeys.themeMode, mode.name);
  }
}

/// Provider for the current [Locale].
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocaleNotifier(prefs);
});

/// Notifier for locale state backed by [SharedPreferences].
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier(this._prefs) : super(_loadLocale(_prefs));

  final SharedPreferences _prefs;

  static Locale? _loadLocale(SharedPreferences prefs) {
    final code = prefs.getString(PrefKeys.locale);
    if (code == null) return null; // Follow system
    return Locale(code);
  }

  /// Set locale. Pass `null` to follow system.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await _prefs.remove(PrefKeys.locale);
    } else {
      await _prefs.setString(PrefKeys.locale, locale.languageCode);
    }
  }
}

/// Provider tracking whether onboarding has been completed.
final onboardingCompleteProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingNotifier(prefs);
});

/// Notifier for onboarding completion state.
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(this._prefs)
      : super(_prefs.getBool(PrefKeys.onboardingComplete) ?? false);

  final SharedPreferences _prefs;

  /// Mark onboarding as complete.
  Future<void> complete() async {
    state = true;
    await _prefs.setBool(PrefKeys.onboardingComplete, true);
  }

  /// Reset onboarding (for re-showing from settings).
  Future<void> reset() async {
    state = false;
    await _prefs.setBool(PrefKeys.onboardingComplete, false);
  }
}

/// Provider tracking whether terms have been accepted.
final termsAcceptedProvider = StateNotifierProvider<TermsNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TermsNotifier(prefs);
});

/// Notifier for terms acceptance state.
class TermsNotifier extends StateNotifier<bool> {
  TermsNotifier(this._prefs)
      : super(_prefs.getBool(PrefKeys.termsAccepted) ?? false);

  final SharedPreferences _prefs;

  /// Accept terms of use.
  Future<void> accept() async {
    state = true;
    await _prefs.setBool(PrefKeys.termsAccepted, true);
  }

  /// Revoke terms acceptance.
  Future<void> revoke() async {
    state = false;
    await _prefs.setBool(PrefKeys.termsAccepted, false);
  }
}
