// =============================================================================
// GPX Export Tests — Survey GPX generation
// =============================================================================

import 'package:birdnet_live/features/history/session_export.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/shared/models/gps_point.dart';
import 'package:birdnet_live/shared/models/altitude_reference.dart';
import 'package:flutter_test/flutter_test.dart';

LiveSession _makeSurveySession({
  List<DetectionRecord>? detections,
  List<GpsPoint>? gpsTrack,
  String? transectId,
  String? observerName,
}) {
  final start = DateTime.utc(2025, 7, 1, 8, 0, 0);
  return LiveSession(
    id: '2025-07-01T08-00-00',
    startTime: start,
    endTime: start.add(const Duration(hours: 2)),
    type: SessionType.survey,
    detections: detections,
    gpsTrack: gpsTrack ?? [],
    transectId: transectId,
    observerName: observerName,
    settings: SessionSettings(
      windowDuration: 3,
      confidenceThreshold: 25,
      inferenceRate: 1.0,
      speciesFilterMode: 'off',
    ),
  );
}

void main() {
  group('buildGpxExport', () {
    test('produces valid GPX 1.1 structure', () {
      final session = _makeSurveySession();
      final gpx = buildGpxExport(session);

      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx version="1.1"'));
      expect(gpx, contains('xmlns="http://www.topografix.com/GPX/1/1"'));
      expect(gpx, contains('</gpx>'));
    });

    test('includes metadata with session name and time', () {
      final session = _makeSurveySession();
      final gpx = buildGpxExport(session);

      expect(gpx, contains('<metadata>'));
      expect(gpx, contains('<name>'));
      expect(gpx, contains('<time>'));
      expect(gpx, contains('2025-07-01'));
    });

    test('includes observer name as author', () {
      final session = _makeSurveySession(observerName: 'Jane Doe');
      final gpx = buildGpxExport(session);

      expect(gpx, contains('<author>'));
      expect(gpx, contains('Jane Doe'));
      // GPX 1.1 requires <author> before <time> inside <metadata>.
      final metadata = gpx.substring(
        gpx.indexOf('<metadata>'),
        gpx.indexOf('</metadata>'),
      );
      expect(
        metadata.indexOf('<author>'),
        lessThan(metadata.indexOf('<time>')),
      );
    });

    test('omits author when no observer name', () {
      final session = _makeSurveySession();
      final gpx = buildGpxExport(session);

      expect(gpx, isNot(contains('<author>')));
    });

    test('includes detection waypoints with coordinates', () {
      final start = DateTime.utc(2025, 7, 1, 8, 0, 0);
      final session = _makeSurveySession(
        detections: [
          DetectionRecord(
            scientificName: 'Parus major',
            commonName: 'Great Tit',
            confidence: 0.85,
            timestamp: start.add(const Duration(minutes: 5)),
            latitude: 52.52,
            longitude: 13.405,
          ),
        ],
      );

      final gpx = buildGpxExport(session);
      expect(gpx, contains('<wpt lat="52.52" lon="13.405">'));
      expect(gpx, contains('<name>Great Tit</name>'));
      expect(gpx, contains('Parus major'));
      expect(gpx, contains('85.0%'));
    });

    test('reviewed waypoint follows GPX 1.1 child order', () {
      final ts = DateTime.utc(2025, 7, 1, 8);
      final session = _makeSurveySession(
        detections: [
          DetectionRecord(
            scientificName: 'Parus major',
            commonName: 'Great Tit',
            confidence: 0.85,
            timestamp: ts,
            latitude: 52.52,
            longitude: 13.405,
            altitude: 34.5,
            reviewStatus: ReviewStatus.confirmed,
            reviewedAt: ts,
          ),
        ],
      );

      final gpx = buildGpxExport(session);
      final waypoint = gpx.substring(
        gpx.indexOf('<wpt'),
        gpx.indexOf('</wpt>'),
      );
      expect(waypoint.indexOf('<name>'), lessThan(waypoint.indexOf('<cmt>')));
      expect(waypoint.indexOf('<cmt>'), lessThan(waypoint.indexOf('<desc>')));
      expect(waypoint.indexOf('<desc>'), lessThan(waypoint.indexOf('<sym>')));
      expect(
        waypoint.indexOf('<sym>'),
        lessThan(waypoint.indexOf('<extensions>')),
      );
    });

    test('skips detections without coordinates', () {
      final start = DateTime.utc(2025, 7, 1, 8, 0, 0);
      final session = _makeSurveySession(
        detections: [
          DetectionRecord(
            scientificName: 'Parus major',
            commonName: 'Great Tit',
            confidence: 0.85,
            timestamp: start.add(const Duration(minutes: 5)),
          ),
        ],
      );

      final gpx = buildGpxExport(session);
      expect(gpx, isNot(contains('<wpt')));
    });

    test('includes GPS track as trk element', () {
      final ts = DateTime.utc(2025, 7, 1, 8, 0, 0);
      final session = _makeSurveySession(
        transectId: 'T-001',
        gpsTrack: [
          GpsPoint(latitude: 52.52, longitude: 13.405, timestamp: ts),
          GpsPoint(
            latitude: 52.521,
            longitude: 13.406,
            timestamp: ts.add(const Duration(seconds: 10)),
            altitude: 35.0,
          ),
        ],
      );

      final gpx = buildGpxExport(session);
      expect(gpx, contains('<trk>'));
      expect(gpx, contains('<name>T-001</name>'));
      expect(gpx, contains('<trkseg>'));
      expect(gpx, contains('<trkpt lat="52.52" lon="13.405">'));
      expect(gpx, contains('<trkpt lat="52.521" lon="13.406">'));
      expect(gpx, contains('<ele>35.0</ele>'));
      expect(gpx, contains('</trkseg>'));
      expect(gpx, contains('</trk>'));
    });

    test(
      'exports waypoint and track height with reference and uncertainty',
      () {
        final ts = DateTime.utc(2025, 7, 1, 8);
        final session = _makeSurveySession(
          detections: [
            DetectionRecord(
              scientificName: 'Turdus merula',
              commonName: 'Eurasian Blackbird',
              confidence: 0.9,
              timestamp: ts,
              latitude: 52.52,
              longitude: 13.405,
              altitude: 34.5,
              altitudeAccuracy: 6,
              altitudeReference: AltitudeReference.meanSeaLevel,
              locationFixTime: ts,
            ),
          ],
          gpsTrack: [
            GpsPoint(
              latitude: 52.52,
              longitude: 13.405,
              timestamp: ts,
              altitude: 34.5,
              altitudeAccuracy: 6,
              altitudeReference: AltitudeReference.meanSeaLevel,
            ),
          ],
        )..altitude = 34.5;

        final gpx = buildGpxExport(session);
        expect(gpx, contains('<wpt lat="52.52" lon="13.405">'));
        expect(gpx, contains('<ele>34.5</ele>'));
        expect(
          gpx,
          contains(
            '<birdnet:altitude reference="meanSeaLevel" accuracyMeters="6.0" fixTime="2025-07-01T08:00:00.000Z">34.5</birdnet:altitude>',
          ),
        );
      },
    );

    test('no track element when gpsTrack is empty', () {
      final session = _makeSurveySession(gpsTrack: []);
      final gpx = buildGpxExport(session);

      expect(gpx, isNot(contains('<trk>')));
    });

    test('escapes XML special characters', () {
      final start = DateTime.utc(2025, 7, 1, 8, 0, 0);
      final session = _makeSurveySession(
        detections: [
          DetectionRecord(
            scientificName: 'Species "A" & <B>',
            commonName: "O'Brien's Bird",
            confidence: 0.7,
            timestamp: start.add(const Duration(minutes: 1)),
            latitude: 52.52,
            longitude: 13.405,
          ),
        ],
      );

      final gpx = buildGpxExport(session);
      expect(gpx, contains('O&apos;Brien&apos;s Bird'));
      expect(gpx, contains('Species &quot;A&quot; &amp; &lt;B&gt;'));
    });
  });
}
