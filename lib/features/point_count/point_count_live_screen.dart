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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/wakelock_service.dart';
import '../../shared/providers/settings_providers.dart';
import '../audio/audio_capture_service.dart';
import '../audio/audio_providers.dart';
import '../explore/explore_providers.dart';
import '../explore/widgets/species_info_overlay.dart';
import '../history/session_review_screen.dart';
import '../recording/recording_service.dart';
import '../settings/settings_screen.dart';
import '../spectrogram/spectrogram_widget.dart';
import '../live/live_controller.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../live/widgets/detection_list_widget.dart';

/// Timed point-count survey screen with countdown and auto-stop.
class PointCountLiveScreen extends ConsumerStatefulWidget {
  const PointCountLiveScreen({
    super.key,
    required this.durationMinutes,
    this.latitude,
    this.longitude,
  });

  /// Total survey duration in minutes.
  final int durationMinutes;

  /// Optional latitude chosen during setup (GPS or manual).
  final double? latitude;

  /// Optional longitude chosen during setup (GPS or manual).
  final double? longitude;

  @override
  ConsumerState<PointCountLiveScreen> createState() =>
      _PointCountLiveScreenState();
}

class _PointCountLiveScreenState extends ConsumerState<PointCountLiveScreen>
    with WidgetsBindingObserver {
  /// Remaining time in the countdown (updated every second).
  late Duration _remaining;

  /// Periodic timer that ticks every second to update the countdown.
  Timer? _countdownTimer;

  /// Whether the session has been started.
  bool _started = false;

  /// Whether we're in the process of finalizing (prevents double-finalize).
  bool _finalizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remaining = Duration(minutes: widget.durationMinutes);

    final controller = ref.read(liveControllerProvider);
    controller.onStateChanged = _onControllerStateChanged;

    // Start session after the first frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startSession();
    });
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    final controller = ref.read(liveControllerProvider);
    ref.read(liveStateProvider.notifier).state = controller.state;
    ref.read(sessionDetectionsProvider.notifier).state =
        controller.currentLiveDetections;
    ref.read(currentSessionProvider.notifier).state = controller.session;
  }

  /// Load model (if needed) and start the inference session.
  Future<void> _startSession() async {
    if (_started) return;
    final controller = ref.read(liveControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);
    final deviceId = ref.read(selectedDeviceProvider);

    // Load model if not ready.
    if (controller.state == LiveState.idle) {
      await controller.loadModel();
      _onControllerStateChanged();
    }
    if (controller.state == LiveState.error) return;

    await WakelockService.enable();
    await captureNotifier.start(deviceId: deviceId);

    // Read inference settings.
    final windowDuration = ref.read(windowDurationProvider);
    final inferenceRate = ref.read(inferenceRateProvider);
    final confidenceThreshold = ref.read(confidenceThresholdProvider);
    final filterMode = ref.read(speciesFilterModeProvider);
    final recordingModeStr = ref.read(recordingModeProvider);
    final recordingMode = recordingModeFromString(recordingModeStr);
    final recordingFormat = ref.read(recordingFormatProvider);
    final geoThreshold = ref.read(geoThresholdProvider);
    final geoScores = await ref.read(geoScoresProvider.future);
    final geoSpeciesNames = await ref.read(geoModelSpeciesNamesProvider.future);

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
    );

    _started = true;
    _onControllerStateChanged();

    // Start the countdown.
    _remaining = Duration(minutes: widget.durationMinutes);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(seconds: 1);
      });
      if (_remaining <= Duration.zero) {
        _countdownTimer?.cancel();
        _onCountdownComplete();
      }
    });
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pointCountStopEarlyTitle),
        content: Text(l10n.pointCountStopEarlyMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.pointCountStopEarly),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _finalizeAndReview();
  }

  Future<void> _finalizeAndReview() async {
    if (_finalizing) return;
    _finalizing = true;
    _countdownTimer?.cancel();

    final controller = ref.read(liveControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);

    await WakelockService.disable();
    await captureNotifier.stop();

    final session = await controller.finalizeSession();
    _onControllerStateChanged();

    if (session != null && mounted) {
      // Mark as point count.
      // The session type is on the LiveSession constructor but it's final,
      // so we need to set it via a different approach. Let's check if we can
      // pass it. Looking at LiveController.startSession — it creates the
      // session internally. We need to set the type after finalization.
      _setSessionType(session);

      final repo = ref.read(sessionRepositoryProvider);
      session.sessionNumber = await repo.nextSessionNumber(session.type);

      // Capture location from setup (GPS, manual, or map-picked).
      if (widget.latitude != null && widget.longitude != null) {
        session.latitude = widget.latitude;
        session.longitude = widget.longitude;
      } else {
        try {
          final location = await ref.read(currentLocationProvider.future);
          if (location != null) {
            session.latitude = location.latitude;
            session.longitude = location.longitude;
          }
        } catch (_) {
          // Location unavailable.
        }
      }

      await repo.save(session);
      ref.invalidate(sessionListProvider);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SessionReviewScreen(session: session),
          ),
        );
      }
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Set session type to pointCount. The LiveSession.type is final, so we
  /// need to work around that by using a helper that accesses the internal
  /// JSON serialization path. For now, we'll need to make the type field
  /// settable. See the modification to live_session.dart.
  void _setSessionType(LiveSession session) {
    session.type = SessionType.pointCount;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Point counts don't pause — keep running in background silently.
    // The countdown continues regardless.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
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
    final detections = ref.watch(sessionDetectionsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (isActive) {
          await _confirmStopEarly();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Status bar with countdown ─────────────────────
              _CountdownStatusBar(
                remaining: _remaining,
                totalDuration: Duration(minutes: widget.durationMinutes),
                liveState: liveState,
                onStop: _confirmStopEarly,
              ),

              // ── Progress bar ──────────────────────────────────
              _CountdownProgressBar(
                remaining: _remaining,
                totalDuration: Duration(minutes: widget.durationMinutes),
              ),

              // ── Spectrogram ───────────────────────────────────
              Expanded(
                flex: 2,
                child: Container(
                  color: theme.colorScheme.surfaceContainerLowest,
                  child: _PointCountSpectrogram(isCapturing: isCapturing),
                ),
              ),

              // ── Session info ──────────────────────────────────
              _PointCountInfoBar(
                detections: detections,
                controller: ref.read(liveControllerProvider),
                visible: isActive,
              ),

              // ── Detection list ────────────────────────────────
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: DetectionList(
                      detections: detections,
                      isActive: isActive,
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
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
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
  final VoidCallback onStop;

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
            icon: const Icon(Icons.stop_rounded, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: isActive ? onStop : () => Navigator.of(context).pop(),
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
                          'Loading model…',
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
                          Icons.timer_rounded,
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

          // Settings gear.
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
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
    required this.detections,
    required this.controller,
    required this.visible,
  });

  final List<DetectionRecord> detections;
  final LiveController controller;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
    if (detections.isNotEmpty) parts.add('${detections.length} now');
    parts.add('$totalUnique spp');
    parts.add('$totalDetections det');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
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

    final hopSize = fftSize ~/ 2;
    const sampleRate = 32000;
    final maxColumns = (durationSec * sampleRate / hopSize).round();

    return SpectrogramWidget(
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
    );
  }
}
