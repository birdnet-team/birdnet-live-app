import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/app.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

void main() {
  group('resolveAppLocale', () {
    test('falls back to English for an unsupported device language', () {
      final resolved = resolveAppLocale(const [
        Locale('ca'),
      ], AppLocalizations.supportedLocales);

      expect(resolved, const Locale('en'));
    });

    test('uses a later preferred locale when it is supported', () {
      final resolved = resolveAppLocale(const [
        Locale('ca'),
        Locale('es'),
      ], AppLocalizations.supportedLocales);

      expect(resolved, const Locale('es'));
    });

    test('uses English when no preferred locales are available', () {
      final resolved = resolveAppLocale(
        null,
        AppLocalizations.supportedLocales,
      );

      expect(resolved, const Locale('en'));
    });
  });
}
