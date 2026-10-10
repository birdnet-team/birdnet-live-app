import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/features/history/export_metadata_helper.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/shared/models/gps_point.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LiveSession makeSession() {
    return LiveSession(
      id: 'session-1',
      type: SessionType.survey,
      startTime: DateTime(2026, 1, 1, 10),
      endTime: DateTime(2026, 1, 1, 11),
      detections: [
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Common Blackbird',
          confidence: 0.9,
          timestamp: DateTime(2026, 1, 1, 10, 5),
        ),
      ],
      settings: const SessionSettings(
        windowDuration: 3,
        confidenceThreshold: 30,
        inferenceRate: 1.5,
        speciesFilterMode: 'geoMerge',
        clipContextSeconds: 2,
        recordingMode: 'detectionsOnly',
        recordingFormat: 'flac',
        detectionSamplingMode: 'smart',
        topNPerSpecies: 8,
        gpsIntervalSeconds: 10,
        maxDurationHours: 6,
        autoStopBatteryPercent: 20,
        backgroundGps: true,
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'captures package info and relevant preferences when available',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'BirdNET Live',
        packageName: 'org.birdnet.live',
        version: '1.2.3',
        buildNumber: '123',
        buildSignature: 'sig',
        installerStore: 'store',
      );

      SharedPreferences.setMockInitialValues({
        PrefKeys.windowDuration: 5,
        PrefKeys.confidenceThreshold: 42,
        PrefKeys.inferenceRate: 0.5,
        PrefKeys.recordingFormat: 'wav',
        PrefKeys.recordingMode: 'full',
        PrefKeys.surveyGpsInterval: 15,
        PrefKeys.surveyDetectionSampling: 'all',
        PrefKeys.surveyTopNPerSpecies: 99,
        PrefKeys.exportSelection: 'raven,json',
        PrefKeys.includeAudio: true,
        PrefKeys.lastObserver: 'stale default',
        PrefKeys.announcementsAccessibilityDefaultApplied: true,
      });

      final metadata = await buildSessionExportMetadata(
        makeSession(),
        speciesLocale: 'en',
      );

      final app = metadata['app'] as Map<String, dynamic>;
      expect(app['version'], '1.2.3');
      expect(app['buildNumber'], '123');
      expect(app['packageName'], 'org.birdnet.live');
      expect(metadata['device'], isA<String>());
      expect((metadata['device'] as String), isNotEmpty);
      expect(metadata['os'], isA<String>());
      expect((metadata['os'] as String), isNotEmpty);
      expect(metadata['speciesLocale'], 'en');
      final settings = metadata['settings'] as Map<String, dynamic>;
      final analysis = settings['analysis'] as Map<String, dynamic>;
      expect(analysis['windowDurationSeconds'], 3);
      expect(analysis['confidenceThresholdPercent'], 30);
      expect(analysis['inferenceRateHz'], 1.5);
      expect(analysis['speciesFilterMode'], 'geoMerge');

      final audio = settings['audio'] as Map<String, dynamic>;
      expect(audio['clipContextSeconds'], 2);

      final capture = settings['capture'] as Map<String, dynamic>;
      expect(capture['recordingFormat'], 'flac');
      expect(capture['recordingMode'], 'detectionsOnly');

      final protocol = settings['protocol'] as Map<String, dynamic>;
      expect(protocol['detectionSamplingMode'], 'smart');
      expect(protocol['topNPerSpecies'], 8);
      expect(protocol['gpsIntervalSeconds'], 10);
      expect(protocol['maxDurationHours'], 6);
      expect(protocol['autoStopBatteryPercent'], 20);
      expect(protocol['backgroundGps'], isTrue);

      final export = settings['exportPreferences'] as Map<String, dynamic>;
      expect(export, containsPair(PrefKeys.exportSelection, 'raven,json'));
      expect(export, containsPair(PrefKeys.includeAudio, true));

      expect(settings.containsKey('capturePreferences'), isFalse);
      expect(settings.containsKey('protocolPreferences'), isFalse);
      expect(settings.containsKey(PrefKeys.windowDuration), isFalse);
      expect(settings.toString(), isNot(contains('wav')));
      expect(settings.toString(), isNot(contains('all')));
      expect(settings.toString(), isNot(contains('99')));
      expect(settings.containsKey(PrefKeys.lastObserver), isFalse);
      expect(
        settings.containsKey(PrefKeys.announcementsAccessibilityDefaultApplied),
        isFalse,
      );
      expect(metadata['session'], isA<Map<String, dynamic>>());
      expect(metadata.containsKey('appliedSettings'), isFalse);
    },
  );

  test(
    'still returns base metadata when package info is unavailable',
    () async {
      PackageInfo.setMockInitialValues(
        appName: '',
        packageName: '',
        version: '',
        buildNumber: '',
        buildSignature: '',
        installerStore: '',
      );

      final metadata = await buildSessionExportMetadata(
        makeSession(),
        speciesLocale: 'de',
      );

      expect(metadata['exportedAt'], isA<String>());
      expect(metadata['app'], isA<Map<String, dynamic>>());
      expect(metadata['session'], isA<Map<String, dynamic>>());
      expect(metadata['speciesLocale'], 'de');
    },
  );

  test(
    'adds survey-specific metadata separately from common session fields',
    () async {
      final session =
          makeSession()
            ..transectId = 'T-001'
            ..distanceMeters = 250.5
            ..gpsTrack.add(
              GpsPoint(
                latitude: 52.52,
                longitude: 13.405,
                timestamp: DateTime.utc(2026, 1, 1, 10, 1),
              ),
            );

      final metadata = await buildSessionExportMetadata(
        session,
        speciesLocale: 'en',
      );

      final common = metadata['session'] as Map<String, dynamic>;
      expect(common['type'], 'survey');
      expect(common['displayName'], session.displayName);
      expect(common['detectionCount'], 1);
      expect(common['uniqueSpeciesCount'], 1);

      final typeMetadata = metadata['typeMetadata'] as Map<String, dynamic>;
      expect(typeMetadata['transectId'], 'T-001');
      expect(typeMetadata['distanceMeters'], 250.5);
      expect(typeMetadata['gpsPointCount'], 1);
      expect(typeMetadata['gpsTrack'], isA<List<dynamic>>());
    },
  );

  test('adds point count timing as type-specific metadata', () async {
    final session =
        makeSession()
          ..type = SessionType.pointCount
          ..customName = 'Pond Stop 1';

    final metadata = await buildSessionExportMetadata(
      session,
      speciesLocale: 'en',
    );

    final common = metadata['session'] as Map<String, dynamic>;
    expect(common['type'], 'pointCount');
    expect(common['displayName'], 'Pond Stop 1');

    final typeMetadata = metadata['typeMetadata'] as Map<String, dynamic>;
    expect(typeMetadata['countDurationSeconds'], 3600.0);
  });

  test('adds ARU deployment metadata as type-specific metadata', () async {
    final session =
        makeSession()
          ..type = SessionType.aru
          ..aruMetadata = AruDeploymentMetadata(
            deploymentName: 'Wetland',
            stationId: 'ARU-01',
            scheduleStart: DateTime.utc(2026, 1, 1, 10),
            eachCycleIsSession: false,
            cycleDurationSeconds: 600,
            repeatIntervalSeconds: 3600,
            maxCycles: 2,
          );

    final metadata = await buildSessionExportMetadata(
      session,
      speciesLocale: 'en',
    );

    final common = metadata['session'] as Map<String, dynamic>;
    expect(common['type'], 'aru');

    final typeMetadata = metadata['typeMetadata'] as Map<String, dynamic>;
    final aru = typeMetadata['aru'] as Map<String, dynamic>;
    expect(aru['deploymentName'], 'Wetland');
    expect(aru['stationId'], 'ARU-01');
  });
}
