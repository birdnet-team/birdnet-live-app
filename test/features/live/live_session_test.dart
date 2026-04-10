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
      expect(session.type, SessionType.live);
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
      expect(roundTripped.type, SessionType.live);
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
      // Default type (live) is omitted from JSON.
      expect(json.containsKey('type'), isFalse);
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

  // ── SessionType ────────────────────────────────────────────────────────

  group('SessionType', () {
    test('default type is live', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime.now(),
        settings: testSettings,
      );
      expect(session.type, SessionType.live);
    });

    test('non-default type round-trips through JSON', () {
      final session = LiveSession(
        id: 'test-survey',
        startTime: DateTime(2026, 4, 1, 9, 0),
        type: SessionType.survey,
        settings: testSettings,
      );
      session.endTime = DateTime(2026, 4, 1, 10, 0);

      final jsonStr = jsonEncode(session.toJson());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['type'], 'survey');

      final rt = LiveSession.fromJson(decoded);
      expect(rt.type, SessionType.survey);
    });

    test('all session types round-trip', () {
      for (final type in SessionType.values) {
        final session = LiveSession(
          id: 'test-${type.name}',
          startTime: DateTime(2026, 4, 1),
          type: type,
          settings: testSettings,
        );

        final json = session.toJson();
        final rt = LiveSession.fromJson(json);
        expect(rt.type, type);
      }
    });

    test('missing type in JSON defaults to live', () {
      final json = {
        'id': 'old-session',
        'startTime': DateTime(2026, 1, 1).toIso8601String(),
        'settings': testSettings.toJson(),
      };
      final session = LiveSession.fromJson(json);
      expect(session.type, SessionType.live);
    });
  });

  // ── DetectionSource ────────────────────────────────────────────────────

  group('DetectionSource', () {
    test('default source is auto', () {
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime.now(),
      );
      expect(record.source, DetectionSource.auto);
    });

    test('manual source round-trips through JSON', () {
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime(2026, 3, 1, 10, 0),
        source: DetectionSource.manual,
      );

      final json = record.toJson();
      expect(json['source'], 'manual');

      final roundTripped = DetectionRecord.fromJson(json);
      expect(roundTripped.source, DetectionSource.manual);
    });

    test('auto source omitted from JSON', () {
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime.now(),
        source: DetectionSource.auto,
      );

      final json = record.toJson();
      expect(json.containsKey('source'), isFalse);
    });

    test('fromJson defaults to auto when source missing', () {
      final json = {
        'scientificName': 'Turdus merula',
        'commonName': 'Eurasian Blackbird',
        'confidence': 0.85,
        'timestamp': DateTime.now().toIso8601String(),
      };
      final record = DetectionRecord.fromJson(json);
      expect(record.source, DetectionSource.auto);
    });
  });

  // ── Unknown species ────────────────────────────────────────────────────

  group('Unknown species', () {
    test('unknown species constants', () {
      expect(DetectionRecord.unknownSpeciesName, 'Unknown species');
      expect(DetectionRecord.unknownCommonName, 'Unknown / Other');
    });

    test('isUnknown returns true for unknown species', () {
      final record = DetectionRecord(
        scientificName: DetectionRecord.unknownSpeciesName,
        commonName: DetectionRecord.unknownCommonName,
        confidence: 1.0,
        timestamp: DateTime.now(),
        source: DetectionSource.manual,
      );
      expect(record.isUnknown, isTrue);
    });

    test('isUnknown returns false for regular species', () {
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime.now(),
      );
      expect(record.isUnknown, isFalse);
    });
  });

  // ── SessionAnnotation ──────────────────────────────────────────────────

  group('SessionAnnotation', () {
    test('creates global annotation (no offset)', () {
      final annotation = SessionAnnotation(
        text: 'Clear morning at the city pond',
        createdAt: DateTime(2026, 3, 1, 10, 0),
      );
      expect(annotation.text, 'Clear morning at the city pond');
      expect(annotation.offsetInRecording, isNull);
    });

    test('creates timestamped annotation', () {
      final annotation = SessionAnnotation(
        text: 'Interesting call pattern',
        createdAt: DateTime(2026, 3, 1, 10, 5),
        offsetInRecording: 120.5,
      );
      expect(annotation.offsetInRecording, 120.5);
    });

    test('toJson / fromJson round-trip for global annotation', () {
      final annotation = SessionAnnotation(
        text: 'Cool, clear morning with light wind',
        createdAt: DateTime(2026, 3, 1, 10, 0),
      );

      final json = annotation.toJson();
      expect(json.containsKey('offsetInRecording'), isFalse);

      final roundTripped = SessionAnnotation.fromJson(json);
      expect(roundTripped.text, annotation.text);
      expect(roundTripped.createdAt, annotation.createdAt);
      expect(roundTripped.offsetInRecording, isNull);
    });

    test('toJson / fromJson round-trip for timestamped annotation', () {
      final annotation = SessionAnnotation(
        text: 'Woodpecker drumming here',
        createdAt: DateTime(2026, 3, 1, 10, 2),
        offsetInRecording: 65.3,
      );

      final json = annotation.toJson();
      expect(json['offsetInRecording'], 65.3);

      final roundTripped = SessionAnnotation.fromJson(json);
      expect(roundTripped.text, 'Woodpecker drumming here');
      expect(roundTripped.offsetInRecording, 65.3);
    });
  });

  // ── LiveSession annotations and trim ───────────────────────────────────

  group('LiveSession annotations & trim', () {
    test('annotations default to empty list', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime.now(),
        settings: testSettings,
      );
      expect(session.annotations, isEmpty);
    });

    test('trim offsets default to null', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime.now(),
        settings: testSettings,
      );
      expect(session.trimStartSec, isNull);
      expect(session.trimEndSec, isNull);
    });

    test('annotations round-trip through JSON', () {
      final session = LiveSession(
        id: 'test-annotated',
        startTime: DateTime(2026, 3, 1, 10, 0),
        settings: testSettings,
        annotations: [
          SessionAnnotation(
            text: 'Global note',
            createdAt: DateTime(2026, 3, 1, 10, 1),
          ),
          SessionAnnotation(
            text: 'Timestamped note',
            createdAt: DateTime(2026, 3, 1, 10, 2),
            offsetInRecording: 45.0,
          ),
        ],
      );
      session.endTime = DateTime(2026, 3, 1, 10, 30);

      final jsonStr = jsonEncode(session.toJson());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final rt = LiveSession.fromJson(decoded);

      expect(rt.annotations.length, 2);
      expect(rt.annotations[0].text, 'Global note');
      expect(rt.annotations[0].offsetInRecording, isNull);
      expect(rt.annotations[1].text, 'Timestamped note');
      expect(rt.annotations[1].offsetInRecording, 45.0);
    });

    test('trim offsets round-trip through JSON', () {
      final session = LiveSession(
        id: 'test-trimmed',
        startTime: DateTime(2026, 3, 1, 10, 0),
        settings: testSettings,
        trimStartSec: 5.0,
        trimEndSec: 295.0,
      );
      session.endTime = DateTime(2026, 3, 1, 10, 5);

      final jsonStr = jsonEncode(session.toJson());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final rt = LiveSession.fromJson(decoded);

      expect(rt.trimStartSec, 5.0);
      expect(rt.trimEndSec, 295.0);
    });

    test('toJson omits empty annotations and null trim', () {
      final session = LiveSession(
        id: 'test',
        startTime: DateTime.now(),
        settings: testSettings,
      );

      final json = session.toJson();
      expect(json.containsKey('annotations'), isFalse);
      expect(json.containsKey('trimStartSec'), isFalse);
      expect(json.containsKey('trimEndSec'), isFalse);
    });
  });
}
