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
        reviewStatus: ReviewStatus.confirmed,
        reviewedAt: DateTime.utc(2026, 5, 28, 10, 1, 30),
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

    test('badges a rejected detection and leaves unreviewed ones bare', () {
      // Match the rendered pill, not the class name — both CSS rules are in
      // the stylesheet of every report regardless of review state.
      const rejectedPill = '<span class="occ-rejected">Rejected</span>';
      const confirmedPill = '<span class="occ-confirmed">Confirmed</span>';

      final session = _sessionWithDetections();
      session.detections.single.markRejected(
        at: DateTime.utc(2026, 5, 28, 10, 1, 30),
      );
      final rejected = buildHtmlReport(session);
      expect(rejected, contains(rejectedPill));
      expect(rejected, isNot(contains(confirmedPill)));

      session.detections.single.clearReview();
      final bare = buildHtmlReport(session);
      expect(bare, isNot(contains(rejectedPill)));
      expect(bare, isNot(contains(confirmedPill)));
    });

    test('renders full recording player when audioFileName is provided', () {
      final html = buildHtmlReport(
        _sessionWithDetections(),
        audioFileName: 'full session #1.wav',
      );

      expect(html, contains('Full recording'));
      expect(html, contains('full%20session%20%231.wav'));
      expect(html, contains('class="audio-player"'));
      expect(html, contains('class="custom-player"'));
    });

    test('renders compact inference metadata in footer when provided', () {
      final html = buildHtmlReport(
        _sessionWithDetections(),
        metadata: const {
          'app': {'version': '1.2.3', 'buildNumber': '45'},
          'audioModel': {
            'name': 'BirdNET Test Audio',
            'version': '3.0',
            'speciesCount': 5250,
            'audio': {'sampleRate': 32000},
          },
          'geoModel': {
            'name': 'BirdNET Test Geo',
            'version': '3.0.1',
            'speciesCount': 5250,
          },
          'settings': {
            'analysis': {
              'windowDurationSeconds': 3,
              'confidenceThresholdPercent': 25,
              'inferenceRateHz': 1.0,
              'speciesFilterMode': 'geoMerge',
              'sensitivity': 1.2,
              'poolingMode': 'avg',
              'poolingWindows': 3,
            },
            'audio': {
              'gainLinear': 1.5,
              'highPassHz': 200,
              'clipContextSeconds': 2,
            },
          },
        },
      );

      expect(html, contains('Analysis context'));
      expect(html, contains('v1.2.3 build 45'));
      expect(html, contains('BirdNET Test Audio | v3.0 | 5250 species'));
      expect(html, contains('32000 Hz'));
      expect(html, contains('BirdNET Test Geo | v3.0.1 | 5250 species'));
      expect(
        html,
        contains('3s window | 25% min confidence | 1 Hz | sensitivity 1.2'),
      );
      // The report deliberately omits pooling, species filter, and audio
      // preprocessing — those live only in the exported JSON metadata.
      expect(html, isNot(contains('species filter')));
      expect(html, isNot(contains('pooling avg')));
      expect(html, isNot(contains('Audio preprocessing')));
      expect(html, isNot(contains('high-pass 200 Hz')));
    });

    test(
      'defaults report cards to collapsed confidence order with audio first',
      () {
        final session = LiveSession(
          id: 'sort-session',
          startTime: DateTime.utc(2026, 5, 28, 10, 0, 0),
          endTime: DateTime.utc(2026, 5, 28, 10, 10, 0),
          settings: const SessionSettings(
            windowDuration: 3,
            confidenceThreshold: 25,
            inferenceRate: 1.0,
            speciesFilterMode: 'off',
          ),
          detections: [
            DetectionRecord(
              scientificName: 'Species alpha',
              commonName: 'Alpha',
              confidence: 0.95,
              timestamp: DateTime.utc(2026, 5, 28, 10, 1, 0),
            ),
            DetectionRecord(
              scientificName: 'Species beta',
              commonName: 'Beta',
              confidence: 0.60,
              timestamp: DateTime.utc(2026, 5, 28, 10, 2, 0),
            ),
            DetectionRecord(
              scientificName: 'Species beta',
              commonName: 'Beta',
              confidence: 0.70,
              timestamp: DateTime.utc(2026, 5, 28, 10, 3, 0),
            ),
          ],
        );

        final html = buildHtmlReport(
          session,
          clipFileMap: const {1: 'beta.wav'},
        );

        expect(html, contains('Detection timeline'));
        expect(html, contains('"timeline":{"bins":'));
        expect(html, contains('<div class="detection collapsed"'));
        expect(
          html,
          contains(
            '<button class="sort-btn active" data-sort="conf">Confidence',
          ),
        );
        expect(html, contains('sortDetections(\'conf\')'));
        expect(html, contains('data-has-audio="1"'));
        expect(html, contains('data-has-audio="0"'));
        expect(html, contains('class="audio-player"'));

        final betaIndex = html.indexOf('data-common="beta"');
        final alphaIndex = html.indexOf('data-common="alpha"');
        expect(betaIndex, isNonNegative);
        expect(alphaIndex, isNonNegative);
        expect(betaIndex, lessThan(alphaIndex));
      },
    );

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

    // The report is opened from disk far more often than it is served, so the
    // remote pieces (Leaflet, OSM tiles) have to be able to fail without
    // leaving the reader stuck. See the v1.0.2 bug reports.
    group('degrades gracefully when remote resources are blocked', () {
      test('map card carries a static OpenStreetMap link and notice slot', () {
        final html = buildHtmlReport(_sessionWithDetections());

        // Plain anchor: must not depend on Leaflet or the tile service.
        expect(html, contains('class="map-osm-link"'));
        expect(html, contains('openstreetmap.org/?mlat=50.12340&amp;mlon=8.56780'));
        expect(html, contains('id="map-notice"'));
        // Tile requests are made identical across browsers.
        expect(html, contains("referrerPolicy: 'no-referrer'"));
        expect(html, contains("tiles.on('tileerror'"));
      });

      test('omits the OpenStreetMap link when the session has no position', () {
        final session = LiveSession(
          id: 'no-gps',
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

        expect(html, isNot(contains('class="map-osm-link"')));
      });

      test('audio cards carry a notice slot for missing files', () {
        final html = buildHtmlReport(
          _sessionWithDetections(),
          audioFileName: 'full.wav',
        );

        // One beside the full recording, one in the detections card.
        expect(
          RegExp('class="notice audio-notice"').allMatches(html).length,
          2,
        );
        expect(html, contains("audio.addEventListener('error'"));
        expect(html, contains('extract the whole archive'));
      });
    });
  });
}
