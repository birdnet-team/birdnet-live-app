// =============================================================================
// Sound Class Filter Tests
// =============================================================================
//
// The audio model has a few non-animal sound classes (engines, sirens, music).
// They have no range, so the geo-model has no output for them. These tests pin
// how the location filters treat them:
//
//   - every geo mode passes them through untouched,
//   - the "both models know it" restriction keeps them, and
//   - animal species are filtered exactly as before.
//
// Whether sound classes are reported at all is a separate user choice applied
// to the scores earlier (see species_ignore_filter_test.dart).
// =============================================================================

import 'package:birdnet_live/features/inference/models/detection.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/inference/species_filter.dart';
import 'package:flutter_test/flutter_test.dart';

const _robin = Species(
  index: 0,
  scientificName: 'Erithacus rubecula',
  commonName: 'European Robin',
  className: 'Aves',
);
const _vagrant = Species(
  index: 1,
  scientificName: 'Turdus migratorius',
  commonName: 'American Robin',
  className: 'Aves',
);
const _siren = Species(
  index: 2,
  scientificName: 'Siren',
  commonName: 'Siren',
  className: 'Anthropogenic',
);
const _music = Species(
  index: 3,
  scientificName: 'Music',
  commonName: 'Music',
  className: 'Music',
);

Detection _det(Species species, double confidence) =>
    Detection(species: species, confidence: confidence);

void main() {
  // The geo-model knows both birds; only the robin is expected here.
  const geoScores = {'Erithacus rubecula': 0.9, 'Turdus migratorius': 0.0};
  const geoNames = {'Erithacus rubecula', 'Turdus migratorius'};

  final detections = [
    _det(_siren, 0.95),
    _det(_robin, 0.8),
    _det(_vagrant, 0.6),
    _det(_music, 0.4),
  ];

  List<String> names(List<Detection> result) =>
      result.map((d) => d.species.scientificName).toList();

  test('geoExclude drops the unexpected bird and keeps the sounds', () {
    final result = SpeciesFilter.apply(
      detections: detections,
      mode: SpeciesFilterMode.geoExclude,
      geoScores: geoScores,
    );

    expect(names(result), ['Siren', 'Erithacus rubecula', 'Music']);
  });

  test('geoMerge rescales birds only and keeps the list sorted', () {
    final result = SpeciesFilter.apply(
      detections: detections,
      mode: SpeciesFilterMode.geoMerge,
      geoScores: geoScores,
      confidenceThreshold: 0.1,
    );

    expect(names(result), ['Siren', 'Erithacus rubecula', 'Music']);
    expect(result[0].confidence, 0.95); // sound: untouched
    expect(result[1].confidence, closeTo(0.8 * 0.9, 1e-12)); // bird: merged
    expect(result[2].confidence, 0.4); // sound: untouched
    // Sorted by the confidence that is reported.
    for (var i = 1; i < result.length; i++) {
      expect(
        result[i - 1].confidence,
        greaterThanOrEqualTo(result[i].confidence),
      );
    }
  });

  test('geoAdaptive never drops a sound class', () {
    final result = SpeciesFilter.apply(
      detections: [_det(_music, 0.36), _det(_vagrant, 0.36)],
      mode: SpeciesFilterMode.geoAdaptive,
      geoScores: geoScores,
      confidenceThreshold: 0.35,
    );

    // The weak, locally unexpected bird goes; the equally weak sound stays.
    expect(names(result), ['Music']);
  });

  test('a list without sound classes is filtered exactly as before', () {
    final birdsOnly = [_det(_robin, 0.8), _det(_vagrant, 0.6)];
    for (final mode in [
      SpeciesFilterMode.geoExclude,
      SpeciesFilterMode.geoAdaptive,
      SpeciesFilterMode.geoMerge,
    ]) {
      final result = SpeciesFilter.apply(
        detections: birdsOnly,
        mode: mode,
        geoScores: geoScores,
        confidenceThreshold: 0.35,
      );
      expect(names(result), ['Erithacus rubecula'], reason: '$mode');
    }
  });

  test('a custom list still decides for sound classes', () {
    final result = SpeciesFilter.apply(
      detections: detections,
      mode: SpeciesFilterMode.customList,
      customSpecies: {'Erithacus rubecula'},
    );

    expect(names(result), ['Erithacus rubecula']);
  });

  group('restrictToGeoModelSpecies', () {
    test('keeps sounds and species the geo-model knows', () {
      const unknownToGeo = Species(
        index: 4,
        scientificName: 'Gekko gecko',
        commonName: 'Tokay Gecko',
        className: 'Mammalia', // an animal class the geo-model lacks a row for
      );

      final result = SpeciesFilter.restrictToGeoModelSpecies([
        ...detections,
        _det(unknownToGeo, 0.9),
      ], geoNames);

      expect(names(result), [
        'Siren',
        'Erithacus rubecula',
        'Turdus migratorius',
        'Music',
      ]);
    });

    test('keeps everything while the geo-model is not loaded', () {
      expect(
        SpeciesFilter.restrictToGeoModelSpecies(detections, null),
        same(detections),
      );
    });
  });
}
