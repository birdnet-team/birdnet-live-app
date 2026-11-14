import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/inference/species_ignore_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classes = <String, String>{
    'Bird one': 'Aves',
    'Mammal one': 'Mammalia',
    'Frog one': 'Amphibia',
    'Moth one': 'Insecta',
    'Siren': 'Anthropogenic',
  };

  group('SpeciesIgnoreFilter.ignoredScientificNames', () {
    test('combines selected taxonomic groups with common geo species', () {
      const settings = SpeciesIgnoreSettings(
        ignoreBirds: true,
        ignoreInsects: true,
        includeSoundClasses: true,
        commonGeoScoreCutoff: 0.99,
      );

      final ignored = SpeciesIgnoreFilter.ignoredScientificNames(
        classByScientificName: classes,
        settings: settings,
        geoScores: const {'Mammal one': 0.991, 'Frog one': 0.989},
      );

      expect(ignored, {'Bird one', 'Moth one', 'Mammal one'});
    });

    test('defaults to no taxon groups and a 100 percent cutoff', () {
      const settings = SpeciesIgnoreSettings();
      expect(settings.commonGeoScoreCutoff, 1.0);
      expect(settings.ignoresClass('Aves'), isFalse);

      final ignored = SpeciesIgnoreFilter.ignoredScientificNames(
        classByScientificName: classes,
        settings: settings,
        geoScores: const {'Bird one': 0.98, 'Frog one': 1.0},
      );
      // No animal is ignored by default.
      expect(ignored, {'Siren'});
    });

    test('does not ignore a geo score exactly equal to the cutoff', () {
      final ignored = SpeciesIgnoreFilter.ignoredScientificNames(
        classByScientificName: classes,
        settings: const SpeciesIgnoreSettings(
          includeSoundClasses: true,
          commonGeoScoreCutoff: 0.9,
        ),
        geoScores: const {'Frog one': 0.9},
      );

      expect(ignored, isEmpty);
    });

    test('sound classes are ignored until the user opts in', () {
      const off = SpeciesIgnoreSettings();
      expect(off.includeSoundClasses, isFalse);
      expect(off.ignoresClass('Anthropogenic'), isTrue);
      expect(off.ignoresClass('Geophony'), isTrue);
      expect(off.ignoresClass('Music'), isTrue);

      const on = SpeciesIgnoreSettings(includeSoundClasses: true);
      expect(on.ignoresClass('Anthropogenic'), isFalse);

      expect(
        SpeciesIgnoreFilter.ignoredScientificNames(
          classByScientificName: classes,
          settings: on,
        ),
        isEmpty,
      );
    });

    test('opting into sound classes does not change the animal toggles', () {
      const settings = SpeciesIgnoreSettings(
        ignoreMammals: true,
        includeSoundClasses: true,
      );
      expect(settings.ignoresClass('Mammalia'), isTrue);
      expect(settings.ignoresClass('Aves'), isFalse);
      // A label without a class is not a sound class.
      expect(const SpeciesIgnoreSettings().ignoresClass(''), isFalse);
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
        scientificName: 'Bird one',
        commonName: 'Bird',
        className: 'Aves',
      ),
      const Species(
        index: 1,
        scientificName: 'Frog one',
        commonName: 'Frog',
        className: 'Amphibia',
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
