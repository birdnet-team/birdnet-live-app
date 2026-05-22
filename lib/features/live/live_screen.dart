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
import '../../shared/services/weather_service.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/confirm_destructive.dart';
import '../audio/audio_capture_service.dart';
import '../audio/audio_providers.dart';
import '../explore/explore_providers.dart';
import '../explore/widgets/species_info_overlay.dart';
import '../history/session_library_screen.dart';
import '../history/session_review_screen.dart';
import '../recording/recording_service.dart';
import '../settings/settings_screen.dart';
import '../spectrogram/spectrogram_widget.dart';
import 'live_controller.dart';
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

/// Live mode screen — real-time species identification.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen>
    with WidgetsBindingObserver {
  bool _isStarting = false;
  Timer? _sessionTimer;
  bool _durationWarningShown = false;
  bool _autoStartAttempted = false;

  /// Duration after which a warning dialog is shown to the user.
  static const _warningDuration = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Register the state change callback so the controller can trigger
    // rebuilds when detections arrive.
    final controller = ref.read(liveControllerProvider);
    controller.onStateChanged = _onControllerStateChanged;

    // Eagerly load the model on first mount.
    // Deferred to post-frame so provider updates don't fire during build.
    if (controller.state == LiveState.idle) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.loadModel();
      });
    } else {
      // Model was already loaded on a previous visit, so the controller is
      // sitting in [LiveState.ready] (or paused/active from a backgrounded
      // session). The state-change callback won't fire on its own because
      // nothing actually changes — but we still need to evaluate the
      // auto-start path for the second/third/Nth Live screen visit. Defer
      // to post-frame so provider updates don't fire during build.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onControllerStateChanged();
      });
    }
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
    ref.read(currentSessionProvider.notifier).state = controller.session;

    // Auto-start: if the user opted in via the Live setting, kick off a
    // session as soon as the model finishes loading. Guarded by
    // [_autoStartAttempted] so a single screen visit only ever auto-starts
    // once — leaving the user free to stop and manually restart without
    // the screen re-arming itself.
    if (!_autoStartAttempted &&
        !_isStarting &&
        controller.state == LiveState.ready &&
        ref.read(liveAutoStartProvider)) {
      _autoStartAttempted = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleSession();
      });
    }
  }

  /// Handle the main action button press (pause / resume / start).
  Future<void> _toggleSession() async {
    if (_isStarting) return;
    final controller = ref.read(liveControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);
    final deviceId = ref.read(selectedDeviceProvider);

    if (controller.state == LiveState.active) {
      // ── Stop session → confirm, then go to review ────────────
      await _confirmStop();
    } else if (controller.state == LiveState.paused) {
      // ── Resume the same session ──────────────────────────────────
      await captureNotifier.start(deviceId: deviceId);
      await controller.resumeSession();
      _onControllerStateChanged();
    } else if (controller.state == LiveState.ready ||
        controller.state == LiveState.idle) {
      // ── Start a brand-new session ────────────────────────────────
      _isStarting = true;
      _durationWarningShown = false;
      _pausedByLifecycle = false;
      setState(() {});

      // Ensure model is loaded.
      if (controller.state == LiveState.idle) {
        await controller.loadModel();
        _onControllerStateChanged();
      }

      if (controller.state == LiveState.error) {
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
      await captureNotifier.start(deviceId: deviceId);

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
      final geoSpeciesNames = await ref.read(
        geoModelSpeciesNamesProvider.future,
      );
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
        sensitivity: sensitivity,
        gainLinear: ref.read(audioGainProvider),
        highPassHz: ref.read(highPassFilterProvider).toDouble(),
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
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    // Ensure screen lock is released when leaving the live screen.
    WakelockService.disable();
    super.dispose();
  }

  // ── App lifecycle ─────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(liveControllerProvider);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background — pause session to stop recording/inference.
      if (controller.state == LiveState.active) {
        _pauseSessionForBackground();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground — resume if we paused for background.
      if (controller.state == LiveState.paused && _pausedByLifecycle) {
        _resumeSessionFromBackground();
      }
    }
  }

  bool _pausedByLifecycle = false;

  Future<void> _pauseSessionForBackground() async {
    _pausedByLifecycle = true;
    _sessionTimer?.cancel();
    final controller = ref.read(liveControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);
    await captureNotifier.stop();
    await controller.pauseSession();
    _onControllerStateChanged();
  }

  Future<void> _resumeSessionFromBackground() async {
    _pausedByLifecycle = false;
    final controller = ref.read(liveControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);
    final deviceId = ref.read(selectedDeviceProvider);
    await captureNotifier.start(deviceId: deviceId);
    await controller.resumeSession();
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

      // Capture recording location (best effort — null if unavailable).
      try {
        final location = await ref.read(currentLocationProvider.future);
        if (location != null) {
          session.latitude = location.latitude;
          session.longitude = location.longitude;
        }
      } catch (_) {
        // Location unavailable — leave fields null.
      }

      // Best-effort weather snapshot (gated by privacy toggle, 8 s
      // timeout, never blocks save on failure).
      if (session.latitude != null && session.longitude != null) {
        try {
          final svc = ref.read(weatherServiceProvider);
          session.weather = await svc.fetch(
            latitude: session.latitude!,
            longitude: session.longitude!,
            observedAt: session.endTime ?? DateTime.now(),
          );
        } catch (_) {}
      }

      // Persist completed session.
      await repo.save(session);
      ref.invalidate(sessionListProvider);

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
            builder: (_) => SessionReviewScreen(session: session),
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
    final detections = ref.watch(sessionDetectionsProvider);

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
    ref.listen<String>(scorePoolingProvider, (_, next) {
      ref.read(liveControllerProvider).setPoolingMode(next);
    });
    ref.listen<double>(sensitivityProvider, (_, next) {
      ref.read(liveControllerProvider).setSensitivity(next);
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
      liveCount: detections.length,
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
          if (liveCount > 0) parts.add('$liveCount now');
          parts.add('$totalUnique spp');
          parts.add('$totalDetections det');
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

    // Compute maxColumns from desired duration:
    // hopSize = fftSize ~/ 2, hop duration = hopSize / sampleRate
    // maxColumns = durationSec / hopDuration
    final hopSize = fftSize ~/ 2;
    const sampleRate = 32000; // AppConstants.sampleRate
    final maxColumns = (durationSec * sampleRate / hopSize).round();

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
        maxColumns: maxColumns,
        showFrequencyAxis: false,
        showTimeAxis: false,
        maxDisplayFrequency: maxFreq,
        logAmplitude: logAmplitude,
        filterQuality: spectrogramFilterQualityFromString(quality),
      ),
    );
  }
}
