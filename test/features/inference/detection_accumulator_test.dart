import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/inference/detection_accumulator.dart';
import 'package:birdnet_live/features/inference/models/detection.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/live/live_session.dart';

void main() {
  const species = Species(
    index: 0,
    id: 1,
    scientificName: 'Turdus merula',
    commonName: 'Common Blackbird',
    className: 'Aves',
    order: 'Passeriformes',
  );
  final start = DateTime.utc(2026, 8, 6, 12);

  Detection detection(double confidence, DateTime timestamp) =>
      Detection(species: species, confidence: confidence, timestamp: timestamp);

  test('three mode accumulators produce identical canonical records', () {
    final modeRecords = [
      <DetectionRecord>[],
      <DetectionRecord>[],
      <DetectionRecord>[],
    ];
    final accumulators = [
      for (final records in modeRecords)
        DetectionAccumulator(sessionStart: start, records: records),
    ];

    for (final accumulator in accumulators) {
      accumulator.processCycle(
        detections: [detection(0.6, start)],
        windowEnd: start.add(const Duration(seconds: 3)),
      );
      accumulator.processCycle(
        detections: [detection(0.9, start.add(const Duration(seconds: 1)))],
        windowEnd: start.add(const Duration(seconds: 4)),
      );
      accumulator.processCycle(
        detections: const [],
        windowEnd: start.add(const Duration(seconds: 5)),
      );
    }

    final expected = modeRecords.first.single;
    for (final records in modeRecords.skip(1)) {
      final actual = records.single;
      expect(actual.scientificName, expected.scientificName);
      expect(actual.confidence, expected.confidence);
      expect(actual.timestamp, expected.timestamp);
      expect(actual.endTimestamp, expected.endTimestamp);
    }
    expect(expected.confidence, 0.9);
    expect(expected.endTimestamp, start.add(const Duration(seconds: 4)));
  });

  test('clamps startup timestamp once and keeps later updates connected', () {
    final records = <DetectionRecord>[];
    final accumulator = DetectionAccumulator(
      sessionStart: start,
      records: records,
    );

    accumulator.processCycle(
      detections: [detection(0.6, start.subtract(const Duration(seconds: 2)))],
      windowEnd: start.add(const Duration(seconds: 1)),
    );
    accumulator.processCycle(
      detections: [detection(0.8, start.subtract(const Duration(seconds: 1)))],
      windowEnd: start.add(const Duration(seconds: 2)),
    );
    accumulator.closeAll();

    expect(records, hasLength(1));
    expect(records.single.timestamp, start);
    expect(records.single.confidence, 0.8);
    expect(records.single.endTimestamp, start.add(const Duration(seconds: 2)));
  });

  test('a species returning at a pooled start gets its own record', () {
    // Pooling dates a detection at its earliest supporting window, so a
    // species that drops out and returns can be handed the start of the
    // record that just closed.
    final records = <DetectionRecord>[];
    final accumulator = DetectionAccumulator(
      sessionStart: start,
      records: records,
    );

    accumulator.processCycle(
      detections: [detection(0.6, start)],
      windowEnd: start.add(const Duration(seconds: 3)),
    );
    accumulator.processCycle(
      detections: const [],
      windowEnd: start.add(const Duration(seconds: 4)),
    );
    accumulator.processCycle(
      detections: [detection(0.8, start)], // Same start as the closed record.
      windowEnd: start.add(const Duration(seconds: 5)),
    );
    accumulator.closeAll();

    expect(records, hasLength(2));
    expect(records[0].timestamp, isNot(records[1].timestamp));
    expect(records[0].confidence, 0.6);
    expect(records[1].confidence, 0.8);

    // Each record must be individually addressable, or a clip cut for the
    // second would be attached to — and delete the audio of — the first.
    final reopened = records[1];
    final located = accumulator.recordFor(
      scientificName: reopened.scientificName,
      timestamp: reopened.timestamp,
    );
    expect(identical(located, reopened), isTrue);
  });

  test('the record ceiling is opt-out for bounded inputs', () {
    Species speciesNamed(int i) => Species(
      index: i,
      id: i,
      scientificName: 'Species $i',
      commonName: 'Common $i',
      className: 'Aves',
      order: 'Passeriformes',
    );

    // A capped accumulator stops recording new species; File Analysis passes
    // null because truncating a file's results would under-report it.
    for (final limit in [2, null]) {
      final records = <DetectionRecord>[];
      final accumulator = DetectionAccumulator(
        sessionStart: start,
        records: records,
        maxRecords: limit,
      );
      for (var i = 0; i < 5; i++) {
        accumulator.processCycle(
          detections: [
            Detection(
              species: speciesNamed(i),
              confidence: 0.6,
              timestamp: start.add(Duration(seconds: i)),
            ),
          ],
          windowEnd: start.add(Duration(seconds: i + 3)),
        );
      }
      expect(records, hasLength(limit ?? 5));
    }
  });

  test('confidence and close replacements preserve review metadata', () {
    final reviewedAt = start.add(const Duration(seconds: 1));
    final records = <DetectionRecord>[];
    final accumulator = DetectionAccumulator(
      sessionStart: start,
      records: records,
    );
    accumulator.processCycle(
      detections: [detection(0.6, start)],
      windowEnd: start.add(const Duration(seconds: 3)),
      createRecord:
          (detection, timestamp) => DetectionRecord(
            scientificName: detection.species.scientificName,
            commonName: detection.species.commonName,
            confidence: detection.confidence,
            timestamp: timestamp,
            reviewStatus: ReviewStatus.confirmed,
            reviewedAt: reviewedAt,
            note: 'field note',
            voiceMemoPath: '/memo.m4a',
          ),
    );
    accumulator.processCycle(
      detections: [detection(0.9, start)],
      windowEnd: start.add(const Duration(seconds: 4)),
    );
    accumulator.closeAll();

    expect(records.single.reviewStatus, ReviewStatus.confirmed);
    expect(records.single.reviewedAt, reviewedAt);
    expect(records.single.note, 'field note');
    expect(records.single.voiceMemoPath, '/memo.m4a');
  });

  test('repairs its canonical index after an external list mutation', () {
    final records = <DetectionRecord>[];
    final accumulator = DetectionAccumulator(
      sessionStart: start,
      records: records,
    );
    accumulator.processCycle(
      detections: [detection(0.6, start)],
      windowEnd: start.add(const Duration(seconds: 3)),
    );

    // Survey can append manual records outside the accumulator. Reordering is
    // not part of the normal controller path, but validating the cache keeps
    // the shared primitive safe for any such external list edit.
    records.insert(
      0,
      DetectionRecord(
        scientificName: 'Manual species',
        commonName: 'Manual species',
        confidence: 1,
        timestamp: start.add(const Duration(seconds: 1)),
      ),
    );

    accumulator.processCycle(
      detections: [detection(0.9, start)],
      windowEnd: start.add(const Duration(seconds: 4)),
    );
    accumulator.closeAll();

    expect(records[0].scientificName, 'Manual species');
    expect(records[1].confidence, 0.9);
    expect(records[1].endTimestamp, start.add(const Duration(seconds: 4)));
  });
}
