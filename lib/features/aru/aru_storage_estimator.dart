// =============================================================================
// ARU Storage Estimator - Pure helpers for deployment readiness checks
// =============================================================================

import '../recording/recording_service.dart';
import 'aru_defaults.dart';
import 'aru_schedule.dart';

/// Input values for ARU storage estimation.
class AruStorageEstimateInput {
  const AruStorageEstimateInput({
    required this.schedule,
    required this.recordingMode,
    this.format = 'flac',
    this.sampleRate = 32000,
    this.channels = 1,
    this.bitsPerSample = 16,
    this.flacCompressionRatio = 0.55,
    this.expectedRetainedClips,
    this.clipDurationSeconds = 5,
    this.retainedClipsPerSpecies = 10,
    this.assumedSpeciesCount = 50,
  });

  final AruScheduleConfig schedule;
  final RecordingMode recordingMode;
  final String format;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;

  /// Estimated FLAC bytes divided by WAV bytes.
  ///
  /// Real field recordings vary widely, so this must be shown as an estimate.
  final double flacCompressionRatio;

  /// Optional retained clip count for detection-only deployments.
  final int? expectedRetainedClips;

  /// Expected length of each retained clip.
  final int clipDurationSeconds;

  /// Assumed retained clips per species when [expectedRetainedClips] is not
  /// supplied.
  final int retainedClipsPerSpecies;

  /// Assumed number of species with retained clips when
  /// [expectedRetainedClips] is not supplied.
  final int assumedSpeciesCount;
}

/// Storage estimate for an ARU deployment.
class AruStorageEstimate {
  const AruStorageEstimate({
    required this.bytesPerRecordedSecond,
    required this.bytesPerHour,
    required this.bytesPerDayAtFullDuty,
    required this.bytesPerScheduledDay,
    this.totalBytes,
    this.totalRecordedDuration,
    this.totalCycles,
  });

  /// Estimated bytes for one second of retained audio.
  final int bytesPerRecordedSecond;

  /// Estimated bytes for one hour of retained audio.
  final int bytesPerHour;

  /// Estimated bytes for 24 hours of retained audio.
  final int bytesPerDayAtFullDuty;

  /// Estimated bytes for the first scheduled 24-hour deployment period.
  final int bytesPerScheduledDay;

  /// Estimated total bytes, or null for open-ended deployments.
  final int? totalBytes;

  /// Estimated retained/recorded audio duration, or null when open-ended.
  final Duration? totalRecordedDuration;

  /// Estimated number of scheduled cycles, or null when open-ended.
  final int? totalCycles;

  bool get hasFiniteTotal => totalBytes != null;
}

/// Computes storage estimates without touching platform storage APIs.
class AruStorageEstimator {
  const AruStorageEstimator();

  static const _dielExactRawCandidateLimit = 20000;
  static const _dielApproximationSampleDays = 7;

  /// Estimated number of scheduled cycles, or null when the deployment has no
  /// finite schedule end.
  int? estimateTotalCycles(AruScheduleConfig schedule) {
    schedule.validateOrThrow();
    return _finiteActiveDuration(schedule)?.cycles;
  }

  AruStorageEstimate estimate(AruStorageEstimateInput input) {
    input.schedule.validateOrThrow();

    final bytesPerSecond = _bytesPerSecond(input);
    final scheduledDayActiveDuration = _scheduledDayActiveDuration(
      input.schedule,
    );
    final bytesPerHour = bytesPerSecond * 3600;
    final bytesPerDay = bytesPerHour * 24;
    final scheduledBytesPerDay =
        scheduledDayActiveDuration.inSeconds * bytesPerSecond;

    if (input.recordingMode == RecordingMode.off) {
      return const AruStorageEstimate(
        bytesPerRecordedSecond: 0,
        bytesPerHour: 0,
        bytesPerDayAtFullDuty: 0,
        bytesPerScheduledDay: 0,
        totalBytes: 0,
        totalRecordedDuration: Duration.zero,
        totalCycles: 0,
      );
    }

    if (input.recordingMode == RecordingMode.detectionsOnly) {
      final retainedClips =
          input.expectedRetainedClips ??
          input.retainedClipsPerSpecies * input.assumedSpeciesCount;
      final retainedClipSeconds = retainedClips * input.clipDurationSeconds;
      final clipBytesPerHour =
          _clipEstimateSeconds(
            retainedClipSeconds: retainedClipSeconds,
            activeDuration: const Duration(hours: 1),
          ) *
          bytesPerSecond;
      final clipBytesPerDay =
          _clipEstimateSeconds(
            retainedClipSeconds: retainedClipSeconds,
            activeDuration: const Duration(days: 1),
          ) *
          bytesPerSecond;
      final scheduledClipBytesPerDay =
          _clipEstimateSeconds(
            retainedClipSeconds: retainedClipSeconds,
            activeDuration: scheduledDayActiveDuration,
          ) *
          bytesPerSecond;
      final active = _finiteActiveDuration(input.schedule);
      if (active == null) {
        return AruStorageEstimate(
          bytesPerRecordedSecond: bytesPerSecond,
          bytesPerHour: clipBytesPerHour,
          bytesPerDayAtFullDuty: clipBytesPerDay,
          bytesPerScheduledDay: scheduledClipBytesPerDay,
        );
      }

      final seconds = _clipEstimateSeconds(
        retainedClipSeconds: retainedClipSeconds,
        activeDuration: active.duration,
      );
      return AruStorageEstimate(
        bytesPerRecordedSecond: bytesPerSecond,
        bytesPerHour: clipBytesPerHour,
        bytesPerDayAtFullDuty: clipBytesPerDay,
        bytesPerScheduledDay: scheduledClipBytesPerDay,
        totalBytes: seconds * bytesPerSecond,
        totalRecordedDuration: Duration(seconds: seconds),
        totalCycles: active.cycles,
      );
    }

    final active = _finiteActiveDuration(input.schedule);
    if (active == null) {
      return AruStorageEstimate(
        bytesPerRecordedSecond: bytesPerSecond,
        bytesPerHour: bytesPerHour,
        bytesPerDayAtFullDuty: bytesPerDay,
        bytesPerScheduledDay: scheduledBytesPerDay,
      );
    }

    final totalSeconds = active.duration.inSeconds;
    return AruStorageEstimate(
      bytesPerRecordedSecond: bytesPerSecond,
      bytesPerHour: bytesPerHour,
      bytesPerDayAtFullDuty: bytesPerDay,
      bytesPerScheduledDay: scheduledBytesPerDay,
      totalBytes: totalSeconds * bytesPerSecond,
      totalRecordedDuration: active.duration,
      totalCycles: active.cycles,
    );
  }

  /// Whether [availableBytes] can hold [requiredBytes] plus a safety margin.
  bool hasEnoughStorage({
    required int availableBytes,
    required int requiredBytes,
    int safetyMarginBytes = AruDefaults.defaultStorageSafetyMarginBytes,
  }) {
    if (requiredBytes < 0 || availableBytes < 0 || safetyMarginBytes < 0) {
      return false;
    }
    return availableBytes >= requiredBytes + safetyMarginBytes;
  }

  int _bytesPerSecond(AruStorageEstimateInput input) {
    final wavBytes =
        input.sampleRate * input.channels * (input.bitsPerSample ~/ 8);
    if (input.format.toLowerCase() != 'flac') return wavBytes;
    return (wavBytes * input.flacCompressionRatio).ceil();
  }

  Duration _scheduledDayActiveDuration(AruScheduleConfig schedule) {
    final start = schedule.startTime;
    final end = start.add(const Duration(days: 1));
    final daySchedule = AruScheduleConfig(
      startTime: start,
      cycleDuration: schedule.cycleDuration,
      repeatInterval: schedule.repeatInterval,
      endTime: schedule.endTime != null && schedule.endTime!.isBefore(end)
          ? schedule.endTime
          : end,
      lowBatteryStopPercent: schedule.lowBatteryStopPercent,
      dielPattern: schedule.dielPattern,
      testCycleEnabled: schedule.testCycleEnabled,
      latitude: schedule.latitude,
      longitude: schedule.longitude,
    );
    final active = _finiteActiveDuration(daySchedule);
    return active?.duration ?? Duration.zero;
  }

  int _clipEstimateSeconds({
    required int retainedClipSeconds,
    required Duration activeDuration,
  }) {
    if (retainedClipSeconds <= 0 || activeDuration <= Duration.zero) return 0;
    final activeSeconds = activeDuration.inSeconds;
    return retainedClipSeconds < activeSeconds
        ? retainedClipSeconds
        : activeSeconds;
  }

  _FiniteActiveDuration? _finiteActiveDuration(AruScheduleConfig schedule) {
    if (schedule.maxCycles == null && schedule.endTime == null) return null;

    if (schedule.dielPattern == AruDielPattern.anyTime) {
      return _finiteAnyTimeActiveDuration(schedule);
    }

    final end = schedule.endTime;
    if (schedule.maxCycles != null) {
      return _scanDielActiveDuration(schedule);
    }

    if (end != null) {
      final rawCandidates = _rawCandidateCountBefore(
        _firstClockAlignedStart(schedule),
        end,
        schedule.repeatInterval,
      );
      if (rawCandidates <= _dielExactRawCandidateLimit) {
        return _scanDielActiveDuration(schedule);
      }
    }

    return _approximateDielActiveDuration(schedule);
  }

  _FiniteActiveDuration _finiteAnyTimeActiveDuration(
    AruScheduleConfig schedule,
  ) {
    var cycles = 0;
    var duration = Duration.zero;
    final end = schedule.endTime;

    final testDuration = _testCycleDuration(schedule, end);
    if (testDuration > Duration.zero) {
      cycles++;
      duration += testDuration;
    }

    final maxCycles = schedule.maxCycles;
    final firstRegular = _firstClockAlignedStart(schedule);
    final countBeforeEnd = end == null
        ? maxCycles
        : _rawCandidateCountBefore(firstRegular, end, schedule.repeatInterval);
    final regularCycles = maxCycles == null
        ? countBeforeEnd ?? 0
        : countBeforeEnd == null
        ? maxCycles
        : _minInt(maxCycles, countBeforeEnd);

    if (regularCycles <= 0) {
      return _FiniteActiveDuration(cycles: cycles, duration: duration);
    }

    cycles += regularCycles;
    if (end == null) {
      duration += schedule.cycleDuration * regularCycles;
      return _FiniteActiveDuration(cycles: cycles, duration: duration);
    }

    if (regularCycles > 1) {
      duration += schedule.cycleDuration * (regularCycles - 1);
    }
    final lastStart = _regularCycleStart(schedule, regularCycles - 1);
    final lastEnd = lastStart.add(schedule.cycleDuration);
    final effectiveLastEnd = lastEnd.isAfter(end) ? end : lastEnd;
    duration += effectiveLastEnd.difference(lastStart);

    return _FiniteActiveDuration(cycles: cycles, duration: duration);
  }

  _FiniteActiveDuration _scanDielActiveDuration(AruScheduleConfig schedule) {
    var cycles = 0;
    var acceptedRegular = 0;
    var duration = Duration.zero;
    final end = schedule.endTime;

    final testDuration = _testCycleDuration(schedule, end);
    if (testDuration > Duration.zero) {
      cycles++;
      duration += testDuration;
    }

    var rawIndex = 0;
    while (true) {
      final maxCycles = schedule.maxCycles;
      if (maxCycles != null && acceptedRegular >= maxCycles) break;

      final start = _regularCycleStart(schedule, rawIndex);
      if (end != null && !start.isBefore(end)) break;
      if (_isAllowedStart(schedule, start)) {
        final plannedEnd = start.add(schedule.cycleDuration);
        final effectiveEnd = end != null && plannedEnd.isAfter(end)
            ? end
            : plannedEnd;
        if (effectiveEnd.isAfter(start)) {
          acceptedRegular++;
          cycles++;
          duration += effectiveEnd.difference(start);
        }
      }
      rawIndex++;
    }

    return _FiniteActiveDuration(cycles: cycles, duration: duration);
  }

  _FiniteActiveDuration _approximateDielActiveDuration(
    AruScheduleConfig schedule,
  ) {
    final end = schedule.endTime;
    if (end == null) return _scanDielActiveDuration(schedule);

    var cycles = 0;
    var duration = Duration.zero;
    final testDuration = _testCycleDuration(schedule, end);
    if (testDuration > Duration.zero) {
      cycles++;
      duration += testDuration;
    }

    final firstRegular = _firstClockAlignedStart(schedule);
    if (!firstRegular.isBefore(end)) {
      return _FiniteActiveDuration(cycles: cycles, duration: duration);
    }

    final sampleEnd = _minDateTime(
      end,
      firstRegular.add(Duration(days: _dielApproximationSampleDays)),
    );
    final sample = _scanDielActiveDuration(
      AruScheduleConfig(
        startTime: firstRegular,
        cycleDuration: schedule.cycleDuration,
        repeatInterval: schedule.repeatInterval,
        endTime: sampleEnd,
        lowBatteryStopPercent: schedule.lowBatteryStopPercent,
        dielPattern: schedule.dielPattern,
        testCycleEnabled: false,
        latitude: schedule.latitude,
        longitude: schedule.longitude,
      ),
    );
    final sampleSpanSeconds = sampleEnd.difference(firstRegular).inSeconds;
    if (sampleSpanSeconds <= 0) {
      return _FiniteActiveDuration(cycles: cycles, duration: duration);
    }

    final totalSpanSeconds = end.difference(firstRegular).inSeconds;
    final regularCycles = (sample.cycles * totalSpanSeconds / sampleSpanSeconds)
        .round();
    final regularSeconds =
        (sample.duration.inSeconds * totalSpanSeconds / sampleSpanSeconds)
            .round();

    return _FiniteActiveDuration(
      cycles: cycles + regularCycles,
      duration: duration + Duration(seconds: regularSeconds),
    );
  }

  Duration _testCycleDuration(AruScheduleConfig schedule, DateTime? end) {
    if (!schedule.testCycleEnabled) return Duration.zero;
    final plannedEnd = schedule.startTime.add(AruDefaults.testCycleDuration);
    final effectiveEnd = end != null && plannedEnd.isAfter(end)
        ? end
        : plannedEnd;
    if (!schedule.startTime.isBefore(effectiveEnd)) return Duration.zero;
    return effectiveEnd.difference(schedule.startTime);
  }

  DateTime _regularCycleStart(AruScheduleConfig schedule, int rawIndex) =>
      aruRegularCycleStart(schedule, rawIndex);

  DateTime _firstClockAlignedStart(AruScheduleConfig schedule) =>
      aruFirstClockAlignedStart(schedule);

  bool _isAllowedStart(AruScheduleConfig schedule, DateTime start) =>
      aruIsStartAllowed(schedule, start);

  int _rawCandidateCountBefore(
    DateTime firstRegular,
    DateTime end,
    Duration repeatInterval,
  ) {
    if (!firstRegular.isBefore(end)) return 0;
    final elapsedMicros = end.difference(firstRegular).inMicroseconds;
    final intervalMicros = repeatInterval.inMicroseconds;
    return ((elapsedMicros - 1) ~/ intervalMicros) + 1;
  }

  int _minInt(int a, int b) => a < b ? a : b;

  DateTime _minDateTime(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}

class _FiniteActiveDuration {
  const _FiniteActiveDuration({required this.cycles, required this.duration});

  final int cycles;
  final Duration duration;
}
