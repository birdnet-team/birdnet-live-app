// =============================================================================
// Inference window driver — the capture-driven inference loop, once
// =============================================================================
//
// Live Mode, Point Count, Survey, and the ARU cycles that run through
// LiveController are supposed to analyze identical audio given identical
// settings. That only holds if they run the *same* loop: the same rule for
// which samples a window covers, the same wakeup arithmetic, and the same
// handling of a capture buffer that was rewound or that overran. This class is
// that loop, so parity is a property of the code rather than of two files
// staying in sync by hand.
//
// The controllers keep everything that genuinely differs between modes —
// filtering, records, GPS, alerts, clips, teardown.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../audio/ring_buffer.dart';
import 'realtime_inference_scheduler.dart';

/// The rate one step below [inferenceRateHz].
///
/// Steps are [AppConstants.inferenceRateDownshiftStepHz] on the slider's
/// 0.1 Hz grid and never go below [AppConstants.minInferenceRateHz], so the
/// result is always a rate the user could have picked. At the floor the rate
/// is returned unchanged.
double loweredInferenceRate(double inferenceRateHz) {
  final tenths =
      ((inferenceRateHz - AppConstants.inferenceRateDownshiftStepHz) * 10)
          .round();
  final floorTenths = (AppConstants.minInferenceRateHz * 10).round();
  return (tenths < floorTenths ? floorTenths : tenths) / 10;
}

/// A scheduled window together with the audio it covers.
class InferenceWindowAudio {
  const InferenceWindowAudio({
    required this.samples,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.windowEndSample,
    required this.windowDurationSeconds,
  });

  /// The PCM the model should score.
  final Float32List samples;

  /// Wall-clock time of the window's first sample.
  final DateTime startTimestamp;

  /// Wall-clock time just past the window's last sample.
  final DateTime endTimestamp;

  /// The window's exclusive end on [RingBuffer.totalWritten]'s timeline.
  ///
  /// Detection clips are cut against this so they hold the audio that earned
  /// the score even when the write runs late.
  final int windowEndSample;

  final int windowDurationSeconds;
}

/// Drives one session's sample-anchored inference windows.
class InferenceWindowDriver {
  InferenceWindowDriver({required this.ringBuffer, required this.debugLabel});

  final RingBuffer ringBuffer;

  /// Prefix for this driver's debug output, e.g. `LiveController`.
  final String debugLabel;

  /// Capture is polled this often until the first samples of a session
  /// arrive, so the timeline can be calibrated against real audio.
  static const Duration _calibrationPollDelay = Duration(milliseconds: 25);

  /// Floor on any wakeup, so a backlog drains without starving the event loop.
  static const Duration _minimumDelay = Duration(milliseconds: 20);

  RealtimeInferenceScheduler? _scheduler;
  Timer? _timer;
  int _sampleBase = 0;
  int _ringBufferResetGeneration = 0;

  /// Windows in a row that came out at least a hop late, each later than the
  /// one before. See [_trackBacklog].
  int _lateTakes = 0;
  int _previousLateSamples = 0;

  /// Called after the driver lowered the rate on its own, with the new rate.
  ///
  /// See [_trackBacklog] for when that happens.
  void Function(double inferenceRateHz)? onInferenceRateLowered;

  bool get isRunning => _scheduler != null;

  int get windowDurationSeconds => _scheduler?.windowDurationSeconds ?? 0;

  /// The rate the schedule currently runs at, or 0 when stopped.
  ///
  /// Starts as the rate passed to [start] and drops whenever the driver
  /// lowers it.
  double get inferenceRateHz => _scheduler?.inferenceRateHz ?? 0;

  /// Begin (or restart) the schedule from the audio arriving now.
  ///
  /// By default the samples already in the shared buffer belong to whatever
  /// ran before this session, so the timeline starts at the current write
  /// position rather than draining that audio as a backlog. That is what a
  /// fresh Live session and a resume after a pause both want.
  ///
  /// [useBufferedAudio] is for a caller that started capture itself and has
  /// been filling the buffer while it got ready — an ARU cycle opens the mic,
  /// then loads the model, which on a cold start takes seconds. That audio is
  /// part of the cycle and is already on disk, so the schedule reaches back to
  /// cover one window of it and can analyze immediately instead of discarding
  /// it and waiting a further [windowDurationSeconds]. It reaches back one
  /// window and no further: the rest is left alone rather than replayed as a
  /// burst of catch-up inference at the start of every cycle.
  void start({
    required int sampleRate,
    required int windowDurationSeconds,
    required double inferenceRateHz,
    bool useBufferedAudio = false,
  }) {
    _timer?.cancel();
    _timer = null;

    final windowSamples = sampleRate * windowDurationSeconds;
    final buffered = useBufferedAudio
        ? (ringBuffer.available < windowSamples
              ? ringBuffer.available
              : windowSamples)
        : 0;
    _sampleBase = ringBuffer.totalWritten - buffered;
    _ringBufferResetGeneration = ringBuffer.resetGeneration;
    _resetBacklogTracking();

    _scheduler = RealtimeInferenceScheduler(
      sampleRate: sampleRate,
      windowDurationSeconds: windowDurationSeconds,
      inferenceRateHz: inferenceRateHz,
      timelineStart: DateTime.now(),
    );
  }

  /// Cancel the pending wakeup and forget the schedule.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _scheduler = null;
  }

  /// Cancel the pending wakeup but keep the schedule (used while pausing).
  void cancelPendingWakeup() {
    _timer?.cancel();
    _timer = null;
  }

  /// Schedule [runCycle] for the moment the next complete window exists.
  ///
  /// [isActive] is re-checked at fire time so a session torn down during the
  /// wait does not start another cycle. Callers re-arm from their cycle's
  /// completion; [isCurrent] tells the driver whether the caller is still
  /// driving this schedule, so a session that restarted mid-cycle does not
  /// end up with two loops running.
  void arm({
    required bool Function() isActive,
    required Future<void> Function() runCycle,
  }) {
    _timer?.cancel();
    final scheduler = _scheduler;
    if (scheduler == null || !isActive()) return;

    _timer = Timer(_delayUntilNextWindow(scheduler), () {
      if (!isActive()) return;
      unawaited(
        runCycle().whenComplete(() {
          if (identical(scheduler, _scheduler)) {
            arm(isActive: isActive, runCycle: runCycle);
          }
        }),
      );
    });
  }

  /// Take the next complete window and read its audio, or null if there is
  /// none ready yet.
  ///
  /// Windows come out in capture order. When the buffer has overrun, the
  /// windows whose audio is already gone are dropped and reported rather than
  /// quietly replaced by newer audio — silently substituting a different
  /// window is what makes two modes disagree about the same sound.
  InferenceWindowAudio? takeReadyWindow() {
    final scheduler = _scheduler;
    if (scheduler == null) return null;
    if (_rebaseIfBufferReset(scheduler)) return null;
    if (!_calibrate(scheduler)) return null;

    final skipped = scheduler.skipOverwritten(_relativeOldestRetained());
    if (skipped > 0) {
      debugPrint(
        '[$debugLabel] skipped $skipped inference windows after buffer '
        'overrun',
      );
    }

    final window = scheduler.takeNext(_relativeWritten());
    if (window == null) return null;
    _trackBacklog(scheduler, _relativeWritten() - window.endSample);

    final windowEndSample = _sampleBase + window.endSample;
    return InferenceWindowAudio(
      samples: ringBuffer.readEndingAt(
        scheduler.windowSamples,
        windowEndSample,
      ),
      startTimestamp: window.timestamp,
      endTimestamp: window.timestamp.add(
        Duration(seconds: scheduler.windowDurationSeconds),
      ),
      windowEndSample: windowEndSample,
      windowDurationSeconds: scheduler.windowDurationSeconds,
    );
  }

  /// Lower the rate once the schedule has fallen behind for good.
  ///
  /// A window is late by however far capture has moved past its end when it
  /// is taken. A whole hop late means the next window was already complete
  /// before this one was read. One such window is a stall — a slow frame, a
  /// save — and drains on its own; a run of them, each later than the last,
  /// means the model is slower than the schedule. Left alone, that backlog
  /// grows until the buffer overruns, and well before that the detection
  /// clips, cut from the same buffer after a post-roll wait, find their
  /// windows overwritten and are silently skipped. Dropping the rate a step
  /// and continuing from the audio arriving now keeps both inside the buffer.
  /// At the floor the rate stays, and only the backlog is dropped.
  void _trackBacklog(RealtimeInferenceScheduler scheduler, int lateSamples) {
    final growing = lateSamples >= _previousLateSamples;
    _previousLateSamples = lateSamples;
    if (lateSamples < scheduler.hopSamples || !growing) {
      _lateTakes = 0;
      return;
    }
    if (++_lateTakes < AppConstants.lateWindowsBeforeInferenceDownshift) {
      return;
    }
    _resetBacklogTracking();

    final current = scheduler.inferenceRateHz;
    final lowered = loweredInferenceRate(current);
    scheduler.setInferenceRate(lowered, _relativeWritten());
    final lateSeconds = (lateSamples / scheduler.sampleRate).toStringAsFixed(1);
    if (lowered < current) {
      debugPrint(
        '[$debugLabel] inference ran ${lateSeconds}s behind capture; '
        'lowering the rate from $current Hz to $lowered Hz',
      );
      onInferenceRateLowered?.call(lowered);
    } else {
      debugPrint(
        '[$debugLabel] inference ran ${lateSeconds}s behind capture at the '
        'lowest rate; continuing from the newest audio',
      );
    }
  }

  void _resetBacklogTracking() {
    _lateTakes = 0;
    _previousLateSamples = 0;
  }

  int _relativeWritten() => ringBuffer.totalWritten - _sampleBase;

  int _relativeOldestRetained() {
    final oldest = ringBuffer.totalWritten - ringBuffer.available - _sampleBase;
    return oldest < 0 ? 0 : oldest;
  }

  Duration _delayUntilNextWindow(RealtimeInferenceScheduler scheduler) {
    // Until the timeline is calibrated there is nothing to compute a delay
    // from — poll for the first samples instead.
    if (!scheduler.isCalibrated) return _calibrationPollDelay;

    final remaining = (scheduler.nextWindowEndSample - _relativeWritten())
        .clamp(0, scheduler.maxWaitSamples);
    final delay = Duration(
      microseconds:
          (remaining * Duration.microsecondsPerSecond / scheduler.sampleRate)
              .round(),
    );
    return delay < _minimumDelay ? _minimumDelay : delay;
  }

  /// Match the timeline to audio that has actually been captured.
  ///
  /// Returns whether the schedule is ready to produce windows.
  bool _calibrate(RealtimeInferenceScheduler scheduler) {
    if (scheduler.isCalibrated) return true;
    return scheduler.calibrate(_relativeWritten(), DateTime.now());
  }

  /// Re-anchor when the shared capture buffer was reset underneath us.
  ///
  /// [RingBuffer.clear] resets `totalWritten`, and the buffer is shared with
  /// the other capture-driven features — an ARU cycle starting is enough.
  /// Without this the schedule would wait forever for a sample count the
  /// rewound buffer can no longer reach, and the session would stop producing
  /// windows for good with nothing logged.
  bool _rebaseIfBufferReset(RealtimeInferenceScheduler scheduler) {
    if (ringBuffer.resetGeneration == _ringBufferResetGeneration) return false;
    debugPrint(
      '[$debugLabel] capture buffer reset beneath the schedule — '
      're-anchoring the inference timeline',
    );
    _ringBufferResetGeneration = ringBuffer.resetGeneration;
    // RingBuffer.clear starts its absolute offsets from zero. Audio already
    // written on the new timeline is valid session audio, so retain it rather
    // than anchoring at the current counter and silently discarding it.
    _sampleBase = 0;
    _resetBacklogTracking();
    scheduler.rebase(DateTime.now());
    return true;
  }
}
