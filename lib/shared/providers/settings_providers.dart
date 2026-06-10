import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import 'app_providers.dart';

// ---------------------------------------------------------------------------
// Audio Settings
// ---------------------------------------------------------------------------

/// Audio gain (0.0 – 2.0, default 1.0).
final audioGainProvider = StateNotifierProvider<DoubleSettingNotifier, double>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DoubleSettingNotifier(prefs, PrefKeys.audioGain, 1.0);
});

/// High-pass filter cutoff in Hz (0 = off, default 0).
final highPassFilterProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(prefs, PrefKeys.highPassFilter, 0);
    });

// ---------------------------------------------------------------------------
// Inference Settings
// ---------------------------------------------------------------------------

/// Window duration in seconds (3, 5, or 10).
final windowDurationProvider = StateNotifierProvider<IntSettingNotifier, int>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IntSettingNotifier(prefs, PrefKeys.windowDuration, 3);
});

/// Confidence threshold (0 – 100, default 35).
final confidenceThresholdProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.confidenceThreshold, 35);
    });

/// Inference rate in Hz (0.25, 0.5, 1.0, 2.0 — default 1.0).
final inferenceRateProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(prefs, PrefKeys.inferenceRate, 1.0);
    });

/// Sensitivity (0.5 – 1.5, default 1.0).
///
/// Shifts the sigmoid curve: >1 boosts weak signals (more detections),
/// <1 suppresses weak signals (fewer false positives).
final sensitivityProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(prefs, PrefKeys.sensitivity, 1.0);
    });

/// Score pooling mode ('off', 'average', 'max', 'lme' — default 'lme').
///
/// Controls how scores from consecutive inference windows are combined.
final scorePoolingProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(prefs, PrefKeys.scorePooling, 'lme');
    });

/// Number of consecutive inference windows that participate in score pooling.
///
/// A larger value smooths the per-species score over a longer time horizon,
/// which suppresses spurious one-off detections at the cost of latency. The
/// default of 5 matches the value historically baked into the model config.
final scorePoolingWindowsProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.scorePoolingWindows, 5);
    });

/// Species filter mode ('off', 'geoExclude', 'geoMerge', 'customList').
final speciesFilterModeProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.speciesFilterMode,
        'geoExclude',
      );
    });

// ---------------------------------------------------------------------------
// Spectrogram Settings
// ---------------------------------------------------------------------------

/// FFT size (512, 1024, 2048, 4096 — default 2048).
final fftSizeProvider = StateNotifierProvider<IntSettingNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IntSettingNotifier(prefs, PrefKeys.fftSize, 2048);
});

/// Color map name (default 'viridis').
final colorMapProvider = StateNotifierProvider<StringSettingNotifier, String>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StringSettingNotifier(prefs, PrefKeys.colorMap, 'viridis');
});

/// dB floor (default -80).
final dbFloorProvider = StateNotifierProvider<DoubleSettingNotifier, double>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DoubleSettingNotifier(prefs, PrefKeys.dbFloor, -80);
});

/// dB ceiling (default 0).
final dbCeilingProvider = StateNotifierProvider<DoubleSettingNotifier, double>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DoubleSettingNotifier(prefs, PrefKeys.dbCeiling, 0);
});

/// Spectrogram visible duration in seconds (5, 10, 15, 20, 30 — default 20).
final spectrogramDurationProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.spectrogramDuration, 20);
    });

/// Maximum frequency displayed in the spectrogram in Hz (default 16000).
final spectrogramMaxFreqProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.spectrogramMaxFreq, 16000);
    });

/// Whether to use logarithmic amplitude scaling (default true).
final logAmplitudeProvider = StateNotifierProvider<BoolSettingNotifier, bool>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BoolSettingNotifier(prefs, PrefKeys.logAmplitude, true);
});

/// Spectrogram rendering quality — controls the GPU upscale [FilterQuality]
/// used to draw the live spectrogram image.
///
/// Values: `'low'` | `'medium'` | `'high'`.  Default `'medium'`.
/// Older / low-end devices can drop to `'low'` to reduce GPU load.
final spectrogramQualityProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.spectrogramQuality,
        'medium',
      );
    });

// ---------------------------------------------------------------------------
// Recording Settings
// ---------------------------------------------------------------------------

/// Recording format ('wav' or 'flac', default 'flac').
final recordingFormatProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(prefs, PrefKeys.recordingFormat, 'flac');
    });

/// Recording mode ('full', 'detections', 'off' — default 'full').
///
/// Used by live and point-count sessions.  Surveys use their own
/// [surveyRecordingModeProvider] configured in the survey-setup screen.
final recordingModeProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(prefs, PrefKeys.recordingMode, 'full');
    });

/// Clip context in seconds (default 1).
///
/// Number of seconds of audio captured before AND after each detection
/// window. Total saved clip length = analysis window (e.g. 3 s) plus
/// 2 × clipContext, so a context of 1 yields a 5 s clip.
final clipContextProvider = StateNotifierProvider<IntSettingNotifier, int>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IntSettingNotifier(prefs, PrefKeys.clipContext, 1);
});

/// When true, Live mode auto-starts recording as soon as the model is
/// ready. Lets the screen run kiosk-style or hands-free without an
/// extra mic-button tap. Default: false.
final liveAutoStartProvider = StateNotifierProvider<BoolSettingNotifier, bool>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BoolSettingNotifier(prefs, PrefKeys.liveAutoStart, false);
});

// ---------------------------------------------------------------------------
// Export Settings
// ---------------------------------------------------------------------------

/// Export format ('raven', 'csv', 'json', 'gpx' — default 'raven').
///
/// Deprecated since 0.12.0: the export pipeline now reads
/// [exportSelectionProvider] (a multi-select bitmask). This provider
/// remains for one-time migration of pre-0.12.0 installs and for
/// backward-compatible reads from a few legacy call sites.
final exportFormatProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(prefs, PrefKeys.exportFormat, 'raven');
    });

/// Set of formats included in every export ZIP, persisted as a
/// comma-separated string under [PrefKeys.exportSelection]. Empty
/// selections fall back to `{'raven'}` at read time so the pipeline
/// always produces at least one document.
final exportSelectionProvider =
    StateNotifierProvider<ExportSelectionNotifier, Set<String>>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ExportSelectionNotifier(prefs);
    });

class ExportSelectionNotifier extends StateNotifier<Set<String>> {
  ExportSelectionNotifier(this._prefs) : super(_load(_prefs));

  static const Set<String> _allFormats = {'raven', 'csv', 'json', 'gpx'};
  static const Set<String> _defaultFormats = {'raven'};

  final SharedPreferences _prefs;

  static Set<String> _load(SharedPreferences prefs) {
    final raw = prefs.getString(PrefKeys.exportSelection);
    if (raw == null || raw.isEmpty) {
      // Migrate from the legacy single-choice key when present.
      final legacy = prefs.getString(PrefKeys.exportFormat);
      if (legacy != null && _allFormats.contains(legacy)) {
        return {legacy};
      }
      return {..._defaultFormats};
    }
    final parts = raw.split(',').where(_allFormats.contains).toSet();
    return parts.isEmpty ? {..._defaultFormats} : parts;
  }

  void toggle(String format, bool enabled) {
    if (!_allFormats.contains(format)) return;
    final next = {...state};
    if (enabled) {
      next.add(format);
    } else {
      next.remove(format);
    }
    if (next.isEmpty) next.addAll(_defaultFormats);
    state = next;
    _prefs.setString(PrefKeys.exportSelection, next.join(','));
  }

  void set(Set<String> formats) {
    final filtered = formats.where(_allFormats.contains).toSet();
    final next = filtered.isEmpty ? {..._defaultFormats} : filtered;
    state = next;
    _prefs.setString(PrefKeys.exportSelection, next.join(','));
  }
}

/// Include audio files in export (default true).
final includeAudioProvider = StateNotifierProvider<BoolSettingNotifier, bool>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BoolSettingNotifier(prefs, PrefKeys.includeAudio, true);
});

/// Bundle a self-contained `report.html` next to the audio inside the
/// export ZIP (default true). The HTML opens in any browser, embeds the
/// session metadata + clip players, and pulls species images / data
/// from the BirdNET taxonomy API on the fly. Off-by-default for users
/// who only want the raw table + audio.
final exportHtmlReportProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.exportHtmlReport, true);
    });

// ---------------------------------------------------------------------------
// Location / Geo Settings
// ---------------------------------------------------------------------------

/// Use GPS for location (default true).  When false the manual coordinates
/// are used instead.
final useGpsProvider = StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BoolSettingNotifier(prefs, PrefKeys.useGps, true);
});

// ---------------------------------------------------------------------------
// Privacy Gates (0.12.0)
// ---------------------------------------------------------------------------
//
// Three independent toggles, each gating one third-party service. All
// default `false` for new installs. Pre-0.12.0 installs that previously
// consented to OSM tiles get the first two flipped on by the migration
// in `main()`. Consumer code reads these providers and short-circuits
// every network call when the corresponding gate is off.

/// Allow reverse geocoding via Nominatim (nominatim.openstreetmap.org).
final privacyAllowReverseGeocodingProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(
        prefs,
        PrefKeys.privacyAllowReverseGeocoding,
        false,
      );
    });

/// Allow OSM map tile fetches (tile.openstreetmap.org).
final privacyAllowMapProvider =
    StateNotifierProvider<MapPrivacySettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final reverseGeocodingNotifier = ref.watch(
        privacyAllowReverseGeocodingProvider.notifier,
      );
      return MapPrivacySettingNotifier(prefs, reverseGeocodingNotifier);
    });

/// Allow weather snapshot fetches via Open-Meteo (api.open-meteo.com).
final privacyAllowWeatherProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.privacyAllowWeather, false);
    });

/// Show scientific names below common names (default true).
final showSciNamesProvider = StateNotifierProvider<BoolSettingNotifier, bool>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BoolSettingNotifier(prefs, PrefKeys.showSciNames, true);
});

/// Timestamp display mode: `'relative'` (session-relative `MM:SS`) or
/// `'absolute'` (local clock `HH:mm:ss`).  Default `'relative'`.
///
/// Used by [formatDetectionTime] to render per-detection timestamps in
/// Session Review and other history surfaces.  Storage and exports always
/// use UTC instants regardless of this setting.
final timestampDisplayModeProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.timestampDisplayMode,
        'relative',
      );
    });

/// Whether per-detection timestamps in the UI include the trailing seconds
/// component.  When false, relative renders as `MM` / `H:MM` and absolute
/// as `HH:mm`.  Exports always include seconds regardless.
final timestampShowSecondsProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.timestampShowSeconds, true);
    });

/// Geo-model probability threshold (0.0 – 1.0, default 0.03).
final geoThresholdProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(prefs, PrefKeys.geoThreshold, 0.03);
    });

/// Manual latitude for when GPS is disabled (default 52.52 — Berlin).
final manualLatitudeProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(prefs, PrefKeys.manualLatitude, 52.52);
    });

/// Manual longitude for when GPS is disabled (default 13.405 — Berlin).
final manualLongitudeProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(prefs, PrefKeys.manualLongitude, 13.405);
    });

// ---------------------------------------------------------------------------
// Species Language
// ---------------------------------------------------------------------------

/// Species name language code ('system', 'en', 'de', 'es', etc.).
///
/// When 'system', follows the app locale.
final speciesLanguageProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(prefs, PrefKeys.speciesLanguage, 'system');
    });

/// Resolved species locale code (never 'system').
///
/// Resolves 'system' → app locale → platform locale → 'en'.
final effectiveSpeciesLocaleProvider = Provider<String>((ref) {
  final setting = ref.watch(speciesLanguageProvider);
  if (setting != 'system') return setting;

  final appLocale = ref.watch(localeProvider);
  if (appLocale != null) return appLocale.languageCode;

  return PlatformDispatcher.instance.locale.languageCode;
});

// ---------------------------------------------------------------------------
// Point Count
// ---------------------------------------------------------------------------

/// Point count duration in minutes (default: 5).
final pointCountDurationProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.pointCountDuration, 5);
    });

/// Last used observer name in Point Count (persisted for convenience).
final pointCountLastObserverProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(prefs, PrefKeys.pointCountLastObserver, '');
    });

// ---------------------------------------------------------------------------
// Survey Mode
// ---------------------------------------------------------------------------

/// Survey inference rate in Hz (default 0.25).
final surveyInferenceRateProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(prefs, PrefKeys.surveyInferenceRate, 0.3);
    });

/// GPS logging interval in seconds (default 10).
final surveyGpsIntervalProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.surveyGpsInterval, 10);
    });

/// Maximum survey duration in hours (default 12).
final surveyMaxDurationProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.surveyMaxDuration, 8);
    });

/// Auto-stop battery threshold in percent (default 0 = off).
final surveyAutoStopBatteryProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.surveyAutoStopBattery, 0);
    });

/// Survey recording mode ('full', 'detections', 'off' — default 'detections').
final surveyRecordingModeProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.surveyRecordingMode,
        'detections',
      );
    });

/// Survey clip context in seconds (default 1).
///
/// Same semantics as [clipContextProvider] but scoped to survey sessions.
final surveyClipContextProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.surveyClipContext, 1);
    });

/// Detection sampling mode ('all', 'topN', 'smart' — default 'smart').
final surveyDetectionSamplingProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.surveyDetectionSampling,
        'smart',
      );
    });

/// Top N detections per species to keep (default 10).
final surveyTopNPerSpeciesProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.surveyTopNPerSpecies, 10);
    });

/// Last used observer name (persisted for convenience).
final surveyLastObserverProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(prefs, PrefKeys.surveyLastObserver, '');
    });

/// Last used transect ID (persisted for convenience).
final surveyLastTransectIdProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(prefs, PrefKeys.surveyLastTransectId, '');
    });

// ===========================================================================
// Survey species alerts (v0.7.0+)
// ===========================================================================

/// Active alert mode: 0=off, 1=first-in-session, 2=first-ever, 3=rare,
/// 4=watchlist. See `AlertMode` in `survey_alert_engine.dart`.
final surveyAlertModeProvider = StateNotifierProvider<IntSettingNotifier, int>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IntSettingNotifier(prefs, PrefKeys.surveyAlertMode, 0);
});

/// Geo-model probability cutoff for the "rare" alert mode (0.0–0.5).
final surveyAlertRareThresholdProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(
        prefs,
        PrefKeys.surveyAlertRareThreshold,
        0.05,
      );
    });

/// Name of the saved [CustomSpeciesList] used as the watchlist. Empty
/// when no list selected.
final surveyAlertWatchlistNameProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.surveyAlertWatchlistName,
        '',
      );
    });

/// Whether alert notifications play a sound.
final surveyAlertSoundProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.surveyAlertSound, true);
    });

/// Whether alert notifications vibrate.
final surveyAlertVibrateProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.surveyAlertVibrate, true);
    });

/// Detections below this confidence never fire alerts.
final surveyAlertMinConfidenceProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(
        prefs,
        PrefKeys.surveyAlertMinConfidence,
        0.5,
      );
    });

/// Seconds at the start of a survey during which non-bypass alerts are
/// silently suppressed (default 60).
final surveyAlertStartupGraceSecondsProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(
        prefs,
        PrefKeys.surveyAlertStartupGraceSeconds,
        60,
      );
    });

/// Hard cooldown between any two delivered alerts (default 15 s).
final surveyAlertMinIntervalSecondsProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(
        prefs,
        PrefKeys.surveyAlertMinIntervalSeconds,
        15,
      );
    });

/// Maximum delivered alerts per minute. `0` means unlimited.
final surveyAlertMaxPerMinuteProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.surveyAlertMaxPerMinute, 3);
    });

/// Whether over-cap alerts are queued for a summary notification (true)
/// or silently dropped (false).
final surveyAlertCoalesceProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.surveyAlertCoalesce, true);
    });

/// Whether to mirror system notifications as in-app snackbars on the
/// Survey Live screen.
final surveyAlertInAppToastProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.surveyAlertInAppToast, true);
    });

// ===========================================================================
// Generic setting notifiers
// ===========================================================================

/// [StateNotifier] for a `double` setting backed by [SharedPreferences].
class DoubleSettingNotifier extends StateNotifier<double> {
  DoubleSettingNotifier(this._prefs, this._key, double defaultValue)
    : super(_prefs.getDouble(_key) ?? defaultValue);

  final SharedPreferences _prefs;
  final String _key;

  Future<void> set(double value) async {
    state = value;
    await _prefs.setDouble(_key, value);
  }
}

/// [StateNotifier] for an `int` setting backed by [SharedPreferences].
class IntSettingNotifier extends StateNotifier<int> {
  IntSettingNotifier(this._prefs, this._key, int defaultValue)
    : super(_prefs.getInt(_key) ?? defaultValue);

  final SharedPreferences _prefs;
  final String _key;

  Future<void> set(int value) async {
    state = value;
    await _prefs.setInt(_key, value);
  }
}

/// [StateNotifier] for a `String` setting backed by [SharedPreferences].
class StringSettingNotifier extends StateNotifier<String> {
  StringSettingNotifier(this._prefs, this._key, String defaultValue)
    : super(_prefs.getString(_key) ?? defaultValue);

  final SharedPreferences _prefs;
  final String _key;

  Future<void> set(String value) async {
    state = value;
    await _prefs.setString(_key, value);
  }
}

/// [StateNotifier] for a `bool` setting backed by [SharedPreferences].
class BoolSettingNotifier extends StateNotifier<bool> {
  BoolSettingNotifier(this._prefs, this._key, bool defaultValue)
    : super(_prefs.getBool(_key) ?? defaultValue);

  final SharedPreferences _prefs;
  final String _key;

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(_key, value);
  }
}

/// Map tile consent also grants city-name lookup as a convenience, while the
/// reverse-geocoding toggle remains independently revocable in Settings.
class MapPrivacySettingNotifier extends BoolSettingNotifier {
  MapPrivacySettingNotifier(
    SharedPreferences prefs,
    this._reverseGeocodingNotifier,
  ) : super(prefs, PrefKeys.privacyAllowMap, false);

  final BoolSettingNotifier _reverseGeocodingNotifier;

  @override
  Future<void> set(bool value) async {
    final wasAllowed = state;
    await super.set(value);
    if (value && !wasAllowed) {
      await _reverseGeocodingNotifier.set(true);
    }
  }
}
