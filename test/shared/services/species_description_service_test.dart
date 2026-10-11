import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/shared/services/species_description_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseSpeciesDescriptions', () {
    test('inflates and parses a bundled description file', () {
      final json = jsonEncode({
        'Parus major': 'The great tit is a passerine bird.',
        'Turdus merula': 'The common blackbird.',
      });
      final gz = Uint8List.fromList(gzip.encode(utf8.encode(json)));
      expect(parseSpeciesDescriptions(gz), {
        'Parus major': 'The great tit is a passerine bird.',
        'Turdus merula': 'The common blackbird.',
      });
    });

    test('rejects a value that is not a string', () {
      final json = jsonEncode({'Parus major': 42});
      final gz = Uint8List.fromList(gzip.encode(utf8.encode(json)));
      expect(() => parseSpeciesDescriptions(gz), throwsA(isA<TypeError>()));
    });
  });

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

  group('SpeciesDescriptionService.getDescription', () {
    final loads = <String>[];

    setUp(() {
      loads.clear();
      final json = jsonEncode({'Parus major': 'Kohlmeise'});
      final gz = Uint8List.fromList(gzip.encode(utf8.encode(json)));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
            loads.add(utf8.decode(message!.buffer.asUint8List()));
            return ByteData.sublistView(gz);
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    // A species grid builds many cards at once, and each asks for the same
    // unloaded locale before the first parse has landed.
    test('concurrent requests for one locale share a single load', () async {
      final service = SpeciesDescriptionService();
      final results = await Future.wait([
        service.getDescription('Parus major', 'de'),
        service.getDescription('Parus major', 'de'),
        service.getDescription('Parus major', 'de-AT'),
      ]);

      expect(results, everyElement('Kohlmeise'));
      expect(loads.where((k) => k.contains('descriptions_de')).length, 1);
      expect(loads.where((k) => k.contains('descriptions_en')).length, 1);
    });
  });
}
