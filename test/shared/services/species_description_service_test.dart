import 'package:birdnet_live/shared/services/species_description_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeciesDescriptionService.resolveBundleLocale', () {
    test('passes through locales that have a bundled file', () {
      for (final loc in SpeciesDescriptionService.availableLocales) {
        expect(SpeciesDescriptionService.resolveBundleLocale(loc), loc);
      }
    });

    // The species locale tag is the only place a region survives, and Chinese
    // is the one language that always gets one. Without the subtag fallback
    // `descriptions_zh.json.gz` is never opened and Chinese users silently
    // read English descriptions.
    test('falls back to the language subtag for regional tags', () {
      expect(SpeciesDescriptionService.resolveBundleLocale('zh-CN'), 'zh');
      expect(SpeciesDescriptionService.resolveBundleLocale('zh_CN'), 'zh');
      expect(SpeciesDescriptionService.resolveBundleLocale('zh-Hans'), 'zh');
      expect(SpeciesDescriptionService.resolveBundleLocale('es_ES'), 'es');
      expect(SpeciesDescriptionService.resolveBundleLocale('es_MX'), 'es');
      expect(SpeciesDescriptionService.resolveBundleLocale('pt_PT'), 'pt');
    });

    test('falls back to English for unbundled locales', () {
      for (final loc in ['ja', 'ko', 'sv', 'tr', 'uk', 'zz-ZZ', '']) {
        expect(SpeciesDescriptionService.resolveBundleLocale(loc), 'en');
      }
    });

    test('tolerates surrounding whitespace', () {
      expect(SpeciesDescriptionService.resolveBundleLocale('  zh-CN  '), 'zh');
    });
  });
}
