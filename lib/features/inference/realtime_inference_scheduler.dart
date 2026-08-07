// =============================================================================
// Real-time inference scheduler — sample-anchored overlapping audio windows
// =============================================================================

/// One complete analysis window on the capture sample timeline.
class ScheduledInferenceWindow {
  const ScheduledInferenceWindow({
    required this.startSample,
    required this.endSample,
    required this.timestamp,
  });

  /// Inclusive start sample on the session-local capture timeline.
  final int startSample;

  /// Exclusive end sample on the session-local capture timeline.
  final int endSample;

  /// Wall-clock timestamp corresponding to [startSample].
  final DateTime timestamp;
}

/// Produces deterministic inference windows from captured sample counts.
///
/// Wall-clock timers only wake the controller. Window boundaries themselves
/// are derived from the number of captured samples, so a slow inference or an
/// unrelated file write cannot silently shift or skip the PCM being analyzed.
///
/// This is for the capture-driven modes — Live, Point Count, Survey, and the
/// ARU cycles that run through them — which must decide how often to run
/// against audio that keeps arriving. File Analysis owns a fixed recording and
/// steps through it by [FileAnalysisController.analyze]'s `overlap` instead;
/// what the two share is [DetectionAccumulator], not this schedule.
class RealtimeInferenceScheduler {
  RealtimeInferenceScheduler({
    required this.sampleRate,
    required this.windowDurationSeconds,
    required this.inferenceRateHz,
    required this.timelineStart,
  }) : assert(sampleRate > 0),
       assert(windowDurationSeconds > 0),
       assert(inferenceRateHz > 0),
       windowSamples = sampleRate * windowDurationSeconds,
       hopSamples = hopSamplesFor(sampleRate, inferenceRateHz),
       _nextWindowEndSample = sampleRate * windowDurationSeconds;

  final int sampleRate;
  final int windowDurationSeconds;
  final double inferenceRateHz;
  final int windowSamples;
  final int hopSamples;

  DateTime timelineStart;
  int _nextWindowEndSample;
  bool _calibrated = false;

  /// Whether [timelineStart] has been matched to audio that really arrived.
  bool get isCalibrated => _calibrated;

  /// Delay until the first complete, non-zero-padded window can exist.
  Duration get initialDelay => Duration(seconds: windowDurationSeconds);

  /// Longest useful wait between wakeups.
  ///
  /// Below `1 / windowDurationSeconds` Hz the hop is longer than the window,
  /// so a caller bounding its sleep by [windowSamples] alone would wake
  /// several times per scheduled window and find nothing to do.
  int get maxWaitSamples =>
      hopSamples > windowSamples ? hopSamples : windowSamples;

  int get nextWindowEndSample => _nextWindowEndSample;

  /// Return the next complete scheduled window, or `null` if capture has not
  /// written enough samples yet.
  ScheduledInferenceWindow? takeNext(int totalWritten) {
    if (totalWritten < _nextWindowEndSample) return null;

    final endSample = _nextWindowEndSample;
    final startSample = endSample - windowSamples;
    _nextWindowEndSample += hopSamples;
    return ScheduledInferenceWindow(
      startSample: startSample,
      endSample: endSample,
      timestamp: timelineStart.add(_durationForSamples(startSample)),
    );
  }

  /// Match [timelineStart] to audio that has actually been captured.
  ///
  /// A scheduler is built when a session starts, but the first samples reach
  /// the buffer some time later — capture may still be opening the mic, and
  /// ARU starts the mic in the same breath as the session. Dating window one
  /// from construction time would push that entire gap into every timestamp
  /// the session produces. So the timeline does not begin until audio does:
  /// while nothing has been captured, [timelineStart] tracks the clock; on the
  /// first samples it is pinned to when they must have started arriving.
  ///
  /// [capturedSamples] is how much this session has captured so far and
  /// [observedAt] is when that count was read. Returns whether the timeline is
  /// now calibrated; callers keep calling until it is.
  bool calibrate(int capturedSamples, DateTime observedAt) {
    if (_calibrated) return true;
    if (capturedSamples <= 0) {
      timelineStart = observedAt;
      return false;
    }
    timelineStart = observedAt.subtract(_durationForSamples(capturedSamples));
    _calibrated = true;
    return true;
  }

  /// Restart the schedule against a capture buffer that was reset.
  ///
  /// [RingBuffer.clear] rewinds `totalWritten`, and the buffer is shared with
  /// the other capture-driven features. Without this the scheduler would keep
  /// waiting for a sample count the rewound buffer can never reach again, and
  /// the session would stop producing windows for good.
  ///
  /// The rewound buffer is a fresh capture timeline, so this also drops the
  /// calibration: the new audio gets dated by when it actually arrives, the
  /// same as at the start of a session.
  void rebase(DateTime timelineStart) {
    this.timelineStart = timelineStart;
    _nextWindowEndSample = windowSamples;
    _calibrated = false;
  }

  /// Advance past windows whose first samples have already been overwritten.
  ///
  /// Returns the number of windows lost. This should remain zero during
  /// normal operation; exposing it makes overload visible instead of silently
  /// substituting a newer `readLast` window.
  int skipOverwritten(int oldestRetainedSample) {
    var skipped = 0;
    while (_nextWindowEndSample - windowSamples < oldestRetainedSample) {
      _nextWindowEndSample += hopSamples;
      skipped++;
    }
    return skipped;
  }

  Duration _durationForSamples(int samples) => Duration(
    microseconds:
        (samples * Duration.microsecondsPerSecond / sampleRate).round(),
  );

  /// Convert an inference rate to its deterministic sample hop.
  static int hopSamplesFor(int sampleRate, double inferenceRateHz) {
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'Must be positive');
    }
    if (!inferenceRateHz.isFinite || inferenceRateHz <= 0) {
      throw ArgumentError.value(
        inferenceRateHz,
        'inferenceRateHz',
        'Must be finite and positive',
      );
    }
    return (sampleRate / inferenceRateHz)
        .round()
        .clamp(1, sampleRate * 3600)
        .toInt();
  }
}
