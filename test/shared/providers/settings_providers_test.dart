import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';

void main() {
  group('Settings providers default values', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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

    test('confidenceThreshold defaults to 35', () {
      expect(container.read(confidenceThresholdProvider), 35);
    });

    test('inferenceRate defaults to 1.0', () {
      expect(container.read(inferenceRateProvider), 1.0);
    });

    test('species ignore settings use safe defaults', () {
      expect(container.read(ignoreBirdsProvider), isFalse);
      expect(container.read(ignoreMammalsProvider), isFalse);
      expect(container.read(ignoreAmphibiansProvider), isFalse);
      expect(container.read(ignoreInsectsProvider), isFalse);
      expect(container.read(ignoreCommonGeoScoreCutoffProvider), 1.0);
    });

    test('showAllDetectedSpecies defaults to false', () {
      expect(container.read(showAllDetectedSpeciesProvider), false);
    });

    test('detectedSpeciesSortMode defaults to newest first', () {
      expect(
        container.read(detectedSpeciesSortModeProvider),
        DetectedSpeciesSortMode.newest,
      );
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

    test('recordingMode defaults to full', () {
      expect(container.read(recordingModeProvider), 'full');
    });

    test('clipContext defaults to 1', () {
      expect(container.read(clipContextProvider), 1);
    });

    test('exportFormat defaults to raven', () {
      expect(container.read(exportFormatProvider), 'raven');
    });

    test('includeAudio defaults to true', () {
      expect(container.read(includeAudioProvider), true);
    });

    test('playbackVoiceMemoDucking defaults to 0.75', () {
      expect(container.read(playbackVoiceMemoDuckingProvider), 0.75);
    });

    test('spectrogramDuration defaults to 20', () {
      expect(container.read(spectrogramDurationProvider), 20);
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

  group('effectiveSpeciesLocaleProvider', () {
    test('uses phone locale when app language follows system', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          platformLocalesProvider.overrideWithValue(const [Locale('ru', 'RU')]),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(localeProvider), isNull);
      expect(container.read(effectiveSpeciesLocaleProvider), 'ru');
    });

    test('system uses phone locale even when app locale is explicit', () async {
      SharedPreferences.setMockInitialValues({PrefKeys.locale: 'de'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          platformLocalesProvider.overrideWithValue(const [Locale('ru', 'RU')]),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(effectiveSpeciesLocaleProvider), 'ru');
    });

    test('follow app language uses explicit app locale', () async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.locale: 'de',
        PrefKeys.speciesLanguage: 'app',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          platformLocalesProvider.overrideWithValue(const [Locale('ru', 'RU')]),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(effectiveSpeciesLocaleProvider), 'de');
    });

    test(
      'follow app language uses English for unsupported system UI locale',
      () async {
        SharedPreferences.setMockInitialValues({
          PrefKeys.speciesLanguage: 'app',
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            platformLocalesProvider.overrideWithValue(const [
              Locale('ja', 'JP'),
            ]),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(localeProvider), isNull);
        expect(container.read(effectiveSpeciesLocaleProvider), 'en');
      },
    );

    test('follow app language uses supported system UI locale', () async {
      SharedPreferences.setMockInitialValues({PrefKeys.speciesLanguage: 'app'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          platformLocalesProvider.overrideWithValue(const [Locale('de', 'DE')]),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(localeProvider), isNull);
      expect(container.read(effectiveSpeciesLocaleProvider), 'de');
    });

    test(
      'uses explicit species language before app and phone locales',
      () async {
        SharedPreferences.setMockInitialValues({
          PrefKeys.locale: 'de',
          PrefKeys.speciesLanguage: 'fr',
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            platformLocalesProvider.overrideWithValue(const [
              Locale('ru', 'RU'),
            ]),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(effectiveSpeciesLocaleProvider), 'fr');
      },
    );

    test(
      'keeps Chinese region because the taxonomy has regional names',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            platformLocalesProvider.overrideWithValue(const [
              Locale('zh', 'CN'),
            ]),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(effectiveSpeciesLocaleProvider), 'zh-CN');
      },
    );
  });

  group('Settings providers persist changes', () {
    test('DoubleSettingNotifier persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(colorMapProvider.notifier).set('magma');
      expect(container.read(colorMapProvider), 'magma');
      expect(prefs.getString('color_map'), 'magma');
    });

    test('inferenceRate snaps to Survey and ARU tick grid', () async {
      SharedPreferences.setMockInitialValues({'inference_rate': 0.25});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(inferenceRateProvider), 0.3);
      expect(prefs.getDouble('inference_rate'), 0.3);

      await container.read(inferenceRateProvider.notifier).set(2.0);
      expect(container.read(inferenceRateProvider), 1.0);
      expect(prefs.getDouble('inference_rate'), 1.0);
    });

    test('surveyInferenceRate snaps to the shared 0.10-1.00 Hz grid', () async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.surveyInferenceRate: 1.7,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(surveyInferenceRateProvider), 1.0);
      expect(prefs.getDouble(PrefKeys.surveyInferenceRate), 1.0);

      await container.read(surveyInferenceRateProvider.notifier).set(0.04);
      expect(container.read(surveyInferenceRateProvider), 0.1);
      expect(prefs.getDouble(PrefKeys.surveyInferenceRate), 0.1);
    });

    test('colorMap migrates removed inferno value to magma', () async {
      SharedPreferences.setMockInitialValues({'color_map': 'inferno'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(colorMapProvider), 'magma');
      expect(prefs.getString('color_map'), 'magma');
    });

    test('BoolSettingNotifier persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(includeAudioProvider.notifier).set(true);
      expect(container.read(includeAudioProvider), true);
      expect(prefs.getBool('include_audio'), true);
    });

    test('species list settings persist', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(showAllDetectedSpeciesProvider.notifier).set(true);
      await container
          .read(detectedSpeciesSortModeProvider.notifier)
          .set(DetectedSpeciesSortMode.occurrences);

      expect(container.read(showAllDetectedSpeciesProvider), true);
      expect(
        container.read(detectedSpeciesSortModeProvider),
        DetectedSpeciesSortMode.occurrences,
      );
      expect(prefs.getBool(PrefKeys.showAllDetectedSpecies), true);
      expect(
        prefs.getString(PrefKeys.detectedSpeciesSortMode),
        DetectedSpeciesSortMode.occurrences,
      );
    });

    test('species ignore settings persist', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(ignoreAmphibiansProvider.notifier).set(true);
      await container
          .read(ignoreCommonGeoScoreCutoffProvider.notifier)
          .set(0.85);

      expect(prefs.getBool(PrefKeys.ignoreAmphibians), isTrue);
      expect(prefs.getDouble(PrefKeys.ignoreCommonGeoScoreCutoff), 0.85);
    });

    test('common-species cutoff clamps legacy values to 80 percent', () async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.ignoreCommonGeoScoreCutoff: 0.5,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(ignoreCommonGeoScoreCutoffProvider), 0.8);
      expect(prefs.getDouble(PrefKeys.ignoreCommonGeoScoreCutoff), 0.8);

      await container
          .read(ignoreCommonGeoScoreCutoffProvider.notifier)
          .set(1.5);
      expect(container.read(ignoreCommonGeoScoreCutoffProvider), 1.0);
    });

    test(
      'lastObserverProvider persists shared field-session observer',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        await container.read(lastObserverProvider.notifier).set('Jane Doe');

        expect(container.read(lastObserverProvider), 'Jane Doe');
        expect(prefs.getString(PrefKeys.lastObserver), 'Jane Doe');
      },
    );

    test('lastObserverProvider falls back to legacy survey observer', () async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.legacySurveyLastObserver: 'Survey Person',
        PrefKeys.legacyPointCountLastObserver: 'Point Count Person',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(lastObserverProvider), 'Survey Person');
    });

    test(
      'lastObserverProvider falls back to legacy point count observer',
      () async {
        SharedPreferences.setMockInitialValues({
          PrefKeys.legacyPointCountLastObserver: 'Point Count Person',
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        expect(container.read(lastObserverProvider), 'Point Count Person');
      },
    );
  });

  group('Privacy setting relationships', () {
    test('allowing map tiles also allows place-name lookup', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(privacyAllowMapProvider.notifier).set(true);

      expect(container.read(privacyAllowMapProvider), true);
      expect(container.read(privacyAllowReverseGeocodingProvider), true);
      expect(prefs.getBool(PrefKeys.privacyAllowMap), true);
      expect(prefs.getBool(PrefKeys.privacyAllowReverseGeocoding), true);
    });

    test('place-name lookup remains independently revocable', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(privacyAllowMapProvider.notifier).set(true);
      await container
          .read(privacyAllowReverseGeocodingProvider.notifier)
          .set(false);

      expect(container.read(privacyAllowMapProvider), true);
      expect(container.read(privacyAllowReverseGeocodingProvider), false);
      expect(prefs.getBool(PrefKeys.privacyAllowMap), true);
      expect(prefs.getBool(PrefKeys.privacyAllowReverseGeocoding), false);
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
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
