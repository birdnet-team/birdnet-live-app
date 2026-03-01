import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/settings_providers.dart';
import '../audio/audio_capture_service.dart';
import '../audio/audio_providers.dart';

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
// Maximises screen real estate for the spectrogram and detection list.
//
// Layout (top → bottom):
//   1. Compact status bar: back arrow · status text · settings gear
//   2. Spectrogram       (flex: 2)
//   3. Session info bar  (conditional, ~24 px)
//   4. Detection list    (flex: 3)
//   5. FAB mic/stop button (bottom-centre, 56×56)
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
      // ── Pause session (stop capture + inference, keep session) ──
      await controller.pauseSession();
      await captureNotifier.stop();
      _onControllerStateChanged();
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

      // Start audio capture.
      await captureNotifier.start(deviceId: deviceId);

      // Read settings.
      final windowDuration = ref.read(windowDurationProvider);
      final inferenceRate = ref.read(inferenceRateProvider);
      final confidenceThreshold = ref.read(confidenceThresholdProvider);
      final filterMode = ref.read(speciesFilterModeProvider);
      final recordingModeStr = ref.read(recordingModeProvider);
      final recordingMode = recordingModeFromString(recordingModeStr);

      // Start inference session.
      await controller.startSession(
        windowDuration: windowDuration,
        inferenceRate: inferenceRate,
        confidenceThreshold: confidenceThreshold,
        speciesFilterMode: filterMode,
        recordingMode: recordingMode,
      );

      _isStarting = false;
      _onControllerStateChanged();
    }
  }

  /// Finalise and save the session when leaving the live screen.
  Future<void> _finalizeAndSave() async {
    final controller = ref.read(liveControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);

    // Stop audio capture if still running.
    await captureNotifier.stop();

    // Finalise the session (works from both active and paused states).
    final session = await controller.finalizeSession();
    _onControllerStateChanged();

    // Persist completed session.
    if (session != null) {
      final repo = ref.read(sessionRepositoryProvider);
      await repo.save(session);
      ref.invalidate(sessionListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final liveState = ref.watch(liveStateProvider);
    final captureState = ref.watch(captureStateProvider);
    final isCapturing = captureState == CaptureState.capturing;
    final isActive = liveState == LiveState.active;
    final isPaused = liveState == LiveState.paused;
    final detections = ref.watch(sessionDetectionsProvider);

    // Edge-to-edge overlay styling.
    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _finalizeAndSave();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        // ── Bottom-centre capture button ───────────────────────
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

              // ── Model Status Banner ─────────────────────────────
              if (liveState == LiveState.loading ||
                  liveState == LiveState.error)
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
                        if (detection.audioClipPath != null) {
                          ref
                              .read(liveControllerProvider)
                              .playClip(detection.audioClipPath!);
                        }
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
/// Height: ~48 dp.  No AppBar — just a thin Row to maximise vertical space.
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
                  builder: (_) => const SettingsScreen(),
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

/// Circular microphone / stop button — bottom-centre FAB (56×56).
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

/// Banner showing model loading or error state.
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
    final isError = liveState == LiveState.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (!isError) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (isError)
            Icon(
              Icons.error_outline,
              size: 16,
              color: theme.colorScheme.onErrorContainer,
            ),
          if (isError) const SizedBox(width: 8),
          Expanded(
            child: Text(
              isError
                  ? 'Model loading failed. Check assets.'
                  : 'Loading model…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isError
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          if (isError)
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
class _SessionInfoBar extends StatelessWidget {
  const _SessionInfoBar({
    required this.liveCount,
    required this.controller,
  });

  /// Number of species currently shown in the live view.
  final int liveCount;

  /// Controller for reading cumulative session stats.
  final LiveController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Unique species across the entire session (cumulative).
    final totalUnique = controller.sessionDetections
        .map((d) => d.scientificName)
        .toSet()
        .length;

    final label = liveCount > 0
        ? '$liveCount detected now · $totalUnique species this session'
        : '$totalUnique species this session';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          Icon(
            Icons.pets,
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
    );
  }
}
