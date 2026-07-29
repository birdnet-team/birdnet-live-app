// =============================================================================
// Survey Alert Engine Tests
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/features/history/global_species_history.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/survey/survey_alert_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GlobalSpeciesHistory emptyHistory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    emptyHistory = GlobalSpeciesHistory(prefs)..load();
  });

  DetectionRecord det({
    String name = 'Turdus merula',
    String common = 'Eurasian Blackbird',
    double conf = 0.8,
  }) {
    return DetectionRecord(
      scientificName: name,
      commonName: common,
      confidence: conf,
      timestamp: DateTime(2025, 6, 15, 10, 0),
    );
  }

  group('AlertMode prefValue / fromPrefValue', () {
    test('round-trips every mode', () {
      for (final m in AlertMode.values) {
        expect(AlertMode.fromPrefValue(m.prefValue), m);
      }
    });

    test('falls back to off for invalid values', () {
      expect(AlertMode.fromPrefValue(null), AlertMode.off);
      expect(AlertMode.fromPrefValue(-1), AlertMode.off);
      expect(AlertMode.fromPrefValue(99), AlertMode.off);
    });
  });

  group('SurveyAlertEngine.evaluate', () {
    test('off mode never fires', () {
      final engine = SurveyAlertEngine(
        mode: AlertMode.off,
        minConfidence: 0.0,
        globalHistory: emptyHistory,
      );
      expect(engine.evaluate(det(), firstInSession: true), isNull);
    });

    test('minConfidence floor suppresses across all modes', () {
      for (final m in [
        AlertMode.firstInSession,
        AlertMode.firstEver,
        AlertMode.rare,
        AlertMode.watchlist,
      ]) {
        final engine = SurveyAlertEngine(
          mode: m,
          minConfidence: 0.5,
          globalHistory: emptyHistory,
          watchlist: const {'Turdus merula'},
        );
        expect(
          engine.evaluate(det(conf: 0.4), firstInSession: true),
          isNull,
          reason: 'mode=$m should suppress sub-threshold',
        );
      }
    });

    test('non-first-in-session suppresses across all non-off modes', () {
      for (final m in [
        AlertMode.firstInSession,
        AlertMode.firstEver,
        AlertMode.rare,
        AlertMode.watchlist,
      ]) {
        final engine = SurveyAlertEngine(
          mode: m,
          minConfidence: 0.0,
          globalHistory: emptyHistory,
          watchlist: const {'Turdus merula'},
        );
        expect(
          engine.evaluate(det(), firstInSession: false),
          isNull,
          reason: 'mode=$m should suppress repeats',
        );
      }
    });

    test('empty scientific name is suppressed', () {
      final engine = SurveyAlertEngine(
        mode: AlertMode.firstInSession,
        minConfidence: 0.0,
        globalHistory: emptyHistory,
      );
      expect(engine.evaluate(det(name: ''), firstInSession: true), isNull);
    });

    test('firstInSession mode fires once and reports correct reason', () {
      final engine = SurveyAlertEngine(
        mode: AlertMode.firstInSession,
        minConfidence: 0.0,
        globalHistory: emptyHistory,
      );
      final c = engine.evaluate(det(), firstInSession: true);
      expect(c, isNotNull);
      expect(c!.reason, AlertReason.firstInSession);
      expect(c.scientificName, 'Turdus merula');
      expect(c.commonName, 'Eurasian Blackbird');
    });

    test(
      'firstEver fires only when species absent from global history',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final history = GlobalSpeciesHistory(prefs)..load();
        await history.add('Turdus merula');

        final engine = SurveyAlertEngine(
          mode: AlertMode.firstEver,
          minConfidence: 0.0,
          globalHistory: history,
        );
        expect(engine.evaluate(det(), firstInSession: true), isNull);
        final c = engine.evaluate(
          det(name: 'Parus major'),
          firstInSession: true,
        );
        expect(c, isNotNull);
        expect(c!.reason, AlertReason.firstEver);
      },
    );

    test('rare mode fires when geoScore below threshold', () {
      final engine = SurveyAlertEngine(
        mode: AlertMode.rare,
        minConfidence: 0.0,
        globalHistory: emptyHistory,
        rareThreshold: 0.05,
        geoScores: const {
          'Turdus merula': 0.5, // common here
          'Parus major': 0.02, // rare here
        },
      );
      expect(engine.evaluate(det(), firstInSession: true), isNull);

      final c = engine.evaluate(det(name: 'Parus major'), firstInSession: true);
      expect(c, isNotNull);
      expect(c!.reason, AlertReason.rare);
      expect(c.geoScore, 0.02);
    });

    test('rare mode treats absent geoScore as 0 (always rare)', () {
      final engine = SurveyAlertEngine(
        mode: AlertMode.rare,
        minConfidence: 0.0,
        globalHistory: emptyHistory,
        rareThreshold: 0.05,
        geoScores: const {},
      );
      final c = engine.evaluate(
        det(name: 'Cyanistes caeruleus'),
        firstInSession: true,
      );
      expect(c, isNotNull);
      expect(c!.geoScore, 0.0);
    });

    test('rare mode boundary: score == threshold does not fire', () {
      final engine = SurveyAlertEngine(
        mode: AlertMode.rare,
        minConfidence: 0.0,
        globalHistory: emptyHistory,
        rareThreshold: 0.05,
        geoScores: const {'Turdus merula': 0.05},
      );
      expect(engine.evaluate(det(), firstInSession: true), isNull);
    });

    test('watchlist mode fires only when name in list', () {
      final engine = SurveyAlertEngine(
        mode: AlertMode.watchlist,
        minConfidence: 0.0,
        globalHistory: emptyHistory,
        watchlist: const {'Parus major'},
      );
      expect(engine.evaluate(det(), firstInSession: true), isNull);
      final c = engine.evaluate(det(name: 'Parus major'), firstInSession: true);
      expect(c, isNotNull);
      expect(c!.reason, AlertReason.watchlist);
    });

    test('watchlist mode with empty list never fires', () {
      final engine = SurveyAlertEngine(
        mode: AlertMode.watchlist,
        minConfidence: 0.0,
        globalHistory: emptyHistory,
        watchlist: const {},
      );
      expect(engine.evaluate(det(), firstInSession: true), isNull);
    });
  });
}
