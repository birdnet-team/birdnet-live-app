import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../features/inference/advanced_pooling_params.dart';
import '../../features/inference/species_ignore_filter.dart';
import '../../l10n/app_localizations.dart';
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

const List<double> inferenceRateHzValues = <double>[
  0.1,
  0.2,
  0.3,
  0.4,
  0.5,
  0.6,
  0.7,
  0.8,
  0.9,
  1.0,
];

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

/// Inference rate in Hz (0.1–1.0 in 0.1 Hz steps — default 1.0).
final inferenceRateProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return InferenceRateSettingNotifier(prefs);
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

/// Taxonomic groups excluded by the inference-time binary score mask.
final ignoreBirdsProvider = StateNotifierProvider<BoolSettingNotifier, bool>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BoolSettingNotifier(prefs, PrefKeys.ignoreBirds, false);
});

final ignoreMammalsProvider = StateNotifierProvider<BoolSettingNotifier, bool>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BoolSettingNotifier(prefs, PrefKeys.ignoreMammals, false);
});

final ignoreAmphibiansProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.ignoreAmphibians, false);
    });

final ignoreInsectsProvider = StateNotifierProvider<BoolSettingNotifier, bool>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BoolSettingNotifier(prefs, PrefKeys.ignoreInsects, false);
});

/// Geo-model score at or above which a species is ignored as common.
final ignoreCommonGeoScoreCutoffProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return CommonGeoScoreCutoffSettingNotifier(prefs);
    });

/// Composed snapshot used by geo and audio inference.
final speciesIgnoreSettingsProvider = Provider<SpeciesIgnoreSettings>((ref) {
  return SpeciesIgnoreSettings(
    ignoreBirds: ref.watch(ignoreBirdsProvider),
    ignoreMammals: ref.watch(ignoreMammalsProvider),
    ignoreAmphibians: ref.watch(ignoreAmphibiansProvider),
    ignoreInsects: ref.watch(ignoreInsectsProvider),
    commonGeoScoreCutoff: ref.watch(ignoreCommonGeoScoreCutoffProvider),
  );
});

/// Show every species detected in the current Live or Point Count session
/// instead of only species present in the latest inference cycle.
final showAllDetectedSpeciesProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.showAllDetectedSpecies, false);
    });

abstract final class DetectedSpeciesSortMode {
  static const newest = 'newest';
  static const confidence = 'confidence';
  static const alphabetical = 'alphabetical';
  static const occurrences = 'occurrences';

  static const values = <String>[newest, confidence, alphabetical, occurrences];

  static String normalize(String value) {
    return values.contains(value) ? value : newest;
  }
}

/// Sorting for the all-species Live and Point Count display.
final detectedSpeciesSortModeProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.detectedSpeciesSortMode,
        DetectedSpeciesSortMode.newest,
      );
    });

/// Score pooling mode ('off', 'average', 'max', 'lme', 'adaptive_lme_peak').
///
/// Controls how scores from consecutive inference windows are combined.
final scorePoolingProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.scorePooling,
        'adaptive_lme_peak',
      );
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

/// Maximum real-time age, in seconds, for windows used in score pooling.
///
/// Hidden advanced setting: not exposed in Settings, but persisted so we can
/// tune it or expose it later without changing inference plumbing.
final scorePoolingMaxAgeSecondsProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(
        prefs,
        PrefKeys.scorePoolingMaxAgeSeconds,
        10.0,
      );
    });

// ── Advanced temporal-pooling knobs (LME alpha + support gate) ─────────────
//
// Normally baked into `temporalPooling` in the model config; exposed here as
// overridable settings so they can be tuned live from the Advanced section of
// the Inference settings. Defaults mirror the model-config defaults, so with
// factory settings these providers are behaviourally transparent. Bundled for
// transport via [advancedPoolingParamsProvider].

/// LME alpha — higher weights recent peaks more heavily (default 5.0).
final scorePoolingAlphaProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(prefs, PrefKeys.scorePoolingAlpha, 5.0);
    });

/// Recent windows required to clear the temporal support gate before a new
/// LME/adaptive detection appears (default 2; `1` disables the gate).
final scorePoolingMinSupportWindowsProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(
        prefs,
        PrefKeys.scorePoolingMinSupportWindows,
        2,
      );
    });

/// Fraction of the confidence threshold used as the per-window support
/// threshold, before the floor (default 0.6).
final scorePoolingSupportThresholdFractionProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(
        prefs,
        PrefKeys.scorePoolingSupportThresholdFraction,
        0.6,
      );
    });

/// Lower bound on the per-window support threshold (default 0.25).
final scorePoolingSupportThresholdFloorProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(
        prefs,
        PrefKeys.scorePoolingSupportThresholdFloor,
        0.25,
      );
    });

/// Raw current-window score that bypasses multi-window support (default 0.98).
final scorePoolingVeryHighImmediateThresholdProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(
        prefs,
        PrefKeys.scorePoolingVeryHighImmediateThreshold,
        0.98,
      );
    });

/// Composed snapshot of the advanced temporal-pooling overrides, rebuilt
/// whenever any of the underlying providers changes. Threaded through the mode
/// controllers into the inference isolate.
final advancedPoolingParamsProvider = Provider<AdvancedPoolingParams>((ref) {
  return AdvancedPoolingParams(
    alpha: ref.watch(scorePoolingAlphaProvider),
    minSupportWindows: ref.watch(scorePoolingMinSupportWindowsProvider),
    supportThresholdFraction: ref.watch(
      scorePoolingSupportThresholdFractionProvider,
    ),
    supportThresholdFloor: ref.watch(scorePoolingSupportThresholdFloorProvider),
    veryHighImmediateThreshold: ref.watch(
      scorePoolingVeryHighImmediateThresholdProvider,
    ),
  );
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
  return ColorMapSettingNotifier(prefs);
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

/// When true (default), completed Live and Point Count sessions are saved to
/// the library automatically as soon as they finish. When false, the session
/// opens in review as *unsaved*: the floppy-disk save icon is highlighted, the
/// user must tap it to keep the session, and leaving review without saving
/// discards the session and its recordings. Survey and ARU deployments always
/// auto-save regardless of this setting. Default: true (preserves the historic
/// behavior).
final saveSessionAutomaticallyProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(
        prefs,
        PrefKeys.saveSessionAutomatically,
        true,
      );
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
/// comma-separated string under [PrefKeys.exportSelection]. Defaults to
/// `{'raven'}` for new installs; users may deselect every format to
/// share the raw audio file without a ZIP container.
final exportSelectionProvider =
    StateNotifierProvider<ExportSelectionNotifier, Set<String>>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ExportSelectionNotifier(prefs);
    });

class ExportSelectionNotifier extends StateNotifier<Set<String>> {
  ExportSelectionNotifier(this._prefs) : super(_load(_prefs));

  // Sentinel string used to persist an intentionally-empty selection,
  // so SharedPreferences can distinguish "never set" from "explicitly
  // none" (the latter must NOT trigger the new-install default).
  static const String _emptySentinel = '__none__';
  static const Set<String> _allFormats = {'raven', 'csv', 'json', 'gpx'};
  static const Set<String> _defaultFormats = {'raven'};

  final SharedPreferences _prefs;

  static Set<String> _load(SharedPreferences prefs) {
    final raw = prefs.getString(PrefKeys.exportSelection);
    if (raw == null) {
      // Migrate from the legacy single-choice key when present.
      final legacy = prefs.getString(PrefKeys.exportFormat);
      if (legacy != null && _allFormats.contains(legacy)) {
        return {legacy};
      }
      return {..._defaultFormats};
    }
    if (raw.isEmpty || raw == _emptySentinel) return <String>{};
    return raw.split(',').where(_allFormats.contains).toSet();
  }

  void toggle(String format, bool enabled) {
    if (!_allFormats.contains(format)) return;
    final next = {...state};
    if (enabled) {
      next.add(format);
    } else {
      next.remove(format);
    }
    _persist(next);
  }

  void set(Set<String> formats) {
    _persist(formats.where(_allFormats.contains).toSet());
  }

  void _persist(Set<String> next) {
    state = next;
    _prefs.setString(
      PrefKeys.exportSelection,
      next.isEmpty ? _emptySentinel : next.join(','),
    );
  }
}

/// Include audio files in export (default true).
final includeAudioProvider = StateNotifierProvider<BoolSettingNotifier, bool>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BoolSettingNotifier(prefs, PrefKeys.includeAudio, true);
});

/// Convert FLAC recordings to WAV before sharing/exporting (default false).
/// WAV is universally compatible but larger; FLAC is lossless compressed.
final shareAudioAsWavProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.shareAudioAsWav, false);
    });

/// Bundle a self-contained `<session>_report.html` next to the audio in the
/// export ZIP (default true). The HTML opens in any browser, embeds the
/// session metadata + clip players, and pulls species images / data
/// from the BirdNET taxonomy API on the fly. Off-by-default for users
/// who only want the raw table + audio.
final exportHtmlReportProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.exportHtmlReport, true);
    });

/// Bundle the BirdNET Live app metadata side-file (`*.metadata.json`)
/// inside the export ZIP (default true). The side-file carries
/// provenance such as app version, model identity, weather snapshot,
/// and audio integrity warnings. Disable to share audio + selected
/// formats without app-specific metadata.
final includeAppMetadataProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.includeAppMetadata, true);
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

/// Whether to show the playback overlay (clip player sheet) in session review (default true).
final sessionReviewPlaybackOverlayProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(
        prefs,
        PrefKeys.sessionReviewPlaybackOverlay,
        true,
      );
    });

/// Whether to auto-play voice memo annotations at their timestamp during session review (default false).
final playbackVoiceMemosProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.playbackVoiceMemos, false);
    });

/// Main recording ducking while auto-playing voice memos (0.0-0.95, default 0.75).
final playbackVoiceMemoDuckingProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(
        prefs,
        PrefKeys.playbackVoiceMemoDucking,
        0.75,
      );
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

/// Species name language code ('system', 'app', 'en', 'de', 'es', etc.).
///
/// When 'system', uses the phone's preferred locale. When 'app', follows the
/// resolved app interface locale.
final speciesLanguageProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(prefs, PrefKeys.speciesLanguage, 'system');
    });

/// Preferred phone locales, exposed as a provider so locale fallback is testable.
final platformLocalesProvider = Provider<List<Locale>>((ref) {
  final locales = PlatformDispatcher.instance.locales;
  return locales.isNotEmpty
      ? locales
      : <Locale>[PlatformDispatcher.instance.locale];
});

/// Resolved app-interface locale tag, including the supported-locale fallback
/// used by [AppLocalizations].
final effectiveAppLocaleProvider = Provider<String>(_effectiveAppLocaleTag);

/// Resolved species locale code (never 'system').
///
/// Resolves 'system' to the phone locale and 'app' to the app interface locale.
final effectiveSpeciesLocaleProvider = Provider<String>((ref) {
  final setting = ref.watch(speciesLanguageProvider);
  if (setting == 'app') return _effectiveAppLocaleTag(ref);
  if (setting != 'system') return setting;

  return _platformSpeciesLocaleTag(ref);
});

String _effectiveAppLocaleTag(Ref ref) {
  final appLocale = ref.watch(localeProvider);
  if (appLocale != null) return _speciesLocaleTag(appLocale);

  final platformLocales = ref.watch(platformLocalesProvider);
  for (final preferred in platformLocales) {
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == preferred.languageCode) {
        return _speciesLocaleTag(supported);
      }
    }
  }

  return 'en';
}

String _platformSpeciesLocaleTag(Ref ref) {
  final platformLocales = ref.watch(platformLocalesProvider);
  if (platformLocales.isEmpty) return 'en';
  return _speciesLocaleTag(platformLocales.first);
}

String _speciesLocaleTag(Locale locale) {
  final language = locale.languageCode.trim();
  if (language.isEmpty) return 'en';

  final country = locale.countryCode?.trim();
  if (country != null && country.isNotEmpty && language == 'zh') {
    return '$language-$country';
  }

  return language;
}

// ---------------------------------------------------------------------------
// Point Count
// ---------------------------------------------------------------------------

/// Point count duration in minutes (default: 5).
final pointCountDurationProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.pointCountDuration, 5);
    });

/// Last used observer name in Point Count (shared across field modes).
final pointCountLastObserverProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.lastObserver,
        _legacyLastObserver(prefs),
      );
    });

/// Last used observer name across field-session modes.
final lastObserverProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.lastObserver,
        _legacyLastObserver(prefs),
      );
    });

/// Last used ARU/station ID for fixed-site deployments.
final aruLastStationIdProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(prefs, PrefKeys.aruLastStationId, '');
    });

String _legacyLastObserver(SharedPreferences prefs) {
  final surveyObserver = prefs.getString(PrefKeys.legacySurveyLastObserver);
  if (surveyObserver != null && surveyObserver.trim().isNotEmpty) {
    return surveyObserver;
  }

  final pointCountObserver = prefs.getString(
    PrefKeys.legacyPointCountLastObserver,
  );
  if (pointCountObserver != null && pointCountObserver.trim().isNotEmpty) {
    return pointCountObserver;
  }

  return '';
}

// ---------------------------------------------------------------------------
// Survey Mode
// ---------------------------------------------------------------------------

/// Survey inference rate in Hz (default 0.7).
final surveyInferenceRateProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return InferenceRateSettingNotifier(
        prefs,
        key: PrefKeys.surveyInferenceRate,
        defaultValue: 0.7,
      );
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

/// Last used observer name (shared across field modes).
final surveyLastObserverProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.lastObserver,
        _legacyLastObserver(prefs),
      );
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

class InferenceRateSettingNotifier extends DoubleSettingNotifier {
  InferenceRateSettingNotifier(
    this._inferenceRatePrefs, {
    this.key = PrefKeys.inferenceRate,
    double defaultValue = _defaultRate,
  }) : super(_inferenceRatePrefs, key, defaultValue) {
    final sanitized = _sanitize(state);
    if (sanitized != state) {
      state = sanitized;
      _inferenceRatePrefs.setDouble(key, sanitized);
    }
  }

  static const double _defaultRate = 1.0;
  final SharedPreferences _inferenceRatePrefs;
  final String key;

  static double _sanitize(double value) {
    final minTick = (inferenceRateHzValues.first * 10).round();
    final maxTick = (inferenceRateHzValues.last * 10).round();
    final tick = (value * 10).round().clamp(minTick, maxTick);
    return tick / 10.0;
  }

  @override
  Future<void> set(double value) => super.set(_sanitize(value));
}

/// Keeps the common-species cutoff on the user-visible 80–100% grid and
/// migrates values saved by earlier builds that exposed a wider range.
class CommonGeoScoreCutoffSettingNotifier extends DoubleSettingNotifier {
  CommonGeoScoreCutoffSettingNotifier(this._cutoffPrefs)
    : super(_cutoffPrefs, PrefKeys.ignoreCommonGeoScoreCutoff, 1.0) {
    final sanitized = _sanitize(state);
    if (sanitized != state) {
      state = sanitized;
      _cutoffPrefs.setDouble(PrefKeys.ignoreCommonGeoScoreCutoff, sanitized);
    }
  }

  final SharedPreferences _cutoffPrefs;

  static double _sanitize(double value) {
    final percentage = (value * 100).round().clamp(80, 100);
    return percentage / 100.0;
  }

  @override
  Future<void> set(double value) => super.set(_sanitize(value));
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

class ColorMapSettingNotifier extends StringSettingNotifier {
  ColorMapSettingNotifier(this._colorMapPrefs)
    : super(_colorMapPrefs, PrefKeys.colorMap, _defaultColorMap) {
    final sanitized = _sanitize(state);
    if (sanitized != state) {
      state = sanitized;
      _colorMapPrefs.setString(PrefKeys.colorMap, sanitized);
    }
  }

  static const String _defaultColorMap = 'viridis';
  static const Set<String> _allowedColorMaps = {
    'viridis',
    'magma',
    'plasma',
    'cividis',
    'jet',
    'turbo',
    'grayscale',
    'birdnet',
  };

  final SharedPreferences _colorMapPrefs;

  static String _sanitize(String value) {
    if (value == 'inferno') return 'magma';
    return _allowedColorMaps.contains(value) ? value : _defaultColorMap;
  }

  @override
  Future<void> set(String value) => super.set(_sanitize(value));
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
