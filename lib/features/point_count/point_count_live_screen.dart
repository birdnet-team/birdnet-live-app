// =============================================================================
// Point Count Live Screen — Timed survey with countdown and auto-stop
// =============================================================================
//
// Reuses the Live Mode infrastructure ([LiveController], audio capture,
// spectrogram, recording) but with key differences:
//
//   - **Countdown timer** — prominent display counts down from the configured
//     duration.  Auto-finalizes and navigates to session review when it
//     reaches zero.
//   - **Session type** — set to [SessionType.pointCount] so saved sessions
//     are categorized correctly.
//   - **No pause** — point counts run continuously once started.  The user
//     can stop early, but pausing would break protocol.
//   - **Auto-start** — inference begins immediately on screen open.
//
// Layout (top → bottom):
//   1. Status bar with back arrow, countdown timer (center), settings gear
//   2. Spectrogram (flex: 2)
//   3. Session info bar
//   4. Detection list (flex: 3)
//
// No FAB button — the count starts automatically and stops via timer or the
// "End Count Early" action in the status bar.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../core/services/wakelock_service.dart';
import '../../core/services/location_service.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/audio_background_notification.dart';
import '../../shared/services/quick_action_service.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/confirm_destructive.dart';
import '../audio/audio_capture_service.dart';
import '../audio/audio_providers.dart';
import '../explore/explore_providers.dart';
import '../explore/widgets/species_info_overlay.dart';
import '../history/session_library_screen.dart';
import '../history/session_checkpoint_writer.dart';
import '../history/session_review_screen.dart';
import '../inference/advanced_pooling_params.dart';
import '../recording/recording_service.dart';
import '../settings/settings_screen.dart';
import '../spectrogram/spectrogram_widget.dart';
import '../live/live_controller.dart';
import '../live/live_detection_display.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../live/widgets/detection_list_widget.dart';

/// Timed point-count survey screen with countdown and auto-stop.
class PointCountLiveScreen extends ConsumerStatefulWidget {
  const PointCountLiveScreen({
    super.key,
    required this.durationMinutes,
    required this.recordingMode,
    required this.continueWithScreenOff,
    this.latitude,
    this.longitude,
    this.startLocation,
    this.customName,
    this.observerName,
    this.windowDurationOverride,
    this.inferenceRateOverride,
    this.confidenceThresholdOverride,
    this.speciesFilterModeOverride,
    this.sensitivityOverride,
  });

  /// Total survey duration in minutes.
  final int durationMinutes;

  /// Recording choice made in Point Count setup.
  final String recordingMode;

  /// Screen-off choice made in Point Count setup for this count.
  final bool continueWithScreenOff;

  /// Optional latitude chosen during setup (GPS or manual).
  final double? latitude;

  /// Optional longitude chosen during setup (GPS or manual).
  final double? longitude;
  final AppLocation? startLocation;

  /// Optional user-chosen name for the count (e.g., "Pond Stop 1").
  final String? customName;

  /// Optional observer name persisted with the session.
  final String? observerName;

  /// Optional per-session inference parameter overrides chosen in the setup
  /// wizard. When `null`, the corresponding global setting is used.
  final int? windowDurationOverride;
  final double? inferenceRateOverride;
  final int? confidenceThresholdOverride;
  final String? speciesFilterModeOverride;
  final double? sensitivityOverride;

  @override
  ConsumerState<PointCountLiveScreen> createState() =>
      _PointCountLiveScreenState();
}

class _PointCountLiveScreenState extends ConsumerState<PointCountLiveScreen>
    with WidgetsBindingObserver {
  final Object _quickListenSafetyOwner = Object();

  /// The long-lived Live controller, resolved once in [initState].
  ///
  /// `ref` is unusable from [dispose] — Riverpod throws, because the element is
  /// already deactivated by then — and the listener this screen installs has to
  /// be cleared there. The provider is never invalidated, so the instance held
  /// here cannot go stale.
  late final LiveController _liveController;

  /// Remaining time in the countdown (updated every second).
  late final ValueNotifier<Duration> _remainingNotifier;

  /// Periodic timer that ticks every second to update the countdown.
  Timer? _countdownTimer;
  SessionCheckpointWriter? _checkpointWriter;
  DateTime? _countEndTime;
  int _lastNotifiedRemainingMinutes = -1;
  bool _appBackgrounded = false;
  bool _endWhenStarted = false;
  bool _endOnResume = false;
  bool _backgroundReady = false;
  final AudioBackgroundNotificationService _backgroundService =
      AudioBackgroundNotificationService(AudioBackgroundMode.pointCount);
  Future<void> _backgroundTransition = Future<void>.value();

  /// Whether the session has been started.
  bool _started = false;

  /// Whether we're in the process of finalizing (prevents double-finalize).
  bool _finalizing = false;
  bool _stopDialogOpen = false;

  @override
  void initState() {
    super.initState();
    QuickListenSafety.registerIncompatibleSessionOwner(
      _quickListenSafetyOwner,
      QuickListenSessionOwner.pointCount,
    );
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onNotificationData);
    _remainingNotifier = ValueNotifier(
      Duration(minutes: widget.durationMinutes),
    );

    _liveController = ref.read(liveControllerProvider);
    final controller = _liveController;
    controller.onStateChanged = _onControllerStateChanged;

    // Start session after the first frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Reset previous session state post-frame to ensure blank screen on load and avoid build-phase modifications.
        if (controller.state != LiveState.active &&
            controller.state != LiveState.paused) {
          controller.clearSessionState();
          ref.read(sessionDetectionsProvider.notifier).state = const [];
          ref.read(allSessionDetectionsProvider.notifier).state = const [];
          ref.read(latestLiveDetectionsProvider.notifier).state = const [];
          ref.read(currentSessionProvider.notifier).state = null;
        }
        _startSession();
      }
    });
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    final controller = ref.read(liveControllerProvider);
    ref.read(liveStateProvider.notifier).state = controller.state;
    ref.read(sessionDetectionsProvider.notifier).state =
        controller.currentLiveDetections;
    ref.read(allSessionDetectionsProvider.notifier).state =
        controller.sessionDetections;
    ref.read(currentSessionProvider.notifier).state = controller.session;
  }

  Future<bool> _abortPendingStart(CaptureStateNotifier captureNotifier) async {
    if (mounted && !_endWhenStarted) return false;
    await captureNotifier.stop();
    await WakelockService.disable();
    // No session exists yet to review when startup was interrupted. The
    // message stays queued until the user returns to the app.
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final message = AppLocalizations.of(context)!.pointCountStartInterrupted;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
          showCloseIcon: true,
        ),
      );
    }
    return true;
  }

  /// Load model (if needed) and start the inference session.
  Future<void> _startSession() async {
    if (_started) return;
    final controller = ref.read(liveControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);
    final audioSource = ref.read(audioSourceProvider);
    final repo = ref.read(sessionRepositoryProvider);

    // Load model if not ready.
    if (controller.state == LiveState.idle) {
      await controller.loadModel();
      _onControllerStateChanged();
    }
    if (await _abortPendingStart(captureNotifier)) return;
    if (controller.state == LiveState.error) return;

    await WakelockService.enable();

    // Apply user-tunable DSP (gain + high-pass) before capture starts.
    final captureService = ref.read(audioCaptureServiceProvider);
    captureService.setGain(ref.read(audioGainProvider));
    captureService.setHighPassCutoff(ref.read(highPassFilterProvider));

    await captureNotifier.start(source: audioSource);
    if (await _abortPendingStart(captureNotifier)) return;

    // Read inference settings (use wizard overrides when provided).
    final int windowDuration =
        widget.windowDurationOverride ?? ref.read(windowDurationProvider);
    final double inferenceRate =
        widget.inferenceRateOverride ?? ref.read(inferenceRateProvider);
    final int confidenceThreshold =
        widget.confidenceThresholdOverride ??
        ref.read(confidenceThresholdProvider);
    final String filterMode =
        widget.speciesFilterModeOverride ?? ref.read(speciesFilterModeProvider);
    final double sensitivity =
        widget.sensitivityOverride ?? ref.read(sensitivityProvider);
    final recordingMode = recordingModeFromString(widget.recordingMode);
    final recordingFormat = ref.read(recordingFormatProvider);
    final geoThreshold = ref.read(geoThresholdProvider);
    final geoScores = await ref.read(geoScoresProvider.future);
    final ignoredSpeciesNames = await ref.read(
      ignoredSpeciesNamesProvider.future,
    );
    final geoSpeciesNames = await ref.read(geoModelSpeciesNamesProvider.future);
    if (await _abortPendingStart(captureNotifier)) return;

    double? startLat = widget.latitude;
    double? startLon = widget.longitude;
    AppLocation? startLocation = widget.startLocation;
    if (startLat == null || startLon == null) {
      try {
        final loc = ref.read(currentLocationProvider).value;
        if (loc != null) {
          startLat = loc.latitude;
          startLon = loc.longitude;
          startLocation = loc;
        }
      } catch (_) {}
    }

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
      poolingWindows: ref.read(scorePoolingWindowsProvider),
      poolingMode: ref.read(scorePoolingProvider),
      poolingMaxAgeSeconds: ref.read(scorePoolingMaxAgeSecondsProvider),
      advancedPooling: ref.read(advancedPoolingParamsProvider),
      sensitivity: sensitivity,
      ignoreSettings: ref.read(speciesIgnoreSettingsProvider),
      ignoredSpeciesNames: ignoredSpeciesNames,
      targetDurationSeconds: widget.durationMinutes * 60,
      latitude: startLat,
      longitude: startLon,
      startLocation: startLocation,
      fixedLocationForDetections: true,
    );

    if (!mounted) {
      await captureNotifier.stop();
      final abandoned = await controller.finalizeSession();
      if (abandoned != null) await repo.delete(abandoned.id);
      await WakelockService.disable();
      return;
    }

    _started = true;
    _onControllerStateChanged();
    _checkpointWriter = SessionCheckpointWriter(
      repository: repo,
      session: () => controller.session,
      shouldSave: () => ref.read(saveSessionAutomaticallyProvider),
      prepare: (session) {
        session.type = SessionType.pointCount;
        session.customName = widget.customName;
        session.observerName = widget.observerName;
        session.latitude ??= widget.latitude;
        session.longitude ??= widget.longitude;
        if (session.latitude == widget.startLocation?.latitude &&
            session.longitude == widget.startLocation?.longitude) {
          session.altitude ??= widget.startLocation?.altitude;
          session.altitudeAccuracy ??= widget.startLocation?.altitudeAccuracy;
          session.altitudeReference ??= widget.startLocation?.altitudeReference;
          session.locationFixTime ??= widget.startLocation?.timestamp;
        }
      },
    )..start();

    // Use wall time so a suspended UI timer cannot extend the count.
    _countEndTime = DateTime.now().add(
      Duration(minutes: widget.durationMinutes),
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshCountdown();
    });
    if (_endWhenStarted) {
      await _finalizeAndReview(endedEarlyByBackground: true);
      return;
    }
    await _syncBackgroundSupport();
    if (_appBackgrounded && !_backgroundReady) {
      await _finalizeAndReview(endedEarlyByBackground: true);
    }
  }

  void _refreshCountdown() {
    if (!mounted || _finalizing || _countEndTime == null) return;
    final remaining = _countEndTime!.difference(DateTime.now());
    _remainingNotifier.value = remaining > Duration.zero
        ? remaining
        : Duration.zero;
    if (_backgroundReady && remaining > Duration.zero) {
      final minutesLeft = (remaining.inSeconds + 59) ~/ 60;
      if (minutesLeft != _lastNotifiedRemainingMinutes) {
        _lastNotifiedRemainingMinutes = minutesLeft;
        unawaited(
          _backgroundService.update(AppLocalizations.of(context)!, minutesLeft),
        );
      }
    }
    if (remaining <= Duration.zero) {
      _countdownTimer?.cancel();
      unawaited(_onCountdownComplete());
    }
  }

  void _onNotificationData(Object data) {
    if (data is Map && data['action'] == 'pointCountStop' && mounted) {
      unawaited(_finalizeAndReview());
    }
  }

  Future<void> _finishPendingNotificationStop() async {
    if (!await _backgroundService.hasPendingStop()) return;
    if (mounted && !_finalizing && _liveController.session != null) {
      await _finalizeAndReview();
    }
  }

  Future<void> _endIfBackgroundUnavailable() async {
    await _backgroundTransition;
    if (!mounted || _finalizing || !_started) return;
    if (_backgroundReady && widget.continueWithScreenOff) {
      _endOnResume = false;
      return;
    }
    await _finalizeAndReview(endedEarlyByBackground: true);
  }

  Future<void> _syncBackgroundSupport() {
    _backgroundTransition = _backgroundTransition
        .then((_) async {
          if (!mounted || _finalizing) return;
          if (!_started || !widget.continueWithScreenOff) {
            _backgroundReady = false;
            _lastNotifiedRemainingMinutes = -1;
            await _backgroundService.stop();
            if (mounted && _started) await WakelockService.enable();
            return;
          }

          final l10n = AppLocalizations.of(context)!;
          final remaining = _countEndTime?.difference(DateTime.now());
          final minutesLeft = remaining == null
              ? widget.durationMinutes
              : ((remaining.inSeconds + 59) ~/ 60)
                    .clamp(1, widget.durationMinutes)
                    .toInt();
          _backgroundReady = await _backgroundService.start(l10n, minutesLeft);
          if (!mounted || _finalizing) return;
          if (!widget.continueWithScreenOff) {
            _backgroundReady = false;
            await _backgroundService.stop();
            await WakelockService.enable();
          } else if (_backgroundReady) {
            _lastNotifiedRemainingMinutes = minutesLeft;
            await WakelockService.disable();
          } else {
            await WakelockService.enable();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.backgroundAudioUnavailable)),
            );
          }
        })
        .catchError((Object error, StackTrace stack) async {
          debugPrint('PointCount: background support failed: $error\n$stack');
          _backgroundReady = false;
          await _backgroundService.stop();
          if (mounted && _appBackgrounded && !_finalizing) {
            await _finalizeAndReview(endedEarlyByBackground: true);
          }
        });
    return _backgroundTransition;
  }

  /// Called when the countdown reaches zero.
  Future<void> _onCountdownComplete() async {
    if (_finalizing) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.pointCountComplete),
        duration: const Duration(seconds: 2),
      ),
    );
    await _finalizeAndReview();
  }

  /// User wants to stop early.
  Future<void> _confirmStopEarly() async {
    if (_finalizing || _stopDialogOpen) return;
    _stopDialogOpen = true;
    try {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await confirmDestructive(
        context,
        title: l10n.pointCountStopEarlyTitle,
        body: l10n.pointCountStopEarlyMessage,
        confirmLabel: l10n.pointCountStopEarly,
        cancelLabel: l10n.cancel,
      );
      if (!confirmed || !mounted) return;
      await _finalizeAndReview();
    } finally {
      _stopDialogOpen = false;
    }
  }

  Future<void> _finalizeAndReview({bool endedEarlyByBackground = false}) async {
    // [ref] and [context] are read below; both are invalid once unmounted.
    if (_finalizing || !mounted) return;
    _finalizing = true;
    _countdownTimer?.cancel();
    if (mounted) setState(() {});

    // Capture dependencies before any await. Persistence must complete even
    // if the route is removed while the app is in the background.
    final controller = ref.read(liveControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);
    final repo = ref.read(sessionRepositoryProvider);
    final autoSave = ref.read(saveSessionAutomaticallyProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final customName = widget.customName;
    final observerName = widget.observerName;
    final latitude = widget.latitude;
    final longitude = widget.longitude;
    final cachedLocation = ref.read(currentLocationProvider).value;
    var serviceStopped = false;

    try {
      await _checkpointWriter?.stop();
      _checkpointWriter = null;
      try {
        await WakelockService.disable();
      } catch (error, stack) {
        debugPrint('PointCount: wakelock release failed: $error\n$stack');
      }
      try {
        await captureNotifier.stop();
      } catch (error, stack) {
        debugPrint('PointCount: capture stop failed: $error\n$stack');
      }

      final session = await controller.finalizeSession();
      _onControllerStateChanged();
      if (session == null) {
        if (mounted) {
          final navigator = Navigator.of(context);
          final sessionRoute = ModalRoute.of(context);
          if (sessionRoute != null) {
            navigator.popUntil((route) => route == sessionRoute);
          }
          navigator.pop();
        }
        return;
      }

      if (endedEarlyByBackground) {
        session.stopReason = SessionStopReason.backgrounded;
      }
      session.type = SessionType.pointCount;
      session.customName = customName;
      session.observerName = observerName;
      session.latitude ??= latitude;
      session.longitude ??= longitude;
      session.latitude ??= cachedLocation?.latitude;
      session.longitude ??= cachedLocation?.longitude;
      final location = widget.startLocation ?? cachedLocation;
      if (session.latitude == location?.latitude &&
          session.longitude == location?.longitude) {
        session.altitude ??= location?.altitude;
        session.altitudeAccuracy ??= location?.altitudeAccuracy;
        session.altitudeReference ??= location?.altitudeReference;
        session.locationFixTime ??= location?.timestamp;
      }

      try {
        session.sessionNumber = await repo.nextSessionNumber(session.type);
      } catch (error, stack) {
        debugPrint('PointCount: session numbering failed: $error\n$stack');
      }

      var saved = false;
      if (autoSave) {
        try {
          await repo.save(session);
          if (await repo.load(session.id) == null) {
            throw StateError('Saved Point Count could not be reopened');
          }
          saved = true;
        } catch (error, stack) {
          debugPrint('PointCount: session save failed: $error\n$stack');
        }
        if (saved) {
          try {
            final listed = await container.refresh(sessionListProvider.future);
            if (!listed.any((item) => item.id == session.id)) {
              throw StateError(
                'Saved Point Count missing from Session Library',
              );
            }
          } catch (error, stack) {
            debugPrint('PointCount: library refresh failed: $error\n$stack');
            container.invalidate(sessionListProvider);
          }
        }
      }

      if (!autoSave) {
        await repo.deleteMetadataOnly(session.id);
      }

      // Release the old service before review permits a new session to start.
      await _backgroundService.stop();
      serviceStopped = true;
      if (mounted) {
        final navigator = Navigator.of(context);
        final sessionRoute = ModalRoute.of(context);
        if (sessionRoute != null) {
          navigator.popUntil((route) => route == sessionRoute);
        }
        if (autoSave && !saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.sessionUnsavedSession,
              ),
            ),
          );
        }
        navigator.pushReplacement(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (a, b, c) => const SessionLibraryScreen(),
          ),
        );
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SessionReviewScreen(session: session, autoSaved: saved),
          ),
        );
      }
    } catch (error, stack) {
      debugPrint('PointCount: finalization failed: $error\n$stack');
      if (mounted) {
        _finalizing = false;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.statusError)),
        );
      }
    } finally {
      // Keep the foreground service alive until the session has been saved.
      if (!serviceStopped) await _backgroundService.stop();
    }
  }

  /// Whether the spectrogram was suppressed while the app is not visible.
  bool _spectrogramPaused = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Suspend the spectrogram ticker when it is not visible. Audio and
    // inference continue only when background operation is enabled.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_checkpointWriter != null) {
        unawaited(_checkpointWriter!.saveNow());
      }
      if (!_spectrogramPaused) {
        _spectrogramPaused = true;
        setState(() {});
      }
      // Windows never reports [paused], so a minimized count keeps running.
      if (state == AppLifecycleState.paused) {
        _appBackgrounded = true;
        if (_started) _refreshCountdown();
        if (!_started) {
          _endWhenStarted = true;
        } else if (!_finalizing && !widget.continueWithScreenOff) {
          _endOnResume = true;
          unawaited(_finalizeAndReview(endedEarlyByBackground: true));
        } else if (!_finalizing && !_backgroundReady) {
          _endOnResume = true;
          unawaited(_endIfBackgroundUnavailable());
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      _appBackgrounded = false;
      unawaited(_finishPendingNotificationStop());
      if (!_started) _endWhenStarted = false;
      if (_endOnResume &&
          _started &&
          !_finalizing &&
          !widget.continueWithScreenOff) {
        unawaited(_finalizeAndReview(endedEarlyByBackground: true));
      }
      _refreshCountdown();
      if (_spectrogramPaused) {
        _spectrogramPaused = false;
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    QuickListenSafety.unregisterIncompatibleSessionOwner(
      _quickListenSafetyOwner,
    );
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onNotificationData);
    _countdownTimer?.cancel();
    _checkpointWriter?.dispose();
    if (!_finalizing) unawaited(_backgroundService.stop());
    _remainingNotifier.dispose();

    // Clear the state-change callback on the long-lived controller to avoid calling
    // updates on a defunct/disposed widget state.
    if (_liveController.onStateChanged == _onControllerStateChanged) {
      _liveController.onStateChanged = null;
    }

    WakelockService.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final liveState = ref.watch(liveStateProvider);
    final captureState = ref.watch(captureStateProvider);
    final isCapturing = captureState == CaptureState.capturing;
    final isActive = liveState == LiveState.active;
    final currentDetections = isActive
        ? ref.watch(sessionDetectionsProvider)
        : const <DetectionRecord>[];
    final allDetections = isActive
        ? ref.watch(allSessionDetectionsProvider)
        : const <DetectionRecord>[];
    final showAllDetectedSpecies = ref.watch(showAllDetectedSpeciesProvider);
    final detectedSpeciesSortMode = ref.watch(detectedSpeciesSortModeProvider);
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final detections = isActive
        ? buildLiveDetectionDisplayList(
            currentDetections: currentDetections,
            sessionDetections: allDetections,
            showAllDetectedSpecies: showAllDetectedSpecies,
            sortMode: detectedSpeciesSortMode,
            localizedCommonName: (detection) =>
                taxonomy
                    ?.lookup(detection.scientificName)
                    ?.commonNameForLocale(speciesLocale) ??
                detection.commonName,
          )
        : const <DetectionRecord>[];
    final activeDetections = showAllDetectedSpecies
        ? (Set<DetectionRecord>.identity()..addAll(currentDetections))
        : null;
    final speciesDetectionCounts = showAllDetectedSpecies
        ? buildSpeciesDetectionCounts(allDetections)
        : null;

    // Hot-apply tunable settings to the running point count: changes
    // made on the Settings screen mid-count are pushed straight to the
    // controller so the next inference cycle picks them up.
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
        if (_finalizing) return;
        if (_started && _liveController.session != null) {
          await _confirmStopEarly();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: _buildBody(
            context,
            theme,
            liveState,
            isActive,
            isCapturing,
            currentDetections.length,
            activeDetections,
            speciesDetectionCounts,
            detections,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    LiveState liveState,
    bool isActive,
    bool isCapturing,
    int currentDetectionCount,
    Set<DetectionRecord>? activeDetections,
    Map<String, int>? speciesDetectionCounts,
    List<DetectionRecord> detections,
  ) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final statusBar = ValueListenableBuilder<Duration>(
      valueListenable: _remainingNotifier,
      builder: (context, remaining, _) => _CountdownStatusBar(
        remaining: remaining,
        totalDuration: Duration(minutes: widget.durationMinutes),
        liveState: liveState,
        onStop: _finalizing
            ? null
            : _started
            ? _confirmStopEarly
            : () => Navigator.of(context).pop(),
      ),
    );
    final progressBar = ValueListenableBuilder<Duration>(
      valueListenable: _remainingNotifier,
      builder: (context, remaining, _) => _CountdownProgressBar(
        remaining: remaining,
        totalDuration: Duration(minutes: widget.durationMinutes),
      ),
    );
    final spectrogram = Container(
      color: theme.colorScheme.surfaceContainerLowest,
      child: _PointCountSpectrogram(
        isCapturing: isCapturing && !_spectrogramPaused,
      ),
    );
    final sessionInfo = _PointCountInfoBar(
      currentDetectionCount: currentDetectionCount,
      controller: ref.read(liveControllerProvider),
      visible: isActive,
    );
    final detectionList = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: DetectionList(
          detections: detections,
          isActive: isActive,
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
          progressBar,
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(child: spectrogram),
                      sessionInfo,
                    ],
                  ),
                ),
                Expanded(flex: 1, child: detectionList),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Column(
      children: [
        statusBar,
        progressBar,
        Expanded(flex: 2, child: spectrogram),
        sessionInfo,
        Expanded(flex: 3, child: detectionList),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Countdown Status Bar
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownStatusBar extends StatelessWidget {
  const _CountdownStatusBar({
    required this.remaining,
    required this.totalDuration,
    required this.liveState,
    required this.onStop,
  });

  final Duration remaining;
  final Duration totalDuration;
  final LiveState liveState;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isActive = liveState == LiveState.active;
    final isLoading =
        liveState == LiveState.loading || liveState == LiveState.idle;

    // Format remaining time as mm:ss.
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Row(
        children: [
          // Stop button (replaces back arrow).
          IconButton(
            icon: const Icon(AppIcons.stopRounded, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: onStop,
            tooltip: l10n.pointCountStopEarly,
            color: isActive ? theme.colorScheme.error : null,
          ),

          // Countdown timer (center).
          Expanded(
            child: Center(
              child: isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.statusLoadingModel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.timerRounded,
                          size: 18,
                          color: remaining.inSeconds <= 30
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.pointCountTimeRemaining(minutes, seconds),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: remaining.inSeconds <= 30
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
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
            onPressed: () => _showPointCountLiveHelp(context),
            tooltip: l10n.pointCountLiveHelpTitle,
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
                  builder: (_) => const SettingsScreen(
                    settingsContext: SettingsContext.pointCount,
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

void _showPointCountLiveHelp(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AppHelpBottomSheet(
      title: l10n.pointCountLiveHelpTitle,
      sections: [
        AppHelpSection(
          icon: AppIcons.timerRounded,
          body: l10n.pointCountLiveHelpTimer,
        ),
        AppHelpSection(
          icon: AppIcons.infoOutline,
          body: l10n.pointCountLiveHelpDetections,
        ),
        AppHelpSection(
          icon: AppIcons.stopRounded,
          body: l10n.pointCountLiveHelpFinish,
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Countdown Progress Bar
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownProgressBar extends StatelessWidget {
  const _CountdownProgressBar({
    required this.remaining,
    required this.totalDuration,
  });

  final Duration remaining;
  final Duration totalDuration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = totalDuration - remaining;
    final progress = totalDuration.inSeconds > 0
        ? (elapsed.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return LinearProgressIndicator(
      value: progress,
      minHeight: 3,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      valueColor: AlwaysStoppedAnimation(
        remaining.inSeconds <= 30
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Info Bar
// ─────────────────────────────────────────────────────────────────────────────

class _PointCountInfoBar extends StatelessWidget {
  const _PointCountInfoBar({
    required this.currentDetectionCount,
    required this.controller,
    required this.visible,
  });

  final int currentDetectionCount;
  final LiveController controller;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!visible) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: SizedBox(height: 20),
      );
    }

    final totalDetections = controller.sessionDetections.length;
    final totalUnique = controller.sessionDetections
        .map((d) => d.scientificName)
        .toSet()
        .length;

    final parts = <String>[];
    if (currentDetectionCount > 0) {
      parts.add(l10n.liveStatusNow(currentDetectionCount));
    }
    parts.add(l10n.liveStatusSpecies(totalUnique));
    parts.add(l10n.liveStatusDetections(totalDetections));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.infoOutline,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            parts.join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spectrogram
// ─────────────────────────────────────────────────────────────────────────────

class _PointCountSpectrogram extends ConsumerWidget {
  const _PointCountSpectrogram({required this.isCapturing});

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

    return SpectrogramWidget(
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
    );
  }
}
