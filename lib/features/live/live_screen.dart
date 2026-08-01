import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/wakelock_service.dart';

import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/confirm_destructive.dart';
import '../audio/audio_capture_service.dart';
import '../audio/audio_providers.dart';
import '../explore/explore_providers.dart';
import '../explore/widgets/species_info_overlay.dart';
import '../history/session_library_screen.dart';
import '../history/session_review_screen.dart';
import '../inference/advanced_pooling_params.dart';
import '../recording/recording_service.dart';
import '../settings/settings_screen.dart';
import '../spectrogram/spectrogram_widget.dart';
import 'live_controller.dart';
import 'live_detection_display.dart';
import 'live_providers.dart';
import 'live_session.dart';
import 'widgets/detection_list_widget.dart';

// =============================================================================
// Live Mode Screen — Edge-to-Edge Layout
// =============================================================================
//
// Maximizes screen real estate for the spectrogram and detection list.
//
// Layout (top → bottom):
//   1. Compact status bar: back arrow · status text · settings gear
//   2. Spectrogram       (flex: 2)
//   3. Session info bar  (conditional, ~24 px)
//   4. Detection list    (flex: 3)
//   5. FAB mic/stop button (bottom-center, 56×56)
//
// The screen is its own route (pushed from HomeScreen) so it has a Scaffold
// with no AppBar — edge-to-edge with SafeArea only at top/bottom.
// =============================================================================

/// Tracks mounted Live Mode routes so Quick Listen can reveal and reuse an
/// existing screen instead of rebuilding it.
///
/// Reusing matters while a session is active: disposing its screen cancels
/// the duration-warning timer and disables the wakelock even though the
/// app-wide controller keeps recording. Route identity also stays correct
/// when two routes briefly overlap during a transition.
abstract final class LiveScreenPresence {
  static final Map<Route<dynamic>, VoidCallback> _routes =
      <Route<dynamic>, VoidCallback>{};

  static bool get isMounted => _routes.isNotEmpty;

  /// Prefer the visible route, then the most recently mounted route.
  static Route<dynamic>? get mountedRoute {
    for (final route in _routes.keys.toList().reversed) {
      if (route.isCurrent) return route;
    }
    if (_routes.isEmpty) return null;
    return _routes.keys.last;
  }

  static void register(
    Route<dynamic> route, {
    required VoidCallback onStartListening,
  }) {
    _routes[route] = onStartListening;
  }

  static void unregister(Route<dynamic> route) {
    _routes.remove(route);
  }

  static void requestStartListening(Route<dynamic> route) {
    _routes[route]?.call();
  }
}

/// Live mode screen — real-time species identification.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key, this.forceAutoStart = false});

  /// One-shot override that starts a session as soon as the model is
  /// ready, regardless of the persistent [liveAutoStartProvider] setting.
  /// Used by the Quick Listen home-screen widget so tapping it always
  /// starts listening without silently flipping the user's saved
  /// preference. Guarded by the same [_autoStartAttempted] single-attempt
  /// latch as the persistent setting.
  final bool forceAutoStart;

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen>
    with WidgetsBindingObserver {
  bool _isStarting = false;
  bool _finalizing = false;
  Timer? _sessionTimer;
  bool _durationWarningShown = false;
  bool _autoStartAttempted = false;
  bool _startScheduled = false;
  bool _forceAutoStartRequested = false;
  Route<dynamic>? _presenceRoute;

  /// Whether [_initLiveScreen] has finished clearing the previous session's
  /// state.  The controller's load may settle — and notify — before that, so
  /// auto-start stays disarmed until this is true.
  bool _initialised = false;

  /// Cached reference to the long-lived controller so [dispose] can detach
  /// its callback without touching [ref] after the widget is unmounted.
  LiveController? _liveController;

  /// Duration after which a warning dialog is shown to the user.
  static const _warningDuration = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _forceAutoStartRequested = widget.forceAutoStart;
    WidgetsBinding.instance.addObserver(this);
    // Register the state change callback so the controller can trigger
    // rebuilds when detections arrive.
    final controller = ref.read(liveControllerProvider);
    _liveController = controller;
    controller.onStateChanged = _onControllerStateChanged;

    // Deferred to post-frame so provider updates don't fire during build.
    SchedulerBinding.instance.addPostFrameCallback((_) => _initLiveScreen());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, _presenceRoute)) return;
    final previousRoute = _presenceRoute;
    if (previousRoute != null) {
      LiveScreenPresence.unregister(previousRoute);
    }
    _presenceRoute = route;
    LiveScreenPresence.register(
      route,
      onStartListening: _requestQuickListenStart,
    );
  }

  /// Bring the screen in sync with the controller, whatever state it is in.
  ///
  /// The main menu warms the model up in the background, so this screen can be
  /// entered at any point of that load.  Every entry state is handled here, in
  /// one path, rather than being split across branches that each assume a
  /// different starting point:
  ///
  ///   * `active` / `paused` — a session survived backgrounding.  Adopt it
  ///     untouched: do not wipe its detections, do not reload its model.
  ///   * `ready` — the warm-up (or a previous visit) already finished.  Start
  ///     straight away; this is the fast path the warm-up exists to produce.
  ///   * `loading` — the warm-up is still running.  [LiveController.loadModel]
  ///     joins the in-flight load instead of starting a second one, so the
  ///     background work is never thrown away and restarted.
  ///   * `idle` — no warm-up ran (or it was skipped).  Load now.
  ///   * `error` — the warm-up failed, somewhere the user never saw.  Retry
  ///     rather than dropping them onto an error banner for a failure that
  ///     happened off-screen.
  Future<void> _initLiveScreen() async {
    if (!mounted) return;
    final controller = ref.read(liveControllerProvider);

    final hasRunningSession =
        controller.state == LiveState.active ||
        controller.state == LiveState.paused;

    if (!hasRunningSession) {
      controller.clearSessionState();
      ref.read(sessionDetectionsProvider.notifier).state = const [];
      ref.read(allSessionDetectionsProvider.notifier).state = const [];
      ref.read(latestLiveDetectionsProvider.notifier).state = const [];
      ref.read(currentSessionProvider.notifier).state = null;
    }

    // Session state is clean, so it is now safe for the auto-start to fire.
    // Until this point it must not: the load can settle (and notify) while
    // this callback is still running, and auto-starting a session that we
    // then cleared out from under would lose its first detections.
    _initialised = true;

    if (!hasRunningSession && controller.state != LiveState.ready) {
      // Joins the warm-up's load if one is in flight; starts or retries one
      // otherwise. Completes only once the model has settled.
      await controller.loadModel();
      if (!mounted) return;
    }

    _onControllerStateChanged();
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    final controller = ref.read(liveControllerProvider);

    // Sync controller state to reactive providers.
    ref.read(liveStateProvider.notifier).state = controller.state;

    // Show the current live detections (replaced each cycle, like the PWA).
    // Each species appears at most once with its latest confidence score.
    ref.read(sessionDetectionsProvider.notifier).state =
        controller.currentLiveDetections;
    ref.read(allSessionDetectionsProvider.notifier).state =
        controller.sessionDetections;
    ref.read(currentSessionProvider.notifier).state = controller.session;

    // Auto-start: if the user opted in via the Live setting, kick off a
    // session as soon as the model finishes loading. Guarded by
    // [_autoStartAttempted] so a single screen visit only ever auto-starts
    // once — leaving the user free to stop and manually restart without
    // the screen re-arming itself.
    if (_initialised &&
        !_autoStartAttempted &&
        !_isStarting &&
        !_startScheduled &&
        controller.state == LiveState.ready &&
        (_forceAutoStartRequested || ref.read(liveAutoStartProvider))) {
      _forceAutoStartRequested = false;
      _scheduleStart();
    }
  }

  void _requestQuickListenStart() {
    if (!mounted || _isStarting || _startScheduled) return;
    final controller = ref.read(liveControllerProvider);
    if (controller.state == LiveState.active ||
        controller.state == LiveState.paused) {
      return;
    }

    _forceAutoStartRequested = true;
    _autoStartAttempted = false;
    if (!_initialised) return;

    if (controller.state == LiveState.ready) {
      _onControllerStateChanged();
    } else {
      // A second tap after a failed load should retry, and a tap while the
      // home-screen warm-up is loading should join that load immediately.
      _forceAutoStartRequested = false;
      _scheduleStart();
    }
  }

  void _scheduleStart() {
    if (_isStarting || _startScheduled) return;
    _autoStartAttempted = true;
    _startScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _startScheduled = false;
      if (mounted) unawaited(_toggleSession());
    });
  }

  /// Handle the main action button press (pause / resume / start).
  Future<void> _toggleSession() async {
    if (_isStarting) return;
    final controller = ref.read(liveControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);
    final audioSource = ref.read(audioSourceProvider);

    if (controller.state == LiveState.active) {
      // ── Stop session → confirm, then go to review ────────────
      await _confirmStop();
    } else if (controller.state == LiveState.paused) {
      // ── Resume the same session ──────────────────────────────────
      await captureNotifier.start(source: audioSource);
      await controller.resumeSession();
      _onControllerStateChanged();
    } else {
      // ── Start a brand-new session ────────────────────────────────
      // Every non-session state lands here — `ready`, but also `idle`,
      // `loading` (the menu's warm-up is still running) and `error` (it
      // failed). The model is brought up first, so the user can press start
      // at any point of the warm-up and simply have it take effect when the
      // load lands, instead of the press being silently dropped.
      _isStarting = true;
      _durationWarningShown = false;
      _pausedByLifecycle = false;
      setState(() {});

      // No-op when already ready; otherwise joins the in-flight load, or
      // starts/retries one. Returns only once the model has settled.
      if (controller.state != LiveState.ready) {
        await controller.loadModel();
        if (!mounted) {
          _isStarting = false;
          return;
        }
        _onControllerStateChanged();
      }

      // Still not ready → the load failed. Leave the error banner up.
      if (controller.state != LiveState.ready) {
        _isStarting = false;
        setState(() {});
        return;
      }

      // Keep screen on during live recording.
      await WakelockService.enable();

      // Apply user-tunable DSP (gain + high-pass) before starting
      // capture so the very first chunk is already processed.
      final captureService = ref.read(audioCaptureServiceProvider);
      captureService.setGain(ref.read(audioGainProvider));
      captureService.setHighPassCutoff(ref.read(highPassFilterProvider));

      // Start audio capture.
      await captureNotifier.start(source: audioSource);

      // Read settings.
      final windowDuration = ref.read(windowDurationProvider);
      final inferenceRate = ref.read(inferenceRateProvider);
      final confidenceThreshold = ref.read(confidenceThresholdProvider);
      final filterMode = ref.read(speciesFilterModeProvider);
      final recordingModeStr = ref.read(recordingModeProvider);
      final recordingMode = recordingModeFromString(recordingModeStr);
      final recordingFormat = ref.read(recordingFormatProvider);
      final geoThreshold = ref.read(geoThresholdProvider);
      final poolingWindows = ref.read(scorePoolingWindowsProvider);
      final poolingMaxAgeSeconds = ref.read(scorePoolingMaxAgeSecondsProvider);
      final sensitivity = ref.read(sensitivityProvider);

      // Fetch geo-model scores (if available) for species filtering.
      // Also fetch the full geo-model species names for model intersection.
      // Invalidating the location provider forces a fresh GPS fix instead
      // of reusing whatever stale value the FutureProvider cached on a
      // previous build — important when the user has moved between
      // sessions (e.g. setting up a survey at one stop and then another).
      // [LocationService] internally falls back to the OS-cached last
      // position on a 10s timeout, so we still get something usable
      // indoors / under poor signal — we just warn the user via SnackBar.
      final useGps = ref.read(useGpsProvider);
      if (useGps) {
        ref.invalidate(currentLocationProvider);
      }
      final geoScores = await ref.read(geoScoresProvider.future);
      final ignoredSpeciesNames = await ref.read(
        ignoredSpeciesNamesProvider.future,
      );
      final geoSpeciesNames = await ref.read(
        geoModelSpeciesNamesProvider.future,
      );
      // The geo-model futures can take seconds; the user may have left the
      // Live screen in the meantime. Bail out before touching [ref] again so
      // we never read providers on an unmounted widget.
      if (!mounted) {
        _isStarting = false;
        return;
      }
      if (useGps && mounted) {
        final svc = ref.read(locationServiceProvider);
        if (svc.lastFetchUsedCachedFallback) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.gpsStaleWarning),
                duration: const Duration(seconds: 4),
              ),
            );
        }
      }

      double? startLat;
      double? startLon;
      try {
        final loc = ref.read(currentLocationProvider).value;
        if (loc != null) {
          startLat = loc.latitude;
          startLon = loc.longitude;
        }
      } catch (_) {}

      // Start inference session.
      await controller.startSession(
        windowDuration: windowDuration,
        inferenceRate: inferenceRate,
        confidenceThreshold: confidenceThreshold,
        speciesFilterMode: filterMode,
        recordingMode: recordingMode,
        recordingFormat: recordingFormat,
        geoScores: geoScores,
        geoThreshold: geoThreshold,
        geoModelSpeciesNames: geoSpeciesNames,
        poolingWindows: poolingWindows,
        poolingMode: ref.read(scorePoolingProvider),
        poolingMaxAgeSeconds: poolingMaxAgeSeconds,
        advancedPooling: ref.read(advancedPoolingParamsProvider),
        sensitivity: sensitivity,
        ignoreSettings: ref.read(speciesIgnoreSettingsProvider),
        ignoredSpeciesNames: ignoredSpeciesNames,
        gainLinear: ref.read(audioGainProvider),
        highPassHz: ref.read(highPassFilterProvider).toDouble(),
        latitude: startLat,
        longitude: startLon,
      );

      _isStarting = false;
      _onControllerStateChanged();
      _startSessionTimer();
    }
  }

  /// Show confirmation dialog, then finalize and navigate to review.
  Future<void> _confirmStop() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.sessionStopTitle,
      body: l10n.sessionStopMessage,
      confirmLabel: l10n.sessionStopConfirm,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed || !mounted) return;
    await _finalizeAndReview();
  }

  @override
  void dispose() {
    final presenceRoute = _presenceRoute;
    if (presenceRoute != null) {
      LiveScreenPresence.unregister(presenceRoute);
    }
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();

    // Clear the state-change callback on the long-lived controller to avoid calling
    // updates on a defunct/disposed widget state. Use the cached reference
    // because reading [ref] during dispose is unsafe.
    final controller = _liveController;
    if (controller != null &&
        controller.onStateChanged == _onControllerStateChanged) {
      controller.onStateChanged = null;
    }

    // Ensure screen lock is released when leaving the live screen.
    WakelockService.disable();
    super.dispose();
  }

  // ── App lifecycle ─────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only [paused] means the app is actually backgrounded. [inactive] also
    // fires for transient interruptions that leave the app on screen — the
    // rotation transition under auto-rotate, the app switcher, Control
    // Center, an incoming call, and the task-to-front blip when the Quick
    // Listen widget or an ARU notification action relaunches an app that is
    // already in the foreground — and must not tear down a live recording.
    if (state == AppLifecycleState.paused) {
      _enqueueLifecycleTransition(_pauseSessionForBackground);
    } else if (state == AppLifecycleState.resumed) {
      _enqueueLifecycleTransition(_resumeSessionFromBackground);
    }
  }

  bool _pausedByLifecycle = false;

  /// Tail of the serialized lifecycle pause/resume chain.
  Future<void> _lifecycleTransition = Future<void>.value();

  /// Queue a lifecycle transition behind any still-running one.
  ///
  /// Pausing spans an await (tearing down audio capture) during which the
  /// controller still reports [LiveState.active]. A quick background→
  /// foreground bounce would otherwise let the resume observe that stale
  /// state, skip itself, and strand the session paused with no further
  /// lifecycle event coming. Serializing makes each transition read the
  /// state its predecessor actually left behind.
  void _enqueueLifecycleTransition(Future<void> Function() transition) {
    _lifecycleTransition = _lifecycleTransition.then((_) async {
      if (!mounted) return;
      try {
        await transition();
      } catch (e, stack) {
        // A throwing transition must not poison the chain. An errored tail
        // makes every later `.then` propagate the error instead of running
        // its callback, which would leave the screen deaf to background and
        // foreground events for the rest of its life — exactly the stuck
        // state the queue exists to prevent.
        debugPrint('LiveScreen: lifecycle transition failed: $e\n$stack');
      }
    });
  }

  Future<void> _pauseSessionForBackground() async {
    // The session is already being torn down — finalizing stops capture and
    // closes the session itself, so pausing would only race it.
    if (_finalizing) return;
    final controller = ref.read(liveControllerProvider);
    if (controller.state != LiveState.active) return;
    _pausedByLifecycle = true;
    _sessionTimer?.cancel();
    final captureNotifier = ref.read(captureStateProvider.notifier);
    await captureNotifier.stop();
    await controller.pauseSession();
    _onControllerStateChanged();
  }

  Future<void> _resumeSessionFromBackground() async {
    // Don't hand the microphone back to a session that is on its way out.
    if (_finalizing) return;
    final controller = ref.read(liveControllerProvider);
    if (!_pausedByLifecycle || controller.state != LiveState.paused) return;
    final captureNotifier = ref.read(captureStateProvider.notifier);
    final audioSource = ref.read(audioSourceProvider);
    await captureNotifier.start(source: audioSource);
    await controller.resumeSession();
    // Disarmed only once the resume has actually landed. Clearing it up front
    // would make a failure here permanent: the session would stay paused with
    // the flag down, so no later `resumed` event could retry it.
    _pausedByLifecycle = false;
    _onControllerStateChanged();
    _startSessionTimer();
  }

  // ── Session duration timer ────────────────────────────────────────────

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    if (_durationWarningShown) return;
    final controller = ref.read(liveControllerProvider);
    final elapsed = controller.session?.duration ?? Duration.zero;
    final remaining = _warningDuration - elapsed;
    if (remaining <= Duration.zero) return;
    _sessionTimer = Timer(remaining, _showDurationWarning);
  }

  Future<void> _showDurationWarning() async {
    if (!mounted || _durationWarningShown) return;
    _durationWarningShown = true;
    final l10n = AppLocalizations.of(context)!;
    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.sessionDurationWarningTitle),
            content: Text(l10n.sessionDurationWarningMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.sessionStopConfirm),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.sessionContinue),
              ),
            ],
          ),
    );
    if (!mounted) return;
    if (shouldContinue != true) {
      await _finalizeAndReview();
    }
  }

  /// Finalize and save the session when leaving the live screen.
  Future<void> _finalizeAndReview() async {
    if (_finalizing) return;
    _finalizing = true;
    _sessionTimer?.cancel();
    final controller = ref.read(liveControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);

    // Release screen wakelock.
    await WakelockService.disable();

    // Stop audio capture if still running.
    await captureNotifier.stop();

    // Finalize the session (works from both active and paused states).
    final session = await controller.finalizeSession();
    _onControllerStateChanged();

    if (session != null && mounted) {
      // Assign a per-type sequential session number.
      final repo = ref.read(sessionRepositoryProvider);
      session.sessionNumber = await repo.nextSessionNumber(session.type);

      // Capture recording location (best effort — null if unavailable) if not already set.
      if (session.latitude == null || session.longitude == null) {
        try {
          final location = await ref.read(currentLocationProvider.future);
          if (location != null) {
            session.latitude = location.latitude;
            session.longitude = location.longitude;
          }
        } catch (_) {
          // Location unavailable — leave fields null.
        }
      }

      // Persist completed session — unless the user turned off automatic
      // saving, in which case the review screen opens in the "unsaved" state
      // and only writes the session if the user explicitly saves it.
      final autoSave = ref.read(saveSessionAutomaticallyProvider);
      if (autoSave) {
        await repo.save(session);
        ref.invalidate(sessionListProvider);
      }

      // Replace the live screen with the session library (instantly,
      // no transition) and then push the review screen on top with the
      // normal page animation. The user sees `live → review`; closing
      // review pops back to the library instead of the home screen.
      if (mounted) {
        final navigator = Navigator.of(context);
        navigator.pushReplacement(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (a, b, c) => const SessionLibraryScreen(),
          ),
        );
        navigator.push(
          MaterialPageRoute<void>(
            builder:
                (_) =>
                    SessionReviewScreen(session: session, autoSaved: autoSave),
          ),
        );
      }
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final liveState = ref.watch(liveStateProvider);
    final captureState = ref.watch(captureStateProvider);
    final isCapturing = captureState == CaptureState.capturing;
    final isActive = liveState == LiveState.active;
    final isPaused = liveState == LiveState.paused;
    final currentDetections =
        (isActive || isPaused)
            ? ref.watch(sessionDetectionsProvider)
            : const <DetectionRecord>[];
    final allDetections =
        (isActive || isPaused)
            ? ref.watch(allSessionDetectionsProvider)
            : const <DetectionRecord>[];
    final showAllDetectedSpecies = ref.watch(showAllDetectedSpeciesProvider);
    final detectedSpeciesSortMode = ref.watch(detectedSpeciesSortModeProvider);
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final detections =
        (isActive || isPaused)
            ? buildLiveDetectionDisplayList(
              currentDetections: currentDetections,
              sessionDetections: allDetections,
              showAllDetectedSpecies: showAllDetectedSpecies,
              sortMode: detectedSpeciesSortMode,
              localizedCommonName:
                  (detection) =>
                      taxonomy
                          ?.lookup(detection.scientificName)
                          ?.commonNameForLocale(speciesLocale) ??
                      detection.commonName,
            )
            : const <DetectionRecord>[];
    final activeDetections =
        showAllDetectedSpecies
            ? (Set<DetectionRecord>.identity()..addAll(currentDetections))
            : null;
    final speciesDetectionCounts =
        showAllDetectedSpecies
            ? buildSpeciesDetectionCounts(allDetections)
            : null;

    // Hot-apply tunable settings to the running session: when the user
    // tweaks the confidence threshold or pooling window count from the
    // Settings screen mid-session, push the new value straight to the
    // controller so the next inference cycle picks it up — no need to
    // restart the session.
    ref.listen<int>(confidenceThresholdProvider, (_, next) {
      ref.read(liveControllerProvider).setConfidenceThreshold(next);
    });
    ref.listen<int>(scorePoolingWindowsProvider, (_, next) {
      ref.read(liveControllerProvider).setPoolingWindows(next);
    });
    ref.listen<double>(scorePoolingMaxAgeSecondsProvider, (_, next) {
      ref.read(liveControllerProvider).setPoolingMaxAgeSeconds(next);
    });
    ref.listen<String>(scorePoolingProvider, (_, next) {
      ref.read(liveControllerProvider).setPoolingMode(next);
    });
    ref.listen<AdvancedPoolingParams>(advancedPoolingParamsProvider, (_, next) {
      ref.read(liveControllerProvider).setAdvancedPoolingParams(next);
    });
    ref.listen<double>(sensitivityProvider, (_, next) {
      ref.read(liveControllerProvider).setSensitivity(next);
    });
    ref.listen(speciesIgnoreSettingsProvider, (_, _) async {
      final names = await ref.read(ignoredSpeciesNamesProvider.future);
      final geoScores = await ref.read(geoScoresProvider.future);
      ref
          .read(liveControllerProvider)
          .setSpeciesIgnoreFilter(scientificNames: names, geoScores: geoScores);
    });
    ref.listen<double>(audioGainProvider, (_, next) {
      ref.read(audioCaptureServiceProvider).setGain(next);
    });
    ref.listen<double>(highPassFilterProvider, (_, next) {
      ref.read(audioCaptureServiceProvider).setHighPassCutoff(next);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (liveState == LiveState.active || liveState == LiveState.paused) {
          await _confirmStop();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        // ── Bottom-center capture button ─────────────────────────
        floatingActionButton: _CaptureButton(
          isActive: isActive,
          isPaused: isPaused,
          isLoading: liveState == LiveState.loading || _isStarting,
          onPressed: _toggleSession,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: SafeArea(
          bottom: false,
          child: _buildBody(
            context,
            theme: theme,
            liveState: liveState,
            isActive: isActive,
            isPaused: isPaused,
            isCapturing: isCapturing,
            currentDetectionCount: currentDetections.length,
            activeDetections: activeDetections,
            speciesDetectionCounts: speciesDetectionCounts,
            detections: detections,
          ),
        ),
      ),
    );
  }

  /// Builds the main body, switching between portrait (vertical stack)
  /// and landscape (side-by-side) layouts.
  Widget _buildBody(
    BuildContext context, {
    required ThemeData theme,
    required LiveState liveState,
    required bool isActive,
    required bool isPaused,
    required bool isCapturing,
    required int currentDetectionCount,
    required Set<DetectionRecord>? activeDetections,
    required Map<String, int>? speciesDetectionCounts,
    required List<DetectionRecord> detections,
  }) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final statusBar = _CompactStatusBar(liveState: liveState, ref: ref);
    final errorBanner =
        liveState == LiveState.error
            ? _StatusBanner(liveState: liveState, ref: ref)
            : null;
    final spectrogram = Container(
      color: theme.colorScheme.surfaceContainerLowest,
      child: _LiveSpectrogram(isCapturing: isCapturing),
    );
    final sessionInfo = _SessionInfoBar(
      liveCount: currentDetectionCount,
      controller: ref.read(liveControllerProvider),
      visible: isActive || isPaused,
    );
    final detectionList = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: DetectionList(
          detections: detections,
          isActive: isActive || isPaused,
          showTips: true,
          activeDetections: activeDetections,
          speciesDetectionCounts: speciesDetectionCounts,
          onDetectionTap: (detection) {
            SpeciesInfoOverlay.show(
              context,
              ref,
              scientificName: detection.scientificName,
              commonName: detection.commonName,
            );
          },
        ),
      ),
    );

    if (isLandscape) {
      return Column(
        children: [
          statusBar,
          if (errorBanner != null) errorBanner,
          Expanded(
            child: Row(
              children: [
                // Left: spectrogram + session info
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [Expanded(child: spectrogram), sessionInfo],
                  ),
                ),
                // Right: detection list
                Expanded(flex: 1, child: detectionList),
              ],
            ),
          ),
          const SizedBox(height: 72),
        ],
      );
    }

    // Portrait: original vertical stack.
    return Column(
      children: [
        statusBar,
        if (errorBanner != null) errorBanner,
        Expanded(flex: 2, child: spectrogram),
        sessionInfo,
        Expanded(flex: 3, child: detectionList),
        const SizedBox(height: 72),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Compact top bar: ← back | status text | settings ⚙.
///
/// Height: ~48 dp.  No AppBar — just a thin Row to maximize vertical space.
class _CompactStatusBar extends StatelessWidget {
  const _CompactStatusBar({required this.liveState, required this.ref});

  final LiveState liveState;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isActive = liveState == LiveState.active;
    final isLoading = liveState == LiveState.loading;

    String statusText;
    Color statusColor;

    if (isActive) {
      statusText = l10n.statusIdentifying;
      statusColor = theme.colorScheme.primary;
    } else if (liveState == LiveState.paused) {
      statusText = l10n.statusPaused;
      statusColor = theme.colorScheme.onSurface.withAlpha(180);
    } else if (isLoading) {
      statusText = l10n.statusLoadingModel;
      statusColor = theme.colorScheme.onSurface.withAlpha(153);
    } else if (liveState == LiveState.error) {
      statusText = l10n.statusError;
      statusColor = theme.colorScheme.error;
    } else if (liveState == LiveState.ready) {
      statusText = l10n.statusReady;
      statusColor = theme.colorScheme.onSurface;
    } else {
      statusText = l10n.statusInitializing;
      statusColor = theme.colorScheme.onSurface.withAlpha(153);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 2),
      child: Row(
        children: [
          // Back button.
          IconButton(
            icon: const Icon(AppIcons.arrowBackRounded, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: l10n.tooltipBack,
          ),

          // Status text.
          Expanded(
            child: Text(
              statusText,
              style: theme.textTheme.titleSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          IconButton(
            icon: Icon(
              AppIcons.helpOutlineRounded,
              size: 20,
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => _showLiveHelp(context),
            tooltip: l10n.liveScreenHelpTitle,
          ),

          // Settings gear.
          IconButton(
            icon: Icon(
              AppIcons.tuneRounded,
              size: 20,
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => const SettingsScreen(
                        settingsContext: SettingsContext.live,
                      ),
                ),
              );
            },
            tooltip: l10n.settings,
          ),
        ],
      ),
    );
  }
}

void _showLiveHelp(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder:
        (_) => AppHelpBottomSheet(
          title: l10n.liveScreenHelpTitle,
          sections: [
            AppHelpSection(
              icon: AppIcons.mic,
              body: l10n.liveScreenHelpOverview,
            ),
            AppHelpSection(
              icon: AppIcons.helpOutlineRounded,
              body: l10n.liveScreenHelpControls,
            ),
            AppHelpSection(
              icon: AppIcons.infoOutline,
              body: l10n.liveScreenHelpInfoBar,
            ),
            AppHelpSection(
              icon: AppIcons.libraryMusic,
              body: l10n.liveScreenHelpDetections,
            ),
          ],
        ),
  );
}

/// Circular microphone / stop button — bottom-center FAB (56×56).
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.isActive,
    required this.isPaused,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isActive;
  final bool isPaused;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Active → red stop button, paused → primary play button, idle → primary mic.
    final Color bgColor;
    final IconData icon;
    final Color iconColor;
    final String semanticsLabel;

    if (isActive) {
      bgColor = theme.colorScheme.error;
      icon = AppIcons.stopRounded;
      iconColor = theme.colorScheme.onError;
      semanticsLabel = l10n.a11yLiveCaptureStop;
    } else if (isPaused) {
      bgColor = theme.colorScheme.primary;
      icon = AppIcons.playArrowRounded;
      iconColor = theme.colorScheme.onPrimary;
      semanticsLabel = l10n.a11yLiveCaptureResume;
    } else {
      bgColor = theme.colorScheme.primary;
      icon = AppIcons.mic;
      iconColor = theme.colorScheme.onPrimary;
      semanticsLabel = l10n.a11yLiveCaptureStart;
    }

    return Semantics(
      button: true,
      enabled: !isLoading,
      label: semanticsLabel,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Material(
          shape: const CircleBorder(),
          color: bgColor,
          elevation: 4,
          shadowColor: bgColor.withAlpha(120),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap:
                isLoading
                    ? null
                    : () {
                      HapticFeedback.lightImpact();
                      onPressed();
                    },
            child:
                isLoading
                    ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                    : ExcludeSemantics(
                      child: Icon(icon, color: iconColor, size: 28),
                    ),
          ),
        ),
      ),
    );
  }
}

/// Banner showing model error state with retry button.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.liveState, required this.ref});

  final LiveState liveState;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.errorOutline,
            size: 16,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.modelLoadFailed,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(liveControllerProvider).loadModel();
            },
            child: Text(AppLocalizations.of(context)!.retry),
          ),
        ],
      ),
    );
  }
}

/// Session info bar showing detection count and duration.
///
/// Always present in the layout to prevent the spectrogram from resizing
/// when a session starts.  When [visible] is false, the bar still occupies
/// space but renders transparent placeholder content.
class _SessionInfoBar extends ConsumerWidget {
  const _SessionInfoBar({
    required this.liveCount,
    required this.controller,
    required this.visible,
  });

  /// Number of species currently shown in the live view.
  final int liveCount;

  /// Controller for reading cumulative session stats.
  final LiveController controller;

  /// Whether to show actual stats (true) or an invisible placeholder (false).
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!visible) {
      // Invisible placeholder — same height, no content.
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: SizedBox(height: 20),
      );
    }

    // Calculate total detections
    final totalDetections = controller.sessionDetections.length;

    // Unique species across the entire session (cumulative).
    final totalUnique =
        controller.sessionDetections
            .map((d) => d.scientificName)
            .toSet()
            .length;

    // Duration of the active session.
    int durationSec = 0;
    if (controller.session != null) {
      durationSec = controller.session!.duration.inSeconds;
    }

    final recordingMode = ref.watch(recordingModeProvider);
    final String durationStr = _formatDuration(durationSec);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: FutureBuilder<int>(
        // Read the actual on-disk size of the session's recording directory
        // so this matches the size reported by the session library card.
        // Falls back to 0 (omitted) when recording is off or the directory
        // doesn't exist yet.
        future:
            recordingMode == 'off'
                ? Future.value(0)
                : _readRecordingBytes(controller.recordingService.sessionDir),
        builder: (context, snap) {
          final bytes = snap.data ?? 0;
          final List<String> parts = [];
          if (liveCount > 0) parts.add(l10n.liveStatusNow(liveCount));
          parts.add(l10n.liveStatusSpecies(totalUnique));
          parts.add(l10n.liveStatusDetections(totalDetections));
          if (durationSec > 0) {
            parts.add(durationStr);
            if (recordingMode != 'off' && bytes > 0) {
              parts.add(_formatSize(bytes));
            }
          }
          final label = parts.join(' • ');

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AppIcons.infoOutline,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Sum the size of every file inside the recording session directory.
  ///
  /// This includes the streaming `full.flac`/`full.wav` for continuous
  /// recording mode and any per-detection clip files for detections-only
  /// mode. The resulting number matches what the session library card
  /// computes after the session is closed.
  static Future<int> _readRecordingBytes(String? sessionDir) async {
    if (sessionDir == null) return 0;
    var total = 0;
    try {
      final dir = Directory(sessionDir);
      if (!await dir.exists()) return 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            /* ignore */
          }
        }
      }
    } catch (_) {
      /* ignore */
    }
    return total;
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final rh = m % 60;
      return '${h}h ${rh}m';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(0)}KB';
    final mb = kb / 1024.0;
    if (mb < 10) return '${mb.toStringAsFixed(1)}MB';
    if (mb < 1024) return '${mb.toStringAsFixed(0)}MB';
    final gb = mb / 1024.0;
    return '${gb.toStringAsFixed(1)}GB';
  }
}

/// Wraps the [SpectrogramWidget] and connects it to the shared ring buffer
/// and spectrogram settings from Riverpod providers.
///
/// When capture is inactive the spectrogram remains visible (frozen on the
/// last frame) but the FFT ticker is paused to conserve CPU.
class _LiveSpectrogram extends ConsumerWidget {
  const _LiveSpectrogram({required this.isCapturing});

  final bool isCapturing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringBuffer = ref.watch(ringBufferProvider);
    final fftSize = ref.watch(fftSizeProvider);
    final colorMap = ref.watch(colorMapProvider);
    final dbFloor = ref.watch(dbFloorProvider);
    final dbCeiling = ref.watch(dbCeilingProvider);
    final durationSec = ref.watch(spectrogramDurationProvider);
    final maxFreq = ref.watch(spectrogramMaxFreqProvider);

    final logAmplitude = ref.watch(logAmplitudeProvider);
    final quality = ref.watch(spectrogramQualityProvider);

    return ExcludeSemantics(
      child: SpectrogramWidget(
        ringBuffer: ringBuffer,
        isActive: isCapturing,
        fftSize: fftSize,
        colorMapName: colorMap,
        dbFloor: dbFloor,
        dbCeiling: dbCeiling,
        displaySeconds: durationSec.toDouble(),
        showFrequencyAxis: false,
        showTimeAxis: false,
        maxDisplayFrequency: maxFreq,
        logAmplitude: logAmplitude,
        filterQuality: spectrogramFilterQualityFromString(quality),
        quality: quality,
      ),
    );
  }
}
