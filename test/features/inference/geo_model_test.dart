// =============================================================================
// Geo-Model Tests
// =============================================================================
//
// Verifies the geo-model's label parsing, week calculation, lifecycle, and
// data class behaviour.  ONNX inference tests are skipped here since they
// require the real model file — see integration_test/ for those.
// =============================================================================

import 'package:birdnet_live/features/inference/geo_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal tab-delimited labels (same format as geomodel labels file).
const _testLabels = '1044390\tParus major\tGreat Tit\n'
    '1044391\tTurdus merula\tEurasian Blackbird\n'
    '1044392\tErithacus rubecula\tEuropean Robin\n'
    '1044393\tFringilla coelebs\tCommon Chaffinch\n'
    '1044394\tCyanistes caeruleus\tEurasian Blue Tit';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Label parsing
  // ─────────────────────────────────────────────────────────────────────────

  group('GeoModel.loadLabels', () {
    test('parses tab-delimited labels', () {
      final model = GeoModel();
      model.loadLabels(_testLabels);
      expect(model.labels.length, 5);
    });

    test('extracts scientific names', () {
      final model = GeoModel();
      model.loadLabels(_testLabels);
      expect(model.labels[0].scientificName, 'Parus major');
      expect(model.labels[4].scientificName, 'Cyanistes caeruleus');
    });

    test('extracts common names', () {
      final model = GeoModel();
      model.loadLabels(_testLabels);
      expect(model.labels[0].commonName, 'Great Tit');
      expect(model.labels[1].commonName, 'Eurasian Blackbird');
    });

    test('extracts numeric IDs', () {
      final model = GeoModel();
      model.loadLabels(_testLabels);
      expect(model.labels[0].id, 1044390);
      expect(model.labels[2].id, 1044392);
    });

    test('assigns sequential indices starting from 0', () {
      final model = GeoModel();
      model.loadLabels(_testLabels);
      for (var i = 0; i < model.labels.length; i++) {
        expect(model.labels[i].index, i);
      }
    });

    test('handles labels with only id and sci_name (no common name)', () {
      final model = GeoModel();
      model.loadLabels('123\tSome species');
      expect(model.labels.length, 1);
      expect(model.labels[0].scientificName, 'Some species');
      // Falls back to scientific name as common name.
      expect(model.labels[0].commonName, 'Some species');
    });

    test('skips blank lines', () {
      final model = GeoModel();
      model.loadLabels('1\tA\tA\n\n\n2\tB\tB\n');
      expect(model.labels.length, 2);
    });

    test('skips lines with fewer than 2 tab-separated fields', () {
      final model = GeoModel();
      model.loadLabels('1\tA\tA\nmalformed_line\n2\tB\tB');
      expect(model.labels.length, 2);
    });

    test('handles empty input', () {
      final model = GeoModel();
      model.loadLabels('');
      expect(model.labels, isEmpty);
    });

    test('handles whitespace-only input', () {
      final model = GeoModel();
      model.loadLabels('  \n  \n  ');
      expect(model.labels, isEmpty);
    });

    test('trims whitespace from fields', () {
      final model = GeoModel();
      model.loadLabels('  1  \t  Parus major  \t  Great Tit  ');
      expect(model.labels[0].scientificName, 'Parus major');
      expect(model.labels[0].commonName, 'Great Tit');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  group('GeoModel lifecycle', () {
    test('isReady is false before initialisation', () {
      final model = GeoModel();
      expect(model.isReady, isFalse);
    });

    test('isReady is false with only labels loaded (no ONNX session)', () {
      final model = GeoModel();
      model.loadLabels(_testLabels);
      expect(model.isReady, isFalse);
    });

    test('dispose clears labels', () {
      final model = GeoModel();
      model.loadLabels(_testLabels);
      expect(model.labels.length, 5);

      model.dispose();
      expect(model.labels, isEmpty);
      expect(model.isReady, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Prediction (without ONNX — error path only)
  // ─────────────────────────────────────────────────────────────────────────

  group('GeoModel.predict (no model loaded)', () {
    test('throws StateError when not ready', () {
      final model = GeoModel();
      expect(
        () => model.predict(latitude: 0, longitude: 0, week: 1),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError with labels but no model', () {
      final model = GeoModel();
      model.loadLabels(_testLabels);
      expect(
        () => model.predict(latitude: 51.5, longitude: -0.1, week: 20),
        throwsA(isA<StateError>()),
      );
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
      expect(GeoModel.dateTimeToWeek(DateTime(2026, 1, 31)), 4);
    });

    test('February 1 → week 5', () {
      expect(GeoModel.dateTimeToWeek(DateTime(2026, 2, 1)), 5);
    });

    test('June 15 → week 23', () {
      final w = GeoModel.dateTimeToWeek(DateTime(2026, 6, 15));
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

  // ─────────────────────────────────────────────────────────────────────────
  // Data classes
  // ─────────────────────────────────────────────────────────────────────────

  group('GeoSpecies', () {
    test('toString includes name and scientific name', () {
      const sp = GeoSpecies(
        index: 0,
        id: 42,
        scientificName: 'Parus major',
        commonName: 'Great Tit',
      );
      expect(sp.toString(), contains('Parus major'));
      expect(sp.toString(), contains('Great Tit'));
    });
  });

  group('GeoSpeciesScore', () {
    test('toString includes name and score', () {
      const score = GeoSpeciesScore(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        score: 0.85,
      );
      expect(score.toString(), contains('Great Tit'));
      expect(score.toString(), contains('0.850'));
    });
  });
}
