import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/history/html_report.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/shared/models/gps_point.dart';
import 'package:birdnet_live/shared/models/weather_snapshot.dart';

LiveSession _sessionWithDetections() {
  final session = LiveSession(
    id: 'session-1',
    type: SessionType.survey,
    startTime: DateTime.utc(2026, 5, 28, 10, 0, 0),
    endTime: DateTime.utc(2026, 5, 28, 10, 15, 0),
    customName: 'Morning <script>alert(1)</script>',
    locationName: 'Forest & Wetland',
    latitude: 50.1234,
    longitude: 8.5678,
    observerName: 'A & B',
    settings: const SessionSettings(
      windowDuration: 3,
      confidenceThreshold: 25,
      inferenceRate: 1.0,
      speciesFilterMode: 'off',
      sensitivity: 1.2,
      poolingMode: 'avg',
      poolingWindows: 3,
      gainLinear: 1.5,
      highPassHz: 200,
    ),
    gpsTrack: [
      GpsPoint(
        latitude: 50.1234,
        longitude: 8.5678,
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 0),
      ),
    ],
    detections: [
      DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Common <Blackbird>',
        confidence: 0.8,
        timestamp: DateTime.utc(2026, 5, 28, 10, 1, 0),
        latitude: 50.1234,
        longitude: 8.5678,
        note: 'note with <b>tag</b> & symbols',
        confirmedAt: DateTime.utc(2026, 5, 28, 10, 1, 30),
      ),
    ],
  );
  session.weather = WeatherSnapshot(
    fetchedAt: DateTime.utc(2026, 5, 28, 10, 0, 0),
    temperatureC: 16.2,
    windSpeedMs: 3.0,
    windDirectionDeg: 200,
  );
  return session;
}

void main() {
  group('buildHtmlReport', () {
    test('renders escaped fields, map section, and encoded clip names', () {
      final html = buildHtmlReport(
        _sessionWithDetections(),
        clipFileMap: const {0: 'clip #1.wav'},
      );

      expect(html, contains('Morning &lt;script&gt;alert(1)&lt;/script&gt;'));
      expect(html, contains('Forest &amp; Wetland'));
      expect(html, contains('Common &lt;Blackbird&gt;'));
      expect(html, contains('note with &lt;b&gt;tag&lt;/b&gt; &amp; symbols'));
      expect(html, contains('id="map"'));
      expect(html, contains('clip%20%231.wav'));
      expect(html, contains('Confirmed'));
      expect(html, contains('Recording settings'));
    });

    test('renders full recording player when audioFileName is provided', () {
      final html = buildHtmlReport(
        _sessionWithDetections(),
        audioFileName: 'full session #1.wav',
      );

      expect(html, contains('Full recording'));
      expect(html, contains('full%20session%20%231.wav'));
    });

    test('renders empty-state text for sessions without detections', () {
      final session = LiveSession(
        id: 'empty',
        startTime: DateTime.utc(2026, 5, 28, 10, 0, 0),
        endTime: DateTime.utc(2026, 5, 28, 10, 1, 0),
        settings: const SessionSettings(
          windowDuration: 3,
          confidenceThreshold: 25,
          inferenceRate: 1.0,
          speciesFilterMode: 'off',
        ),
      );

      final html = buildHtmlReport(session);

      expect(html, contains('No detections recorded.'));
      expect(html, isNot(contains('id="map"')));
    });
  });
}
