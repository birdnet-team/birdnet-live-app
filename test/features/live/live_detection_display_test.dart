import 'package:birdnet_live/features/live/live_detection_display.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DetectionRecord record(String scientificName, DateTime timestamp) {
    return DetectionRecord(
      scientificName: scientificName,
      commonName: scientificName,
      confidence: 0.8,
      timestamp: timestamp,
    );
  }

  DetectionRecord closedRecord(
    String scientificName,
    DateTime timestamp,
    DateTime endTimestamp,
  ) {
    return DetectionRecord(
      scientificName: scientificName,
      commonName: scientificName,
      confidence: 0.8,
      timestamp: timestamp,
      endTimestamp: endTimestamp,
    );
  }

  test('uses only current detections by default', () {
    final now = DateTime(2026, 7, 5, 10);
    final current = [record('A', now)];
    final session = [record('B', now.subtract(const Duration(minutes: 1)))];

    final result = buildLiveDetectionDisplayList(
      currentDetections: current,
      sessionDetections: session,
      showAllDetectedSpecies: false,
      sortMode: DetectedSpeciesSortMode.newest,
    );

    expect(result.map((d) => d.scientificName), ['A']);
  });

  test('keeps unique species in newest-first order', () {
    final base = DateTime(2026, 7, 5, 10);
    final session = [
      record('B', base.add(const Duration(minutes: 3))),
      record('C', base.add(const Duration(minutes: 2))),
      record('A', base.add(const Duration(minutes: 1))),
      record('B', base),
    ];

    final result = buildLiveDetectionDisplayList(
      currentDetections: const [],
      sessionDetections: session,
      showAllDetectedSpecies: true,
      sortMode: DetectedSpeciesSortMode.newest,
    );

    expect(result.map((d) => d.scientificName), ['B', 'C', 'A']);
  });

  test('sorts species alphabetically by common name', () {
    final base = DateTime(2026, 7, 5, 10);
    final session = [
      record('B', base.add(const Duration(minutes: 2))),
      record('C', base.add(const Duration(minutes: 1))),
      record('A', base),
    ];
    final current = [
      DetectionRecord(
        scientificName: 'A',
        commonName: 'A',
        confidence: 0.99,
        timestamp: base.add(const Duration(minutes: 4)),
      ),
    ];

    final result = buildLiveDetectionDisplayList(
      currentDetections: current,
      sessionDetections: session,
      showAllDetectedSpecies: true,
      sortMode: DetectedSpeciesSortMode.alphabetical,
    );

    expect(result.map((d) => d.scientificName), ['A', 'B', 'C']);
    expect(result.first.confidence, 0.99);
  });

  test('sorts alphabetically by the localized common name', () {
    final base = DateTime(2026, 7, 5, 10);
    // English common names would order these Amsel(A) < Buchfink(B) < Kohl(K),
    // but the localized German names reverse the first two.
    final session = [
      record('Fringilla coelebs', base.add(const Duration(minutes: 2))),
      record('Turdus merula', base.add(const Duration(minutes: 1))),
      record('Parus major', base),
    ];
    const localized = {
      'Turdus merula': 'Amsel',
      'Fringilla coelebs': 'Buchfink',
      'Parus major': 'Kohlmeise',
    };

    final result = buildLiveDetectionDisplayList(
      currentDetections: const [],
      sessionDetections: session,
      showAllDetectedSpecies: true,
      sortMode: DetectedSpeciesSortMode.alphabetical,
      localizedCommonName: (detection) => localized[detection.scientificName]!,
    );

    expect(result.map((d) => d.scientificName), [
      'Turdus merula',
      'Fringilla coelebs',
      'Parus major',
    ]);
  });

  test(
    'floats currently vocalizing species to the top by confidence for newest '
    'first',
    () {
      final base = DateTime(2026, 7, 5, 10);
      final session = [
        record('C', base.add(const Duration(minutes: 2))),
        record('A', base.add(const Duration(minutes: 1))),
        record('B', base),
      ];
      // A started its current streak later than C, but C is louder this cycle.
      // Active species must be ordered by current confidence, not streak start,
      // so C outranks A even though A's streak is newer.
      final current = [
        DetectionRecord(
          scientificName: 'A',
          commonName: 'A',
          confidence: 0.7,
          timestamp: base.add(const Duration(minutes: 5)),
        ),
        DetectionRecord(
          scientificName: 'C',
          commonName: 'C',
          confidence: 0.9,
          timestamp: base.add(const Duration(minutes: 4)),
        ),
      ];

      final result = buildLiveDetectionDisplayList(
        currentDetections: current,
        sessionDetections: session,
        showAllDetectedSpecies: true,
        sortMode: DetectedSpeciesSortMode.newest,
      );

      // C, A (active, by confidence desc) then B (retained).
      expect(result.map((d) => d.scientificName), ['C', 'A', 'B']);
      expect(result.first.confidence, 0.9);
    },
  );

  test('uses current confidence for active species in all-species mode', () {
    final base = DateTime(2026, 7, 5, 10);
    final session = [
      DetectionRecord(
        scientificName: 'A',
        commonName: 'A',
        confidence: 0.95,
        timestamp: base,
      ),
    ];
    final current = [
      DetectionRecord(
        scientificName: 'A',
        commonName: 'A',
        confidence: 0.42,
        timestamp: base.add(const Duration(seconds: 3)),
      ),
    ];

    final result = buildLiveDetectionDisplayList(
      currentDetections: current,
      sessionDetections: session,
      showAllDetectedSpecies: true,
      sortMode: DetectedSpeciesSortMode.newest,
    );

    expect(result.single.confidence, 0.42);
  });

  test('sorts species by confidence', () {
    final base = DateTime(2026, 7, 5, 10);
    final session = [
      DetectionRecord(
        scientificName: 'A',
        commonName: 'A',
        confidence: 0.3,
        timestamp: base.add(const Duration(minutes: 2)),
      ),
      DetectionRecord(
        scientificName: 'B',
        commonName: 'B',
        confidence: 0.9,
        timestamp: base.add(const Duration(minutes: 1)),
      ),
      DetectionRecord(
        scientificName: 'C',
        commonName: 'C',
        confidence: 0.6,
        timestamp: base,
      ),
    ];

    final result = buildLiveDetectionDisplayList(
      currentDetections: const [],
      sessionDetections: session,
      showAllDetectedSpecies: true,
      sortMode: DetectedSpeciesSortMode.confidence,
    );

    expect(result.map((d) => d.scientificName), ['B', 'C', 'A']);
  });

  test('sorts species by the maximum confidence ever reached', () {
    final base = DateTime(2026, 7, 5, 10);
    // Species A peaked at 0.95 in an earlier window but its most recent
    // (newest, current) record is only 0.20. Confidence sorting must use the
    // peak, so A still outranks B whose best is 0.60.
    final session = [
      DetectionRecord(
        scientificName: 'A',
        commonName: 'A',
        confidence: 0.20,
        timestamp: base.add(const Duration(minutes: 2)),
        endTimestamp: base.add(const Duration(minutes: 2, seconds: 3)),
      ),
      DetectionRecord(
        scientificName: 'B',
        commonName: 'B',
        confidence: 0.60,
        timestamp: base.add(const Duration(minutes: 1)),
        endTimestamp: base.add(const Duration(minutes: 1, seconds: 3)),
      ),
      DetectionRecord(
        scientificName: 'A',
        commonName: 'A',
        confidence: 0.95,
        timestamp: base,
        endTimestamp: base.add(const Duration(seconds: 3)),
      ),
    ];

    final result = buildLiveDetectionDisplayList(
      currentDetections: const [],
      sessionDetections: session,
      showAllDetectedSpecies: true,
      sortMode: DetectedSpeciesSortMode.confidence,
    );

    expect(result.map((d) => d.scientificName), ['A', 'B']);
  });

  test('sorts species by occurrence count', () {
    final base = DateTime(2026, 7, 5, 10);
    final session = [
      record('A', base.add(const Duration(minutes: 5))),
      record('B', base.add(const Duration(minutes: 4))),
      record('C', base.add(const Duration(minutes: 3))),
      record('B', base.add(const Duration(minutes: 2))),
      record('C', base.add(const Duration(minutes: 1))),
      record('C', base),
    ];

    final result = buildLiveDetectionDisplayList(
      currentDetections: const [],
      sessionDetections: session,
      showAllDetectedSpecies: true,
      sortMode: DetectedSpeciesSortMode.occurrences,
    );

    expect(result.map((d) => d.scientificName), ['C', 'B', 'A']);
  });

  test('collapses inactive repeats in all-species mode', () {
    final base = DateTime(2026, 7, 5, 10);
    final session = [
      record('B', base.add(const Duration(minutes: 3))),
      record('C', base.add(const Duration(minutes: 2))),
      record('B', base),
    ];

    final result = buildLiveDetectionDisplayList(
      currentDetections: const [],
      sessionDetections: session,
      showAllDetectedSpecies: true,
      sortMode: DetectedSpeciesSortMode.newest,
    );

    expect(result.map((d) => d.scientificName), ['B', 'C']);
  });

  test('keeps the saved end time for retained all-species rows', () {
    final start = DateTime(2026, 7, 5, 10);
    final end = start.add(const Duration(seconds: 12));
    final session = [closedRecord('A', start, end)];

    final result = buildLiveDetectionDisplayList(
      currentDetections: const [],
      sessionDetections: session,
      showAllDetectedSpecies: true,
      sortMode: DetectedSpeciesSortMode.newest,
    );

    expect(result.single.endTimestamp, end);
  });

  test('reports the highest confidence per species', () {
    final base = DateTime(2026, 7, 5, 10);
    DetectionRecord scored(String name, double confidence, int minute) {
      return DetectionRecord(
        scientificName: name,
        commonName: name,
        confidence: confidence,
        timestamp: base.add(Duration(minutes: minute)),
      );
    }

    final maxima = buildSpeciesMaxConfidences(
      sessionDetections: [
        scored('A', 0.20, 2),
        scored('B', 0.60, 1),
        scored('A', 0.95, 0),
      ],
      // The current cycle can run ahead of the saved session records.
      currentDetections: [scored('B', 0.70, 3), scored('C', 0.40, 3)],
    );

    expect(maxima, {'A': 0.95, 'B': 0.70, 'C': 0.40});
  });

  test('counts cumulative detection events by species', () {
    final base = DateTime(2026, 7, 5, 10);
    final counts = buildSpeciesDetectionCounts([
      record('A', base.add(const Duration(minutes: 2))),
      record('B', base.add(const Duration(minutes: 1))),
      record('A', base),
    ]);

    expect(counts, {'A': 2, 'B': 1});
  });
}
