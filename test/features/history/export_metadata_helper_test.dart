import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/features/history/export_metadata_helper.dart';
import 'package:birdnet_live/features/live/live_session.dart';

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
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('captures package info and shared preferences when available', () async {
    PackageInfo.setMockInitialValues(
      appName: 'BirdNET Live',
      packageName: 'org.birdnet.live',
      version: '1.2.3',
      buildNumber: '123',
      buildSignature: 'sig',
      installerStore: 'store',
    );

    SharedPreferences.setMockInitialValues({
      'someSetting': true,
      'anotherSetting': 42,
    });

    final metadata = await buildSessionExportMetadata(
      makeSession(),
      speciesLocale: 'en',
    );

    final app = metadata['app'] as Map<String, dynamic>;
    expect(app['version'], '1.2.3');
    expect(app['buildNumber'], '123');
    expect(app['packageName'], 'org.birdnet.live');
    expect(metadata['speciesLocale'], 'en');
    expect(metadata['settings'], containsPair('someSetting', true));
    expect(metadata['session'], isA<Map<String, dynamic>>());
    expect(metadata['appliedSettings'], isA<Map<String, dynamic>>());
  });

  test('still returns base metadata when package info is unavailable', () async {
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
  });
}
