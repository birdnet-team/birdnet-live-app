// Tests for docs-site locale routing.
//
// The user guide is only translated for a subset of UI locales, but the
// Privacy Policy and Acceptable Use Policy are translated for every UI locale.
// These tests lock in that split so a future edit can't silently send, say, a
// Dutch user to the English privacy page.

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('docsLocalePrefix (user guide)', () {
    test('returns a prefix for locales with a translated guide', () {
      for (final loc in ['de', 'cs', 'es', 'fr', 'it', 'pt']) {
        expect(AppConstants.docsLocalePrefix(loc), '/$loc');
      }
    });

    test('falls back to English for locales without a translated guide', () {
      for (final loc in ['en', 'nl', 'pl', 'ru', 'zz']) {
        expect(AppConstants.docsLocalePrefix(loc), '');
      }
    });
  });

  group('policyDocsLocalePrefix (privacy / acceptable use)', () {
    test('returns a prefix for every locale with a translated policy', () {
      for (final loc in [
        'de',
        'cs',
        'es',
        'fr',
        'it',
        'pt',
        'nl',
        'pl',
        'ru',
      ]) {
        expect(AppConstants.policyDocsLocalePrefix(loc), '/$loc');
      }
    });

    test('falls back to English for English and unknown locales', () {
      for (final loc in ['en', 'zz']) {
        expect(AppConstants.policyDocsLocalePrefix(loc), '');
      }
    });

    test('covers a superset of the user-guide locales', () {
      expect(
        AppConstants.policyDocsLocales.containsAll(AppConstants.docsLocales),
        isTrue,
      );
    });
  });
}
