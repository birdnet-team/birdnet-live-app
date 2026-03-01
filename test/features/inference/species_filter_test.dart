// =============================================================================
// Species Filter Tests
// =============================================================================
//
// Verifies the four species filter modes: off, geoExclude, geoMerge, and
// customList.  Uses synthetic detections and geo-scores — no model or
// platform dependencies.
// =============================================================================

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
            result[i].confidence, lessThanOrEqualTo(result[i - 1].confidence));
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
