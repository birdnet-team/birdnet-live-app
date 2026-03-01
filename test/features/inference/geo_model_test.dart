// =============================================================================
// Geo-Model Tests
// =============================================================================
//
// Verifies the geo-model's public interface, week calculation, and dummy
// prediction behaviour.  Since the real ONNX model is not yet available,
// these tests exercise the placeholder implementation.
// =============================================================================

import 'package:birdnet_live/features/inference/geo_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal labels CSV for testing.
const _testLabelsCsv = '''idx;id;sci_name;com_name;class;order
0;1;Parus major;Great Tit;Aves;Passeriformes
1;2;Turdus merula;Eurasian Blackbird;Aves;Passeriformes
2;3;Erithacus rubecula;European Robin;Aves;Passeriformes
3;4;Fringilla coelebs;Common Chaffinch;Aves;Passeriformes
4;5;Cyanistes caeruleus;Eurasian Blue Tit;Aves;Passeriformes''';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  group('GeoModel lifecycle', () {
    test('isReady is false before initialisation', () {
      final model = GeoModel();
      expect(model.isReady, isFalse);
    });

    test('isReady is false with only labels loaded', () {
      final model = GeoModel();
      model.loadLabels(_testLabelsCsv);
      expect(model.isReady, isFalse);
    });

    test('isReady is true after labels + model loaded', () async {
      final model = GeoModel();
      model.loadLabels(_testLabelsCsv);
      await model.loadModel();
      expect(model.isReady, isTrue);
    });

    test('labels are parsed correctly', () {
      final model = GeoModel();
      model.loadLabels(_testLabelsCsv);
      expect(model.labels.length, 5);
      expect(model.labels[0].scientificName, 'Parus major');
      expect(model.labels[4].scientificName, 'Cyanistes caeruleus');
    });

    test('dispose resets state', () async {
      final model = GeoModel();
      model.loadLabels(_testLabelsCsv);
      await model.loadModel();
      expect(model.isReady, isTrue);

      model.dispose();
      expect(model.isReady, isFalse);
      expect(model.labels, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Prediction
  // ─────────────────────────────────────────────────────────────────────────

  group('GeoModel.predict', () {
    late GeoModel model;

    setUp(() async {
      model = GeoModel();
      model.loadLabels(_testLabelsCsv);
      await model.loadModel();
    });

    tearDown(() => model.dispose());

    test('throws StateError when not ready', () {
      final uninit = GeoModel();
      expect(
        () => uninit.predict(latitude: 0, longitude: 0, week: 1),
        throwsA(isA<StateError>()),
      );
    });

    test('returns scores for all species', () {
      final scores = model.predict(
        latitude: 51.5,
        longitude: -0.1,
        week: 20,
      );
      expect(scores.length, 5);
      expect(scores.containsKey('Parus major'), isTrue);
      expect(scores.containsKey('Turdus merula'), isTrue);
    });

    test('scores are in [0, 1]', () {
      final scores = model.predict(
        latitude: 40.7,
        longitude: -74.0,
        week: 10,
      );
      for (final score in scores.values) {
        expect(score, greaterThanOrEqualTo(0.0));
        expect(score, lessThanOrEqualTo(1.0));
      }
    });

    test('same location/week produces same scores (deterministic)', () {
      final a = model.predict(latitude: 48.1, longitude: 11.5, week: 25);
      final b = model.predict(latitude: 48.1, longitude: 11.5, week: 25);
      expect(a, equals(b));
    });

    test('different location produces different scores', () {
      final a = model.predict(latitude: 0.0, longitude: 0.0, week: 1);
      final b = model.predict(latitude: 90.0, longitude: 180.0, week: 1);
      // Very unlikely to be identical with different seeds.
      expect(a, isNot(equals(b)));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Expected species
  // ─────────────────────────────────────────────────────────────────────────

  group('GeoModel.expectedSpecies', () {
    late GeoModel model;

    setUp(() async {
      model = GeoModel();
      model.loadLabels(_testLabelsCsv);
      await model.loadModel();
    });

    tearDown(() => model.dispose());

    test('returns a subset of species scientific names', () {
      final expected = model.expectedSpecies(
        latitude: 51.5,
        longitude: -0.1,
        week: 20,
        threshold: 0.03,
      );
      // Should be a non-empty subset of the 5 label species.
      expect(expected, isNotEmpty);
      for (final name in expected) {
        expect(
          model.labels.any((s) => s.scientificName == name),
          isTrue,
          reason: '$name should be in labels',
        );
      }
    });

    test('threshold 0.0 returns all species', () {
      final expected = model.expectedSpecies(
        latitude: 51.5,
        longitude: -0.1,
        week: 20,
        threshold: 0.0,
      );
      expect(expected.length, 5);
    });

    test('threshold 1.0 returns very few or no species', () {
      final expected = model.expectedSpecies(
        latitude: 51.5,
        longitude: -0.1,
        week: 20,
        threshold: 1.0,
      );
      // With dummy random scores, probability of exactly 1.0 is negligible.
      expect(expected.length, lessThanOrEqualTo(1));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Week calculation
  // ─────────────────────────────────────────────────────────────────────────

  group('GeoModel.dateTimeToWeek', () {
    test('January 1 → week 1', () {
      expect(GeoModel.dateTimeToWeek(DateTime(2026, 1, 1)), 1);
    });

    test('January 7 → week 1', () {
      expect(GeoModel.dateTimeToWeek(DateTime(2026, 1, 7)), 1);
    });

    test('January 8 → week 2', () {
      expect(GeoModel.dateTimeToWeek(DateTime(2026, 1, 8)), 2);
    });

    test('January 31 → week 4 (clamped)', () {
      // Day 31 → (31-1)/7 = 4.28 → clamped to 3 → +1 = 4
      expect(GeoModel.dateTimeToWeek(DateTime(2026, 1, 31)), 4);
    });

    test('February 1 → week 5', () {
      expect(GeoModel.dateTimeToWeek(DateTime(2026, 2, 1)), 5);
    });

    test('June 15 → week 22 or 23', () {
      final w = GeoModel.dateTimeToWeek(DateTime(2026, 6, 15));
      // June = month 6, base = (6-1)*4 = 20.  Day 15 → (15-1)/7 = 2.0 → +1 = 23
      expect(w, 23);
    });

    test('December 31 → week 48', () {
      expect(GeoModel.dateTimeToWeek(DateTime(2026, 12, 31)), 48);
    });

    test('all months produce weeks 1–48', () {
      for (var m = 1; m <= 12; m++) {
        for (var d = 1; d <= 28; d++) {
          final w = GeoModel.dateTimeToWeek(DateTime(2026, m, d));
          expect(w, inInclusiveRange(1, 48),
              reason: 'Month $m, day $d → week $w');
        }
      }
    });
  });
}
