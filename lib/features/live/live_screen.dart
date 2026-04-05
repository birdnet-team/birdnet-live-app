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
import 'live_controller.dart';
import 'live_providers.dart';
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

class _LiveScreenState extends ConsumerState<LiveScreen> {
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
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

      // Fetch geo-model scores (if available) for species filtering.
      // Also fetch the full geo-model species names for model intersection.
      final geoScores = await ref.read(geoScoresProvider.future);
      final geoSpeciesNames =
          await ref.read(geoModelSpeciesNamesProvider.future);

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
      );

      _isStarting = false;
      _onControllerStateChanged();
    }
  }

  /// Show confirmation dialog, then finalize and navigate to review.
  Future<void> _confirmStop() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sessionStopTitle),
        content: Text(l10n.sessionStopMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.sessionStopConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _finalizeAndReview();
  }

  @override
  void dispose() {
    // Ensure screen lock is released when leaving the live screen.
    WakelockService.disable();
    super.dispose();
  }

  /// Finalize and save the session when leaving the live screen.
  Future<void> _finalizeAndReview() async {
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
      // Persist completed session.
      final repo = ref.read(sessionRepositoryProvider);
      await repo.save(session);
      ref.invalidate(sessionListProvider);

      // Navigate to session review (replace live screen on the stack).
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final liveState = ref.watch(liveStateProvider);
    final captureState = ref.watch(captureStateProvider);
    final isCapturing = captureState == CaptureState.capturing;
    final isActive = liveState == LiveState.active;
    final isPaused = liveState == LiveState.paused;
    final detections = ref.watch(sessionDetectionsProvider);

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
          child: Column(
            children: [
              // ── Compact Status Bar ──────────────────────────────
              _CompactStatusBar(
                liveState: liveState,
                ref: ref,
              ),

              // ── Error Banner ────────────────────────────────────
              if (liveState == LiveState.error)
                _StatusBanner(liveState: liveState, ref: ref),

              // ── Spectrogram ─────────────────────────────────────
              Expanded(
                flex: 2,
                child: Container(
                  color: theme.colorScheme.surfaceContainerLowest,
                  child: _LiveSpectrogram(isCapturing: isCapturing),
                ),
              ),

              // ── Session Info ────────────────────────────────────
              if (isActive || isPaused)
                _SessionInfoBar(
                  liveCount: detections.length,
                  controller: ref.read(liveControllerProvider),
                ),

              // ── Detection List ──────────────────────────────────
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: DetectionList(
                      detections: detections,
                      isActive: isActive || isPaused,
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

              // Bottom padding so the FAB doesn't overlap the last item.
              const SizedBox(height: 72),
            ],
          ),
        ),
      ),
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
  const _CompactStatusBar({
    required this.liveState,
    required this.ref,
  });

  final LiveState liveState;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = liveState == LiveState.active;
    final isLoading = liveState == LiveState.loading;

    String statusText;
    Color statusColor;

    if (isActive) {
      statusText = 'Identifying species…';
      statusColor = theme.colorScheme.primary;
    } else if (liveState == LiveState.paused) {
      statusText = 'Paused';
      statusColor = theme.colorScheme.onSurface.withAlpha(180);
    } else if (isLoading) {
      statusText = 'Loading model…';
      statusColor = theme.colorScheme.onSurface.withAlpha(153);
    } else if (liveState == LiveState.error) {
      statusText = 'Error';
      statusColor = theme.colorScheme.error;
    } else if (liveState == LiveState.ready) {
      statusText = 'Ready';
      statusColor = theme.colorScheme.onSurface;
    } else {
      statusText = 'Initialising…';
      statusColor = theme.colorScheme.onSurface.withAlpha(153);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 2),
      child: Row(
        children: [
          // Back button.
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
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
                    settingsContext: SettingsContext.live,
                  ),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
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

    // Active → red stop button, paused → primary play button, idle → primary mic.
    final Color bgColor;
    final IconData icon;
    final Color iconColor;

    if (isActive) {
      bgColor = theme.colorScheme.error;
      icon = Icons.stop_rounded;
      iconColor = theme.colorScheme.onError;
    } else if (isPaused) {
      bgColor = theme.colorScheme.primary;
      icon = Icons.play_arrow_rounded;
      iconColor = theme.colorScheme.onPrimary;
    } else {
      bgColor = theme.colorScheme.primary;
      icon = Icons.mic;
      iconColor = theme.colorScheme.onPrimary;
    }

    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        shape: const CircleBorder(),
        color: bgColor,
        elevation: 4,
        shadowColor: bgColor.withAlpha(120),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isLoading ? null : onPressed,
          child: isLoading
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Icon(icon, color: iconColor, size: 28),
        ),
      ),
    );
  }
}

/// Banner showing model error state with retry button.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.liveState,
    required this.ref,
  });

  final LiveState liveState;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Model loading failed. Check assets.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(liveControllerProvider).loadModel();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Session info bar showing detection count and duration.
class _SessionInfoBar extends ConsumerWidget {
  const _SessionInfoBar({
    required this.liveCount,
    required this.controller,
  });

  /// Number of species currently shown in the live view.
  final int liveCount;

  /// Controller for reading cumulative session stats.
  final LiveController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Calculate total detections
    final totalDetections = controller.sessionDetections.length;

    // Unique species across the entire session (cumulative).
    final totalUnique = controller.sessionDetections
        .map((d) => d.scientificName)
        .toSet()
        .length;

    // Estimate file size and duration
    int durationSec = 0;
    if (controller.session != null) {
      durationSec = controller.session!.duration.inSeconds;
    }

    final recordingFormat = ref.read(recordingFormatProvider);
    // Estimate: Wav is ~96 kB/s, FLAC is ~60 kB/s
    final bytesPerSec = recordingFormat == 'flac' ? 60000 : 96000;
    final estimatedBytes = durationSec * bytesPerSec;
    final mb = estimatedBytes / (1024 * 1024);

    final String durationStr = _formatDuration(durationSec);

    final List<String> parts = [];
    if (liveCount > 0) parts.add('$liveCount now');
    parts.add('$totalUnique spp');
    parts.add('$totalDetections det');
    if (durationSec > 0) {
      parts.add(durationStr);
      parts.add('${mb.toStringAsFixed(1)}MB');
    }

    final label = parts.join(' • ');

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
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final rh = m % 60;
      return '${h}h ${rh}m';
    }
    return '${m}:${s.toString().padLeft(2, '0')}';
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
