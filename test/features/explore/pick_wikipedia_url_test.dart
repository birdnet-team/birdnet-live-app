import 'package:birdnet_live/features/explore/widgets/pick_wikipedia_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickWikipediaUrl', () {
    test('returns localized URL when available', () {
      final url = pickWikipediaUrl(
        scientificName: 'Parus major',
        bundledUrls: const {
          'en': 'https://en.wikipedia.org/wiki/Great_tit',
          'de': 'https://de.wikipedia.org/wiki/Kohlmeise',
        },
        locale: 'de',
      );
      expect(url, 'https://de.wikipedia.org/wiki/Kohlmeise');
    });

    // `wikipedia_url_*` columns are keyed by bare language code, but the
    // effective species locale carries a region for Chinese and for the
    // regional picker entries.
    test('falls back to the language subtag for regional tags', () {
      const urls = {
        'en': 'https://en.wikipedia.org/wiki/Great_tit',
        'zh': 'https://zh.wikipedia.org/wiki/%E5%A4%A7%E5%B1%B1%E9%9B%80',
        'pt': 'https://pt.wikipedia.org/wiki/Chapim-real',
      };
      expect(
        pickWikipediaUrl(
          scientificName: 'Parus major',
          bundledUrls: urls,
          locale: 'zh-CN',
        ),
        urls['zh'],
      );
      expect(
        pickWikipediaUrl(
          scientificName: 'Parus major',
          bundledUrls: urls,
          locale: 'pt_PT',
        ),
        urls['pt'],
      );
    });

    test('prefers an exact regional match over the language subtag', () {
      final url = pickWikipediaUrl(
        scientificName: 'Parus major',
        bundledUrls: const {
          'en': 'https://en.wikipedia.org/wiki/Great_tit',
          'pt': 'https://pt.wikipedia.org/wiki/Chapim-real',
          'pt-BR': 'https://pt.wikipedia.org/wiki/Chapim-real-BR',
        },
        locale: 'pt-BR',
      );
      expect(url, 'https://pt.wikipedia.org/wiki/Chapim-real-BR');
    });

    test('falls back to English when locale missing', () {
      final url = pickWikipediaUrl(
        scientificName: 'Parus major',
        bundledUrls: const {'en': 'https://en.wikipedia.org/wiki/Great_tit'},
        locale: 'fr',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Great_tit');
    });

    test('falls back to English when localized entry is empty string', () {
      final url = pickWikipediaUrl(
        scientificName: 'Parus major',
        bundledUrls: const {
          'en': 'https://en.wikipedia.org/wiki/Great_tit',
          'de': '',
        },
        locale: 'de',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Great_tit');
    });

    test('constructs scientific-name URL when bundledUrls is null', () {
      final url = pickWikipediaUrl(
        scientificName: 'Parus major',
        bundledUrls: null,
        locale: 'en',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Parus_major');
    });

    test('constructs scientific-name URL when bundledUrls is empty', () {
      final url = pickWikipediaUrl(
        scientificName: 'Loxia curvirostra',
        bundledUrls: const {},
        locale: 'de',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Loxia_curvirostra');
    });

    test('constructs scientific-name URL when no usable bundled entries', () {
      final url = pickWikipediaUrl(
        scientificName: 'Loxia curvirostra',
        bundledUrls: const {'de': ''},
        locale: 'de',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Loxia_curvirostra');
    });

    test('URL-encodes scientific names with special characters', () {
      final url = pickWikipediaUrl(
        scientificName: "Pica pica",
        bundledUrls: null,
        locale: 'en',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Pica_pica');
    });

    test('trims surrounding whitespace from scientific name', () {
      final url = pickWikipediaUrl(
        scientificName: '  Parus major  ',
        bundledUrls: null,
        locale: 'en',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Parus_major');
    });
  });
}
