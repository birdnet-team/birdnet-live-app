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
        'recordingMode': 'detectionsOnly',
        'recordingFormat': 'flac',
        'detectionSamplingMode': 'smart',
        'topNPerSpecies': 7,
        'gpsIntervalSeconds': 15,
        'maxDurationHours': 4,
        'targetDurationSeconds': 600,
        'autoStopBatteryPercent': 25,
        'backgroundGps': true,
      };
      final settings = SessionSettings.fromJson(json);

      expect(settings.windowDuration, 5);
      expect(settings.confidenceThreshold, 50);
      expect(settings.inferenceRate, 2.0);
      expect(settings.speciesFilterMode, 'geoMerge');
      expect(settings.recordingMode, 'detectionsOnly');
      expect(settings.recordingFormat, 'flac');
      expect(settings.detectionSamplingMode, 'smart');
      expect(settings.topNPerSpecies, 7);
      expect(settings.gpsIntervalSeconds, 15);
      expect(settings.maxDurationHours, 4);
      expect(settings.targetDurationSeconds, 600);
      expect(settings.autoStopBatteryPercent, 25);
      expect(settings.backgroundGps, isTrue);
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
        recordingMode: 'full',
        recordingFormat: 'wav',
        detectionSamplingMode: 'topN',
        topNPerSpecies: 5,
        gpsIntervalSeconds: 30,
        maxDurationHours: 8,
        targetDurationSeconds: 300,
        autoStopBatteryPercent: 10,
        backgroundGps: false,
      );
      final json = settings.toJson();
      final roundTripped = SessionSettings.fromJson(json);

      expect(roundTripped.windowDuration, 10);
      expect(roundTripped.confidenceThreshold, 75);
      expect(roundTripped.inferenceRate, 0.5);
      expect(roundTripped.speciesFilterMode, 'customList');
      expect(roundTripped.recordingMode, 'full');
      expect(roundTripped.recordingFormat, 'wav');
      expect(roundTripped.detectionSamplingMode, 'topN');
      expect(roundTripped.topNPerSpecies, 5);
      expect(roundTripped.gpsIntervalSeconds, 30);
      expect(roundTripped.maxDurationHours, 8);
      expect(roundTripped.targetDurationSeconds, 300);
      expect(roundTripped.autoStopBatteryPercent, 10);
      expect(roundTripped.backgroundGps, isFalse);
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
      expect(
        roundTripped.timestamp.isAtSameMomentAs(
          DateTime(2026, 2, 28, 14, 30, 0),
        ),
        isTrue,
      );
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

    test('confirmedAt defaults to null and isConfirmed is false', () {
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime.now(),
      );
      expect(record.confirmedAt, isNull);
      expect(record.isConfirmed, isFalse);
      expect(record.toJson().containsKey('confirmedAt'), isFalse);
    });

    test('confirmedAt round-trips as UTC ISO string', () {
      final confirmed = DateTime.utc(2026, 5, 6, 12, 30, 45);
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime(2026, 5, 6, 12, 0, 0),
        confirmedAt: confirmed,
      );

      final json = record.toJson();
      expect(json['confirmedAt'], endsWith('Z'));

      final roundTripped = DetectionRecord.fromJson(json);
      expect(roundTripped.isConfirmed, isTrue);
      expect(roundTripped.confirmedAt!.isAtSameMomentAs(confirmed), isTrue);
    });

    test('legacy JSON without confirmedAt deserializes with null', () {
      final json = {
        'scientificName': 'Turdus merula',
        'commonName': 'Eurasian Blackbird',
        'confidence': 0.85,
        'timestamp': '2026-05-06T12:00:00.000Z',
      };
      final record = DetectionRecord.fromJson(json);
      expect(record.confirmedAt, isNull);
      expect(record.isConfirmed, isFalse);
    });

    test('note defaults to null and hasNote is false', () {
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime.now(),
      );
      expect(record.note, isNull);
      expect(record.hasNote, isFalse);
      expect(record.toJson().containsKey('note'), isFalse);
    });

    test('note round-trips and whitespace-only is treated as empty', () {
      final record = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime(2026, 5, 6, 12, 0, 0),
        note: 'juvenile, distant call',
      );
      final json = record.toJson();
      expect(json['note'], 'juvenile, distant call');
      final roundTripped = DetectionRecord.fromJson(json);
      expect(roundTripped.note, 'juvenile, distant call');
      expect(roundTripped.hasNote, isTrue);

      final blank = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.85,
        timestamp: DateTime(2026, 5, 6, 12, 0, 0),
        note: '   ',
      );
      expect(blank.hasNote, isFalse);
      expect(blank.toJson().containsKey('note'), isFalse);
    });

    test('legacy JSON without note deserializes with null', () {
      final json = {
        'scientificName': 'Turdus merula',
        'commonName': 'Eurasian Blackbird',
        'confidence': 0.85,
        'timestamp': '2026-05-06T12:00:00.000Z',
      };
      final record = DetectionRecord.fromJson(json);
      expect(record.note, isNull);
      expect(record.hasNote, isFalse);
    });

    test(
      'voiceMemoPath defaults to null, round-trips, and is omitted when empty',
      () {
        final empty = DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.85,
          timestamp: DateTime(2026, 5, 6, 12, 0, 0),
        );
        expect(empty.voiceMemoPath, isNull);
        expect(empty.hasVoiceMemo, isFalse);
        expect(empty.toJson().containsKey('voiceMemoPath'), isFalse);

        final withMemo = DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.85,
          timestamp: DateTime(2026, 5, 6, 12, 0, 0),
          voiceMemoPath: '/data/recordings/abc/memos/memo_1.m4a',
        );
        final json = withMemo.toJson();
        expect(json['voiceMemoPath'], '/data/recordings/abc/memos/memo_1.m4a');
        final rt = DetectionRecord.fromJson(json);
        expect(rt.voiceMemoPath, '/data/recordings/abc/memos/memo_1.m4a');
        expect(rt.hasVoiceMemo, isTrue);

        // Legacy JSON without the field deserializes to null.
        final legacy = DetectionRecord.fromJson({
          'scientificName': 'Turdus merula',
          'commonName': 'Eurasian Blackbird',
          'confidence': 0.85,
          'timestamp': '2026-05-06T12:00:00.000Z',
        });
        expect(legacy.voiceMemoPath, isNull);
        expect(legacy.hasVoiceMemo, isFalse);
      },
    );

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

      session.addDetection(
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.85,
          timestamp: DateTime.now(),
        ),
      );
      session.addDetection(
        DetectionRecord(
          scientificName: 'Parus major',
          commonName: 'Great Tit',
          confidence: 0.72,
          timestamp: DateTime.now(),
        ),
      );

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
      session.addDetection(
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.85,
          timestamp: DateTime.now(),
        ),
      );
      session.addDetection(
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.90,
          timestamp: DateTime.now(),
        ),
      );

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

    test('ended recorded session duration ignores stale open segment', () {
      final start = DateTime(2026, 2, 28, 14, 0);
      final session = LiveSession(
        id: 'test',
        startTime: start,
        endTime: start.add(const Duration(minutes: 10)),
        type: SessionType.survey,
        settings: testSettings,
        recordedDurationSeconds: 600,
        segments: [
          SessionSegment(
            startTime: start,
            endTime: start.add(const Duration(minutes: 10)),
          ),
          SessionSegment(startTime: start.add(const Duration(minutes: 10))),
        ],
      );

      expect(session.duration, const Duration(minutes: 10));
    });

    test('startSegment does not reopen ended session', () {
      final start = DateTime(2026, 2, 28, 14, 0);
      final session = LiveSession(
        id: 'test',
        startTime: start,
        endTime: start.add(const Duration(minutes: 10)),
        settings: testSettings,
        segments: [
          SessionSegment(
            startTime: start,
            endTime: start.add(const Duration(minutes: 10)),
          ),
        ],
      );

      session.startSegment();

      expect(session.segments, hasLength(1));
      expect(session.segments.single.endTime, isNotNull);
    });

    test('resume opens a distinct segment and keeps accumulated time', () {
      final start = DateTime(2026, 2, 28, 14, 0);
      final session = LiveSession(
        id: 'test',
        startTime: start,
        endTime: start.add(const Duration(minutes: 10)),
        recordedDurationSeconds: 600,
        settings: testSettings,
        segments: [
          SessionSegment(
            startTime: start,
            endTime: start.add(const Duration(minutes: 10)),
          ),
        ],
      );

      // Guard: while stopped, startSegment must not reopen anything.
      session.startSegment();
      expect(session.segments, hasLength(1));

      session.resume();

      expect(session.segments, hasLength(2));
      expect(session.segments.last.endTime, isNull);
      // Duration continues from the accumulated 10 minutes plus the live
      // segment (a few ms of wall-clock), so it must exceed the base total.
      expect(
        session.duration,
        greaterThanOrEqualTo(const Duration(minutes: 10)),
      );
    });

    test('resume never merges a recently closed segment', () {
      final end = DateTime.now();
      final start = end.subtract(const Duration(minutes: 10));
      final session = LiveSession(
        id: 'test',
        startTime: start,
        endTime: end,
        recordedDurationSeconds: 600,
        settings: testSettings,
        segments: [SessionSegment(startTime: start, endTime: end)],
      );

      session.resume();

      expect(session.segments, hasLength(2));
      expect(session.segments.first.endTime, end);
      expect(session.segments.last.startTime, isNot(start));
      expect(session.segments.last.endTime, isNull);
    });

    test('resume seeds timing for a legacy session', () {
      final start = DateTime(2026, 2, 28, 14, 0);
      final end = start.add(const Duration(minutes: 10));
      final session = LiveSession(
        id: 'legacy',
        startTime: start,
        endTime: end,
        settings: testSettings,
      );

      session.resume();

      expect(session.recordedDurationSeconds, 600);
      expect(session.segments, hasLength(2));
      expect(session.segments.first.startTime, start);
      expect(session.segments.first.endTime, end);
      expect(
        session.duration,
        greaterThanOrEqualTo(const Duration(minutes: 10)),
      );
    });

    test('toJson closes stale open segment for ended session', () {
      final start = DateTime(2026, 2, 28, 14, 0);
      final end = start.add(const Duration(minutes: 10));
      final session = LiveSession(
        id: 'test',
        startTime: start,
        endTime: end,
        settings: testSettings,
        segments: [SessionSegment(startTime: start)],
      );

      final json = session.toJson();
      final segments = json['segments'] as List<dynamic>;
      final segment = segments.single as Map<String, dynamic>;

      expect(segment['endTime'], end.toUtc().toIso8601String());
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
      expect(
        roundTripped.startTime.isAtSameMomentAs(DateTime(2026, 2, 28, 14, 0)),
        isTrue,
      );
      expect(
        roundTripped.endTime!.isAtSameMomentAs(DateTime(2026, 2, 28, 15, 0)),
        isTrue,
      );
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
      session.addDetection(
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.85,
          timestamp: DateTime.now(),
        ),
      );

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
      expect(
        roundTripped.createdAt.isAtSameMomentAs(annotation.createdAt),
        isTrue,
      );
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

  group('applyDestructiveTrim', () {
    final start = DateTime.utc(2026, 3, 1, 10, 0, 0);

    LiveSession build({List<SessionSegment> segments = const []}) {
      final session = LiveSession(
        id: 'test-destructive-trim',
        startTime: start,
        settings: testSettings,
        segments: List.of(segments),
        trimStartSec: 60.0,
        trimEndSec: 200.0,
      );
      session.endTime = start.add(const Duration(minutes: 5));
      return session;
    }

    test('rebases a single-run session onto the retained stretch', () {
      final session = build();
      session.applyDestructiveTrim(startSec: 60.0, endSec: 200.0);

      // startTime is untouched — the session still began when it began.
      expect(session.startTime, start);
      expect(session.trimStartSec, isNull);
      expect(session.trimEndSec, isNull);
      expect(session.recordedDurationSeconds, 140);
      expect(session.duration, const Duration(seconds: 140));

      // Offsets now index the shorter recording.
      expect(
        session.absoluteToRelative(start.add(const Duration(seconds: 90))),
        closeTo(30.0, 0.001),
      );
      expect(
        session.relativeToAbsolute(30.0),
        start.add(const Duration(seconds: 90)),
      );
      expect(session.expectedRecordedAudioSeconds, closeTo(140.0, 0.001));
    });

    test('keeps every segment that overlaps the retained range', () {
      final session = build(
        segments: [
          SessionSegment(
            startTime: start,
            endTime: start.add(const Duration(seconds: 60)),
          ),
          SessionSegment(
            startTime: start.add(const Duration(seconds: 180)),
            endTime: start.add(const Duration(seconds: 240)),
          ),
        ],
      );
      // Audio is 120 s long (the gap is not recorded); keep 30 s–90 s of it.
      session.applyDestructiveTrim(startSec: 30.0, endSec: 90.0);

      expect(session.segments.length, 2);
      expect(
        session.segments.first.startTime,
        start.add(const Duration(seconds: 30)),
      );
      expect(
        session.segments.last.endTime,
        start.add(const Duration(seconds: 210)),
      );
      expect(session.recordedDurationSeconds, 60);
    });

    test('drops segments that fall entirely outside the range', () {
      final session = build(
        segments: [
          SessionSegment(
            startTime: start,
            endTime: start.add(const Duration(seconds: 60)),
          ),
          SessionSegment(
            startTime: start.add(const Duration(seconds: 180)),
            endTime: start.add(const Duration(seconds: 240)),
          ),
        ],
      );
      // Keep only the tail of the second segment.
      session.applyDestructiveTrim(startSec: 70.0, endSec: 120.0);

      expect(session.segments.length, 1);
      expect(
        session.segments.single.startTime,
        start.add(const Duration(seconds: 190)),
      );
      expect(
        session.segments.single.endTime,
        start.add(const Duration(seconds: 240)),
      );
      expect(
        session.absoluteToRelative(start.add(const Duration(seconds: 200))),
        closeTo(10.0, 0.001),
      );
    });

    test('measures the retained audio, not the requested range', () {
      final session = build();
      // The session's own timeline is 300 s; ask to keep past the end of it.
      session.applyDestructiveTrim(startSec: 240.0, endSec: 900.0);

      expect(session.recordedDurationSeconds, 60);
      expect(session.duration, const Duration(seconds: 60));
      expect(session.expectedRecordedAudioSeconds, closeTo(60.0, 0.001));
    });

    test('keeps an audio tail that extends past the session clock', () {
      final session = build();
      session.endTime = start.add(const Duration(seconds: 299));
      final tailDetection = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Common Blackbird',
        confidence: 0.8,
        timestamp: start.add(const Duration(milliseconds: 299200)),
        endTimestamp: start.add(const Duration(milliseconds: 299800)),
      );
      session.detections.add(tailDetection);

      // The committed file contained one more second than the wall-clock
      // session. That final second still needs a timeline after the cut.
      session.applyDestructiveTrim(startSec: 299.0, endSec: 300.0);

      expect(session.trimStartSec, isNull);
      expect(session.trimEndSec, isNull);
      expect(session.segments, hasLength(1));
      expect(
        session.segments.single.startTime,
        start.add(const Duration(seconds: 299)),
      );
      expect(
        session.segments.single.endTime,
        start.add(const Duration(seconds: 300)),
      );
      expect(session.recordedDurationSeconds, 1);
      expect(session.detections, [same(tailDetection)]);
    });

    test('drops detections whose audio was cut away', () {
      final session = build();
      DetectionRecord detection(int atSec) => DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Common Blackbird',
        confidence: 0.8,
        timestamp: start.add(Duration(seconds: atSec)),
      );
      final before = detection(10);
      final inside = detection(90);
      final after = detection(280);
      session.detections.addAll([before, inside, after]);

      session.applyDestructiveTrim(startSec: 60.0, endSec: 200.0);

      expect(session.detections, [same(inside)]);
      // Capture time is untouched; only the mapping into the file moved.
      expect(session.detections.single.timestamp, inside.timestamp);
      expect(
        session.absoluteToRelative(inside.timestamp),
        closeTo(30.0, 0.001),
      );
    });

    test('leaves the session alone when nothing survives the cut', () {
      final session = build();
      session.applyDestructiveTrim(startSec: 600.0, endSec: 700.0);

      expect(session.segments, isEmpty);
      expect(session.trimStartSec, 60.0);
      expect(session.trimEndSec, 200.0);
    });

    test('round-trips the rebased timeline through JSON', () {
      final session = build();
      session.applyDestructiveTrim(startSec: 60.0, endSec: 200.0);

      final rt = LiveSession.fromJson(
        jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
      );
      expect(rt.trimStartSec, isNull);
      expect(rt.segments.length, 1);
      expect(rt.recordedDurationSeconds, 140);
      expect(
        rt.absoluteToRelative(start.add(const Duration(seconds: 90))),
        closeTo(30.0, 0.001),
      );
    });
  });
}
