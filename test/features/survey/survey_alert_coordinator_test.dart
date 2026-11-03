// =============================================================================
// Survey Alert Coordinator Tests
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/features/history/global_species_history.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/survey/species_alert_notifier.dart';
import 'package:birdnet_live/features/survey/survey_alert_coordinator.dart';
import 'package:birdnet_live/features/survey/survey_alert_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const strings = SpeciesAlertStrings(
    channelName: 'c',
    channelDescription: 'd',
    firstInSessionBody: 'b',
    firstEverBody: 'b',
    rareBody: 'b',
    watchlistBody: 'b',
    liferBody: 'b',
    summaryTitle: 't',
    summaryBody: 'b',
  );

  late GlobalSpeciesHistory history;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    history = GlobalSpeciesHistory(prefs)..load();
  });

  DetectionRecord det(String name) => DetectionRecord(
    scientificName: name,
    commonName: name,
    confidence: 0.9,
    timestamp: DateTime(2025, 6, 15, 10, 0),
  );

  group('lifer mode', () {
    Future<List<String>> delivered(
      List<String> names, {
      bool Function(String)? isBirdSpecies,
    }) async {
      final out = <String>[];
      final coord = SurveyAlertCoordinator(
        mode: AlertMode.lifer,
        notifier: SpeciesAlertNotifier(),
        notifierStrings: strings,
        globalHistory: history,
        geoScores: null,
        watchlist: null,
        lifeList: const {'Scolopax minor'},
        isBirdSpecies: isBirdSpecies,
        startupGraceSeconds: 0,
        onDelivered: (one, _) {
          if (one != null) out.add(one.scientificName);
        },
      );
      names.map(det).forEach(coord.onDetection);
      await Future<void>.delayed(Duration.zero);
      await coord.shutdown(flushFinal: false);
      return out;
    }

    test('alerts for a bird missing from the life list', () async {
      expect(await delivered(['Turdus merula'], isBirdSpecies: (_) => true), [
        'Turdus merula',
      ]);
    });

    test(
      'never alerts for non-birds, which an eBird list cannot contain',
      () async {
        expect(
          await delivered([
            'Sciurus carolinensis',
            'Turdus merula',
          ], isBirdSpecies: (name) => name == 'Turdus merula'),
          ['Turdus merula'],
        );
      },
    );

    test(
      'alerts for every species when the bird check is unavailable',
      () async {
        expect(await delivered(['Sciurus carolinensis']), [
          'Sciurus carolinensis',
        ]);
      },
    );
  });
}
