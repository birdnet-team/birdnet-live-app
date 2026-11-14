// =============================================================================
// Survey Alert Coordinator Tests — sound classes
// =============================================================================
//
// Species alerts are about species. A non-animal sound class has no geo-model
// score, so in "rare" mode every siren would look maximally rare, and in
// "first ever" mode it would enter the lifetime species history. The
// coordinator therefore ignores detections its [isSoundClass] callback
// recognizes, in every mode.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/features/history/global_species_history.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/survey/species_alert_notifier.dart';
import 'package:birdnet_live/features/survey/survey_alert_coordinator.dart';
import 'package:birdnet_live/features/survey/survey_alert_engine.dart';

const _strings = SpeciesAlertStrings(
  channelName: 'Alerts',
  channelDescription: 'Species alerts',
  firstInSessionBody: 'first in session',
  firstEverBody: 'first ever',
  rareBody: 'rare',
  watchlistBody: 'watchlist',
  summaryTitle: '{count} species',
  summaryBody: 'summary',
);

DetectionRecord _det(String scientificName) => DetectionRecord(
  scientificName: scientificName,
  commonName: scientificName,
  confidence: 0.9,
  timestamp: DateTime(2026, 11, 14, 10),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GlobalSpeciesHistory history;
  late List<String> delivered;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    history = GlobalSpeciesHistory(prefs)..load();
    delivered = [];
  });

  SurveyAlertCoordinator build(AlertMode mode) => SurveyAlertCoordinator(
    mode: mode,
    // Never initialized, so it shows nothing; delivery is observed through
    // the in-app callback.
    notifier: SpeciesAlertNotifier(),
    notifierStrings: _strings,
    globalHistory: history,
    // The geo-model knows the bird and has no entry for the sound class.
    geoScores: const {'Turdus merula': 0.001},
    watchlist: const {'Turdus merula', 'Siren'},
    startupGraceSeconds: 0,
    minIntervalSeconds: 0,
    maxPerMinute: 100,
    coalesce: false,
    onDelivered: (one, _) {
      if (one != null) delivered.add(one.scientificName);
    },
    isSoundClass: (name) => name == 'Siren',
  );

  for (final mode in [
    AlertMode.firstInSession,
    AlertMode.firstEver,
    AlertMode.rare,
    AlertMode.watchlist,
  ]) {
    test('${mode.name}: a sound class never alerts, a species does', () async {
      final coordinator = build(mode);
      addTearDown(() => coordinator.shutdown(flushFinal: false));

      coordinator.onDetection(_det('Siren'));
      coordinator.onDetection(_det('Turdus merula'));
      await Future<void>.delayed(Duration.zero);

      expect(delivered, ['Turdus merula']);
      expect(history.contains('Siren'), isFalse);
    });
  }

  test('without the callback every detection is a species', () async {
    final coordinator = SurveyAlertCoordinator(
      mode: AlertMode.firstInSession,
      notifier: SpeciesAlertNotifier(),
      notifierStrings: _strings,
      globalHistory: history,
      geoScores: const {},
      watchlist: null,
      startupGraceSeconds: 0,
      minIntervalSeconds: 0,
      maxPerMinute: 100,
      coalesce: false,
      onDelivered: (one, _) {
        if (one != null) delivered.add(one.scientificName);
      },
    );
    addTearDown(() => coordinator.shutdown(flushFinal: false));

    coordinator.onDetection(_det('Siren'));
    await Future<void>.delayed(Duration.zero);

    expect(delivered, ['Siren']);
  });
}
