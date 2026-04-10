import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';

void main() {
  group('Settings providers default values', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('audioGain defaults to 1.0', () {
      expect(container.read(audioGainProvider), 1.0);
    });

    test('highPassFilter defaults to 0', () {
      expect(container.read(highPassFilterProvider), 0.0);
    });

    test('windowDuration defaults to 3', () {
      expect(container.read(windowDurationProvider), 3);
    });

    test('confidenceThreshold defaults to 25', () {
      expect(container.read(confidenceThresholdProvider), 25);
    });

    test('inferenceRate defaults to 1.0', () {
      expect(container.read(inferenceRateProvider), 1.0);
    });

    test('fftSize defaults to 2048', () {
      expect(container.read(fftSizeProvider), 2048);
    });

    test('colorMap defaults to viridis', () {
      expect(container.read(colorMapProvider), 'viridis');
    });

    test('recordingFormat defaults to flac', () {
      expect(container.read(recordingFormatProvider), 'flac');
    });

    test('recordingMode defaults to off', () {
      expect(container.read(recordingModeProvider), 'off');
    });

    test('preBuffer defaults to 5', () {
      expect(container.read(preBufferProvider), 5);
    });

    test('postBuffer defaults to 5', () {
      expect(container.read(postBufferProvider), 5);
    });

    test('exportFormat defaults to raven', () {
      expect(container.read(exportFormatProvider), 'raven');
    });

    test('includeAudio defaults to true', () {
      expect(container.read(includeAudioProvider), true);
    });

    test('spectrogramDuration defaults to 15', () {
      expect(container.read(spectrogramDurationProvider), 15);
    });

    test('spectrogramMaxFreq defaults to 16000', () {
      expect(container.read(spectrogramMaxFreqProvider), 16000);
    });

    test('logAmplitude defaults to true', () {
      expect(container.read(logAmplitudeProvider), true);
    });

    test('useGps defaults to true', () {
      expect(container.read(useGpsProvider), true);
    });

    test('geoThreshold defaults to 0.03', () {
      expect(container.read(geoThresholdProvider), 0.03);
    });

    test('manualLatitude defaults to 52.52', () {
      expect(container.read(manualLatitudeProvider), 52.52);
    });

    test('manualLongitude defaults to 13.405', () {
      expect(container.read(manualLongitudeProvider), 13.405);
    });
  });

  group('Settings providers persist changes', () {
    test('DoubleSettingNotifier persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(audioGainProvider.notifier).set(1.5);
      expect(container.read(audioGainProvider), 1.5);
      expect(prefs.getDouble('audio_gain'), 1.5);
    });

    test('IntSettingNotifier persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(windowDurationProvider.notifier).set(10);
      expect(container.read(windowDurationProvider), 10);
      expect(prefs.getInt('window_duration'), 10);
    });

    test('StringSettingNotifier persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(colorMapProvider.notifier).set('magma');
      expect(container.read(colorMapProvider), 'magma');
      expect(prefs.getString('color_map'), 'magma');
    });

    test('BoolSettingNotifier persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(includeAudioProvider.notifier).set(true);
      expect(container.read(includeAudioProvider), true);
      expect(prefs.getBool('include_audio'), true);
    });
  });

  group('Settings load persisted values', () {
    test('loads previously saved values', () async {
      SharedPreferences.setMockInitialValues({
        'audio_gain': 1.5,
        'window_duration': 10,
        'color_map': 'magma',
        'include_audio': true,
        'confidence_threshold': 50,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(audioGainProvider), 1.5);
      expect(container.read(windowDurationProvider), 10);
      expect(container.read(colorMapProvider), 'magma');
      expect(container.read(includeAudioProvider), true);
      expect(container.read(confidenceThresholdProvider), 50);
    });
  });
}
