// =============================================================================
// Species Filter Tests
// =============================================================================
//
// Verifies the five species filter modes: off, geoExclude, geoAdaptive,
// geoMerge, and customList.  Uses synthetic detections and geo-scores — no
// model or platform dependencies.
// =============================================================================

import 'package:birdnet_live/features/inference/geo_abundance.dart';
import 'package:birdnet_live/features/inference/models/detection.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/inference/species_filter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build a test species.
Species _sp(int idx, String sciName) => Species(
  index: idx,
  id: idx,
  scientificName: sciName,
  commonName: 'Common $idx',
  className: 'Aves',
  order: 'Order',
);

/// Build a test detection.
Detection _det(Species sp, double confidence) =>
    Detection(species: sp, confidence: confidence);

void main() {
  // Test species
  final spA = _sp(0, 'Species alpha');
  final spB = _sp(1, 'Species beta');
  final spC = _sp(2, 'Species gamma');
  final spD = _sp(3, 'Species delta');

  // Test detections (sorted by descending confidence)
  final detections = [
    _det(spA, 0.9),
    _det(spB, 0.7),
    _det(spC, 0.5),
    _det(spD, 0.3),
  ];

  // Geo-scores: spA and spC are expected, spB is below threshold, spD absent
  final geoScores = {
    'Species alpha': 0.8, // above threshold
    'Species beta': 0.01, // below default threshold 0.03
    'Species gamma': 0.5, // above threshold
    // 'Species delta' absent
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Off mode
  // ─────────────────────────────────────────────────────────────────────────

  group('SpeciesFilterMode.off', () {
    test('returns all detections unchanged', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.off,
      );
      expect(result, detections);
    });

    test('returns same reference (no copy)', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.off,
      );
      expect(identical(result, detections), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Geo-exclude mode
  // ─────────────────────────────────────────────────────────────────────────

  group('SpeciesFilterMode.geoExclude', () {
    test('keeps only species above geo threshold', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.geoExclude,
        geoScores: geoScores,
        geoThreshold: 0.03,
      );
      // spA (0.8 ≥ 0.03) ✓, spB (0.01 < 0.03) ✗, spC (0.5 ≥ 0.03) ✓,
      // spD (absent) ✗
      expect(result.length, 2);
      expect(result[0].species.scientificName, 'Species alpha');
      expect(result[1].species.scientificName, 'Species gamma');
    });

    test('preserves original confidence scores', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.geoExclude,
        geoScores: geoScores,
      );
      expect(result[0].confidence, 0.9);
      expect(result[1].confidence, 0.5);
    });

    test('returns all detections when geoScores is null', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.geoExclude,
        geoScores: null,
      );
      expect(result, detections);
    });

    test('custom threshold changes results', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.geoExclude,
        geoScores: geoScores,
        geoThreshold: 0.001, // now spB (0.01) passes too
      );
      expect(result.length, 3);
    });

    test('very high threshold excludes everything', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.geoExclude,
        geoScores: geoScores,
        geoThreshold: 0.99,
      );
      // Only spA (0.8) is below 0.99, so nothing passes
      expect(result, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Geo-adaptive mode
  // ─────────────────────────────────────────────────────────────────────────

  group('SpeciesFilterMode.geoAdaptive', () {
    // A synthetic location whose abundant-tier floor is a round 0.90: 200
    // included species of which the top 20 (10%, comfortably past the 8% edge)
    // sit at 0.90, so adding a subject anywhere cannot shift the floor. The
    // filter calibrates against this distribution exactly as it would against
    // a real one.
    Map<String, double> location({double? subject}) => {
      for (var i = 0; i < 20; i++) 'Top $i': 0.90,
      for (var i = 0; i < 180; i++) 'Rest $i': 0.10,
      if (subject != null) 'Subject': subject,
    };

    /// Run adaptive mode over a single detection at [confidence] whose species
    /// scores [geoScore], against the synthetic location above.
    bool survives(
      double confidence,
      double? geoScore, {
      double confidenceThreshold = 0.35,
    }) {
      final sp = _sp(0, 'Subject');
      final result = SpeciesFilter.apply(
        detections: [_det(sp, confidence)],
        mode: SpeciesFilterMode.geoAdaptive,
        geoScores: location(subject: geoScore),
        confidenceThreshold: confidenceThreshold,
      );
      return result.isNotEmpty;
    }

    test('the neutral point is the local abundant-tier floor', () {
      final scale = ExploreTierScale.fromGeoScores(location());
      expect(scale.minRawFor(ExploreTier.abundant), closeTo(0.90, 0.02));
    });

    test('detections at or above 0.99 are never filtered', () {
      expect(survives(0.99, 0.0), isTrue);
      expect(survives(0.995, 0.0), isTrue);
      expect(survives(1.0, 0.0), isTrue);
    });

    test('a species at or above the abundant floor is never filtered', () {
      // g >= g0 cancels or reverses the geo penalty, so the mode matches 'off'.
      for (final p in [0.35, 0.4, 0.6, 0.9]) {
        expect(survives(p, 0.90), isTrue, reason: 'at the floor, p=$p');
        expect(survives(p, 0.95), isTrue, reason: 'above the floor, p=$p');
      }
      expect(survives(0.34, 0.90), isFalse, reason: 'still needs to clear T');
    });

    test('confidence ladder matches the calibrated boundary', () {
      // Minimum confidence by geo score, for a location whose abundant-tier
      // floor is 0.90, at the defaults (T=0.35, k=1.1, immunity 0.99).
      // See dev/adaptive_location_filter.md.
      const ladder = <(double geoScore, double minConfidence)>[
        (0.90, 0.350), // abundant — never filtered
        (0.50, 0.709), // frequent
        (0.20, 0.809), // uncommon
        (0.05, 0.868), // scarce
        (1e-3, 0.930), // off the local list
        (1e-6, 0.960), // wrong continent
        (0.0, 0.971), // model has never placed it here
      ];

      for (final (geoScore, minConfidence) in ladder) {
        expect(
          survives(minConfidence + 0.008, geoScore),
          isTrue,
          reason: 'g=$geoScore should survive just above $minConfidence',
        );
        if (minConfidence > 0.35) {
          expect(
            survives(minConfidence - 0.008, geoScore),
            isFalse,
            reason: 'g=$geoScore should be dropped just below $minConfidence',
          );
        }
      }
    });

    test('rarer species need more confidence (monotonic in geo score)', () {
      expect(survives(0.75, 0.50), isTrue);
      expect(survives(0.75, 0.05), isFalse);
      expect(survives(0.90, 0.05), isTrue);
    });

    test('the bar is rank-relative, not absolute', () {
      // The same geo score behaves differently depending on how it ranks
      // locally: 0.5 is unremarkable where the top species score 0.9, but
      // abundant where nothing scores above 0.5.
      final richArea = {
        for (var i = 0; i < 20; i++) 'Top $i': 0.90,
        for (var i = 0; i < 180; i++) 'Rest $i': 0.10,
        'Subject': 0.50,
      };
      final poorArea = {
        for (var i = 0; i < 20; i++) 'Top $i': 0.50,
        for (var i = 0; i < 180; i++) 'Rest $i': 0.05,
        'Subject': 0.50,
      };
      List<Detection> run(Map<String, double> area) => SpeciesFilter.apply(
        detections: [_det(_sp(0, 'Subject'), 0.5)],
        mode: SpeciesFilterMode.geoAdaptive,
        geoScores: area,
        confidenceThreshold: 0.35,
      );
      expect(run(richArea), isEmpty);
      expect(run(poorArea), isNotEmpty);
    });

    test('preserves original confidence scores and order', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.geoAdaptive,
        geoScores: location(),
        confidenceThreshold: 0.25,
      );
      // No species is in geoScores, so all are neutral and all clear 0.25.
      expect(result.map((d) => d.confidence), [0.9, 0.7, 0.5, 0.3]);
      expect(
        result.map((d) => d.species.scientificName),
        detections.map((d) => d.species.scientificName),
      );
    });

    test('species unknown to the geo-model are treated as neutral', () {
      // Neutral means the geo term vanishes: kept iff confidence clears the
      // threshold, exactly as in 'off' mode.
      expect(survives(0.4, null), isTrue);
      expect(survives(0.3, null), isFalse);
    });

    test('stricter than geoExclude when weak, looser when confident', () {
      // A species well below the abundant floor but comfortably above the
      // geoExclude cutoff: adaptive drops it at low confidence...
      expect(survives(0.5, 0.05), isFalse);
      // ...where geoExclude would keep it at any confidence.
      final excluded = SpeciesFilter.apply(
        detections: [_det(_sp(0, 'Subject'), 0.5)],
        mode: SpeciesFilterMode.geoExclude,
        geoScores: location(subject: 0.05),
        geoThreshold: 0.03,
      );
      expect(excluded, isNotEmpty);

      // Conversely a species geoExclude rejects outright still gets through
      // on strong audio evidence.
      expect(survives(0.98, 1e-6), isTrue);
      final excludedRare = SpeciesFilter.apply(
        detections: [_det(_sp(0, 'Subject'), 0.98)],
        mode: SpeciesFilterMode.geoExclude,
        geoScores: location(subject: 1e-6),
        geoThreshold: 0.03,
      );
      expect(excludedRare, isEmpty);
    });

    test('ignores the manual geo threshold', () {
      // Adaptive mode derives its own bar, so the slider must not affect it.
      for (final t in [0.0, 0.03, 0.5]) {
        final result = SpeciesFilter.apply(
          detections: [_det(_sp(0, 'Subject'), 0.5)],
          mode: SpeciesFilterMode.geoAdaptive,
          geoScores: location(subject: 0.05),
          geoThreshold: t,
          confidenceThreshold: 0.35,
        );
        expect(result, isEmpty, reason: 'geoThreshold=$t');
      }
    });

    test('returns all detections when geoScores is null', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.geoAdaptive,
        geoScores: null,
      );
      expect(result, detections);
    });

    test('extreme inputs stay finite', () {
      for (final p in [0.0, 1.0]) {
        for (final g in [0.0, 1.0]) {
          expect(
            () => survives(p, g),
            returnsNormally,
            reason: 'p=$p g=$g',
          );
        }
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Geo-merge mode
  // ─────────────────────────────────────────────────────────────────────────

  group('SpeciesFilterMode.geoMerge', () {
    test('multiplies audio score by geo score', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.geoMerge,
        geoScores: geoScores,
      );

      // spA: 0.9 * 0.8 = 0.72
      // spB: 0.7 * 0.01 = 0.007
      // spC: 0.5 * 0.5 = 0.25
      // spD: 0.3 * 0.0 = 0.0 (absent → 0)
      expect(result.length, 4);
      expect(result[0].species.scientificName, 'Species alpha');
      expect(result[0].confidence, closeTo(0.72, 1e-10));
      expect(result[1].species.scientificName, 'Species gamma');
      expect(result[1].confidence, closeTo(0.25, 1e-10));
    });

    test('re-sorts by merged confidence', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.geoMerge,
        geoScores: geoScores,
      );
      // Should be sorted descending: 0.72, 0.25, 0.007, 0.0
      for (var i = 1; i < result.length; i++) {
        expect(
          result[i].confidence,
          lessThanOrEqualTo(result[i - 1].confidence),
        );
      }
    });

    test('applies confidence threshold after merging', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.geoMerge,
        geoScores: geoScores,
        confidenceThreshold: 0.1,
      );
      // Only spA (0.72) and spC (0.25) survive 0.1 threshold
      expect(result.length, 2);
    });

    test('returns all detections when geoScores is null', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.geoMerge,
        geoScores: null,
      );
      expect(result, detections);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Custom list mode
  // ─────────────────────────────────────────────────────────────────────────

  group('SpeciesFilterMode.customList', () {
    test('filters to custom species set', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.customList,
        customSpecies: {'Species alpha', 'Species delta'},
      );
      expect(result.length, 2);
      expect(result[0].species.scientificName, 'Species alpha');
      expect(result[1].species.scientificName, 'Species delta');
    });

    test('preserves original order and confidence', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.customList,
        customSpecies: {'Species gamma', 'Species alpha'},
      );
      // Order matches original detection order (descending confidence)
      expect(result[0].confidence, 0.9); // spA
      expect(result[1].confidence, 0.5); // spC
    });

    test('returns all detections when customSpecies is null', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.customList,
        customSpecies: null,
      );
      expect(result, detections);
    });

    test('returns all detections when customSpecies is empty', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.customList,
        customSpecies: {},
      );
      expect(result, detections);
    });

    test('returns empty when no species match', () {
      final result = SpeciesFilter.apply(
        detections: detections,
        mode: SpeciesFilterMode.customList,
        customSpecies: {'Nonexistent species'},
      );
      expect(result, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Edge cases
  // ─────────────────────────────────────────────────────────────────────────

  group('SpeciesFilter edge cases', () {
    test('empty detections returns empty for all modes', () {
      for (final mode in SpeciesFilterMode.values) {
        final result = SpeciesFilter.apply(
          detections: const [],
          mode: mode,
          geoScores: geoScores,
          customSpecies: {'Species alpha'},
        );
        expect(result, isEmpty, reason: 'mode=$mode');
      }
    });
  });
}
