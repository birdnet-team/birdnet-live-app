// =============================================================================
// Taxonomy Service Tests
// =============================================================================
//
// Verifies CSV parsing, species lookup, search, and URL generation.
// API enrichment tests are skipped (network-dependent).
// =============================================================================

import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal CSV matching the real taxonomy format.
const _testCsv =
    '''birdnet_id,scientific_name,common_name,common_name_alt,taxon_group,inat_id,ebird_code,observations_count,image_url,image_author,image_license,image_source,description_source,common_name_en,common_name_de
BN00498,Parus major,Great Tit,Eurasian Great Tit,Aves,204839,gretit1,50000,https://ex.com/pm.webp,John Doe,cc-by,iNaturalist,wikipedia,Great Tit,Kohlmeise
BN00499,Turdus merula,Eurasian Blackbird,,Aves,12716,eurbla,30000,,,,,,Eurasian Blackbird,Amsel
BN00500,Erithacus rubecula,European Robin,,Aves,13033,eurrob1,25000,,,,,,European Robin,Rotkehlchen''';

/// CSV with a quoted field containing a comma.
const _testCsvQuoted =
    '''birdnet_id,scientific_name,common_name,common_name_alt,taxon_group
BN001,"Strix aluco","Tawny Owl","Brown Owl, Eurasian Tawny Owl",Aves''';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // CSV Loading
  // ─────────────────────────────────────────────────────────────────────────

  group('TaxonomyService.loadFromCsv', () {
    test('parses species from CSV', () {
      final service = TaxonomyService();
      service.loadFromCsv(_testCsv);
      expect(service.isLoaded, isTrue);
      expect(service.speciesCount, 3);
    });

    test('species are queryable by scientific name', () {
      final service = TaxonomyService();
      service.loadFromCsv(_testCsv);

      final sp = service.lookup('Parus major');
      expect(sp, isNotNull);
      expect(sp!.commonName, 'Great Tit');
      expect(sp.ebirdCode, 'gretit1');
      expect(sp.inatId, 204839);
    });

    test('lookup returns null for unknown species', () {
      final service = TaxonomyService();
      service.loadFromCsv(_testCsv);
      expect(service.lookup('Nonexistent species'), isNull);
    });

    test('handles empty CSV', () {
      final service = TaxonomyService();
      service.loadFromCsv('');
      expect(service.isLoaded, isFalse);
      expect(service.speciesCount, 0);
    });

    test('handles header-only CSV', () {
      final service = TaxonomyService();
      service.loadFromCsv('birdnet_id,scientific_name,common_name');
      expect(service.isLoaded, isFalse);
      expect(service.speciesCount, 0);
    });

    test('handles quoted commas in fields', () {
      final service = TaxonomyService();
      service.loadFromCsv(_testCsvQuoted);
      expect(service.speciesCount, 1);

      final sp = service.lookup('Strix aluco');
      expect(sp, isNotNull);
      expect(sp!.commonName, 'Tawny Owl');
      expect(sp.commonNameAlt, 'Brown Owl, Eurasian Tawny Owl');
    });

    test('reloading clears previous data', () {
      final service = TaxonomyService();
      service.loadFromCsv(_testCsv);
      expect(service.speciesCount, 3);

      service.loadFromCsv(_testCsvQuoted);
      expect(service.speciesCount, 1);
      expect(service.lookup('Parus major'), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup
  // ─────────────────────────────────────────────────────────────────────────

  group('TaxonomyService.lookupAll', () {
    late TaxonomyService service;

    setUp(() {
      service = TaxonomyService();
      service.loadFromCsv(_testCsv);
    });

    test('returns matching species in order', () {
      final results = service.lookupAll([
        'Turdus merula',
        'Parus major',
      ]);
      expect(results.length, 2);
      expect(results[0].scientificName, 'Turdus merula');
      expect(results[1].scientificName, 'Parus major');
    });

    test('skips unknown species', () {
      final results = service.lookupAll([
        'Parus major',
        'Nonexistent',
        'Turdus merula',
      ]);
      expect(results.length, 2);
    });

    test('returns empty for all unknown', () {
      final results = service.lookupAll(['X', 'Y']);
      expect(results, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Search
  // ─────────────────────────────────────────────────────────────────────────

  group('TaxonomyService.search', () {
    late TaxonomyService service;

    setUp(() {
      service = TaxonomyService();
      service.loadFromCsv(_testCsv);
    });

    test('finds by common name substring', () {
      final results = service.search('Blackbird');
      expect(results.length, 1);
      expect(results[0].scientificName, 'Turdus merula');
    });

    test('finds by scientific name substring', () {
      final results = service.search('Erithacus');
      expect(results.length, 1);
      expect(results[0].commonName, 'European Robin');
    });

    test('search is case-insensitive', () {
      final results = service.search('great tit');
      expect(results.length, 1);
      expect(results[0].scientificName, 'Parus major');
    });

    test('empty query returns empty list', () {
      expect(service.search(''), isEmpty);
    });

    test('no match returns empty list', () {
      expect(service.search('Dinosaur'), isEmpty);
    });

    test('respects limit parameter', () {
      final results = service.search('a', limit: 2);
      expect(results.length, lessThanOrEqualTo(2));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Static URL builders
  // ─────────────────────────────────────────────────────────────────────────

  group('TaxonomyService URL builders', () {
    test('thumbUrl encodes scientific name', () {
      final url = TaxonomyService.thumbUrl('Parus major');
      expect(url, contains('Parus%20major'));
      expect(url, contains('size=thumb'));
      expect(url, startsWith('https://birdnet.cornell.edu/taxonomy/api/'));
    });

    test('mediumUrl encodes scientific name', () {
      final url = TaxonomyService.mediumUrl('Parus major');
      expect(url, contains('Parus%20major'));
      expect(url, contains('size=medium'));
    });

    test('URL encodes special characters', () {
      final url = TaxonomyService.thumbUrl("Corvus corone/cornix");
      expect(url, contains(Uri.encodeComponent("Corvus corone/cornix")));
    });
  });
}
