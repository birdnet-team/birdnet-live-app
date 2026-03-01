// =============================================================================
// Live Providers — Riverpod wiring for the live identification pipeline
// =============================================================================
//
// Connects the [LiveController], [RecordingService], and [SessionRepository]
// to the widget tree via Riverpod providers.
//
// ### Provider dependency graph
//
// ```
// ringBufferProvider (from audio)
//   └─ recordingServiceProvider
//       └─ liveControllerProvider
//           └─ liveStateProvider
//           └─ sessionDetectionsProvider
//           └─ latestLiveDetectionsProvider
//           └─ currentSessionProvider
//
// sessionRepositoryProvider (independent)
//   └─ sessionListProvider
// ```
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/settings_providers.dart';
import '../audio/audio_providers.dart';
import '../history/session_repository.dart';
import '../recording/recording_service.dart';
import 'live_controller.dart';
import 'live_session.dart';

// ---------------------------------------------------------------------------
// Recording
// ---------------------------------------------------------------------------

/// The [RecordingService] instance, connected to the shared ring buffer.
final recordingServiceProvider = Provider<RecordingService>((ref) {
  final ringBuffer = ref.watch(ringBufferProvider);
  final preBuffer = ref.watch(preBufferProvider);
  final postBuffer = ref.watch(postBufferProvider);
  final service = RecordingService(
    ringBuffer: ringBuffer,
    sampleRate: AppConstants.sampleRate,
    preBufferSeconds: preBuffer,
    postBufferSeconds: postBuffer,
  );
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// Live Controller
// ---------------------------------------------------------------------------

/// The [LiveController] orchestrating the full pipeline.
///
/// Depends on [ringBufferProvider] and [recordingServiceProvider].
/// The controller is long-lived: it persists as long as the app is running.
final liveControllerProvider = Provider<LiveController>((ref) {
  final ringBuffer = ref.watch(ringBufferProvider);
  final recordingService = ref.watch(recordingServiceProvider);

  final controller = LiveController(
    ringBuffer: ringBuffer,
    recordingService: recordingService,
  );

  ref.onDispose(() => controller.dispose());
  return controller;
});

// ---------------------------------------------------------------------------
// Reactive state providers (updated by LiveController)
// ---------------------------------------------------------------------------

/// Reactive [LiveState] — tracks the pipeline lifecycle.
///
/// Updated from the live screen after controller operations.
final liveStateProvider = StateProvider<LiveState>((ref) => LiveState.idle);

/// All detection records from the current session (newest first).
///
/// Updated by the live screen after each inference cycle.
final sessionDetectionsProvider =
    StateProvider<List<DetectionRecord>>((ref) => const []);

/// Latest batch of detections from the most recent inference cycle.
///
/// Updated by the live screen after each inference cycle.
final latestLiveDetectionsProvider =
    StateProvider<List<DetectionRecord>>((ref) => const []);

/// The currently active [LiveSession] (null when idle).
final currentSessionProvider = StateProvider<LiveSession?>((ref) => null);

// ---------------------------------------------------------------------------
// Session History
// ---------------------------------------------------------------------------

/// The [SessionRepository] for persisting completed sessions.
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository();
});

/// List of all saved sessions (newest first).
///
/// Refresh by invalidating this provider after saving/deleting.
final sessionListProvider = FutureProvider<List<LiveSession>>((ref) async {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.listAll();
});
