// =============================================================================
// Taxonomy Species Tests
// =============================================================================
//
// Verifies the TaxonomySpecies model: factory constructors (CSV + API JSON),
// convenience getters (URLs, descriptions, common names), and equality.
// =============================================================================

import 'package:birdnet_live/shared/models/taxonomy_species.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Factory: fromCsvRow
  // ─────────────────────────────────────────────────────────────────────────

  group('TaxonomySpecies.fromCsvRow', () {
    test('parses all CSV fields', () {
      final sp = TaxonomySpecies.fromCsvRow({
        'scientific_name': 'Parus major',
        'common_name': 'Great Tit',
        'common_name_alt': 'Eurasian Great Tit',
        'taxon_group': 'Aves',
        'birdnet_id': 'BN00498',
        'ebird_code': 'gretit1',
        'inat_id': '12345',
        'observations_count': '10000',
        'image_url': 'https://example.com/img.webp',
        'image_author': 'John Doe',
        'image_license': 'cc-by-nc',
        'image_source': 'iNaturalist',
        'description_source': 'wikipedia',
      });

      expect(sp.scientificName, 'Parus major');
      expect(sp.commonName, 'Great Tit');
      expect(sp.commonNameAlt, 'Eurasian Great Tit');
      expect(sp.taxonGroup, 'Aves');
      expect(sp.birdnetId, 'BN00498');
      expect(sp.ebirdCode, 'gretit1');
      expect(sp.inatId, 12345);
      expect(sp.observationsCount, 10000);
      expect(sp.imageUrl, 'https://example.com/img.webp');
      expect(sp.imageAuthor, 'John Doe');
      expect(sp.imageLicense, 'cc-by-nc');
      expect(sp.imageSource, 'iNaturalist');
      expect(sp.descriptionSource, 'wikipedia');
    });

    test('handles minimal fields', () {
      final sp = TaxonomySpecies.fromCsvRow({
        'scientific_name': 'Turdus merula',
        'common_name': 'Eurasian Blackbird',
      });

      expect(sp.scientificName, 'Turdus merula');
      expect(sp.commonName, 'Eurasian Blackbird');
      expect(sp.ebirdCode, isNull);
      expect(sp.inatId, isNull);
      expect(sp.birdnetId, isNull);
    });

    test('treats empty strings as null for optional fields', () {
      final sp = TaxonomySpecies.fromCsvRow({
        'scientific_name': 'Turdus merula',
        'common_name': 'Eurasian Blackbird',
        'ebird_code': '',
        'inat_id': '',
        'common_name_alt': '  ',
      });

      expect(sp.ebirdCode, isNull);
      expect(sp.inatId, isNull);
      expect(sp.commonNameAlt, isNull);
    });

    test('handles missing scientific_name gracefully', () {
      final sp = TaxonomySpecies.fromCsvRow({
        'common_name': 'Unknown',
      });
      expect(sp.scientificName, '');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Factory: fromApiJson
  // ─────────────────────────────────────────────────────────────────────────

  group('TaxonomySpecies.fromApiJson', () {
    test('parses full API response', () {
      final sp = TaxonomySpecies.fromApiJson({
        'scientific_name': 'Parus major',
        'common_name': 'Great Tit',
        'common_name_alt': 'Eurasian Great Tit',
        'taxon_group': 'Aves',
        'birdnet_id': 'BN00498',
        'ebird_code': 'gretit1',
        'inat_id': 12345,
        'observations_count': 10000,
        'description_source': 'wikipedia',
        'image': {
          'medium': 'https://api.example.com/img/medium.webp',
          'author': 'Jane Smith',
          'license': 'cc-by',
          'source': 'Macaulay Library',
        },
        'descriptions': {'en': 'A small bird.', 'de': 'Ein kleiner Vogel.'},
        'common_names': {'en': 'Great Tit', 'de': 'Kohlmeise'},
        'wikipedia_urls': {
          'en': 'https://en.wikipedia.org/wiki/Great_tit',
          'de': 'https://de.wikipedia.org/wiki/Kohlmeise',
        },
      });

      expect(sp.scientificName, 'Parus major');
      expect(sp.commonName, 'Great Tit');
      expect(sp.imageUrl, 'https://api.example.com/img/medium.webp');
      expect(sp.imageAuthor, 'Jane Smith');
      expect(sp.descriptions!['en'], 'A small bird.');
      expect(sp.commonNames!['de'], 'Kohlmeise');
      expect(
          sp.wikipediaUrls!['en'], 'https://en.wikipedia.org/wiki/Great_tit');
    });

    test('handles missing image block', () {
      final sp = TaxonomySpecies.fromApiJson({
        'scientific_name': 'Parus major',
        'common_name': 'Great Tit',
      });

      expect(sp.imageUrl, isNull);
      expect(sp.imageAuthor, isNull);
    });

    test('handles missing descriptions and common_names', () {
      final sp = TaxonomySpecies.fromApiJson({
        'scientific_name': 'Parus major',
        'common_name': 'Great Tit',
      });

      expect(sp.descriptions, isNull);
      expect(sp.commonNames, isNull);
      expect(sp.wikipediaUrls, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // URL getters
  // ─────────────────────────────────────────────────────────────────────────

  group('URL getters', () {
    test('thumbUrl encodes scientific name', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
      );
      expect(sp.thumbUrl, contains('Parus%20major'));
      expect(sp.thumbUrl, contains('size=thumb'));
    });

    test('mediumUrl uses imageUrl when available', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        imageUrl: 'https://custom.example.com/img.webp',
      );
      expect(sp.mediumUrl, 'https://custom.example.com/img.webp');
    });

    test('mediumUrl falls back to API URL when imageUrl is null', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
      );
      expect(sp.mediumUrl, contains('Parus%20major'));
      expect(sp.mediumUrl, contains('size=medium'));
    });

    test('ebirdUrl is null when no ebird code', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
      );
      expect(sp.ebirdUrl, isNull);
    });

    test('ebirdUrl generated from ebird code', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        ebirdCode: 'gretit1',
      );
      expect(sp.ebirdUrl, 'https://ebird.org/species/gretit1');
    });

    test('inatUrl is null when no iNat ID', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
      );
      expect(sp.inatUrl, isNull);
    });

    test('inatUrl generated from iNat ID', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        inatId: 12345,
      );
      expect(sp.inatUrl, 'https://www.inaturalist.org/taxa/12345');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Description & locale helpers
  // ─────────────────────────────────────────────────────────────────────────

  group('Description helpers', () {
    test('descriptionEn returns English description', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        descriptions: {'en': 'English desc', 'de': 'German desc'},
      );
      expect(sp.descriptionEn, 'English desc');
    });

    test('descriptionEn falls back to first available', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        descriptions: {'de': 'German desc'},
      );
      expect(sp.descriptionEn, 'German desc');
    });

    test('descriptionEn returns null when no descriptions', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
      );
      expect(sp.descriptionEn, isNull);
    });

    test('descriptionForLocale returns requested locale', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        descriptions: {'en': 'English', 'de': 'Deutsch'},
      );
      expect(sp.descriptionForLocale('de'), 'Deutsch');
    });

    test('descriptionForLocale falls back to English', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        descriptions: {'en': 'English'},
      );
      expect(sp.descriptionForLocale('fr'), 'English');
    });

    test('commonNameForLocale returns localized name', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        commonNames: {'de': 'Kohlmeise'},
      );
      expect(sp.commonNameForLocale('de'), 'Kohlmeise');
    });

    test('commonNameForLocale falls back to default common name', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        commonNames: {'de': 'Kohlmeise'},
      );
      expect(sp.commonNameForLocale('fr'), 'Great Tit');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Equality & toString
  // ─────────────────────────────────────────────────────────────────────────

  group('Equality', () {
    test('species with same scientific name are equal', () {
      const a = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
      );
      const b = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Different Name',
        ebirdCode: 'xyz',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('species with different scientific names are not equal', () {
      const a = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
      );
      const b = TaxonomySpecies(
        scientificName: 'Turdus merula',
        commonName: 'Great Tit',
      );
      expect(a, isNot(equals(b)));
    });

    test('toString contains species info', () {
      const sp = TaxonomySpecies(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
      );
      expect(sp.toString(), contains('Parus major'));
      expect(sp.toString(), contains('Great Tit'));
    });
  });
}
