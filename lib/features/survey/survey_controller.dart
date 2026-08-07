// =============================================================================
// Survey Controller — Orchestrates a long-running background survey
// =============================================================================
//
// Uses composition (not inheritance) with the same components as LiveController:
//
//   - [AudioCaptureService] + [RingBuffer] — audio pipeline
//   - [InferenceIsolate] — ONNX model inference
//   - [RecordingService] — audio file writing
//   - [SurveyGpsTracker] — GPS track recording
//   - [DetectionSampler] — controls which detections to keep
//
// ### State machine
//
//   idle → starting → active → stopping → finalized
//
// No paused state — surveys are always-on or stopped.
//
// ### Key differences from LiveController
//
//   - Incremental persistence every 30 s (crash resilience)
//   - GPS tracking with detection location tagging
//   - Detection sampling (All / Top N / Smart)
//   - No spectrogram (battery saving)
//   - Auto-stop on max duration or low battery
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'survey_notification.dart';
import 'survey_alert_coordinator.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/asset_pack_service.dart';
import '../../core/services/memory_monitor.dart';
import '../announcements/announcements_controller.dart'
    show AnnouncementDetection;
import '../audio/ring_buffer.dart';
import '../history/session_path_codec.dart';
import '../inference/advanced_pooling_params.dart';
import '../inference/detection_accumulator.dart';
import '../inference/detection_clip_writer.dart';
import '../inference/inference_isolate.dart';
import '../inference/inference_window_driver.dart';
import '../inference/model_config.dart';
import '../inference/species_filter.dart';
import '../inference/species_ignore_filter.dart';
import '../recording/recording_service.dart';
import 'detection_sampler.dart';
import 'survey_gps_tracker.dart';
import '../live/live_session.dart';
import '../../shared/models/gps_point.dart';

// =============================================================================
// State
// =============================================================================

/// Lifecycle state of the survey pipeline.
enum SurveyState { idle, loading, starting, active, stopping, finalized, error }

// =============================================================================
// Controller
// =============================================================================

/// Orchestrates a long-running survey with GPS tracking, inference, recording,
/// and incremental persistence.
class SurveyController {
  SurveyController({
    required this.ringBuffer,
    required this.recordingService,
    bool Function()? gpsEnabled,
  }) : _gpsEnabled = gpsEnabled;

  final RingBuffer ringBuffer;
  final RecordingService recordingService;

  /// Reads Settings → Location → Use GPS. When off, no GPS tracker is
  /// created and the survey runs on the coordinates chosen in setup.
  final bool Function()? _gpsEnabled;
  bool get _useGps => _gpsEnabled?.call() ?? true;
  final SurveyNotificationService _notificationService =
      SurveyNotificationService();
  final Battery _battery = Battery();

  // ── Internal state ──────────────────────────────────────────────────────

  final InferenceIsolate _isolate = InferenceIsolate();
  ModelConfig? _config;
  LiveSession? _session;
  late final InferenceWindowDriver _windowDriver = InferenceWindowDriver(
    ringBuffer: ringBuffer,
    debugLabel: 'SurveyController',
  );
  int _sessionGeneration = 0;
  Timer? _persistTimer;
  Timer? _notificationTimer;
  SurveyGpsTracker? _gpsTracker;
  DetectionSampler? _sampler;
  SurveyState _state = SurveyState.idle;
  String? _errorMessage;
  DateTime? _maxEndTime;
  int _autoStopBattery = 0;

  /// All session detections (newest first).
  final List<DetectionRecord> _sessionDetections = [];

  /// Current live detections — replaced each inference cycle.
  List<DetectionRecord> _currentLiveDetections = const [];

  bool _inferring = false;
  int _inferenceCycleCount = 0;

  // Species filtering state.
  Map<String, double>? _geoScores;
  Set<String>? _geoModelSpeciesNames;
  SpeciesFilterMode _filterMode = SpeciesFilterMode.off;
  double _geoThreshold = 0.03;
  bool _saveDetectionClips = false;

  /// Live-tunable confidence threshold (0–100 scale). Captured at
  /// survey start; updated by [setConfidenceThreshold] without
  /// restarting the inference timer so a mid-survey settings change is
  /// picked up on the next cycle.
  int _confidenceThreshold = 50;

  /// Live-tunable sensitivity (typically 0.5–1.5). Same semantics as
  /// in [LiveController]: shifts the sigmoid horizontally in logit
  /// space without changing slope. Updated mid-survey by
  /// [setSensitivity].
  double _sensitivity = 1.0;

  DetectionAccumulator? _accumulator;

  /// Clip writes run outside the inference critical path.
  ///
  /// Closed records reach the sampler through [onClipsSettled] rather than the
  /// moment they close: the sampler may delete a clip and clear its path in
  /// place, which must not happen while a write for that record is still in
  /// flight.
  late final DetectionClipWriter _clipWriter = DetectionClipWriter(
    recordingService: recordingService,
    debugLabel: 'SurveyController',
    accumulatorOf: () => _accumulator,
    isCurrentSession: () => _session != null,
    onRecordsChanged: () {
      _syncSessionDetections();
      _notifyListeners();
    },
    onClipsSettled: _queueClosedForSampling,
  );
  Future<void> _samplerTail = Future<void>.value();

  /// Optional per-survey alert pipeline. `null` when alerts are disabled
  /// for the current survey (mode == off, or no notifier was configured).
  SurveyAlertCoordinator? _alertCoordinator;

  /// Maps a scientific name to the user's preferred localized common name.
  /// Used by the foreground notification when listing recent detections.
  /// `null` falls back to [DetectionRecord.commonName] (English).
  String Function(String sciName, String fallback)? _nameLocalizer;

  /// Localized strings for the foreground notification's recent-detections
  /// list. `null` keeps the previous (stats-only) layout.
  _NotificationStrings? _notificationStrings;

  /// Whether the microphone is currently held by another app. When `true`,
  /// the foreground notification surfaces a status line so users know
  /// why audio appears frozen (e.g. an audiobook is playing). Updated
  /// from [setMicContested] which is wired to the audio capture
  /// service's contention stream by the survey screen.
  bool _micContested = false;

  /// Immutable snapshot of the up-to-3 most-recent unique-species
  /// detections used by the foreground notification body. Rebuilt via
  /// [_refreshRecentForNotification] every time `_sessionDetections`
  /// changes so the notification text never iterates a list that may be
  /// mutated mid-render. Always replaced by an immutable list (swap),
  /// never mutated in place.
  List<DetectionRecord> _recentForNotification = const <DetectionRecord>[];

  /// Update the microphone-contested flag and refresh the notification
  /// so the user immediately sees the status change.
  void setMicContested(bool contested) {
    if (_micContested == contested) return;
    _micContested = contested;
    // Best-effort notification refresh; safe to await elsewhere.
    _updateNotification();
  }

  static const int _maxInMemoryDetections = 10000;

  /// How often we persist the session to disk and run the battery check.
  /// Cheap notification text refresh runs on its own faster cadence (see
  /// [_notificationIntervalSeconds]) so the lock-screen timer matches the
  /// recorded time without thrashing storage.
  static const int _persistIntervalSeconds = 30;

  /// How often the foreground notification body is refreshed.
  static const int _notificationIntervalSeconds = 1;

  /// Wall-clock time when the current recording segment started. Reset on
  /// [startSurvey] / [resumeSurvey] and cleared when the survey stops.
  /// Used together with [LiveSession.recordedDurationSeconds] so that
  /// pause/resume gaps don't inflate the reported recording duration.
  DateTime? _segmentStart;

  // ── Getters ─────────────────────────────────────────────────────────────

  SurveyState get state => _state;
  String? get errorMessage => _errorMessage;
  ModelConfig? get config => _config;
  LiveSession? get session => _session;
  SurveyGpsTracker? get gpsTracker => _gpsTracker;
  DetectionSampler? get sampler => _sampler;

  List<DetectionRecord> get sessionDetections =>
      List.unmodifiable(_sessionDetections);

  List<DetectionRecord> get currentLiveDetections =>
      List.unmodifiable(_currentLiveDetections);

  bool get isInferring => _inferring;

  /// Elapsed *recording* duration (excludes pause/resume gaps).
  ///
  /// Computed as the persisted [LiveSession.recordedDurationSeconds]
  /// (accumulated from previous segments) plus the time since the current
  /// segment started. Falls back to wall-clock when no segment is open.
  Duration get elapsed {
    if (_session == null) return Duration.zero;
    final accumulated = Duration(
      seconds: _session!.recordedDurationSeconds ?? 0,
    );
    if (_segmentStart == null) return accumulated;
    return accumulated + DateTime.now().difference(_segmentStart!);
  }

  // ── Callbacks ───────────────────────────────────────────────────────────

  /// Called whenever the state changes.
  void Function()? onStateChanged;

  /// Called when auto-stop triggers (max duration or battery).
  void Function(String reason)? onAutoStop;

  /// Called once per inference cycle with the current cycle's full set
  /// of filtered detections (one record per species, with that cycle's
  /// score). Used by the Announcements feature; submitting every cycle
  /// lets the controller pick the peak score per species, while its
  /// streak silence and min-interval gates throttle re-announcements.
  /// Errors thrown by the callback are swallowed so TTS hiccups never
  /// reach the inference loop.
  void Function(List<AnnouncementDetection> batch)? onFreshDetections;

  /// Called when a fresh survey starts (at the bottom of
  /// [startSurvey]). Used by the Announcements feature to reset
  /// per-session bookkeeping.
  void Function()? onSessionStarted;

  /// Attach (or detach) the per-survey alert coordinator. Call before
  /// [startSurvey] / [resumeSurvey] so initial detections go through the
  /// pipeline. Pass `null` to disable alerts entirely. Replacing an
  /// existing coordinator first calls `shutdown()` on it.
  Future<void> setAlertCoordinator(SurveyAlertCoordinator? coord) async {
    final old = _alertCoordinator;
    _alertCoordinator = coord;
    if (old != null && !identical(old, coord)) {
      await old.shutdown(flushFinal: false);
    }
  }

  /// Currently-attached alert coordinator (read-only).
  SurveyAlertCoordinator? get alertCoordinator => _alertCoordinator;

  /// Localized title used for the foreground-service notification. Falls
  /// back to the device-locale title loaded in [SurveyNotificationService]
  /// until [setNotificationStrings] supplies an app-locale title.
  String get _notificationTitle =>
      _notificationStrings?.title ??
      SurveyNotificationService.notificationTitle;

  /// Set the species-name localizer used by the foreground notification.
  /// Pass `null` to revert to English fallbacks.
  void setNameLocalizer(
    String Function(String sciName, String fallback)? localizer,
  ) {
    _nameLocalizer = localizer;
  }

  /// Set localized strings for the foreground-notification recent-detections
  /// list and the stats footer. Call once during survey setup with values
  /// pulled from [AppLocalizations]. Without this the controller falls
  /// back to terse English ("just now", "X det · Y spp · Z km").
  void setNotificationStrings({
    String? title,
    required String justNow,
    required String Function(int seconds) secondsAgo,
    required String Function(int minutes) minutesAgo,
    required String Function(int hours) hoursAgo,
    required String Function(
      String elapsed,
      int detections,
      int species,
      String distanceKm,
    )
    stats,
    String? micContested,
  }) {
    _notificationStrings = _NotificationStrings(
      title: title,
      justNow: justNow,
      secondsAgo: secondsAgo,
      minutesAgo: minutesAgo,
      hoursAgo: hoursAgo,
      stats: stats,
      micContested: micContested,
    );
  }

  // ── Model loading ───────────────────────────────────────────────────────

  /// Load the ONNX model from assets.
  Future<void> loadModel() async {
    if (_state == SurveyState.loading || _state == SurveyState.active) return;

    _state = SurveyState.loading;
    _errorMessage = null;
    _notifyListeners();

    try {
      final configJson = await rootBundle.loadString(
        AppConstants.modelConfigAssetPath,
      );
      final fullConfig = json.decode(configJson) as Map<String, dynamic>;
      _config = ModelConfig.fromJson(
        fullConfig['audioModel'] as Map<String, dynamic>,
      );

      // Resolve via install-time asset pack (Play Store AAB) or fall
      // back to extracting from rootBundle (sideload APK).
      final modelFilePath = await AssetPackService.resolveModelPath(
        fileName: _config!.onnx.modelFile,
        version: _config!.version,
      );

      final labelsAssetPath =
          '${AppConstants.modelAssetsDir}/${_config!.labels.file}';
      final labelsCsv = await rootBundle.loadString(labelsAssetPath);

      final blacklistFile = _config!.scoreBlacklistFile;
      final scoreBlacklistJson =
          blacklistFile == null
              ? null
              : await rootBundle.loadString(
                '${AppConstants.modelAssetsDir}/$blacklistFile',
              );

      await _isolate.start(
        modelFilePath: modelFilePath,
        labelsCsv: labelsCsv,
        config: _config!,
        scoreBlacklistJson: scoreBlacklistJson,
      );

      _state = SurveyState.idle;
      debugPrint('[SurveyController] model loaded');
    } catch (e, st) {
      debugPrint('[SurveyController] loadModel error: $e\n$st');
      _state = SurveyState.error;
      _errorMessage = e.toString();
    }
    _notifyListeners();
  }

  // ── Session lifecycle ─────────────────────────────────────────────────

  /// Start a new survey session.
  Future<void> startSurvey({
    required int windowDuration,
    required double inferenceRate,
    required int confidenceThreshold,
    required String speciesFilterMode,
    required RecordingMode recordingMode,
    String recordingFormat = 'flac',
    Map<String, double>? geoScores,
    double geoThreshold = 0.03,
    Set<String>? geoModelSpeciesNames,
    required int gpsIntervalSeconds,
    required int maxDurationHours,
    required SamplingMode samplingMode,
    int topNPerSpecies = 10,
    int clipContextSeconds = 0,
    String? transectId,
    String? observerName,
    String? customName,
    double? startLatitude,
    double? startLongitude,
    bool backgroundGps = true,
    bool foregroundGps = false,
    int autoStopBattery = 0,
    SessionSettings? settingsSnapshot,
    int? poolingWindows,
    String poolingMode = 'adaptive_lme_peak',
    double? poolingMaxAgeSeconds,
    AdvancedPoolingParams advancedPooling = AdvancedPoolingParams.none,
    double sensitivity = 1.0,
    SpeciesIgnoreSettings ignoreSettings = const SpeciesIgnoreSettings(),
    Set<String> ignoredSpeciesNames = const <String>{},
    double? gainLinear,
    double? highPassHz,
  }) async {
    if (_state == SurveyState.active) return;
    _sessionGeneration++;
    _state = SurveyState.starting;
    _notifyListeners();

    try {
      // Load model if not already loaded.
      if (!_isolate.isRunning) {
        await loadModel();
        if (_state == SurveyState.error) return;
      }

      final sessionId = DateTime.now().toIso8601String().replaceAll(':', '-');

      _session = LiveSession(
        id: sessionId,
        startTime: DateTime.now(),
        type: SessionType.survey,
        settings:
            settingsSnapshot ??
            SessionSettings(
              windowDuration: windowDuration,
              confidenceThreshold: confidenceThreshold,
              inferenceRate: inferenceRate,
              speciesFilterMode: speciesFilterMode,
              clipContextSeconds: clipContextSeconds,
              sensitivity: sensitivity,
              ignoreBirds: ignoreSettings.ignoreBirds,
              ignoreMammals: ignoreSettings.ignoreMammals,
              ignoreAmphibians: ignoreSettings.ignoreAmphibians,
              ignoreInsects: ignoreSettings.ignoreInsects,
              ignoreCommonGeoScoreCutoff: ignoreSettings.commonGeoScoreCutoff,
              poolingMode: poolingMode,
              poolingWindows: poolingWindows,
              poolingMaxAgeSeconds: poolingMaxAgeSeconds,
              poolingAlpha: advancedPooling.alpha,
              poolingMinSupportWindows: advancedPooling.minSupportWindows,
              poolingSupportThresholdFraction:
                  advancedPooling.supportThresholdFraction,
              poolingSupportThresholdFloor:
                  advancedPooling.supportThresholdFloor,
              poolingVeryHighImmediateThreshold:
                  advancedPooling.veryHighImmediateThreshold,
              gainLinear: gainLinear,
              highPassHz: highPassHz,
              recordingMode: recordingMode.name,
              recordingFormat: recordingFormat,
              detectionSamplingMode: samplingMode.name,
              topNPerSpecies: topNPerSpecies,
              gpsIntervalSeconds: gpsIntervalSeconds,
              maxDurationHours: maxDurationHours,
              autoStopBatteryPercent: autoStopBattery,
              backgroundGps: backgroundGps,
            ),
        transectId: transectId,
        observerName: observerName,
        customName: customName,
      );

      if (startLatitude != null && startLongitude != null) {
        _session!.latitude = startLatitude;
        _session!.longitude = startLongitude;
      }

      _sessionDetections.clear();
      _refreshRecentForNotification();
      _currentLiveDetections = const [];
      _accumulator = DetectionAccumulator(
        sessionStart: _session!.startTime,
        records: _session!.detections,
      );
      _clipWriter.reset();
      _samplerTail = Future<void>.value();
      _confidenceThreshold = confidenceThreshold;
      _sensitivity = sensitivity;
      _isolate.setMaxPoolWindows(poolingWindows);
      _isolate.setMaxPoolAgeSeconds(poolingMaxAgeSeconds);
      _isolate.setPoolingMode(poolingMode);
      _isolate.applyAdvancedPoolingParams(advancedPooling);
      _isolate.setIgnoredSpeciesNames(ignoredSpeciesNames);
      _isolate.resetPooling();
      _inferenceCycleCount = 0;
      ringBuffer.clear();
      _windowDriver.start(
        sampleRate: _config?.audio.sampleRate ?? AppConstants.sampleRate,
        windowDurationSeconds: windowDuration,
        inferenceRateHz: inferenceRate,
      );

      if (kDebugMode) {
        MemoryMonitor.startPeriodic(intervalSeconds: 30);
        MemoryMonitor.logOnce(tag: 'survey-start');
      }

      // Store geo-filter state.
      _geoScores = geoScores;
      _geoThreshold = geoThreshold;
      _geoModelSpeciesNames = geoModelSpeciesNames;
      _filterMode = switch (speciesFilterMode) {
        'geoExclude' => SpeciesFilterMode.geoExclude,
        'geoMerge' => SpeciesFilterMode.geoMerge,
        'customList' => SpeciesFilterMode.customList,
        _ => SpeciesFilterMode.off,
      };

      // Detection sampling.
      _sampler = DetectionSampler(mode: samplingMode, topN: topNPerSpecies);

      // Recording: respect the user’s choice (full / clips / off).
      _saveDetectionClips = recordingMode == RecordingMode.detectionsOnly;
      // Clips cover the window the model scored, whichever length this survey
      // analyzes with.
      recordingService.setWindowSeconds(windowDuration);
      if (recordingMode != RecordingMode.off) {
        final dir = await recordingService.startRecording(
          sessionId: sessionId,
          mode: recordingMode,
          format: recordingFormat,
        );
        _session!.recordingPath = dir;
      }

      // GPS tracking — skipped entirely when the user has GPS turned off.
      if (_useGps) {
        _gpsTracker = SurveyGpsTracker(intervalSeconds: gpsIntervalSeconds);
        _gpsTracker!.onPoint = _onGpsPoint;
        if (backgroundGps || foregroundGps) {
          await _gpsTracker!.startTracking();
        } else {
          // Manual GPS mode: capture initial fix.
          await _gpsTracker!.captureOnce();
        }
      }

      // Max duration auto-stop.
      _maxEndTime = DateTime.now().add(Duration(hours: maxDurationHours));
      _autoStopBattery = autoStopBattery;

      // Open the first recording segment so [elapsed] starts ticking.
      _session!.startSegment();
      _segmentStart = DateTime.now();

      // Start incremental persistence timer.
      _persistTimer = Timer.periodic(
        const Duration(seconds: _persistIntervalSeconds),
        (_) {
          _persistSession();
          _checkBatteryAutoStop();
        },
      );

      // Refresh the foreground notification on its own faster cadence so
      // the lock-screen timer matches the recorded time.
      _notificationTimer = Timer.periodic(
        const Duration(seconds: _notificationIntervalSeconds),
        (_) => _updateNotification(),
      );

      // Start foreground service notification.
      await _notificationService.start(
        title: _notificationTitle,
        text: _buildNotificationText(),
      );

      _state = SurveyState.active;
      _armNextInference();
      onSessionStarted?.call();
      _notifyListeners();

      debugPrint(
        '[SurveyController] survey started '
        '(rate=${inferenceRate}Hz, gps=${gpsIntervalSeconds}s, '
        'sampling=${samplingMode.name})',
      );
    } catch (e, st) {
      debugPrint('[SurveyController] startSurvey error: $e\n$st');
      await _cleanupFailedStart();
      _state = SurveyState.error;
      _errorMessage = e.toString();
      _notifyListeners();
    }
  }

  /// Resume an unfinished survey from an existing [LiveSession].
  ///
  /// Restores detections and GPS track from the saved session, then starts
  /// a fresh inference + GPS pipeline that appends to the existing data.
  Future<void> resumeSurvey({
    required LiveSession existingSession,
    required int windowDuration,
    required double inferenceRate,
    required int confidenceThreshold,
    required String speciesFilterMode,
    required RecordingMode recordingMode,
    String recordingFormat = 'flac',
    Map<String, double>? geoScores,
    double geoThreshold = 0.03,
    Set<String>? geoModelSpeciesNames,
    required int gpsIntervalSeconds,
    required int maxDurationHours,
    required SamplingMode samplingMode,
    int topNPerSpecies = 10,
    bool backgroundGps = true,
    bool foregroundGps = false,
    int autoStopBattery = 0,
    int? poolingWindows,
    String poolingMode = 'adaptive_lme_peak',
    double? poolingMaxAgeSeconds,
    AdvancedPoolingParams advancedPooling = AdvancedPoolingParams.none,
    double sensitivity = 1.0,
    SpeciesIgnoreSettings ignoreSettings = const SpeciesIgnoreSettings(),
    Set<String> ignoredSpeciesNames = const <String>{},
  }) async {
    if (_state == SurveyState.active) return;
    _sessionGeneration++;
    _state = SurveyState.starting;
    _notifyListeners();

    try {
      if (!_isolate.isRunning) {
        await loadModel();
        if (_state == SurveyState.error) return;
      }

      // Restore the existing session.
      _session = existingSession;

      // Restore in-memory detection list (newest first).
      _sessionDetections.clear();
      _sessionDetections.addAll(existingSession.detections.reversed);
      _refreshRecentForNotification();
      _currentLiveDetections = const [];
      _accumulator = DetectionAccumulator(
        sessionStart: existingSession.startTime,
        records: existingSession.detections,
      );
      _clipWriter.reset();
      _samplerTail = Future<void>.value();
      _confidenceThreshold = confidenceThreshold;
      _sensitivity = sensitivity;
      _isolate.setMaxPoolWindows(poolingWindows);
      _isolate.setMaxPoolAgeSeconds(poolingMaxAgeSeconds);
      _isolate.setPoolingMode(poolingMode);
      _isolate.applyAdvancedPoolingParams(advancedPooling);
      _isolate.setIgnoredSpeciesNames(ignoredSpeciesNames);
      _isolate.resetPooling();
      _inferenceCycleCount = 0;
      ringBuffer.clear();
      _windowDriver.start(
        sampleRate: _config?.audio.sampleRate ?? AppConstants.sampleRate,
        windowDurationSeconds: windowDuration,
        inferenceRateHz: inferenceRate,
      );

      if (kDebugMode) {
        MemoryMonitor.startPeriodic(intervalSeconds: 30);
        MemoryMonitor.logOnce(tag: 'survey-resume');
      }

      _geoScores = geoScores;
      _geoThreshold = geoThreshold;
      _geoModelSpeciesNames = geoModelSpeciesNames;
      _filterMode = switch (speciesFilterMode) {
        'geoExclude' => SpeciesFilterMode.geoExclude,
        'geoMerge' => SpeciesFilterMode.geoMerge,
        'customList' => SpeciesFilterMode.customList,
        _ => SpeciesFilterMode.off,
      };

      _sampler = DetectionSampler(mode: samplingMode, topN: topNPerSpecies);

      // Recording: respect the user’s choice (full / clips / off).
      _saveDetectionClips = recordingMode == RecordingMode.detectionsOnly;
      // Clips cover the window the model scored, whichever length this survey
      // analyzes with.
      recordingService.setWindowSeconds(windowDuration);
      if (recordingMode != RecordingMode.off) {
        final dir = await recordingService.startRecording(
          sessionId: existingSession.id,
          mode: recordingMode,
          format: recordingFormat,
        );
        _session!.recordingPath = dir;
      }

      // GPS tracking: seed with existing track data.
      if (_useGps) {
        _gpsTracker = SurveyGpsTracker(intervalSeconds: gpsIntervalSeconds);
        _gpsTracker!.onPoint = _onGpsPoint;
        _gpsTracker!.seedTrack(existingSession.gpsTrack);
        if (backgroundGps || foregroundGps) {
          await _gpsTracker!.startTracking();
        } else {
          await _gpsTracker!.captureOnce();
        }
      }

      _maxEndTime = DateTime.now().add(Duration(hours: maxDurationHours));
      _autoStopBattery = autoStopBattery;

      await _notificationService.start(
        title: _notificationTitle,
        text: _buildNotificationText(),
      );

      // Reactivate only after all fallible async setup has completed so the
      // original session stays untouched if setup fails. LiveSession.resume
      // always opens a distinct segment and seeds legacy duration tracking.
      _session!.resume();
      _segmentStart = DateTime.now();

      _persistTimer = Timer.periodic(
        const Duration(seconds: _persistIntervalSeconds),
        (_) {
          _persistSession();
          _checkBatteryAutoStop();
        },
      );
      _notificationTimer = Timer.periodic(
        const Duration(seconds: _notificationIntervalSeconds),
        (_) => _updateNotification(),
      );

      _state = SurveyState.active;
      _armNextInference();
      _notifyListeners();

      debugPrint(
        '[SurveyController] survey resumed '
        '(${existingSession.detections.length} existing detections, '
        '${existingSession.gpsTrack.length} GPS points)',
      );
    } catch (e, st) {
      debugPrint('[SurveyController] resumeSurvey error: $e\n$st');
      await _cleanupFailedStart();
      _state = SurveyState.error;
      _errorMessage = e.toString();
      _notifyListeners();
    }
  }

  Future<void> _cleanupFailedStart() async {
    _windowDriver.stop();
    _persistTimer?.cancel();
    _persistTimer = null;
    _notificationTimer?.cancel();
    _notificationTimer = null;

    await _notificationService.stop();
    await _gpsTracker?.stopTracking();
    await recordingService.stopRecording();

    final coord = _alertCoordinator;
    _alertCoordinator = null;
    if (coord != null) {
      await coord.shutdown(flushFinal: false);
    }

    _gpsTracker = null;
    _sampler = null;
    _maxEndTime = null;
    _segmentStart = null;
    _inferring = false;
    _session = null;
    _sessionDetections.clear();
    _refreshRecentForNotification();
    _currentLiveDetections = const [];
    _accumulator = null;
    _clipWriter.reset();
    _samplerTail = Future<void>.value();
  }

  /// Stop and finalize the survey.
  Future<LiveSession?> stopSurvey() async {
    if (_session == null) return null;
    _sessionGeneration++;
    _state = SurveyState.stopping;
    _errorMessage = null;
    _notifyListeners();

    // Stop timers.
    _windowDriver.cancelPendingWakeup();
    _persistTimer?.cancel();
    _persistTimer = null;
    _notificationTimer?.cancel();
    _notificationTimer = null;

    // Close the active recording segment so that the time spent recording
    // since the last persist tick is counted in the final duration.
    _closeRecordingSegment();

    // Stop foreground service notification.
    await _notificationService.stop();

    // Stop GPS.
    await _gpsTracker?.stopTracking();

    // Simplify GPS track.
    _gpsTracker?.simplifyTrack();
    if (_gpsTracker != null) {
      _session!.gpsTrack
        ..clear()
        ..addAll(_gpsTracker!.track);
      _session!.distanceMeters = _gpsTracker!.distanceMeters;
    }

    // Ensure the session has a representative lat/lon so the review screen
    // can show a map even when the GPS track is empty or very short.
    if (_session!.latitude == null || _session!.longitude == null) {
      final track = _gpsTracker?.track ?? const <GpsPoint>[];
      if (track.isNotEmpty) {
        final last = track.last;
        _session!.latitude = last.latitude;
        _session!.longitude = last.longitude;
      }
    }

    // Let post-roll jobs finish while capture and recording are still alive.
    await _waitForClipTasks();

    // Stop recording.
    final recordingPath = await recordingService.stopRecording();
    if (recordingPath != null) {
      _session!.recordingPath = recordingPath;
    }

    if (kDebugMode) {
      MemoryMonitor.logOnce(tag: 'survey-end');
      MemoryMonitor.printSummary();
      MemoryMonitor.stop();
    }

    // Shared close semantics use the last supporting audio-window end.
    final finalClosed = _accumulator?.closeAll() ?? const <DetectionRecord>[];
    _syncSessionDetections();
    for (final closed in finalClosed) {
      await _sampler?.onRecordClosed(closed);
    }

    _session!.end();
    final completedSession = _session!;

    // Shut down alerts: flush queued summaries, cancel timer.
    final alertCoord = _alertCoordinator;
    _alertCoordinator = null;
    if (alertCoord != null) {
      await alertCoord.shutdown();
    }

    try {
      // Final persist.
      await _persistSession();

      // Delete recovery file.
      await _deleteRecoveryFile();
    } catch (e, st) {
      debugPrint('[SurveyController] finalize persist error: $e\n$st');
      _errorMessage = e.toString();
    } finally {
      // Reset state even if persistence cleanup fails so the controller
      // cannot get stuck in the stopping state.
      _session = null;
      _sessionDetections.clear();
      _refreshRecentForNotification();
      _currentLiveDetections = const [];
      _accumulator = null;
      _windowDriver.stop();
      _clipWriter.reset();
      _samplerTail = Future<void>.value();
      _gpsTracker = null;
      _sampler = null;

      _state = SurveyState.finalized;
      _notifyListeners();
    }

    debugPrint('[SurveyController] survey finalized');
    return completedSession;
  }

  /// Capture a manual GPS fix (for manual GPS mode).
  Future<void> captureGpsFix() async {
    if (!_useGps) return;
    await _gpsTracker?.captureOnce();
  }

  /// Restart foreground GPS tracking after an app lifecycle resume.
  ///
  /// The setting is checked here, not only by the screen, so a tracker cannot
  /// be restarted after the user turns off GPS during an active survey.
  Future<void> startGpsTracking() async {
    if (!_useGps) return;
    await _gpsTracker?.startTracking();
  }

  /// Stop an active GPS stream when the app-wide setting is turned off.
  Future<void> stopGpsTracking() async {
    await _gpsTracker?.stopTracking();
  }

  /// Insert a user-entered species observation into the active session.
  ///
  /// Used by the live survey "Add observation" entry point so surveyors can
  /// log birds they saw or heard but BirdNET didn't detect (or before/after
  /// inference would catch them). The record:
  ///
  ///   - Has [DetectionSource.manual] — or [DetectionSource.userSpecified]
  ///     when the label was typed via "Other (specify)" rather than picked
  ///     from the taxonomy — so it's clearly distinguishable from model
  ///     detections everywhere it's rendered or exported.
  ///   - Carries confidence 1.0 (manual entries are by definition certain
  ///     from the user's point of view).
  ///   - Is timestamped to the moment the user confirms the entry.
  ///   - Carries the heard / seen [evidence] the user ticked in the picker,
  ///     or null when they ticked neither.
  ///   - Is tagged from [SurveyGpsTracker.lastPoint] when available, falling
  ///     back to the session's fixed coordinates when GPS is disabled.
  ///   - Skips the [DetectionSampler] (manuals are always kept) and the alert
  ///     coordinator (the user just typed it; alerting them again is noise).
  ///   - Does not touch the accumulator's active map; manuals are one-shot and
  ///     should not interfere with the auto card-visibility pipeline.
  ///
  /// Returns the newly-inserted record, or null if no session is active.
  Future<DetectionRecord?> addManualDetection({
    required String scientificName,
    required String commonName,
    DetectionEvidence? evidence,
    bool userSpecified = false,
  }) async {
    if (_session == null) return null;
    final gpsPoint = _gpsTracker?.lastPoint;
    final record = DetectionRecord(
      scientificName: scientificName,
      commonName: commonName,
      confidence: 1.0,
      timestamp: DateTime.now(),
      source:
          userSpecified
              ? DetectionSource.userSpecified
              : DetectionSource.manual,
      evidence: evidence,
      latitude: gpsPoint?.latitude ?? _session!.latitude,
      longitude: gpsPoint?.longitude ?? _session!.longitude,
    );
    _session!.addDetection(record);
    _sessionDetections.insert(0, record);
    _refreshRecentForNotification();
    // Persist immediately so the record survives a crash before the next
    // periodic flush.
    await _persistSession();
    _notifyListeners();
    return record;
  }

  /// Append a session-level [SessionAnnotation] to the active survey.
  ///
  /// Mirrors [addManualDetection]: the annotation is stored on the live
  /// session, persisted immediately so a crash before the next periodic
  /// flush doesn't lose it, and listeners are notified so any in-tree
  /// chip rows can repaint. Voice memos are intentionally not allowed
  /// here — recording one would conflict with the active capture mic;
  /// memos are added in Session Review after the survey ends.
  ///
  /// Returns the appended annotation, or null if no session is active.
  Future<SessionAnnotation?> addAnnotation(SessionAnnotation annotation) async {
    if (_session == null) return null;
    _session!.annotations.add(annotation);
    await _persistSession();
    _notifyListeners();
    return annotation;
  }

  // ── Live setting hot-apply ────────────────────────────────────────────

  /// Update the confidence threshold (0–100 scale) used by the inference
  /// loop. Takes effect on the next cycle so a mid-survey settings
  /// change is picked up without restarting the timer.
  ///
  /// The original `SessionSettings.confidenceThreshold` recorded at
  /// session start is intentionally left untouched — it remains a
  /// snapshot of what the user chose when they hit start.
  void setConfidenceThreshold(int value) {
    _confidenceThreshold = value;
  }

  /// Update the sigmoid-shift sensitivity used by inference. Takes
  /// effect on the next cycle.
  void setSensitivity(double value) {
    _sensitivity = value;
  }

  /// Hot-apply the inference-time species mask before temporal pooling.
  void setSpeciesIgnoreFilter({
    required Set<String> scientificNames,
    required Map<String, double>? geoScores,
  }) {
    _isolate.setIgnoredSpeciesNames(scientificNames);
    _geoScores = geoScores;
  }

  /// Update the score-pooling window count and forward to the inference
  /// isolate. Pass `null` to use the model-config default.
  void setPoolingWindows(int? value) {
    _isolate.setMaxPoolWindows(value);
  }

  /// Update the score-pooling real-time age gate and forward to the inference
  /// isolate. Pass `null` to use the model-config default.
  void setPoolingMaxAgeSeconds(double? value) {
    _isolate.setMaxPoolAgeSeconds(value);
  }

  /// Update the score-pooling mode and forward to the inference isolate.
  /// Recognized values: `'off' | 'average' | 'max' | 'lme'`.
  void setPoolingMode(String value) {
    _isolate.setPoolingMode(value);
  }

  /// Update the advanced temporal-pooling overrides (LME alpha + support gate)
  /// and forward to the inference isolate. Takes effect on the next cycle.
  void setAdvancedPoolingParams(AdvancedPoolingParams params) {
    _isolate.applyAdvancedPoolingParams(params);
  }

  /// Dispose of all resources.
  Future<void> dispose() async {
    _windowDriver.stop();
    _persistTimer?.cancel();
    _notificationTimer?.cancel();
    final coord = _alertCoordinator;
    _alertCoordinator = null;
    if (coord != null) {
      await coord.shutdown(flushFinal: false);
    }
    await _gpsTracker?.stopTracking();
    await _isolate.stop();
    recordingService.dispose();
  }

  // ── GPS callbacks ───────────────────────────────────────────────────────

  void _onGpsPoint(GpsPoint point) {
    if (_session == null) return;
    _session!.gpsTrack.add(point);
    if (_gpsTracker != null) {
      _session!.distanceMeters = _gpsTracker!.distanceMeters;
    }
    _notifyListeners();
  }

  // ── Inference ───────────────────────────────────────────────────────────

  Future<void> _runInference() async {
    // Check auto-stop conditions.
    if (_maxEndTime != null && DateTime.now().isAfter(_maxEndTime!)) {
      _triggerAutoStop(
        'Maximum survey duration reached',
        reasonCode: SessionStopReason.maxDuration,
        value:
            _maxEndTime!
                .difference(_session?.startTime ?? _maxEndTime!)
                .inHours,
      );
      return;
    }

    if (_inferring || !_isolate.isRunning) return;
    final generation = _sessionGeneration;
    final session = _session;
    final window = _windowDriver.takeReadyWindow();
    if (window == null) return;
    _inferring = true;
    _inferenceCycleCount++;

    // Snapshot the live-tunable threshold for this cycle so a mid-cycle
    // setter call can't half-apply.
    final confidenceThreshold = _confidenceThreshold;
    final sensitivity = _sensitivity;

    try {
      final windowDuration = window.windowDurationSeconds;
      final windowTimestamp = window.startTimestamp;
      final windowEnd = window.endTimestamp;
      final audioSamples = window.samples;

      if (kDebugMode && _inferenceCycleCount % 30 == 0) {
        MemoryMonitor.logOnce(tag: 'survey-cycle-$_inferenceCycleCount');
      }

      final detections = await _isolate.infer(
        audioSamples,
        windowSeconds: windowDuration,
        sensitivity: sensitivity,
        confidenceThreshold: confidenceThreshold / 100.0,
        timestamp: windowTimestamp,
      );

      if (generation != _sessionGeneration ||
          _state != SurveyState.active ||
          !identical(session, _session)) {
        return;
      }

      // Apply species filter.
      final speciesFiltered = SpeciesFilter.apply(
        detections: detections,
        mode: _filterMode,
        geoScores: _geoScores,
        geoThreshold: _geoThreshold,
        confidenceThreshold: confidenceThreshold / 100.0,
      );

      final geoNames = _geoModelSpeciesNames;
      final filteredDetections =
          geoNames == null
              ? speciesFiltered
              : speciesFiltered
                  .where((d) => geoNames.contains(d.species.scientificName))
                  .toList();

      // Update live detection list.
      _currentLiveDetections = [
        for (final d in filteredDetections) DetectionRecord.fromDetection(d),
      ];

      if (session != null && _accumulator != null) {
        // Use the current GPS position for detection tagging. Before the first
        // fix, or when GPS is disabled, fall back to the session's fixed
        // coordinates from setup.
        final gpsPoint = _gpsTracker?.lastPoint;
        final detectionLatitude = gpsPoint?.latitude ?? session.latitude;
        final detectionLongitude = gpsPoint?.longitude ?? session.longitude;

        final cycle = _accumulator!.processCycle(
          detections: filteredDetections,
          windowEnd: windowEnd,
          createRecord:
              (detection, timestamp) => DetectionRecord(
                scientificName: detection.species.scientificName,
                commonName: detection.species.commonName,
                confidence: detection.confidence,
                timestamp: timestamp,
                latitude: detectionLatitude,
                longitude: detectionLongitude,
              ),
        );
        for (final closed in cycle.closedRecords) {
          _clipWriter.forget(closed);
          // A record with a clip write still in flight reaches the sampler
          // from the writer instead, once nothing can replace it any more.
          if (!_clipWriter.hasPendingWrite(closed)) {
            _queueClosedForSampling(closed);
          }
        }
        for (final change in cycle.changes) {
          if (change.isNew) _alertCoordinator?.onDetection(change.record);
        }
        _syncSessionDetections();
        // The clip is cut from this window's samples, so a late write still
        // stores the audio `clipTimestamp` claims it holds.
        if (_saveDetectionClips) {
          _clipWriter.requestClips(
            changes: cycle.changes,
            clipTimestamp: windowTimestamp,
            windowEndSample: window.windowEndSample,
          );
        }

        // Hand the current cycle's detections to the Announcements
        // pipeline (no-op when the feature is disabled). We submit the
        // full per-cycle list, not just newly-appeared species: the
        // first sighting is often near the confidence floor, while the
        // peak score arrives a few cycles later when the card is still
        // on screen. The controller's per-species streak silence and
        // global min-interval gates dedup re-submissions, and it picks
        // the highest score per species inside the batch, so this
        // surfaces the strongest call rather than the marginal one.
        final cb = onFreshDetections;
        if (cb != null && filteredDetections.isNotEmpty) {
          final batch = <AnnouncementDetection>[
            for (final d in filteredDetections)
              AnnouncementDetection(
                speciesId: d.species.scientificName,
                displayName: d.species.commonName,
                score: d.confidence,
                at: d.timestamp ?? DateTime.now(),
              ),
          ];
          try {
            cb(batch);
          } catch (_) {
            /* Announcements errors must never escape. */
          }
        }
      }

      _notifyListeners();
    } catch (e, st) {
      debugPrint('[SurveyController] inference error: $e\n$st');
    } finally {
      _inferring = false;
    }
  }

  /// Arm a one-shot wakeup for the next complete sample-anchored window.
  void _armNextInference() {
    _windowDriver.arm(
      isActive: () => _state == SurveyState.active,
      runCycle: _runInference,
    );
  }

  /// Hand a closed record to the sampler, one at a time.
  ///
  /// The sampler may delete a clip and clear its path on the record it is
  /// given, and may evict a previously-kept clip at the same time, so these
  /// calls are serialized rather than overlapped.
  void _queueClosedForSampling(DetectionRecord record) {
    final previous = _samplerTail.catchError((_) {});
    _samplerTail = previous
        .then((_) async {
          await _sampler?.onRecordClosed(record);
          _syncSessionDetections();
          _notifyListeners();
        })
        .catchError((error, stackTrace) {
          debugPrint('[SurveyController] sampler error: $error\n$stackTrace');
        });
  }

  /// Let outstanding clip writes — and the sampling they trigger — finish.
  Future<void> _waitForClipTasks() async {
    await _clipWriter.drain();
    await _samplerTail;
  }

  void _syncSessionDetections() {
    final records = _session?.detections ?? const <DetectionRecord>[];
    _sessionDetections
      ..clear()
      ..addAll(records.reversed.take(_maxInMemoryDetections));
    _refreshRecentForNotification();
  }

  // ── Persistence ─────────────────────────────────────────────────────────

  /// Accumulate the time elapsed since [_segmentStart] into the session's
  /// recorded duration and clear [_segmentStart]. Safe to call multiple
  /// times — a no-op when no segment is open.
  void _closeRecordingSegment() {
    final start = _segmentStart;
    final session = _session;
    if (start == null || session == null) return;
    final secs = DateTime.now().difference(start).inSeconds;
    if (secs > 0) session.accumulateRecordedSeconds(secs);
    session.closeSegment();
    _segmentStart = null;
  }

  Future<void> _persistSession() async {
    if (_session == null) return;
    try {
      // Roll the segment forward so the persisted recordedDurationSeconds
      // reflects time recorded since the last persist tick. We immediately
      // open a new segment for active surveys so [elapsed] keeps ticking
      // smoothly. Final persists run after [LiveSession.end] and must not
      // reopen a segment, otherwise saved Survey durations keep growing in
      // Session Library.
      _closeRecordingSegment();
      if (_session!.endTime == null) {
        _session!.startSegment();
        _segmentStart = DateTime.now();
      }

      final appDir = await getApplicationDocumentsDirectory();
      final sessionsDir = Directory('${appDir.path}/sessions');
      if (!sessionsDir.existsSync()) {
        await sessionsDir.create(recursive: true);
      }

      final sessionFile = File('${sessionsDir.path}/${_session!.id}.json');
      final recoveryFile = File(
        '${sessionsDir.path}/${_session!.id}.recovery.json',
      );

      // Write-ahead: rename current → recovery, write new, delete recovery.
      if (await sessionFile.exists()) {
        await sessionFile.rename(recoveryFile.path);
      }

      final sessionJson = sessionJsonForStorage(
        _session!,
        documentsPath: appDir.path,
      );
      final jsonStr = json.encode(sessionJson);
      await File(
        '${sessionsDir.path}/${_session!.id}.json',
      ).writeAsString(jsonStr, flush: true);

      if (await recoveryFile.exists()) {
        await recoveryFile.delete();
      }

      debugPrint(
        '[SurveyController] session persisted '
        '(${_session!.detections.length} detections, '
        '${_session!.gpsTrack.length} GPS points)',
      );
    } catch (e) {
      debugPrint('[SurveyController] persist error: $e');
    }
  }

  Future<void> _deleteRecoveryFile() async {
    if (_session == null) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final recoveryFile = File(
        '${appDir.path}/sessions/${_session!.id}.recovery.json',
      );
      if (await recoveryFile.exists()) {
        await recoveryFile.delete();
      }
    } catch (_) {}
  }

  // ── Notification + battery ─────────────────────────────────────────────

  /// Rebuild [_recentForNotification] from the current `_sessionDetections`.
  /// Always emits a fresh immutable list (swap) so the foreground
  /// notification body — which may render at any moment on a cadence
  /// independent from inference — sees a stable view of the last three
  /// unique-species detections. Newest-first ordering matches the rest
  /// of the notification UI.
  void _refreshRecentForNotification() {
    if (_sessionDetections.isEmpty) {
      _recentForNotification = const <DetectionRecord>[];
      return;
    }

    // Rank by when each species was last heard rather than by when its record
    // was created. A bird that has been calling for twenty minutes belongs on
    // the lock screen ahead of three that started more recently and have
    // already stopped. A detection with no end is still going, so it outranks
    // every closed one; ties fall back to the later start.
    final now = DateTime.now();
    DateTime lastHeard(DetectionRecord r) => r.endTimestamp ?? now;

    final bestByName = <String, DetectionRecord>{};
    for (final r in _sessionDetections) {
      final existing = bestByName[r.scientificName];
      if (existing == null || lastHeard(r).isAfter(lastHeard(existing))) {
        bestByName[r.scientificName] = r;
      }
    }

    final ranked =
        bestByName.values.toList()..sort((a, b) {
          final byHeard = lastHeard(b).compareTo(lastHeard(a));
          return byHeard != 0 ? byHeard : b.timestamp.compareTo(a.timestamp);
        });
    _recentForNotification = List<DetectionRecord>.unmodifiable(
      ranked.take(3),
    );
  }

  /// Build the notification body text with the three most recent
  /// detections on top, an empty separator line, then a compact stats
  /// footer (elapsed time, detections, species, distance). Android
  /// expands the multi-line body via [Notification.BigTextStyle].
  String _buildNotificationText() {
    final e = elapsed;
    final hh = e.inHours.toString().padLeft(2, '0');
    final mm = (e.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (e.inSeconds % 60).toString().padLeft(2, '0');
    final elapsedStr = '$hh:$mm:$ss';
    final det = _session?.detections.length ?? 0;
    final spp = _session?.uniqueSpeciesCount ?? 0;
    final dist = _gpsTracker?.distanceMeters ?? 0;
    final km = (dist / 1000).toStringAsFixed(1);
    final s = _notificationStrings;
    // Localized stats footer (falls back to English when no strings have
    // been wired). The localizer takes care of plural / unit ordering.
    final stats =
        s?.stats(elapsedStr, det, spp, km) ??
        '\u23F1 $elapsedStr   \uD83D\uDC26 $det det · $spp spp   '
            '\uD83D\uDCCD $km km';

    // Heads-up status when the microphone is held by another app.
    final micWarning =
        _micContested
            ? (s?.micContested ??
                '\u26A0 Microphone in use by another app — audio paused')
            : null;

    // Render up to 3 most-recent *unique* species (so a chatty bird
    // doesn't fill the whole list). The buffer is maintained on the
    // detection-insert path via [_refreshRecentForNotification], so we
    // never iterate `_sessionDetections` here — that list may be mutated
    // by inference callbacks in between two notification ticks.
    final recent = _recentForNotification;
    if (recent.isEmpty) {
      return micWarning == null ? stats : '$micWarning\n$stats';
    }
    final now = DateTime.now();
    final lines = <String>[];
    if (micWarning != null) {
      lines.add(micWarning);
      lines.add('');
    }
    for (final r in recent) {
      final name =
          _nameLocalizer?.call(r.scientificName, r.commonName) ?? r.commonName;
      final pct = (r.confidence * 100).round();
      final ago = _formatRelativeTime(now.difference(r.timestamp));
      lines.add('$name · $pct% · $ago');
    }
    lines.add(''); // blank separator line between detections and stats
    lines.add(stats);
    return lines.join('\n');
  }

  /// Format a duration as a short, localized "N ago" string suitable for
  /// the notification. Falls back to terse English when no localized
  /// strings have been provided.
  String _formatRelativeTime(Duration d) {
    final s = _notificationStrings;
    final secs = d.inSeconds;
    if (secs < 5) return s?.justNow ?? 'just now';
    if (secs < 60) return s?.secondsAgo(secs) ?? '${secs}s ago';
    final mins = d.inMinutes;
    if (mins < 60) return s?.minutesAgo(mins) ?? '${mins}m ago';
    final hrs = d.inHours;
    return s?.hoursAgo(hrs) ?? '${hrs}h ago';
  }

  /// Push updated stats to the foreground notification.
  Future<void> _updateNotification() async {
    await _notificationService.update(
      title: _notificationTitle,
      text: _buildNotificationText(),
    );
  }

  /// Check battery level and trigger auto-stop if below threshold.
  Future<void> _checkBatteryAutoStop() async {
    if (_autoStopBattery <= 0) return;
    try {
      final level = await _battery.batteryLevel;
      if (level <= _autoStopBattery) {
        _triggerAutoStop(
          'Battery below $_autoStopBattery%',
          reasonCode: SessionStopReason.lowBattery,
          value: level,
        );
      }
    } catch (e) {
      debugPrint('[SurveyController] battery check error: $e');
    }
  }

  // ── Auto-stop ───────────────────────────────────────────────────────────

  void _triggerAutoStop(
    String reason, {
    SessionStopReason? reasonCode,
    num? value,
  }) {
    debugPrint('[SurveyController] auto-stop: $reason');
    if (_session != null && reasonCode != null) {
      _session!.stopReason = reasonCode;
      _session!.stopReasonValue = value;
    }
    final autoStopHandler = onAutoStop;
    if (autoStopHandler != null) {
      autoStopHandler(reason);
      return;
    }
    stopSurvey();
  }

  void _notifyListeners() {
    onStateChanged?.call();
  }
}

/// Localized strings used to render the recent-detections list inside the
/// survey foreground notification.
class _NotificationStrings {
  const _NotificationStrings({
    required this.title,
    required this.justNow,
    required this.secondsAgo,
    required this.minutesAgo,
    required this.hoursAgo,
    required this.stats,
    this.micContested,
  });

  final String? title;
  final String justNow;
  final String Function(int seconds) secondsAgo;
  final String Function(int minutes) minutesAgo;
  final String Function(int hours) hoursAgo;
  final String Function(
    String elapsed,
    int detections,
    int species,
    String distanceKm,
  )
  stats;
  final String? micContested;
}
