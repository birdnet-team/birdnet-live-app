import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/inference/species_ignore_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classes = <String, String>{
    'Bird one': 'Aves',
    'Mammal one': 'Mammalia',
    'Frog one': 'Amphibia',
    'Moth one': 'Insecta',
    'Fish one': 'Actinopterygii',
  };

  group('SpeciesIgnoreFilter.ignoredScientificNames', () {
    test('combines selected taxonomic groups with common geo species', () {
      const settings = SpeciesIgnoreSettings(
        ignoreBirds: true,
        ignoreInsects: true,
        commonGeoScoreCutoff: 0.99,
      );

      final ignored = SpeciesIgnoreFilter.ignoredScientificNames(
        classByScientificName: classes,
        settings: settings,
        geoScores: const {
          'Mammal one': 0.991,
          'Frog one': 0.989,
          'Fish one': 1.0,
        },
      );

      expect(ignored, {'Bird one', 'Moth one', 'Mammal one', 'Fish one'});
    });

    test('defaults to no taxon groups and a 100 percent cutoff', () {
      const settings = SpeciesIgnoreSettings();
      expect(settings.commonGeoScoreCutoff, 1.0);
      expect(settings.ignoresClass('Aves'), isFalse);

      final ignored = SpeciesIgnoreFilter.ignoredScientificNames(
        classByScientificName: classes,
        settings: settings,
        geoScores: const {'Bird one': 0.98, 'Fish one': 1.0},
      );
      expect(ignored, isEmpty);
    });

    test('does not ignore a geo score exactly equal to the cutoff', () {
      final ignored = SpeciesIgnoreFilter.ignoredScientificNames(
        classByScientificName: classes,
        settings: const SpeciesIgnoreSettings(commonGeoScoreCutoff: 0.9),
        geoScores: const {'Fish one': 0.9},
      );

      expect(ignored, isEmpty);
    });
  });

  test('sets ignored geo scores to zero without changing other scores', () {
    final original = {'Bird one': 0.8, 'Frog one': 0.4};
    final filtered = SpeciesIgnoreFilter.applyToGeoScores(original, {
      'Bird one',
    });

    expect(filtered, {'Bird one': 0.0, 'Frog one': 0.4});
    expect(original['Bird one'], 0.8);
  });

  test('sets ignored audio scores to zero before pooling', () {
    final labels = [
      const Species(
        index: 0,
        id: 1,
        scientificName: 'Bird one',
        commonName: 'Bird',
        className: 'Aves',
        order: 'Order',
      ),
      const Species(
        index: 1,
        id: 2,
        scientificName: 'Frog one',
        commonName: 'Frog',
        className: 'Amphibia',
        order: 'Order',
      ),
    ];
    final original = [0.92, 0.61];

    final filtered = SpeciesIgnoreFilter.applyToAudioScores(
      scores: original,
      labels: labels,
      ignoredScientificNames: {'Bird one'},
    );

    expect(filtered, [0.0, 0.61]);
    expect(original, [0.92, 0.61]);
  });
}
