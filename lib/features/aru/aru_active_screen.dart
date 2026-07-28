import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:birdnet_live/shared/widgets/app_help_bottom_sheet.dart';
import 'package:birdnet_live/shared/widgets/confirm_destructive.dart';
import 'package:birdnet_live/shared/widgets/stat_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:birdnet_live/core/theme/app_semantic_colors.dart';
import 'package:birdnet_live/core/theme/score_colors.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/locale_time_format.dart';
import '../audio/audio_capture_service.dart';
import '../audio/audio_providers.dart';
import '../audio/ring_buffer.dart';
import '../explore/explore_providers.dart';
import '../history/session_library_screen.dart';
import '../history/session_review_screen.dart';
import '../inference/advanced_pooling_params.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../live/widgets/detection_list_widget.dart';
import '../settings/settings_screen.dart';
import '../spectrogram/spectrogram_widget.dart';
import 'aru_controller.dart';
import 'aru_providers.dart';
import 'aru_runner.dart';
import 'aru_schedule.dart';
import 'aru_storage_estimator.dart';

class AruActiveScreen extends ConsumerStatefulWidget {
  const AruActiveScreen({this.confirmStopOnOpen = false, super.key});

  final bool confirmStopOnOpen;

  @override
  ConsumerState<AruActiveScreen> createState() => _AruActiveScreenState();
}

class _AruActiveScreenState extends ConsumerState<AruActiveScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AruRunner _runner;
  bool _stopping = false;
  bool _stopDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _runner = ref.read(aruRunnerProvider);
    _runner.onFinished = _onRunnerFinished;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Attach the long-lived runner so the deployment loop keeps advancing
      // even while this screen is backgrounded or covered by another route.
      _runner.attach(
        AppLocalizations.of(context)!,
        use24Hour: MediaQuery.of(context).alwaysUse24HourFormat,
      );
      if (widget.confirmStopOnOpen) {
        unawaited(_confirmStop());
      }
    });
  }

  @override
  void dispose() {
    if (_runner.onFinished == _onRunnerFinished) {
      _runner.onFinished = null;
    }
    _tabController.dispose();
    super.dispose();
  }

  void _onRunnerFinished(AruFinishResult result) {
    if (!mounted) return;
    setState(() => _stopping = false);
    if (result.reason == SessionStopReason.lowBattery &&
        result.batteryLevel != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.sessionAutoStopLowBattery(result.batteryLevel!),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    _openReview(result.reviewSession);
  }

  Future<void> _confirmStop() async {
    if (_stopDialogShowing || _stopping) return;
    _stopDialogShowing = true;
    final l10n = AppLocalizations.of(context)!;
    try {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.aruStopConfirmTitle,
        body: l10n.aruStopConfirmBody,
        confirmLabel: l10n.aruStopDeployment,
        cancelLabel: l10n.cancel,
      );
      if (confirmed && mounted) {
        await _stopDeployment();
      }
    } finally {
      _stopDialogShowing = false;
    }
  }

  Future<void> _stopDeployment() async {
    if (_stopping || !mounted) return;
    setState(() => _stopping = true);
    // The runner finalizes the deployment and invokes [_onRunnerFinished],
    // which clears the spinner and opens review.
    await _runner.requestStop();
  }

  void _openReview(LiveSession? session) {
    if (!mounted) return;
    if (session == null) {
      Navigator.of(context).pop();
      return;
    }
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

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => AppHelpBottomSheet(
            title: l10n.helpAruTitle,
            sections: [
              AppHelpSection(
                icon: AppIcons.scheduleRounded,
                body: l10n.helpAruBody,
              ),
              AppHelpSection(
                icon: AppIcons.infoOutline,
                body: l10n.aruHelpStatusIcons,
              ),
              AppHelpSection(
                icon: AppIcons.graphicEqRounded,
                body: l10n.aruSetupHelpBody,
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(aruStateProvider);
    final session = ref.watch(aruSessionProvider);
    // The active session is mutated in place as detections arrive, so watch the
    // revision counter to rebuild when its contents change without a new
    // instance (otherwise detections only appear after a tab switch).
    ref.watch(aruSessionRevisionProvider);
    final ringBuffer = ref.watch(ringBufferProvider);
    final captureState = ref.watch(captureStateProvider);
    final isRecording = state == AruControllerState.recording;
    final spectrogramActive =
        isRecording &&
        captureState == CaptureState.capturing &&
        _tabController.index == 1;

    // Keep the background runner's notification text localized to the
    // current locale / clock format.
    _runner.refreshLocalization(
      l10n,
      use24Hour: MediaQuery.of(context).alwaysUse24HourFormat,
    );

    ref.listen<int>(confidenceThresholdProvider, (_, next) {
      ref.read(liveControllerProvider).setConfidenceThreshold(next);
    });
    ref.listen<int?>(scorePoolingWindowsProvider, (_, next) {
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
    ref.listen<double>(audioGainProvider, (_, next) {
      ref.read(audioCaptureServiceProvider).setGain(next);
    });
    ref.listen<double>(highPassFilterProvider, (_, next) {
      ref.read(audioCaptureServiceProvider).setHighPassCutoff(next);
    });

    // While a deployment is active the user cannot navigate elsewhere WITHIN
    // the app (the deployment owns the foreground). Leaving the app entirely
    // (e.g. the device home button) is an OS action this guard does not block,
    // and the deployment keeps running in the background via [AruRunner] and
    // the foreground service.
    return PopScope(
      canPop: session == null || state == AruControllerState.completed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmStop();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child:
              session == null
                  ? Center(child: Text(l10n.aruNoActiveDeployment))
                  : _buildBody(
                    context,
                    theme: theme,
                    l10n: l10n,
                    state: state,
                    session: session,
                    ringBuffer: ringBuffer,
                    spectrogramActive: spectrogramActive,
                  ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required ThemeData theme,
    required AppLocalizations l10n,
    required AruControllerState state,
    required LiveSession session,
    required RingBuffer ringBuffer,
    required bool spectrogramActive,
  }) {
    final isRecording = state == AruControllerState.recording;
    final visibleDetections = _visibleDetections(session, state);
    final showDetectionPane =
        _tabController.index == 0 || _tabController.index == 1;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final statusBar = _AruStatusBar(
      state: state,
      session: session,
      onStop: _confirmStop,
      onHelp: _showHelp,
    );
    final tabBar = TabBar(
      controller: _tabController,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      indicatorWeight: 2,
      labelStyle: theme.textTheme.labelSmall,
      tabs: [
        Tab(
          icon: const Icon(AppIcons.infoOutline, size: 18),
          text: l10n.aruTabStatus,
        ),
        Tab(
          icon: const Icon(AppIcons.graphicEq, size: 18),
          text: l10n.aruTabSpectrogram,
        ),
        Tab(
          icon: const Icon(AppIcons.scheduleRounded, size: 18),
          text: l10n.aruTabSchedule,
        ),
        Tab(
          icon: const Icon(AppIcons.summaryChart, size: 18),
          text: l10n.aruTabSummary,
        ),
      ],
    );
    final tabContent = TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatusPanel(session: session, state: state),
        _SpectrogramPanel(isActive: spectrogramActive, state: state),
        _SchedulePanel(session: session),
        _SummaryPanel(session: session),
      ],
    );
    final statsBar = _AruStatsBar(session: session, state: state);
    final detectionPane = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: DetectionList(
          detections: visibleDetections,
          isActive: isRecording,
          emptyIcon: isRecording ? null : AppIcons.scheduleRounded,
          emptyTitle: isRecording ? null : l10n.aruWaitingDetectionsTitle,
          emptySubtitle: isRecording ? null : l10n.aruWaitingDetectionsBody,
          emptyAlignment: const Alignment(0, -0.35),
        ),
      ),
    );

    if (isLandscape && showDetectionPane) {
      return Column(
        children: [
          statusBar,
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [tabBar, Expanded(child: tabContent), statsBar],
                  ),
                ),
                Expanded(child: detectionPane),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        statusBar,
        tabBar,
        Expanded(flex: showDetectionPane ? 2 : 1, child: tabContent),
        if (showDetectionPane) ...[
          statsBar,
          Expanded(flex: 3, child: detectionPane),
        ],
      ],
    );
  }
}

class _AruStatusBar extends StatefulWidget {
  const _AruStatusBar({
    required this.state,
    required this.session,
    required this.onStop,
    required this.onHelp,
  });

  final AruControllerState state;
  final LiveSession session;
  final VoidCallback onStop;
  final VoidCallback onHelp;

  @override
  State<_AruStatusBar> createState() => _AruStatusBarState();
}

class _AruStatusBarState extends State<_AruStatusBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _AruStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isActive && _timer == null) {
      _startTimer();
    } else if (!_isActive && _timer != null) {
      _stopTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  bool get _isActive => widget.state != AruControllerState.completed;

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final snapshot = _scheduleSnapshot(widget.session);
    final current = snapshot?.currentWindow;
    final next = snapshot?.nextWindow;
    final now = DateTime.now();
    final label = switch (widget.state) {
      AruControllerState.recording => l10n.aruStatusRecording,
      AruControllerState.completed => l10n.aruActiveCompleted,
      _ => l10n.aruStatusWaiting,
    };
    final detail =
        current != null
            ? _formatDuration(current.end.difference(now))
            : next != null
            ? _formatDuration(next.start.difference(now))
            : _formatDuration(widget.session.duration);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isActive ? AppIcons.stopRounded : AppIcons.arrowBackRounded,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed:
                _isActive ? widget.onStop : () => Navigator.of(context).pop(),
            tooltip: _isActive ? l10n.aruStopDeployment : l10n.tooltipBack,
            color: _isActive ? theme.colorScheme.error : null,
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.state == AruControllerState.recording
                        ? AppIcons.fiberManualRecordRounded
                        : AppIcons.scheduleRounded,
                    size: 18,
                    color:
                        widget.state == AruControllerState.recording
                            ? AppSemanticColors.of(context).sessionAru
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$label  $detail',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color:
                            widget.state == AruControllerState.recording
                                ? AppSemanticColors.of(context).sessionAru
                                : theme.colorScheme.onSurfaceVariant,
                      ),
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
            onPressed: widget.onHelp,
            tooltip: l10n.helpAruTitle,
          ),
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
                        settingsContext: SettingsContext.aru,
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

enum _AudioQuality { bad, marginal, good }

class _AruStatsBar extends ConsumerStatefulWidget {
  const _AruStatsBar({required this.session, required this.state});

  final LiveSession session;
  final AruControllerState state;

  @override
  ConsumerState<_AruStatsBar> createState() => _AruStatsBarState();
}

class _AruStatsBarState extends ConsumerState<_AruStatsBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_isRecording) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _AruStatsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isRecording && _timer == null) {
      _startTimer();
    } else if (!_isRecording && _timer != null) {
      _stopTimer();
    }
  }

  bool get _isRecording => widget.state == AruControllerState.recording;

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final ringBuffer = ref.watch(ringBufferProvider);
    final audioLevel = _isRecording ? ringBuffer.rmsLevel() : 0.0;
    final peakLevel = _isRecording ? ringBuffer.peakLevel() : 0.0;

    final semanticColors = AppSemanticColors.of(context);
    final _AudioQuality quality;
    if (audioLevel < 0.0005) {
      quality = _AudioQuality.bad;
    } else if (peakLevel > 0.95) {
      quality = _AudioQuality.bad;
    } else if (audioLevel > 0.15) {
      quality = _AudioQuality.bad;
    } else if (audioLevel < 0.001 || audioLevel > 0.08) {
      quality = _AudioQuality.marginal;
    } else {
      quality = _AudioQuality.good;
    }

    final levelColor = switch (quality) {
      _AudioQuality.bad => theme.colorScheme.error,
      _AudioQuality.marginal => theme.colorScheme.tertiary,
      _AudioQuality.good => semanticColors.success,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AudioLevelChip(
            isActive: _isRecording,
            level: audioLevel,
            quality: quality,
            color: levelColor,
            style: style,
          ),
          StatChip(
            icon: AppIcons.checkCircleRounded,
            value: '${_completedCycleCount(widget.session)}',
            style: style,
          ),
          StatChip(
            icon: AppIcons.detections,
            value: '${widget.session.detections.length}',
            style: style,
          ),
          StatChip(
            icon: AppIcons.species,
            value: '${widget.session.uniqueSpeciesCount}',
            style: style,
          ),
        ],
      ),
    );
  }
}

class _AudioLevelChip extends StatelessWidget {
  const _AudioLevelChip({
    required this.isActive,
    required this.level,
    required this.quality,
    required this.color,
    this.style,
  });

  final bool isActive;
  final double level;
  final _AudioQuality quality;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filledBars =
        isActive
            ? switch (quality) {
              _AudioQuality.good => 3,
              _AudioQuality.marginal => 2,
              _AudioQuality.bad => 1,
            }
            : 0;
    final muted = theme.colorScheme.onSurface.withAlpha(40);
    final activeColor = isActive ? color : muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(AppIcons.mic, size: 16, color: activeColor),
        const SizedBox(width: 3),
        for (int i = 0; i < 3; i++)
          Container(
            width: 4,
            height: 6.0 + i * 4, // 6, 10, 14
            margin: const EdgeInsets.only(right: 1.5),
            decoration: BoxDecoration(
              color: i < filledBars ? color : muted,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.session, required this.state});

  final LiveSession session;
  final AruControllerState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = _scheduleSnapshot(session);
    final now = DateTime.now();
    final metadata = session.aruMetadata;
    final nextWindow = snapshot?.nextWindow;
    final elapsed = (session.endTime ?? now).difference(session.startTime);
    final completed = _completedCycleCount(session);
    final totalCycles = _estimatedCycleCount(metadata);
    final progress =
        totalCycles == null || totalCycles == 0
            ? null
            : (completed / totalCycles).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      children: [
        _ScheduleFocusCard(
          state: state,
          session: session,
          currentWindow: snapshot?.currentWindow,
          nextWindow: snapshot?.nextWindow,
        ),
        const SizedBox(height: 8),
        _StatusProgressBlock(
          label: l10n.aruCycleProgress,
          value:
              totalCycles == null
                  ? '$completed / ${l10n.aruScheduleNoLimit}'
                  : '$completed / $totalCycles',
          progress: progress,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 4 : 2;
            final spacing = 8.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _StatusMetricTile(
                  width: width,
                  icon: AppIcons.scheduleRounded,
                  label: l10n.aruNextIn,
                  value:
                      nextWindow == null
                          ? l10n.aruActiveCompleted
                          : _formatDuration(nextWindow.start.difference(now)),
                ),
                _StatusMetricTile(
                  width: width,
                  icon: AppIcons.timerRounded,
                  label: l10n.aruElapsedTime,
                  value: _formatDuration(elapsed),
                ),
                _StatusMetricTile(
                  width: width,
                  icon: AppIcons.detections,
                  label: l10n.surveyTabSummaryDetections,
                  value: '${session.detections.length}',
                ),
                _StatusMetricTile(
                  width: width,
                  icon: AppIcons.species,
                  label: l10n.surveyTabSummarySpecies,
                  value: '${session.uniqueSpeciesCount}',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatusProgressBlock extends StatelessWidget {
  const _StatusProgressBlock({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

class _StatusMetricTile extends StatelessWidget {
  const _StatusMetricTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({required this.session});

  final LiveSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final alwaysUse24HourFormat = MediaQuery.of(context).alwaysUse24HourFormat;
    final metadata = session.aruMetadata;
    final schedule =
        metadata == null
            ? null
            : AruScheduleCalculator(metadata.toScheduleConfig());
    final now = DateTime.now();
    final windows = schedule?.nextWindows(now, count: 10) ?? const [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Text(l10n.aruNextCyclesPreview, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (windows.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(AppIcons.checkCircleRounded),
              title: Text(l10n.aruActiveCompleted),
            ),
          )
        else
          for (final window in windows)
            ListTile(
              leading: Icon(
                window.contains(now)
                    ? AppIcons.fiberManualRecordRounded
                    : AppIcons.scheduleRounded,
                color:
                    window.contains(now)
                        ? AppSemanticColors.of(context).sessionAru
                        : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                _isTestWindow(session, window)
                    ? l10n.aruTestRun
                    : formatLocaleDateTime(
                      window.start,
                      l10n.localeName,
                      alwaysUse24HourFormat: alwaysUse24HourFormat,
                    ),
              ),
              subtitle: Text(
                _windowLabel(
                  l10n.localeName,
                  window,
                  alwaysUse24HourFormat: alwaysUse24HourFormat,
                ),
              ),
            ),
      ],
    );
  }
}

class _ScheduleFocusCard extends StatelessWidget {
  const _ScheduleFocusCard({
    required this.state,
    required this.session,
    required this.currentWindow,
    required this.nextWindow,
  });

  final AruControllerState state;
  final LiveSession session;
  final AruCycleWindow? currentWindow;
  final AruCycleWindow? nextWindow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final alwaysUse24HourFormat = MediaQuery.of(context).alwaysUse24HourFormat;
    final isRecording = state == AruControllerState.recording;
    final currentIsTest =
        currentWindow != null && _isTestWindow(session, currentWindow!);
    final nextIsTest =
        nextWindow != null && _isTestWindow(session, nextWindow!);
    final icon =
        isRecording
            ? AppIcons.fiberManualRecordRounded
            : AppIcons.scheduleRounded;
    final color =
        isRecording
            ? AppSemanticColors.of(context).sessionAru
            : theme.colorScheme.onSurfaceVariant;
    final title =
        currentIsTest || nextIsTest
            ? l10n.aruTestRun
            : isRecording
            ? l10n.aruActiveRecording
            : l10n.aruActiveWaiting;
    final body =
        currentWindow != null
            ? '${_windowLabel(l10n.localeName, currentWindow!, alwaysUse24HourFormat: alwaysUse24HourFormat)} - ${l10n.fileAnalysisEtaRemaining(_formatDuration(currentWindow!.end.difference(DateTime.now())))}'
            : nextWindow != null
            ? '${formatLocaleDateTime(nextWindow!.start, l10n.localeName, alwaysUse24HourFormat: alwaysUse24HourFormat)} - ${l10n.fileAnalysisEtaRemaining(_formatDuration(nextWindow!.start.difference(DateTime.now())))}'
            : l10n.aruActiveCompleted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpectrogramPanel extends ConsumerWidget {
  const _SpectrogramPanel({required this.isActive, required this.state});

  final bool isActive;
  final AruControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ringBuffer = ref.watch(ringBufferProvider);

    if (isActive) {
      return _AruSpectrogram(ringBuffer: ringBuffer, isActive: true);
    }

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state == AruControllerState.recording
                ? l10n.surveyStarting
                : state == AruControllerState.completed
                ? l10n.aruActiveCompleted
                : l10n.aruActiveWaiting,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _AruSpectrogram extends ConsumerWidget {
  const _AruSpectrogram({required this.ringBuffer, required this.isActive});

  final RingBuffer ringBuffer;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      isActive: isActive,
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

class _SummaryPanel extends ConsumerStatefulWidget {
  const _SummaryPanel({required this.session});

  final LiveSession session;

  @override
  ConsumerState<_SummaryPanel> createState() => _SummaryPanelState();
}

class _SummaryPanelState extends ConsumerState<_SummaryPanel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final session = widget.session;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final showSciNames = ref.watch(showSciNamesProvider);
    final elapsed = (session.endTime ?? DateTime.now()).difference(
      session.startTime,
    );
    final species = _speciesSummary(session.detections);
    final completed = _completedCycleCount(session);
    final rate =
        elapsed.inSeconds > 0
            ? (session.detections.length / elapsed.inMinutes.clamp(1, 999999))
                .toStringAsFixed(1)
            : '0';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 16,
          runSpacing: 8,
          children: [
            _SummaryChip(
              label: l10n.surveyTabSummarySpecies,
              value: '${species.length}',
              theme: theme,
            ),
            _SummaryChip(
              label: l10n.surveyTabSummaryDetections,
              value: '${session.detections.length}',
              theme: theme,
            ),
            _SummaryChip(
              label: l10n.aruCyclesShort,
              value: '$completed',
              theme: theme,
            ),
            _SummaryChip(
              label: l10n.surveyTabSummaryRate,
              value: '$rate/min',
              theme: theme,
            ),
            _SummaryChip(
              label: l10n.aruSummaryElapsed,
              value: _formatDuration(elapsed),
              theme: theme,
            ),
            _SummaryChip(
              label: l10n.aruSummaryAudio,
              value: _formatDuration(session.duration),
              theme: theme,
            ),
          ],
        ),
        if (species.isNotEmpty) const SizedBox(height: 12),
        for (final (i, item) in species.take(24).indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${i + 1}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${item.count}x',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        taxonomy
                                ?.lookup(item.scientificName)
                                ?.commonNameForLocale(speciesLocale) ??
                            item.commonName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (showSciNames)
                        Text(
                          taxonomy?.displayScientificName(
                                item.scientificName,
                              ) ??
                              item.scientificName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withAlpha(140),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${(item.bestConfidence * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: (theme.extension<ScoreColors>() ?? ScoreColors.light)
                        .forScore(item.bestConfidence),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AruSpeciesSummary {
  _AruSpeciesSummary({
    required this.scientificName,
    required this.commonName,
    required this.count,
    required this.bestConfidence,
  });

  final String scientificName;
  final String commonName;
  int count;
  double bestConfidence;
}

List<_AruSpeciesSummary> _speciesSummary(List<DetectionRecord> detections) {
  final bySpecies = <String, _AruSpeciesSummary>{};
  for (final detection in detections) {
    final existing = bySpecies[detection.scientificName];
    if (existing == null) {
      bySpecies[detection.scientificName] = _AruSpeciesSummary(
        scientificName: detection.scientificName,
        commonName: detection.commonName,
        count: 1,
        bestConfidence: detection.confidence,
      );
    } else {
      existing.count++;
      if (detection.confidence > existing.bestConfidence) {
        existing.bestConfidence = detection.confidence;
      }
    }
  }
  final list = bySpecies.values.toList();
  list.sort((a, b) {
    final cmp = b.count.compareTo(a.count);
    if (cmp != 0) return cmp;
    return b.bestConfidence.compareTo(a.bestConfidence);
  });
  return list;
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}

AruScheduleSnapshot? _scheduleSnapshot(LiveSession session) {
  final metadata = session.aruMetadata;
  if (metadata == null) return null;
  return AruScheduleCalculator(
    metadata.toScheduleConfig(),
  ).snapshotAt(DateTime.now());
}

List<DetectionRecord> _visibleDetections(
  LiveSession session,
  AruControllerState state,
) {
  final current = _scheduleSnapshot(session)?.currentWindow;
  if (state == AruControllerState.recording && current != null) {
    return session.detections
        .where(
          (detection) =>
              !detection.timestamp.isBefore(current.start) &&
              detection.timestamp.isBefore(current.end),
        )
        .toList()
        .reversed
        .toList();
  }
  return session.detections.reversed.take(20).toList();
}

int _completedCycleCount(LiveSession session) {
  return (session.aruMetadata?.cycles ?? const <AruCycleMetadata>[])
      .where(
        (cycle) =>
            cycle.status == AruCycleStatus.completed ||
            cycle.status == AruCycleStatus.stopped ||
            cycle.status == AruCycleStatus.partial,
      )
      .length;
}

int? _estimatedCycleCount(AruDeploymentMetadata? metadata) {
  if (metadata == null) return null;
  return const AruStorageEstimator().estimateTotalCycles(
    metadata.toScheduleConfig(),
  );
}

bool _isTestWindow(LiveSession session, AruCycleWindow window) {
  return session.aruMetadata?.testCycleEnabled == true && window.index == 0;
}

String _windowLabel(
  String localeName,
  AruCycleWindow window, {
  required bool alwaysUse24HourFormat,
}) {
  return '${formatLocaleTime(window.start, localeName, alwaysUse24HourFormat: alwaysUse24HourFormat)} - ${formatLocaleTime(window.end, localeName, alwaysUse24HourFormat: alwaysUse24HourFormat)}';
}

String _formatDuration(Duration duration) {
  if (duration.isNegative) return '0 s';
  if (duration.inHours >= 1) {
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final minutePart = minutes > 0 ? ' $minutes min' : '';
    final secondPart = ' $seconds s';
    return '${duration.inHours} h$minutePart$secondPart';
  }
  if (duration.inMinutes >= 1) {
    final seconds = duration.inSeconds % 60;
    return '${duration.inMinutes} min $seconds s';
  }
  return '${duration.inSeconds} s';
}
