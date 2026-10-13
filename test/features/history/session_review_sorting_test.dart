import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/history/session_review_screen.dart';
import 'package:birdnet_live/features/live/live_session.dart';

DetectionRecord _record({
  required String scientificName,
  required String commonName,
  required double confidence,
  required DateTime timestamp,
}) {
  return DetectionRecord(
    scientificName: scientificName,
    commonName: commonName,
    confidence: confidence,
    timestamp: timestamp,
  );
}

void main() {
  group('compareSessionReviewConfidenceSortEntries', () {
    final base = DateTime.utc(2026, 5, 24, 8);

    test('prefers clip-backed detections before clipless detections', () {
      final result = compareSessionReviewConfidenceSortEntries(
        aHasAudioClip: true,
        aConfidence: 0.70,
        aTimestamp: base.add(const Duration(seconds: 20)),
        bHasAudioClip: false,
        bConfidence: 0.99,
        bTimestamp: base,
      );

      expect(result, isNegative);
    });

    test('sorts by descending confidence within the same clip state', () {
      final result = compareSessionReviewConfidenceSortEntries(
        aHasAudioClip: true,
        aConfidence: 0.82,
        aTimestamp: base,
        bHasAudioClip: true,
        bConfidence: 0.94,
        bTimestamp: base.add(const Duration(seconds: 20)),
      );

      expect(result, isPositive);
    });

    test('uses timestamp as a deterministic tie-breaker', () {
      final result = compareSessionReviewConfidenceSortEntries(
        aHasAudioClip: false,
        aConfidence: 0.82,
        aTimestamp: base,
        bHasAudioClip: false,
        bConfidence: 0.82,
        bTimestamp: base.add(const Duration(seconds: 20)),
      );

      expect(result, isNegative);
    });
  });

  group('buildSessionReviewPlaybackOrder', () {
    final base = DateTime.utc(2026, 5, 24, 8);

    test('count ties prefer species with the higher score', () {
      final lowerScore = _record(
        scientificName: 'A species',
        commonName: 'Alphabetical First',
        confidence: 0.70,
        timestamp: base,
      );
      final higherScore = _record(
        scientificName: 'B species',
        commonName: 'Alphabetical Second',
        confidence: 0.90,
        timestamp: base.add(const Duration(seconds: 10)),
      );

      final order = buildSessionReviewPlaybackOrder(
        detections: [lowerScore, higherScore],
        maxGapSec: 3,
        sortMode: SpeciesSortMode.count,
        localizedCommonName: (_, fallback) => fallback,
        hasPlayableClip: (_) => true,
      );

      expect(order, [higherScore, lowerScore]);
    });

    test('count mode sorts detections within a species by score', () {
      final lowerScore = _record(
        scientificName: 'A species',
        commonName: 'Species',
        confidence: 0.70,
        timestamp: base,
      );
      final higherScore = _record(
        scientificName: 'A species',
        commonName: 'Species',
        confidence: 0.90,
        timestamp: base.add(const Duration(seconds: 10)),
      );

      final order = buildSessionReviewPlaybackOrder(
        detections: [lowerScore, higherScore],
        maxGapSec: 3,
        sortMode: SpeciesSortMode.count,
        localizedCommonName: (_, fallback) => fallback,
        hasPlayableClip: (_) => true,
      );

      expect(order, [higherScore, lowerScore]);
    });

    test(
      'keeps confidence-sorted playback within a species before advancing',
      () {
        final firstSpeciesBest = _record(
          scientificName: 'Zenaida macroura',
          commonName: 'Mourning Dove',
          confidence: 0.95,
          timestamp: base.add(const Duration(seconds: 30)),
        );
        final secondSpecies = _record(
          scientificName: 'Agelaius phoeniceus',
          commonName: 'Red-winged Blackbird',
          confidence: 0.90,
          timestamp: base.add(const Duration(seconds: 10)),
        );
        final firstSpeciesLower = _record(
          scientificName: 'Zenaida macroura',
          commonName: 'Mourning Dove',
          confidence: 0.40,
          timestamp: base.add(const Duration(seconds: 90)),
        );

        final order = buildSessionReviewPlaybackOrder(
          detections: [secondSpecies, firstSpeciesLower, firstSpeciesBest],
          maxGapSec: 3,
          sortMode: SpeciesSortMode.confidence,
          localizedCommonName: (_, fallback) => fallback,
          hasPlayableClip: (_) => true,
        );

        expect(order, [firstSpeciesBest, firstSpeciesLower, secondSpecies]);
      },
    );
  });
}
