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

  /// Mobile application package identifier.
  static const String packageName = 'de.tu_chemnitz.mi.kahst.birdnet_live';

  /// Contactable User-Agent for public web services used by the app.
  static const String networkUserAgent =
      'BirdNETLive (de.tu_chemnitz.mi.kahst.birdnet_live; '
      '+https://github.com/birdnet-team/birdnet-live-app)';

  /// Documentation site URL.
  static const String docsUrl =
      'https://birdnet-team.github.io/birdnet-live-app';

  /// UI locales that have the full translated user guide on the docs site.
  /// Other UI locales (e.g. nl, pl, ru) fall back to the English guide.
  static const Set<String> docsLocales = {'de', 'cs', 'es', 'fr', 'it', 'pt'};

  /// UI locales that have a translated Privacy Policy and Acceptable Use
  /// Policy on the docs site. Broader than [docsLocales]: the policies are
  /// translated for every UI locale, even those whose user guide is not.
  static const Set<String> policyDocsLocales = {
    'de',
    'cs',
    'es',
    'fr',
    'it',
    'pt',
    'nl',
    'pl',
    'ru',
  };

  /// Docs-site path prefix for [languageCode] (e.g. `/de`), or an empty
  /// string (English docs) when no translated user guide exists for that
  /// locale. Use this for user-guide links.
  static String docsLocalePrefix(String languageCode) =>
      docsLocales.contains(languageCode) ? '/$languageCode' : '';

  /// Docs-site path prefix for the Privacy Policy / Acceptable Use Policy
  /// pages in [languageCode] (e.g. `/nl`), or an empty string (English) when
  /// no translated policy exists for that locale. Use this for policy links.
  static String policyDocsLocalePrefix(String languageCode) =>
      policyDocsLocales.contains(languageCode) ? '/$languageCode' : '';

  /// Support email address.
  static const String supportEmail = 'ccb-birdnet@cornell.edu';

  /// BirdNET website URL.
  static const String birdnetUrl = 'https://birdnet.cornell.edu';

  /// BirdNET donation page URL.
  static const String birdnetDonateUrl = 'https://birdnet.cornell.edu/donate/';

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
  static const int speciesCount = 9789;
}

/// SharedPreferences key constants.
abstract final class PrefKeys {
  static const String onboardingComplete = 'onboarding_complete';
  static const String termsAccepted = 'terms_accepted';
  static const String themeMode = 'theme_mode';
  static const String dynamicColor = 'dynamic_color';
  static const String highContrastTheme = 'high_contrast_theme';
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
  static const String showAllDetectedSpecies = 'show_all_detected_species';
  static const String detectedSpeciesSortMode = 'detected_species_sort_mode';
  static const String scorePooling = 'score_pooling';
  static const String scorePoolingWindows = 'score_pooling_windows';
  static const String scorePoolingMaxAgeSeconds =
      'score_pooling_max_age_seconds';
  static const String scorePoolingDefaultMigration =
      'score_pooling_default_migration_v1';

  /// One-shot flag for deleting the pre-0.19.4 `flutter_cache_manager` tile
  /// store, which flutter_map's built-in tile cache replaced.
  static const String legacyTileCachePurge = 'legacy_tile_cache_purge_v1';

  // Advanced temporal-pooling knobs (LME alpha + support gate). Normally
  // baked into the model config; exposed as overridable settings so they can
  // be tuned live. Defaults mirror `temporalPooling` in model_config.json.
  static const String scorePoolingAlpha = 'score_pooling_alpha';
  static const String scorePoolingMinSupportWindows =
      'score_pooling_min_support_windows';
  static const String scorePoolingSupportThresholdFraction =
      'score_pooling_support_threshold_fraction';
  static const String scorePoolingSupportThresholdFloor =
      'score_pooling_support_threshold_floor';
  static const String scorePoolingVeryHighImmediateThreshold =
      'score_pooling_very_high_immediate_threshold';

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

  /// When true (default), completed Live and Point Count sessions are saved
  /// to the library automatically. When false, the session opens in review as
  /// unsaved and is only kept if the user explicitly saves it.
  static const String saveSessionAutomatically = 'save_session_automatically';

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
  static const String shareAudioAsWav = 'share_audio_as_wav';
  static const String exportHtmlReport = 'export_html_report';
  static const String includeAppMetadata = 'include_app_metadata';

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

  // Shared field-session identity settings
  static const String lastObserver = 'last_observer';
  static const String aruLastStationId = 'aru_last_station_id';
  static const String legacyPointCountLastObserver =
      'point_count_last_observer';
  static const String legacySurveyLastObserver = 'survey_last_observer';

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

  /// Name of the selected [AudioSourceProfile] (Android capture source).
  /// Absent / unknown means the system default.
  static const String audioSourceProfile = 'audio_source_profile';
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
  /// confidence, firstSeen). Default `confidence` so review starts with
  /// the most likely identifications.
  static const String sessionReviewSpeciesSort = 'session_review_species_sort';

  /// Whether to show the playback overlay (clip player sheet) in session review.
  static const String sessionReviewPlaybackOverlay =
      'session_review_playback_overlay';

  /// Whether to auto-play voice memo annotations at their timestamp during review.
  static const String playbackVoiceMemos = 'playback_voice_memos';

  /// Main recording volume reduction while auto-playing voice memos.
  static const String playbackVoiceMemoDucking = 'playback_voice_memo_ducking';

  // --- Announcements (spoken detections, post-v1.0) ---------------------
  // See [dev/announcements.md] for the full design. The user-facing
  // surface is two preset enums (`announcementsVerbosity`,
  // `announcementsFrequency`); the numeric `*` keys below are the
  // Advanced overrides that a preset change stamps into in one
  // transaction. Manually editing an Advanced key sets the matching
  // preset to `custom` so the UI never lies about which preset is in
  // effect.

  /// Master toggle. Default `false`; flipped by the setup wizard.
  static const String announcementsEnabled = 'announcements_enabled';

  /// `true` once the user finished the 5-step setup wizard at least
  /// once. Prevents the wizard from auto-opening a second time.
  static const String announcementsWizardCompleted =
      'announcements_wizard_completed';

  /// Legacy marker for the removed screen-reader accessibility default.
  /// Kept so older exported settings containing this key remain readable.
  static const String announcementsAccessibilityDefaultApplied =
      'announcements_accessibility_default_applied';

  /// One of `AnnouncementVerbosity.name`: `minimal` | `balanced`
  /// (default) | `chatty` | `custom`.
  static const String announcementsVerbosity = 'announcements_verbosity';

  /// One of `AnnouncementFrequency.name`: `sparse` | `normal` (default)
  /// | `frequent` | `custom`.
  static const String announcementsFrequency = 'announcements_frequency';

  /// BCP-47 voice locale (e.g. `en-US`, `de-DE`). Empty string ⇒ track
  /// the active UI locale.
  static const String announcementsVoiceLanguage =
      'announcements_voice_language';

  /// Engine-specific identifier of a pinned voice (as reported by
  /// `flutter_tts.getVoices`). Empty string ⇒ the platform default voice
  /// for the resolved language. Lets users escape a poor default voice.
  static const String announcementsVoiceName = 'announcements_voice_name';

  /// TTS rate multiplier (0.5–1.5, default 1.0).
  static const String announcementsVoiceRate = 'announcements_voice_rate';

  /// TTS pitch multiplier (0.7–1.3, default 1.0).
  static const String announcementsVoicePitch = 'announcements_voice_pitch';

  /// Set by the wizard's "Just the phone" confirmation step. When
  /// `false`, the controller refuses to speak through the built-in
  /// speaker even if no other output device is available.
  static const String announcementsSpeakerOutputAllowed =
      'announcements_speaker_output_allowed';

  /// Mute the input ring buffer for the duration of an utterance plus
  /// the routing-mode guard band (200 ms headphones, 400 ms speaker).
  static const String announcementsMuteCaptureDuringSpeech =
      'announcements_mute_capture_during_speech';

  /// Request `transient_may_duck` audio focus so background media ducks
  /// for ~1 s instead of stopping.
  static const String announcementsDuckOtherAudio =
      'announcements_duck_other_audio';

  /// Play a short pre-roll cue tone (~150 ms) before each utterance.
  static const String announcementsPrerollCue = 'announcements_preroll_cue';

  /// Seconds at session start during which no announcement fires.
  static const String announcementsStartupGraceSeconds =
      'announcements_startup_grace_seconds';

  /// Minimum gap between two consecutive announcements (any species).
  static const String announcementsMinIntervalSeconds =
      'announcements_min_interval_seconds';

  /// Hard cap on announcements per rolling 60 s window.
  static const String announcementsMaxPerMinute =
      'announcements_max_per_minute';

  /// Per-species cooldown — within this window, repeats of the same
  /// species fall into the streak / "again" buckets instead of
  /// triggering a fresh announcement (§3.4).
  static const String announcementsStreakSilenceSeconds =
      'announcements_streak_silence_seconds';

  /// Per-species window after which the species is no longer "recent"
  /// for bucket selection (§3.1).
  static const String announcementsRecencyResetSeconds =
      'announcements_recency_reset_seconds';

  /// Window after which we forget any per-species bookkeeping for the
  /// current session (§3.4).
  static const String announcementsSessionResetSeconds =
      'announcements_session_reset_seconds';

  /// Detections arriving within this window of a pending utterance get
  /// rolled into a Bucket-H multi-species line (§3.7).
  static const String announcementsCoalesceWindowSeconds =
      'announcements_coalesce_window_seconds';

  /// Trigger mode — `all` | `firstInSession` | `watchlist`. Default
  /// `all`; the wizard never asks, but Advanced exposes it.
  static const String announcementsTriggerMode = 'announcements_trigger_mode';
}
