// =============================================================================
// LiveSession Tests
// =============================================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/inference/models/detection.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/live/live_session.dart';

void main() {
  // ── Test data ──────────────────────────────────────────────────────────

  final testSpecies = Species(
    index: 0,
    id: 1,
    scientificName: 'Turdus merula',
    commonName: 'Eurasian Blackbird',
    className: 'Aves',
    order: 'Passeriformes',
  );

  final testDetection = Detection(
    species: testSpecies,
    confidence: 0.85,
    timestamp: DateTime(2026, 2, 28, 14, 30, 0),
  );

  final testSettings = SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 25,
    inferenceRate: 1.0,
    speciesFilterMode: 'off',
  );

  // ── SessionSettings ────────────────────────────────────────────────────

  group('SessionSettings', () {
    test('fromJson parses all fields', () {
      final json = {
        'windowDuration': 5,
        'confidenceThreshold': 50,
        'inferenceRate': 2.0,
        'speciesFilterMode': 'geoMerge',
      };
      final settings = SessionSettings.fromJson(json);

      expect(settings.windowDuration, 5);
      expect(settings.confidenceThreshold, 50);
      expect(settings.inferenceRate, 2.0);
      expect(settings.speciesFilterMode, 'geoMerge');
    });

    test('fromJson uses defaults for missing fields', () {
      final settings = SessionSettings.fromJson({});

      expect(settings.windowDuration, 3);
      expect(settings.confidenceThreshold, 25);
      expect(settings.inferenceRate, 1.0);
      expect(settings.speciesFilterMode, 'off');
    });

    test('toJson round-trip', () {
      final settings = SessionSettings(
        windowDuration: 10,
        confidenceThreshold: 75,
        inferenceRate: 0.5,
        speciesFilterMode: 'customList',
      );
      final json = settings.toJson();
      final roundTripped = SessionSettings.fromJson(json);

      expect(roundTripped.windowDuration, 10);
      expect(roundTripped.confidenceThreshold, 75);
      expect(roundTripped.inferenceRate, 0.5);
      expect(roundTripped.speciesFilterMode, 'customList');
    });
  });

  // ── DetectionRecord ────────────────────────────────────────────────────

  group('DetectionRecord', () {
    test('fromDetection creates correct record', () {
      final record = DetectionRecord.fromDetection(
        testDetection,
        audioClipPath: '/tmp/clip.wav',
      );

      expect(record.scientificName, 'Turdus merula');
      expect(record.commonName, 'Eurasian Blackbird');
      expect(record.confidence, 0.85);
      expect(record.timestamp, DateTime(2026, 2, 28, 14, 30, 0));
      expect(record.audioClipPath, '/tmp/clip.wav');
    });

    test('fromDetection without clip path', () {
      final record = DetectionRecord.fromDetection(testDetection);

      expect(record.audioClipPath, isNull);
    });

    test('confidencePercent formats correctly', () {
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.873,
        timestamp: DateTime.now(),
      );

      expect(record.confidencePercent, '87.3 %');
    });

    test('toJson / fromJson round-trip', () {
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime(2026, 2, 28, 14, 30, 0),
        audioClipPath: '/recordings/clip.wav',
      );

      final json = record.toJson();
      final roundTripped = DetectionRecord.fromJson(json);

      expect(roundTripped.scientificName, 'Turdus merula');
      expect(roundTripped.commonName, 'Eurasian Blackbird');
      expect(roundTripped.confidence, 0.85);
      expect(roundTripped.timestamp, DateTime(2026, 2, 28, 14, 30, 0));
      expect(roundTripped.audioClipPath, '/recordings/clip.wav');
    });

    test('toJson omits null audioClipPath', () {
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime.now(),
      );

      final json = record.toJson();
      expect(json.containsKey('audioClipPath'), isFalse);
    });

    test('equality compares key fields', () {
      final ts = DateTime(2026, 2, 28, 14, 30, 0);
      final a = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: ts,
      );
      final b = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: ts,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('toString includes name and confidence', () {
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime.now(),
      );

      expect(record.toString(), contains('Eurasian Blackbird'));
      expect(record.toString(), contains('85.0'));
    });
  });

  // ── LiveSession ────────────────────────────────────────────────────────

  group('LiveSession', () {
    test('creates with defaults', () {
      final session = LiveSession(
        id: 'test-session-1',
        startTime: DateTime(2026, 2, 28, 14, 0),
        settings: testSettings,
      );

      expect(session.id, 'test-session-1');
      expect(session.endTime, isNull);
      expect(session.detections, isEmpty);
      expect(session.recordingPath, isNull);
      expect(session.isActive, isTrue);
      expect(session.uniqueSpeciesCount, 0);
    });

    test('addDetection accumulates detections', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime.now(),
        settings: testSettings,
      );

      session.addDetection(DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime.now(),
      ));
      session.addDetection(DetectionRecord(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        confidence: 0.72,
        timestamp: DateTime.now(),
      ));

      expect(session.detections.length, 2);
      expect(session.uniqueSpeciesCount, 2);
    });

    test('addDetections adds batch', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime.now(),
        settings: testSettings,
      );

      session.addDetections([
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.85,
          timestamp: DateTime.now(),
        ),
        DetectionRecord(
          scientificName: 'Parus major',
          commonName: 'Great Tit',
          confidence: 0.72,
          timestamp: DateTime.now(),
        ),
      ]);

      expect(session.detections.length, 2);
    });

    test('uniqueSpeciesCount deduplicates', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime.now(),
        settings: testSettings,
      );

      // Same species detected twice.
      session.addDetection(DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime.now(),
      ));
      session.addDetection(DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.90,
        timestamp: DateTime.now(),
      ));

      expect(session.detections.length, 2);
      expect(session.uniqueSpeciesCount, 1);
    });

    test('end() sets endTime and isActive', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime(2026, 2, 28, 14, 0),
        settings: testSettings,
      );

      expect(session.isActive, isTrue);
      session.end();
      expect(session.isActive, isFalse);
      expect(session.endTime, isNotNull);
    });

    test('end() is idempotent', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime(2026, 2, 28, 14, 0),
        settings: testSettings,
      );

      session.end();
      final endTime = session.endTime;
      session.end(); // Should not change.
      expect(session.endTime, endTime);
    });

    test('duration calculates correctly for ended session', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime(2026, 2, 28, 14, 0),
        settings: testSettings,
      );
      session.endTime = DateTime(2026, 2, 28, 14, 30);

      expect(session.duration, const Duration(minutes: 30));
    });

    test('toJson / fromJson round-trip', () {
      final session = LiveSession(
        id: 'session-2026',
        startTime: DateTime(2026, 2, 28, 14, 0),
        settings: testSettings,
        detections: [
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.85,
            timestamp: DateTime(2026, 2, 28, 14, 5),
            audioClipPath: '/clips/clip1.wav',
          ),
        ],
        recordingPath: '/recordings/full.wav',
      );
      session.endTime = DateTime(2026, 2, 28, 15, 0);

      final jsonStr = jsonEncode(session.toJson());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final roundTripped = LiveSession.fromJson(decoded);

      expect(roundTripped.id, 'session-2026');
      expect(roundTripped.startTime, DateTime(2026, 2, 28, 14, 0));
      expect(roundTripped.endTime, DateTime(2026, 2, 28, 15, 0));
      expect(roundTripped.detections.length, 1);
      expect(roundTripped.detections[0].scientificName, 'Turdus merula');
      expect(roundTripped.detections[0].audioClipPath, '/clips/clip1.wav');
      expect(roundTripped.recordingPath, '/recordings/full.wav');
      expect(roundTripped.settings.windowDuration, 3);
    });

    test('toJson omits null fields', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime.now(),
        settings: testSettings,
      );

      final json = session.toJson();
      expect(json.containsKey('endTime'), isFalse);
      expect(json.containsKey('recordingPath'), isFalse);
    });

    test('toString includes key info', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime.now(),
        settings: testSettings,
      );
      session.addDetection(DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime.now(),
      ));

      expect(session.toString(), contains('test'));
      expect(session.toString(), contains('1 detections'));
      expect(session.toString(), contains('1 species'));
    });
  });
}
