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
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/reverse_geocoding_service.dart';
import '../../shared/providers/settings_providers.dart';
import '../announcements/announcements_alert_sink.dart';
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
  final clipContext = ref.watch(clipContextProvider);
  final service = RecordingService(
    ringBuffer: ringBuffer,
    sampleRate: AppConstants.sampleRate,
    clipContextSeconds: clipContext,
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
// Reactive state providers (updated by LiveController)
// ---------------------------------------------------------------------------

/// Reactive [LiveState] — tracks the pipeline lifecycle.
///
/// Updated from the live screen after controller operations.
final liveStateProvider = StateProvider<LiveState>((ref) => LiveState.idle);

/// All detection records from the current session (newest first).
///
/// Updated by the live screen after each inference cycle.
final sessionDetectionsProvider = StateProvider<List<DetectionRecord>>(
  (ref) => const [],
);

/// Latest batch of detections from the most recent inference cycle.
///
/// Updated by the live screen after each inference cycle.
final latestLiveDetectionsProvider = StateProvider<List<DetectionRecord>>(
  (ref) => const [],
);

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
///
/// Side-effect: any session that has GPS coordinates but no resolved
/// `locationName` is silently backfilled from the persistent reverse-
/// geocode cache (no network call). This makes labels resolved in one
/// session "stick" to every other nearby session in the library, and
/// promotes the cached label to a permanent per-session field so the
/// next list load doesn't repeat the lookup.
final sessionListProvider = FutureProvider<List<LiveSession>>((ref) async {
  final repo = ref.watch(sessionRepositoryProvider);
  final sessions = await repo.listAll();

  try {
    final prefs = await SharedPreferences.getInstance();
    for (final s in sessions) {
      final lat = s.latitude;
      final lon = s.longitude;
      if (lat == null || lon == null) continue;
      if (s.locationName != null && s.locationName!.isNotEmpty) continue;
      final cached = cachedReverseGeocode(
        prefs: prefs,
        latitude: lat,
        longitude: lon,
      );
      if (cached != null) {
        s.locationName = cached;
        // Best-effort persist; failure is non-fatal — the in-memory
        // value still reaches the UI for this load.
        try {
          await repo.save(s);
        } catch (_) {
          /* non-fatal */
        }
      }
    }
  } catch (_) {
    // Cache backfill is purely a UX nicety; never let it break the list.
  }

  return sessions;
});
