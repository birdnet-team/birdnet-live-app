/// BirdNET Live — Real-time bird species identification.
///
/// Application constants used across the app.
library;

/// App-wide string constants.
abstract final class AppConstants {
  /// Application display name.
  static const String appName = 'BirdNET Live';

  /// GitHub repository URL.
  static const String githubUrl =
      'https://github.com/birdnet-team/birdnet-live-app';

  /// Documentation site URL.
  static const String docsUrl =
      'https://birdnet-team.github.io/birdnet-live-app';

  /// Support email address.
  static const String supportEmail = 'ccb-birdnet@cornell.edu';

  /// BirdNET website URL.
  static const String birdnetUrl = 'https://birdnet.cornell.edu';

  /// Path to the model configuration JSON asset.
  ///
  /// The config file describes the ONNX model, its label format, tensor
  /// names, and inference defaults.  All model-specific parameters are
  /// read from this file at runtime — no values are hardcoded.
  static const String modelConfigAssetPath = 'assets/models/model_config.json';

  /// Base directory for model assets.
  static const String modelAssetsDir = 'assets/models';

  /// Default audio sample rate in Hz.
  ///
  /// Used by audio capture and spectrogram before a model config is loaded.
  /// The actual rate used for inference comes from the model config JSON.
  static const int sampleRate = 32000;

  /// Default species count for display purposes.
  ///
  /// Overridden at runtime once the model config and labels are loaded.
  static const int speciesCount = 5250;
}

/// SharedPreferences key constants.
abstract final class PrefKeys {
  static const String onboardingComplete = 'onboarding_complete';
  static const String termsAccepted = 'terms_accepted';
  static const String themeMode = 'theme_mode';
  static const String dynamicColors = 'dynamic_colors';
  static const String locale = 'locale';
  static const String speciesLanguage = 'species_language';

  // Audio settings
  static const String audioGain = 'audio_gain';
  static const String highPassFilter = 'high_pass_filter';

  // Inference settings
  static const String windowDuration = 'window_duration';
  static const String confidenceThreshold = 'confidence_threshold';
  static const String inferenceRate = 'inference_rate';
  static const String speciesFilterMode = 'species_filter_mode';
  static const String sensitivity = 'sensitivity';
  static const String scorePooling = 'score_pooling';
  static const String scorePoolingWindows = 'score_pooling_windows';

  // Spectrogram settings
  static const String fftSize = 'fft_size';
  static const String colorMap = 'color_map';
  static const String dbFloor = 'db_floor';
  static const String dbCeiling = 'db_ceiling';
  static const String spectrogramDuration = 'spectrogram_duration';
  static const String spectrogramMaxFreq = 'spectrogram_max_freq';
  static const String logAmplitude = 'log_amplitude';
  static const String spectrogramQuality = 'spectrogram_quality';

  // Recording settings
  static const String recordingFormat = 'recording_format';
  static const String recordingMode = 'recording_mode';

  /// When true, Live mode auto-starts recording as soon as the model is
  /// ready (kiosk-style / hands-free use). Default: false.
  static const String liveAutoStart = 'live_auto_start';

  /// Seconds of audio captured before AND after each detection window.
  /// Total clip length = analysis window (e.g. 3 s) + 2 × clipContext.
  static const String clipContext = 'clip_context';

  // Export settings
  /// Deprecated since 0.12.0 — superseded by [exportSelection]. Kept only
  /// for one-time migration of pre-0.12.0 installs.
  static const String exportFormat = 'export_format';

  /// Comma-separated list of formats included in every export ZIP.
  /// Valid tokens: `raven`, `csv`, `json`, `gpx`. Replaces the legacy
  /// single-choice [exportFormat]. The user can enable any subset; an
  /// empty selection falls back to `raven` so the export pipeline always
  /// produces at least one document.
  static const String exportSelection = 'export_selection';

  static const String includeAudio = 'include_audio';
  static const String exportHtmlReport = 'export_html_report';

  // Location / geo settings
  static const String useGps = 'use_gps';
  static const String geoThreshold = 'geo_threshold';
  static const String manualLatitude = 'manual_latitude';
  static const String manualLongitude = 'manual_longitude';

  /// Deprecated since 0.12.0 — superseded by the three privacy-allow
  /// keys below. Kept only for a one-time migration in [main]: when the
  /// user previously allowed OSM tiles, both [privacyAllowMap] and
  /// [privacyAllowReverseGeocoding] inherit `true`.
  static const String mapTileConsent = 'map_tile_consent';

  // --- Privacy gates (0.12.0) -------------------------------------------
  // Each gates one third-party service. All default `false` for new
  // installs; existing installs that previously consented to OSM tiles
  // get the first two flipped on by the migration in `main()`.

  /// Allow fetching OSM map tiles from `tile.openstreetmap.org`. When
  /// `false`, every map widget falls back to its consent-prompt UI.
  static const String privacyAllowMap = 'privacy_allow_map';

  /// Allow reverse-geocoding GPS fixes via Nominatim
  /// (`nominatim.openstreetmap.org`).
  static const String privacyAllowReverseGeocoding =
      'privacy_allow_reverse_geocoding';

  /// Allow fetching weather snapshots from Open-Meteo
  /// (`api.open-meteo.com`).
  static const String privacyAllowWeather = 'privacy_allow_weather';

  /// Prefix for the persistent weather-snapshot cache. Each entry is
  /// keyed by a 0.1° lat/lon cell so multiple sessions in the same area
  /// share one fetch. See `WeatherService` for the freshness policy.
  static const String weatherCachePrefix = 'weather_cache_';

  /// Prefix for the persistent reverse-geocode cache. Each entry maps a
  /// 0.1° lat/lon cell key to the human-readable place name returned by
  /// Nominatim (e.g. `"Berlin, Germany"`). Place names don't change on
  /// the timescale of a birding trip, so entries have no TTL — they
  /// live until the user clears app data. See
  /// `lib/core/services/reverse_geocoding_service.dart`.
  static const String reverseGeocodeCachePrefix = 'reverse_geocode_cache_';

  // Display settings
  static const String showSciNames = 'show_sci_names';

  /// Timestamp display mode: 'relative' (session-relative `MM:SS`)
  /// or 'absolute' (local clock `HH:mm:ss`). Default 'relative'.
  static const String timestampDisplayMode = 'timestamp_display_mode';

  /// Whether per-detection timestamps in the UI include seconds
  /// (`MM:SS` / `HH:mm:ss`) or stop at minute precision (`MM` / `HH:mm`).
  /// Exports always include seconds regardless of this setting. Default true.
  static const String timestampShowSeconds = 'timestamp_show_seconds';

  // Point count settings
  static const String pointCountDuration = 'point_count_duration';
  static const String pointCountLastObserver = 'point_count_last_observer';

  // Survey settings
  static const String surveyInferenceRate = 'survey_inference_rate';
  static const String surveyGpsInterval = 'survey_gps_interval';
  static const String surveyMaxDuration = 'survey_max_duration';
  static const String surveyAutoStopBattery = 'survey_auto_stop_battery';
  static const String surveyRecordingMode = 'survey_recording_mode';

  /// Seconds of audio captured before AND after each detection window
  /// in survey mode. Total clip = analysis window + 2 × surveyClipContext.
  static const String surveyClipContext = 'survey_clip_context';
  static const String surveyDetectionSampling = 'survey_detection_sampling';
  static const String surveyTopNPerSpecies = 'survey_top_n_per_species';
  static const String micDeviceId = 'mic_device_id';
  static const String surveyLastObserver = 'survey_last_observer';
  static const String surveyLastTransectId = 'survey_last_transect_id';

  // Survey species alerts (v0.7.0+)
  /// Alert mode: 0 = off, 1 = first-in-session, 2 = first-ever,
  /// 3 = rare (geo-model), 4 = watchlist.
  static const String surveyAlertMode = 'survey_alert_mode';
  static const String surveyAlertRareThreshold = 'survey_alert_rare_threshold';
  static const String surveyAlertWatchlistName = 'survey_alert_watchlist_name';
  static const String surveyAlertSound = 'survey_alert_sound';
  static const String surveyAlertVibrate = 'survey_alert_vibrate';
  static const String surveyAlertMinConfidence = 'survey_alert_min_confidence';
  static const String surveyAlertStartupGraceSeconds =
      'survey_alert_startup_grace_seconds';
  static const String surveyAlertMinIntervalSeconds =
      'survey_alert_min_interval_seconds';

  /// Maximum delivered alerts per minute. `0` means unlimited.
  static const String surveyAlertMaxPerMinute = 'survey_alert_max_per_minute';
  static const String surveyAlertCoalesce = 'survey_alert_coalesce';
  static const String surveyAlertInAppToast = 'survey_alert_in_app_toast';

  // Global species history (v0.7.0+)
  /// JSON-encoded list of every scientific name ever detected.
  static const String globalSpeciesHistory = 'global_species_history';

  /// `true` once the one-time backfill from existing sessions has run.
  static const String globalSpeciesHistorySeeded =
      'global_species_history_seeded';

  /// Persisted view mode for the Session Library screen
  /// (one of `_ViewMode.name`: detailed, compact, bySpecies).
  static const String sessionLibraryViewMode = 'session_library_view_mode';

  /// Persisted default mode for the Session Library "new session" FAB
  /// (one of `SessionType.name`: live, pointCount, survey, fileUpload).
  /// Remembers the user's last choice so a single tap re-enters the
  /// preferred workflow.
  static const String sessionLibraryNewMode = 'session_library_new_mode';

  /// Persisted sort order for the species list on the Session Review
  /// screen (one of `SpeciesSortMode.name`: alphabetical, count,
  /// confidence, firstSeen). Default `alphabetical` — once a session
  /// has 50+ species, finding one by detection-time order becomes
  /// painful; alphabetical is the predictable fallback.
  static const String sessionReviewSpeciesSort = 'session_review_species_sort';
}
