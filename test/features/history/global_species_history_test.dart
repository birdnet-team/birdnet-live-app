// =============================================================================
// GlobalSpeciesHistory Tests
// =============================================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/features/history/global_species_history.dart';
import 'package:birdnet_live/features/live/live_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LiveSession makeSession(List<String> sciNames) {
    return LiveSession(
      id: 'test-${sciNames.join("-")}',
      startTime: DateTime(2025, 6, 15, 10, 0),
      endTime: DateTime(2025, 6, 15, 10, 30),
      detections: [
        for (final n in sciNames)
          DetectionRecord(
            scientificName: n,
            commonName: n,
            confidence: 0.8,
            timestamp: DateTime(2025, 6, 15, 10, 5),
          ),
      ],
      settings: const SessionSettings(
        windowDuration: 3,
        confidenceThreshold: 25,
        inferenceRate: 1.0,
        speciesFilterMode: 'off',
      ),
    );
  }

  group('GlobalSpeciesHistory', () {
    test('starts empty when no key persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final history = GlobalSpeciesHistory(prefs)..load();
      expect(history.length, 0);
      expect(history.contains('Turdus merula'), isFalse);
    });

    test('loads previously persisted set', () async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.globalSpeciesHistory: json.encode([
          'Parus major',
          'Turdus merula',
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final history = GlobalSpeciesHistory(prefs)..load();
      expect(history.length, 2);
      expect(history.contains('Turdus merula'), isTrue);
      expect(history.contains('Parus major'), isTrue);
      expect(history.contains('Cyanistes caeruleus'), isFalse);
    });

    test('add returns true only on first insertion', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final history = GlobalSpeciesHistory(prefs)..load();

      expect(await history.add('Turdus merula'), isTrue);
      expect(await history.add('Turdus merula'), isFalse);
      expect(history.length, 1);
    });

    test('add persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final history = GlobalSpeciesHistory(prefs)..load();
      await history.add('Turdus merula');

      // Reload from a fresh instance reading the same prefs.
      final reloaded = GlobalSpeciesHistory(prefs)..load();
      expect(reloaded.contains('Turdus merula'), isTrue);
    });

    test('addAll returns the newly-added subset', () async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.globalSpeciesHistory: json.encode(['Turdus merula']),
      });
      final prefs = await SharedPreferences.getInstance();
      final history = GlobalSpeciesHistory(prefs)..load();

      final added = await history.addAll([
        'Turdus merula',
        'Parus major',
        'Cyanistes caeruleus',
      ]);
      expect(added, {'Parus major', 'Cyanistes caeruleus'});
      expect(history.length, 3);
    });

    test('clear empties the set and removes the pref', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final history = GlobalSpeciesHistory(prefs)..load();
      await history.add('Turdus merula');
      await history.clear();

      expect(history.length, 0);
      expect(prefs.getString(PrefKeys.globalSpeciesHistory), isNull);
    });

    test('persisted JSON is sorted for stable on-disk diffs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final history = GlobalSpeciesHistory(prefs)..load();

      await history.add('Zonotrichia leucophrys');
      await history.add('Anas platyrhynchos');
      await history.add('Mimus polyglottos');

      final raw = prefs.getString(PrefKeys.globalSpeciesHistory);
      expect(raw, isNotNull);
      final list = (json.decode(raw!) as List).cast<String>();
      expect(list, [
        'Anas platyrhynchos',
        'Mimus polyglottos',
        'Zonotrichia leucophrys',
      ]);
    });
  });

  group('seedGlobalSpeciesHistory', () {
    test('backfills from sessions and marks seeded', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final history = GlobalSpeciesHistory(prefs)..load();

      await seedGlobalSpeciesHistory(
        history: history,
        prefs: prefs,
        sessions: [
          makeSession(['Turdus merula', 'Parus major']),
          makeSession(['Parus major', 'Cyanistes caeruleus']),
        ],
      );

      expect(history.length, 3);
      expect(history.contains('Cyanistes caeruleus'), isTrue);
      expect(prefs.getBool(PrefKeys.globalSpeciesHistorySeeded), isTrue);
    });

    test('is a no-op when already seeded', () async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.globalSpeciesHistorySeeded: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final history = GlobalSpeciesHistory(prefs)..load();

      await seedGlobalSpeciesHistory(
        history: history,
        prefs: prefs,
        sessions: [
          makeSession(['Turdus merula']),
        ],
      );

      // History should still be empty — no scan was performed.
      expect(history.length, 0);
    });

    test('handles empty session list gracefully', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final history = GlobalSpeciesHistory(prefs)..load();

      await seedGlobalSpeciesHistory(
        history: history,
        prefs: prefs,
        sessions: const [],
      );

      expect(history.length, 0);
      expect(prefs.getBool(PrefKeys.globalSpeciesHistorySeeded), isTrue);
    });
  });
}
