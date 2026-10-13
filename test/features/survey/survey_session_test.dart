// =============================================================================
// Survey Session Serialization Tests — GPS track, distance, metadata
// =============================================================================

import 'dart:convert';

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/survey/survey_gps_tracker.dart';
import 'package:birdnet_live/shared/models/altitude_reference.dart';
import 'package:birdnet_live/shared/models/gps_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2025, 7, 1, 8, 0, 0);
  final settings = SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 25,
    inferenceRate: 1.0,
    speciesFilterMode: 'off',
  );

  test('track simplification keeps a significant altitude change', () {
    final tracker = SurveyGpsTracker();
    tracker.seedTrack([
      GpsPoint(
        latitude: 52.52,
        longitude: 13.405,
        timestamp: start,
        altitude: 0,
        altitudeAccuracy: 2,
      ),
      GpsPoint(
        latitude: 52.52,
        longitude: 13.405,
        timestamp: start.add(const Duration(seconds: 10)),
        altitude: 30,
        altitudeAccuracy: 2,
      ),
      GpsPoint(
        latitude: 52.52,
        longitude: 13.405,
        timestamp: start.add(const Duration(seconds: 20)),
        altitude: 0,
        altitudeAccuracy: 2,
      ),
    ]);

    tracker.simplifyTrack(toleranceMeters: 10);
    expect(tracker.track, hasLength(3));
  });

  test('last fix keeps tagging a stationary observer', () {
    // A distance-filtered stream emits nothing while standing still, so the
    // latest fix must not expire; detections would otherwise fall back to
    // the survey start coordinates.
    final fix = GpsPoint(
      latitude: 52.52,
      longitude: 13.405,
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      altitude: 34.5,
    );
    final tracker = SurveyGpsTracker()..seedTrack([fix]);
    expect(tracker.lastPoint, same(fix));
  });

  test('resumed track only uses measured points as the latest fix', () {
    final measured = GpsPoint(
      latitude: 52.52,
      longitude: 13.405,
      timestamp: start,
      altitude: 34.5,
    );
    final interpolated = GpsPoint(
      latitude: 52.53,
      longitude: 13.406,
      timestamp: start.add(const Duration(seconds: 10)),
      measured: false,
    );
    final tracker = SurveyGpsTracker()..seedTrack([measured, interpolated]);
    expect(tracker.lastPoint, same(measured));

    tracker.seedTrack([interpolated]);
    expect(tracker.lastPoint, isNull);
  });

  group('SurveyGpsTracker.positionAt', () {
    final a = GpsPoint(
      latitude: 52.0,
      longitude: 13.0,
      timestamp: start,
      altitude: 100,
      altitudeAccuracy: 4,
      altitudeReference: AltitudeReference.meanSeaLevel,
    );
    final b = GpsPoint(
      latitude: 52.1,
      longitude: 13.2,
      timestamp: start.add(const Duration(seconds: 100)),
      altitude: 120,
      altitudeAccuracy: 6,
      altitudeReference: AltitudeReference.meanSeaLevel,
    );

    test('interpolates position and height between fixes', () {
      final p = SurveyGpsTracker.positionAt([
        a,
        b,
      ], start.add(const Duration(seconds: 25)))!;
      expect(p.latitude, closeTo(52.025, 1e-9));
      expect(p.longitude, closeTo(13.05, 1e-9));
      expect(p.altitude, closeTo(105, 1e-9));
      expect(p.altitudeAccuracy, 6);
      expect(p.altitudeReference, AltitudeReference.meanSeaLevel);
      expect(p.measured, isFalse);
    });

    test('clamps to the track ends and returns null without a track', () {
      final before = start.subtract(const Duration(minutes: 1));
      final after = start.add(const Duration(hours: 1));
      expect(SurveyGpsTracker.positionAt([a, b], before), same(a));
      expect(SurveyGpsTracker.positionAt([a, b], after), same(b));
      expect(SurveyGpsTracker.positionAt([], start), isNull);
    });

    test('omits height when the references differ', () {
      final c = GpsPoint(
        latitude: b.latitude,
        longitude: b.longitude,
        timestamp: b.timestamp,
        altitude: 120,
        altitudeReference: AltitudeReference.unknown,
      );
      final p = SurveyGpsTracker.positionAt([
        a,
        c,
      ], start.add(const Duration(seconds: 50)))!;
      expect(p.latitude, closeTo(52.05, 1e-9));
      expect(p.altitude, isNull);
      expect(p.altitudeReference, isNull);
    });
  });

  group('LiveSession survey fields', () {
    test('roundtrips gpsTrack through JSON', () {
      final session = LiveSession(
        id: 'test-survey',
        startTime: start,
        endTime: start.add(const Duration(hours: 1)),
        type: SessionType.survey,
        settings: settings,
        gpsTrack: [
          GpsPoint(
            latitude: 52.52,
            longitude: 13.405,
            timestamp: start,
            altitude: 34.5,
          ),
          GpsPoint(
            latitude: 52.521,
            longitude: 13.406,
            timestamp: start.add(const Duration(seconds: 10)),
          ),
        ],
        distanceMeters: 150.5,
        transectId: 'T-001',
        observerName: 'Jane Doe',
      );

      final json = session.toJson();
      final restored = LiveSession.fromJson(json);

      expect(restored.type, SessionType.survey);
      expect(restored.gpsTrack.length, 2);
      expect(restored.gpsTrack[0].latitude, 52.52);
      expect(restored.gpsTrack[0].altitude, 34.5);
      expect(restored.gpsTrack[1].latitude, 52.521);
      expect(restored.distanceMeters, 150.5);
      expect(restored.transectId, 'T-001');
      expect(restored.observerName, 'Jane Doe');
    });

    test('omits survey fields from JSON when null/empty', () {
      final session = LiveSession(
        id: 'test-live',
        startTime: start,
        settings: settings,
      );

      final json = session.toJson();
      expect(json.containsKey('gpsTrack'), isFalse);
      expect(json.containsKey('distanceMeters'), isFalse);
      expect(json.containsKey('transectId'), isFalse);
      expect(json.containsKey('observerName'), isFalse);
    });

    test('gpsTrack defaults to empty list', () {
      final session = LiveSession(
        id: 'test',
        startTime: start,
        settings: settings,
      );

      expect(session.gpsTrack, isEmpty);
    });

    test('DetectionRecord roundtrips lat/lon', () {
      final det = DetectionRecord(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        confidence: 0.85,
        timestamp: start,
        latitude: 52.52,
        longitude: 13.405,
      );

      final json = det.toJson();
      final restored = DetectionRecord.fromJson(json);

      expect(restored.latitude, 52.52);
      expect(restored.longitude, 13.405);
    });

    test('DetectionRecord without lat/lon serializes without those keys', () {
      final det = DetectionRecord(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        confidence: 0.85,
        timestamp: start,
      );

      final json = det.toJson();
      expect(json.containsKey('detLat'), isFalse);
      expect(json.containsKey('detLon'), isFalse);
    });

    test('full round-trip through JSON encode/decode', () {
      final session = LiveSession(
        id: 'roundtrip-survey',
        startTime: start,
        endTime: start.add(const Duration(hours: 2)),
        type: SessionType.survey,
        settings: settings,
        gpsTrack: [
          GpsPoint(latitude: 52.52, longitude: 13.405, timestamp: start),
        ],
        distanceMeters: 500,
        transectId: 'T-002',
        observerName: 'John',
        detections: [
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.9,
            timestamp: start.add(const Duration(minutes: 5)),
            latitude: 52.52,
            longitude: 13.405,
          ),
        ],
      );

      final jsonStr = jsonEncode(session.toJson());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = LiveSession.fromJson(decoded);

      expect(restored.type, SessionType.survey);
      expect(restored.gpsTrack.length, 1);
      expect(restored.detections.length, 1);
      expect(restored.detections.first.latitude, 52.52);
      expect(restored.distanceMeters, 500);
      expect(restored.transectId, 'T-002');
      expect(restored.observerName, 'John');
    });
  });
}
