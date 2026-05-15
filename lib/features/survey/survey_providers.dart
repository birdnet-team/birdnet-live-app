// =============================================================================
// Survey Providers — Riverpod wiring for Survey Mode
// =============================================================================
//
// Connects [SurveyController], [SurveyGpsTracker], and UI state to the
// widget tree via Riverpod providers.
//
// ### Provider dependency graph
//
// ```
// ringBufferProvider (from audio)
//   └─ surveyRecordingServiceProvider
//       └─ surveyControllerProvider
//           └─ surveyStateProvider
//           └─ surveyDetectionsProvider
//           └─ surveySessionProvider
// ```
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/settings_providers.dart';
import '../announcements/announcements_alert_sink.dart';
import '../audio/audio_providers.dart';
import '../recording/recording_service.dart';
import '../live/live_session.dart';
import 'species_alert_notifier.dart';
import 'survey_controller.dart';

// ---------------------------------------------------------------------------
// Recording (separate instance from live mode)
// ---------------------------------------------------------------------------

/// Recording service for survey mode, with survey-specific buffer settings.
final surveyRecordingServiceProvider = Provider<RecordingService>((ref) {
  final ringBuffer = ref.watch(ringBufferProvider);
  final clipContext = ref.watch(surveyClipContextProvider);
  final service = RecordingService(
    ringBuffer: ringBuffer,
    sampleRate: AppConstants.sampleRate,
    clipContextSeconds: clipContext,
  );
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// Survey Controller
// ---------------------------------------------------------------------------

/// The [SurveyController] orchestrating the full survey pipeline.
final surveyControllerProvider = Provider<SurveyController>((ref) {
  final ringBuffer = ref.watch(ringBufferProvider);
  final recordingService = ref.watch(surveyRecordingServiceProvider);

  final controller = SurveyController(
    ringBuffer: ringBuffer,
    recordingService: recordingService,
  );

  // Announcements wiring (Phase 4): the per-mode "fresh detection"
  // callback feeds the spoken-detection pipeline. The sink itself is
  // lazy — no TTS plugin is touched until the user enables the
  // feature, so this hook is free for users who never opt in.
  final announcementsSink = ref.read(announcementsAlertSinkProvider);
  controller.onFreshDetections = announcementsSink.submit;
  controller.onSessionStarted = announcementsSink.resetSession;

  ref.onDispose(() => controller.dispose());
  return controller;
});

// ---------------------------------------------------------------------------
// Reactive state providers
// ---------------------------------------------------------------------------

/// Current [SurveyState].
final surveyStateProvider = StateProvider<SurveyState>(
  (ref) => SurveyState.idle,
);

/// Current live detections from the active survey.
final surveyDetectionsProvider = StateProvider<List<DetectionRecord>>(
  (ref) => const [],
);

/// The active survey [LiveSession].
final surveySessionProvider = StateProvider<LiveSession?>((ref) => null);

// ---------------------------------------------------------------------------
// Species alerts
// ---------------------------------------------------------------------------

/// App-wide [SpeciesAlertNotifier] singleton. The notifier itself is
/// process-local (`flutter_local_notifications` is a singleton plugin),
/// but exposing it through Riverpod lets tests substitute fakes.
///
/// `init()` is called by the survey live screen with the user's current
/// sound/vibration preferences so toggling them in the wizard takes
/// effect on the next survey start.
final speciesAlertNotifierProvider = Provider<SpeciesAlertNotifier>((ref) {
  return SpeciesAlertNotifier();
});
