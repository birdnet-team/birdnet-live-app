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
import '../inference/inference_isolate.dart';
import '../inference/model_config.dart';
import '../inference/species_filter.dart';
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
  SurveyController({required this.ringBuffer, required this.recordingService});

  final RingBuffer ringBuffer;
  final RecordingService recordingService;
  final SurveyNotificationService _notificationService =
      SurveyNotificationService();
  final Battery _battery = Battery();

  // ── Internal state ──────────────────────────────────────────────────────

  final InferenceIsolate _isolate = InferenceIsolate();
  ModelConfig? _config;
  LiveSession? _session;
  Timer? _inferenceTimer;
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

  /// Species currently shown as active detection cards.
  final Map<String, DetectionRecord> _activeCardSpecies = {};

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

      await _isolate.start(
        modelFilePath: modelFilePath,
        labelsCsv: labelsCsv,
        config: _config!,
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
    int autoStopBattery = 0,
    SessionSettings? settingsSnapshot,
    int? poolingWindows,
    String poolingMode = 'lme',
    double sensitivity = 1.0,
    double? gainLinear,
    double? highPassHz,
  }) async {
    if (_state == SurveyState.active) return;
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
              poolingMode: poolingMode,
              poolingWindows: poolingWindows,
              gainLinear: gainLinear,
              highPassHz: highPassHz,
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
      _activeCardSpecies.clear();
      _confidenceThreshold = confidenceThreshold;
      _sensitivity = sensitivity;
      _isolate.setMaxPoolWindows(poolingWindows);
      _isolate.setPoolingMode(poolingMode);
      _isolate.resetPooling();
      _inferenceCycleCount = 0;
      ringBuffer.clear();

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
      if (recordingMode != RecordingMode.off) {
        final dir = await recordingService.startRecording(
          sessionId: sessionId,
          mode: recordingMode,
          format: recordingFormat,
        );
        _session!.recordingPath = dir;
      }

      // GPS tracking.
      _gpsTracker = SurveyGpsTracker(intervalSeconds: gpsIntervalSeconds);
      _gpsTracker!.onPoint = _onGpsPoint;
      if (backgroundGps) {
        await _gpsTracker!.startTracking();
      } else {
        // Manual GPS mode: capture initial fix.
        await _gpsTracker!.captureOnce();
      }

      // Max duration auto-stop.
      _maxEndTime = DateTime.now().add(Duration(hours: maxDurationHours));
      _autoStopBattery = autoStopBattery;

      // Open the first recording segment so [elapsed] starts ticking.
      _segmentStart = DateTime.now();

      // Start inference timer.
      final intervalMs = (1000.0 / inferenceRate).round();
      _inferenceTimer = Timer.periodic(
        Duration(milliseconds: intervalMs),
        (_) => _runInference(windowDuration: windowDuration),
      );

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
    int autoStopBattery = 0,
    int? poolingWindows,
    String poolingMode = 'lme',
    double sensitivity = 1.0,
  }) async {
    if (_state == SurveyState.active) return;
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
      _activeCardSpecies.clear();
      _confidenceThreshold = confidenceThreshold;
      _sensitivity = sensitivity;
      _isolate.setMaxPoolWindows(poolingWindows);
      _isolate.setPoolingMode(poolingMode);
      _isolate.resetPooling();
      _inferenceCycleCount = 0;
      ringBuffer.clear();

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
      if (recordingMode != RecordingMode.off) {
        final dir = await recordingService.startRecording(
          sessionId: existingSession.id,
          mode: recordingMode,
          format: recordingFormat,
        );
        _session!.recordingPath = dir;
      }

      // GPS tracking: seed with existing track data.
      _gpsTracker = SurveyGpsTracker(intervalSeconds: gpsIntervalSeconds);
      _gpsTracker!.onPoint = _onGpsPoint;
      _gpsTracker!.seedTrack(existingSession.gpsTrack);
      if (backgroundGps) {
        await _gpsTracker!.startTracking();
      } else {
        await _gpsTracker!.captureOnce();
      }

      _maxEndTime = DateTime.now().add(Duration(hours: maxDurationHours));
      _autoStopBattery = autoStopBattery;

      // Open a new recording segment. Any previously accumulated time on
      // the session is preserved via [LiveSession.recordedDurationSeconds].
      _segmentStart = DateTime.now();

      final intervalMs = (1000.0 / inferenceRate).round();
      _inferenceTimer = Timer.periodic(
        Duration(milliseconds: intervalMs),
        (_) => _runInference(windowDuration: windowDuration),
      );

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

      await _notificationService.start(
        title: _notificationTitle,
        text: _buildNotificationText(),
      );

      _state = SurveyState.active;
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
    _inferenceTimer?.cancel();
    _inferenceTimer = null;
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
    _activeCardSpecies.clear();
  }

  /// Stop and finalize the survey.
  Future<LiveSession?> stopSurvey() async {
    if (_session == null) return null;
    _state = SurveyState.stopping;
    _errorMessage = null;
    _notifyListeners();

    // Stop timers.
    _inferenceTimer?.cancel();
    _inferenceTimer = null;
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

    // Close any still-open detection windows so that long-running cards
    // visible at survey end get a proper [endTimestamp]. Each closed
    // record is then handed to the sampler, which may drop its clip.
    if (_activeCardSpecies.isNotEmpty) {
      final now = DateTime.now();
      for (final existing in _activeCardSpecies.values.toList()) {
        final closed = DetectionRecord(
          scientificName: existing.scientificName,
          commonName: existing.commonName,
          confidence: existing.confidence,
          timestamp: existing.timestamp,
          endTimestamp: now,
          audioClipPath: existing.audioClipPath,
          source: existing.source,
          latitude: existing.latitude,
          longitude: existing.longitude,
        );
        final sIdx = _sessionDetections.indexOf(existing);
        if (sIdx != -1) _sessionDetections[sIdx] = closed;
        final lsIdx = _session!.detections.indexOf(existing);
        if (lsIdx != -1) _session!.detections[lsIdx] = closed;
        _refreshRecentForNotification();
        await _sampler?.onRecordClosed(closed);
      }
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
      _activeCardSpecies.clear();
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
    await _gpsTracker?.captureOnce();
  }

  /// Insert a user-entered species observation into the active session.
  ///
  /// Used by the live survey "Add observation" entry point so surveyors can
  /// log birds they saw or heard but BirdNET didn't detect (or before/after
  /// inference would catch them). The record:
  ///
  ///   - Has [DetectionSource.manual] so it's clearly distinguishable from
  ///     model detections everywhere it's rendered or exported.
  ///   - Carries confidence 1.0 (manual entries are by definition certain
  ///     from the user's point of view).
  ///   - Is timestamped to the moment the user confirms the entry.
  ///   - Is GPS-tagged from [SurveyGpsTracker.lastPoint] when available so it
  ///     appears on the map alongside auto detections.
  ///   - Skips the [DetectionSampler] (manuals are always kept) and the alert
  ///     coordinator (the user just typed it; alerting them again is noise).
  ///   - Does NOT touch [_activeCardSpecies] \u2014 manuals are one-shot and
  ///     should not interfere with the auto card-visibility pipeline.
  ///
  /// Returns the newly-inserted record, or null if no session is active.
  Future<DetectionRecord?> addManualDetection({
    required String scientificName,
    required String commonName,
  }) async {
    if (_session == null) return null;
    final gpsPoint = _gpsTracker?.lastPoint;
    final record = DetectionRecord(
      scientificName: scientificName,
      commonName: commonName,
      confidence: 1.0,
      timestamp: DateTime.now(),
      source: DetectionSource.manual,
      latitude: gpsPoint?.latitude,
      longitude: gpsPoint?.longitude,
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

  /// Update the score-pooling window count and forward to the inference
  /// isolate. Pass `null` to use the model-config default.
  void setPoolingWindows(int? value) {
    _isolate.setMaxPoolWindows(value);
  }

  /// Update the score-pooling mode and forward to the inference isolate.
  /// Recognized values: `'off' | 'average' | 'max' | 'lme'`.
  void setPoolingMode(String value) {
    _isolate.setPoolingMode(value);
  }

  /// Dispose of all resources.
  Future<void> dispose() async {
    _inferenceTimer?.cancel();
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

  Future<void> _runInference({required int windowDuration}) async {
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
    _inferring = true;
    _inferenceCycleCount++;

    // Snapshot the live-tunable threshold for this cycle so a mid-cycle
    // setter call can't half-apply.
    final confidenceThreshold = _confidenceThreshold;
    final sensitivity = _sensitivity;

    try {
      final sampleRate = _config?.audio.sampleRate ?? AppConstants.sampleRate;
      final windowSamples = windowDuration * sampleRate;
      final audioSamples = ringBuffer.readLast(windowSamples);

      if (kDebugMode && _inferenceCycleCount % 30 == 0) {
        MemoryMonitor.logOnce(tag: 'survey-cycle-$_inferenceCycleCount');
      }

      final detections = await _isolate.infer(
        audioSamples,
        windowSeconds: windowDuration,
        sensitivity: sensitivity,
        confidenceThreshold: confidenceThreshold / 100.0,
      );

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

      // Detection counting (card-visibility based, same as LiveController).
      if (_session != null) {
        final currentNames = <String>{
          for (final d in filteredDetections) d.species.scientificName,
        };

        final appeared = currentNames.difference(
          _activeCardSpecies.keys.toSet(),
        );
        // Species that disappeared → close their detection window so
        // the review screen can highlight the full duration during
        // which they were continuously above threshold.
        final disappeared = _activeCardSpecies.keys.toSet().difference(
          currentNames,
        );
        final closingNow = DateTime.now();
        for (final name in disappeared) {
          final existing = _activeCardSpecies.remove(name);
          if (existing == null) continue;
          // Mutate endTimestamp in place via list-replace (endTimestamp is
          // a final field). The new record carries the same audioClipPath
          // reference, which the sampler may then mutate to null in place.
          final closed = DetectionRecord(
            scientificName: existing.scientificName,
            commonName: existing.commonName,
            confidence: existing.confidence,
            timestamp: existing.timestamp,
            endTimestamp: closingNow,
            audioClipPath: existing.audioClipPath,
            source: existing.source,
            latitude: existing.latitude,
            longitude: existing.longitude,
          );
          final sIdx = _sessionDetections.indexOf(existing);
          if (sIdx != -1) _sessionDetections[sIdx] = closed;
          final lsIdx = _session!.detections.indexOf(existing);
          if (lsIdx != -1) _session!.detections[lsIdx] = closed;
          _refreshRecentForNotification();

          // Hand the closed record to the sampler. The sampler may delete
          // the clip file and clear `audioClipPath` on this record (or on
          // a previously-kept record it's now evicting).
          await _sampler?.onRecordClosed(closed);
        }

        // Get current GPS position for detection tagging.
        final gpsPoint = _gpsTracker?.lastPoint;

        String? clipPath;
        if (_saveDetectionClips && appeared.isNotEmpty) {
          final clipName = 'clip_${DateTime.now().millisecondsSinceEpoch}';
          clipPath = await recordingService.saveDetectionClip(
            clipName: clipName,
          );
        }

        for (final detection in filteredDetections) {
          final name = detection.species.scientificName;

          if (appeared.contains(name)) {
            final record = DetectionRecord(
              scientificName: detection.species.scientificName,
              commonName: detection.species.commonName,
              confidence: detection.confidence,
              timestamp: detection.timestamp ?? DateTime.now(),
              audioClipPath: clipPath,
              latitude: gpsPoint?.latitude,
              longitude: gpsPoint?.longitude,
            );

            // Records are always added to the session. Audio-clip retention
            // is decided later, when the detection closes (see disappeared
            // branch above and finalize), via [DetectionSampler].
            _session!.addDetection(record);
            _sessionDetections.insert(0, record);
            _refreshRecentForNotification();
            _activeCardSpecies[name] = record;
            // Feed the alert pipeline AFTER the record is durably tracked
            // so a notification firing implies the detection was kept.
            _alertCoordinator?.onDetection(record);
          } else if (_activeCardSpecies.containsKey(name)) {
            // Update confidence if higher — also move to end so it
            // appears at the top of the recent detections list.
            final existing = _activeCardSpecies[name]!;
            if (detection.confidence > existing.confidence) {
              final updated = DetectionRecord(
                scientificName: existing.scientificName,
                commonName: existing.commonName,
                confidence: detection.confidence,
                timestamp: existing.timestamp,
                audioClipPath: existing.audioClipPath ?? clipPath,
                source: existing.source,
                latitude: existing.latitude ?? gpsPoint?.latitude,
                longitude: existing.longitude ?? gpsPoint?.longitude,
              );
              _sessionDetections.remove(existing);
              _sessionDetections.add(updated);
              final lsIdx = _session!.detections.indexOf(existing);
              if (lsIdx != -1) _session!.detections[lsIdx] = updated;
              _refreshRecentForNotification();
              _activeCardSpecies[name] = updated;
            }
          }
        }

        if (_sessionDetections.length > _maxInMemoryDetections) {
          _sessionDetections.removeRange(
            _maxInMemoryDetections,
            _sessionDetections.length,
          );
          _refreshRecentForNotification();
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
    _segmentStart = null;
  }

  Future<void> _persistSession() async {
    if (_session == null) return;
    try {
      // Roll the segment forward so the persisted recordedDurationSeconds
      // reflects time recorded since the last persist tick. We immediately
      // open a new segment so [elapsed] keeps ticking smoothly.
      _closeRecordingSegment();
      _segmentStart = DateTime.now();

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

      final jsonStr = json.encode(_session!.toJson());
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
    final seen = <String>{};
    final next = <DetectionRecord>[];
    for (final r in _sessionDetections) {
      if (seen.add(r.scientificName)) {
        next.add(r);
        if (next.length == 3) break;
      }
    }
    _recentForNotification = List<DetectionRecord>.unmodifiable(next);
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
