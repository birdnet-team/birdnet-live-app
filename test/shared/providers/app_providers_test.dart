import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:birdnet_live/shared/providers/app_providers.dart';

void main() {
  group('ThemeModeNotifier', () {
    test('defaults to dark theme', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeModeNotifier(prefs);

      expect(notifier.state, ThemeMode.dark);
    });

    test('persists theme mode', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeModeNotifier(prefs);

      await notifier.setThemeMode(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);
      expect(prefs.getString('theme_mode'), 'light');
    });

    test('loads persisted theme mode', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeModeNotifier(prefs);

      expect(notifier.state, ThemeMode.light);
    });
  });

  group('LocaleNotifier', () {
    test('defaults to null (system)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = LocaleNotifier(prefs);

      expect(notifier.state, isNull);
    });

    test('persists locale', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = LocaleNotifier(prefs);

      await notifier.setLocale(const Locale('de'));
      expect(notifier.state, const Locale('de'));
      expect(prefs.getString('locale'), 'de');
    });

    test('clears locale when set to null', () async {
      SharedPreferences.setMockInitialValues({'locale': 'de'});
      final prefs = await SharedPreferences.getInstance();
      final notifier = LocaleNotifier(prefs);

      await notifier.setLocale(null);
      expect(notifier.state, isNull);
      expect(prefs.getString('locale'), isNull);
    });
  });

  group('OnboardingNotifier', () {
    test('defaults to false', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = OnboardingNotifier(prefs);

      expect(notifier.state, false);
    });

    test('marks complete', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = OnboardingNotifier(prefs);

      await notifier.complete();
      expect(notifier.state, true);
      expect(prefs.getBool('onboarding_complete'), true);
    });

    test('resets onboarding', () async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
      final prefs = await SharedPreferences.getInstance();
      final notifier = OnboardingNotifier(prefs);

      await notifier.reset();
      expect(notifier.state, false);
    });
  });

  group('TermsNotifier', () {
    test('defaults to false', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = TermsNotifier(prefs);

      expect(notifier.state, false);
    });

    test('accepts terms', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = TermsNotifier(prefs);

      await notifier.accept();
      expect(notifier.state, true);
      expect(prefs.getBool('terms_accepted'), true);
    });

    test('revokes terms', () async {
      SharedPreferences.setMockInitialValues({'terms_accepted': true});
      final prefs = await SharedPreferences.getInstance();
      final notifier = TermsNotifier(prefs);

      await notifier.revoke();
      expect(notifier.state, false);
    });
  });

  group('Providers', () {
    test('sharedPreferencesProvider throws when not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(sharedPreferencesProvider),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('providers work with overridden SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(container.read(localeProvider), isNull);
      expect(container.read(onboardingCompleteProvider), false);
      expect(container.read(termsAcceptedProvider), false);
    });
  });
}
