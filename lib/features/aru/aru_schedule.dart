// =============================================================================
// ARU Schedule - Pure scheduling domain for autonomous recording deployments
// =============================================================================

import 'dart:math' as math;

import 'aru_defaults.dart';

/// High-level schedule status at a point in time.
enum AruScheduleStatus {
  /// The deployment has not reached its first possible recording window.
  notStarted,

  /// The deployment is between recording windows.
  waiting,

  /// The deployment is inside an active recording window.
  recording,

  /// No more windows are allowed by the configured end condition.
  completed,
}

/// Optional day/night restriction for ARU recording windows.
enum AruDielPattern {
  /// No diel restriction; repeat windows run around the clock.
  anyTime,

  /// Daylight-only windows.
  dayOnly,

  /// Night-only windows.
  nightOnly,

  /// Windows around local sunrise.
  aroundSunrise,

  /// Windows around local sunset.
  aroundSunset,

  /// Windows around local sunrise and sunset.
  aroundSunriseAndSunset,
}

/// User-configured repeating ARU schedule.
class AruScheduleConfig {
  const AruScheduleConfig({
    required this.startTime,
    required this.cycleDuration,
    required this.repeatInterval,
    this.endTime,
    this.maxCycles,
    this.lowBatteryStopPercent,
    this.dielPattern = AruDielPattern.anyTime,
    this.testCycleEnabled = false,
    this.latitude,
    this.longitude,
  });

  /// First time at which a recording cycle may start.
  final DateTime startTime;

  /// Duration of every active recording cycle.
  final Duration cycleDuration;

  /// Time from one cycle start to the next cycle start.
  final Duration repeatInterval;

  /// Optional wall-clock deployment end. Cycles starting at or after this time
  /// are not scheduled; cycles already active at this time are clamped.
  final DateTime? endTime;

  /// Optional maximum number of cycles, counted from [startTime].
  final int? maxCycles;

  /// Optional graceful stop threshold. Battery measurement is outside this
  /// pure scheduler; this value is stored so controllers can enforce it.
  final int? lowBatteryStopPercent;

  /// Optional diel restriction.
  final AruDielPattern dielPattern;

  /// Runs one immediate one-minute sanity-check cycle before the regular
  /// clock-aligned schedule begins.
  final bool testCycleEnabled;

  /// Optional deployment latitude for sunrise/sunset estimation.
  final double? latitude;

  /// Optional deployment longitude for sunrise/sunset estimation.
  final double? longitude;

  /// Returns validation errors. Empty means this config can be scheduled.
  List<String> validate() {
    final errors = <String>[];
    if (cycleDuration < AruDefaults.minCycleDuration) {
      errors.add('cycleDuration must be at least 30 seconds');
    }
    if (cycleDuration > AruDefaults.maxCycleDuration) {
      errors.add('cycleDuration must be at most 60 minutes');
    }
    if (repeatInterval < cycleDuration) {
      errors.add(
        'repeatInterval must be greater than or equal to cycleDuration',
      );
    }
    if (endTime != null && !endTime!.isAfter(startTime)) {
      errors.add('endTime must be after startTime');
    }
    if (maxCycles != null && maxCycles! <= 0) {
      errors.add('maxCycles must be greater than zero');
    }
    if (lowBatteryStopPercent != null &&
        (lowBatteryStopPercent! < 0 || lowBatteryStopPercent! > 100)) {
      errors.add('lowBatteryStopPercent must be between 0 and 100');
    }
    return errors;
  }

  /// Throws [ArgumentError] when [validate] reports any errors.
  void validateOrThrow() {
    final errors = validate();
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.join('; '));
    }
  }
}

/// Estimated local sunrise and sunset for one date.
class AruSunTimes {
  const AruSunTimes({required this.sunrise, required this.sunset});

  final DateTime sunrise;
  final DateTime sunset;
}

/// One allowed diel interval for ARU recording starts.
class AruDielWindow {
  const AruDielWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime time) => !time.isBefore(start) && time.isBefore(end);
}

List<AruDielWindow> aruDielWindowsForDate({
  required DateTime date,
  required AruDielPattern pattern,
  double? latitude,
  double? longitude,
}) {
  final localMidnight =
      date.isUtc
          ? DateTime.utc(date.year, date.month, date.day)
          : DateTime(date.year, date.month, date.day);
  final sunTimes = estimateAruSunTimes(
    date: localMidnight,
    latitude: latitude,
    longitude: longitude,
  );

  switch (pattern) {
    case AruDielPattern.anyTime:
      return [
        AruDielWindow(
          start: localMidnight,
          end: localMidnight.add(const Duration(days: 1)),
        ),
      ];
    case AruDielPattern.dayOnly:
      return [
        AruDielWindow(
          start: sunTimes.sunrise.subtract(const Duration(hours: 1)),
          end: sunTimes.sunset.add(const Duration(hours: 1)),
        ),
      ];
    case AruDielPattern.nightOnly:
      final previousSunTimes = estimateAruSunTimes(
        date: localMidnight.subtract(const Duration(days: 1)),
        latitude: latitude,
        longitude: longitude,
      );
      final nextSunTimes = estimateAruSunTimes(
        date: localMidnight.add(const Duration(days: 1)),
        latitude: latitude,
        longitude: longitude,
      );
      return [
        AruDielWindow(
          start: previousSunTimes.sunset.subtract(const Duration(hours: 1)),
          end: sunTimes.sunrise.add(const Duration(hours: 1)),
        ),
        AruDielWindow(
          start: sunTimes.sunset.subtract(const Duration(hours: 1)),
          end: nextSunTimes.sunrise.add(const Duration(hours: 1)),
        ),
      ];
    case AruDielPattern.aroundSunrise:
      return [
        AruDielWindow(
          start: sunTimes.sunrise.subtract(const Duration(hours: 1)),
          end: sunTimes.sunrise.add(const Duration(hours: 1)),
        ),
      ];
    case AruDielPattern.aroundSunset:
      return [
        AruDielWindow(
          start: sunTimes.sunset.subtract(const Duration(hours: 1)),
          end: sunTimes.sunset.add(const Duration(hours: 1)),
        ),
      ];
    case AruDielPattern.aroundSunriseAndSunset:
      return [
        AruDielWindow(
          start: sunTimes.sunrise.subtract(const Duration(hours: 1)),
          end: sunTimes.sunrise.add(const Duration(hours: 1)),
        ),
        AruDielWindow(
          start: sunTimes.sunset.subtract(const Duration(hours: 1)),
          end: sunTimes.sunset.add(const Duration(hours: 1)),
        ),
      ];
  }
}

bool isAruStartAllowedByDielPattern({
  required AruDielPattern pattern,
  required DateTime start,
  required double? latitude,
  required double? longitude,
}) {
  return aruDielWindowsForDate(
    date: start,
    pattern: pattern,
    latitude: latitude,
    longitude: longitude,
  ).any((window) => window.contains(start));
}

/// Estimate local sunrise/sunset for ARU schedule previews.
///
/// Uses a compact NOAA-style approximation. If location is unavailable or the
/// solar calculation is undefined for the latitude/date, falls back to 06:00
/// and 18:00 local time as requested by the setup flow.
AruSunTimes estimateAruSunTimes({
  required DateTime date,
  double? latitude,
  double? longitude,
}) {
  final localMidnight =
      date.isUtc
          ? DateTime.utc(date.year, date.month, date.day)
          : DateTime(date.year, date.month, date.day);
  if (latitude == null || longitude == null) {
    return AruSunTimes(
      sunrise: localMidnight.add(const Duration(hours: 6)),
      sunset: localMidnight.add(const Duration(hours: 18)),
    );
  }

  final dayOfYear = _dayOfYear(date);
  final gamma = 2 * math.pi / 365 * (dayOfYear - 1);
  final equationOfTime =
      229.18 *
      (0.000075 +
          0.001868 * math.cos(gamma) -
          0.032077 * math.sin(gamma) -
          0.014615 * math.cos(2 * gamma) -
          0.040849 * math.sin(2 * gamma));
  final declination =
      0.006918 -
      0.399912 * math.cos(gamma) +
      0.070257 * math.sin(gamma) -
      0.006758 * math.cos(2 * gamma) +
      0.000907 * math.sin(2 * gamma) -
      0.002697 * math.cos(3 * gamma) +
      0.00148 * math.sin(3 * gamma);

  final latRad = latitude * math.pi / 180;
  final zenith = 90.833 * math.pi / 180;
  final hourAngleInput =
      (math.cos(zenith) / (math.cos(latRad) * math.cos(declination))) -
      (math.tan(latRad) * math.tan(declination));

  if (hourAngleInput < -1 || hourAngleInput > 1) {
    return AruSunTimes(
      sunrise: localMidnight.add(const Duration(hours: 6)),
      sunset: localMidnight.add(const Duration(hours: 18)),
    );
  }

  final hourAngleDegrees = math.acos(hourAngleInput) * 180 / math.pi;
  final timezoneOffsetMinutes = date.timeZoneOffset.inMinutes;
  final solarNoonMinutes =
      720 - 4 * longitude - equationOfTime + timezoneOffsetMinutes;
  final sunriseMinutes = (solarNoonMinutes - hourAngleDegrees * 4).round();
  final sunsetMinutes = (solarNoonMinutes + hourAngleDegrees * 4).round();

  return AruSunTimes(
    sunrise: localMidnight.add(Duration(minutes: sunriseMinutes)),
    sunset: localMidnight.add(Duration(minutes: sunsetMinutes)),
  );
}

int _dayOfYear(DateTime date) {
  final startOfYear =
      date.isUtc ? DateTime.utc(date.year) : DateTime(date.year);
  return date.difference(startOfYear).inDays + 1;
}

/// One scheduled ARU recording window.
class AruCycleWindow {
  const AruCycleWindow({
    required this.index,
    required this.start,
    required this.end,
    required this.plannedEnd,
  });

  /// Zero-based cycle index.
  final int index;

  /// Scheduled cycle start.
  final DateTime start;

  /// Effective cycle end, clamped by deployment end when configured.
  final DateTime end;

  /// Unclamped end derived from start + cycle duration.
  final DateTime plannedEnd;

  /// Whether [time] falls inside this active recording window.
  bool contains(DateTime time) => !time.isBefore(start) && time.isBefore(end);

  /// Whether this cycle was shortened by the deployment end time.
  bool get isClamped => end.isBefore(plannedEnd);
}

/// Schedule evaluation result for one point in time.
class AruScheduleSnapshot {
  const AruScheduleSnapshot({
    required this.status,
    required this.skippedCycles,
    this.currentWindow,
    this.nextWindow,
  });

  final AruScheduleStatus status;
  final AruCycleWindow? currentWindow;
  final AruCycleWindow? nextWindow;

  /// Number of windows whose end is before or equal to the evaluated time.
  final int skippedCycles;

  bool get isRecording => status == AruScheduleStatus.recording;
  bool get isWaiting => status == AruScheduleStatus.waiting;
  bool get isCompleted => status == AruScheduleStatus.completed;
}

/// Clock-aligns the first regular cycle start for [config].
///
/// Shared by [AruScheduleCalculator] and `AruStorageEstimator` so schedule
/// generation and storage estimation stay in lockstep. When a test cycle is
/// enabled, the base time is offset by [AruDefaults.testCycleDuration]; the
/// result is then snapped forward to the next multiple of the repeat interval
/// past local midnight.
DateTime aruFirstClockAlignedStart(AruScheduleConfig config) {
  final baseTime =
      config.testCycleEnabled
          ? config.startTime.add(AruDefaults.testCycleDuration)
          : config.startTime;
  final midnight =
      baseTime.isUtc
          ? DateTime.utc(baseTime.year, baseTime.month, baseTime.day)
          : DateTime(baseTime.year, baseTime.month, baseTime.day);
  final elapsed = baseTime.difference(midnight);
  final intervalMicros = config.repeatInterval.inMicroseconds;
  final remainder = elapsed.inMicroseconds % intervalMicros;
  if (remainder == 0) return baseTime;
  return baseTime.add(Duration(microseconds: intervalMicros - remainder));
}

/// Start time of the regular cycle at [rawIndex] (ignoring diel filtering).
DateTime aruRegularCycleStart(AruScheduleConfig config, int rawIndex) =>
    aruFirstClockAlignedStart(config).add(config.repeatInterval * rawIndex);

/// Whether a cycle starting at [start] is permitted by the config's diel
/// pattern.
bool aruIsStartAllowed(AruScheduleConfig config, DateTime start) =>
    isAruStartAllowedByDielPattern(
      pattern: config.dielPattern,
      start: start,
      latitude: config.latitude,
      longitude: config.longitude,
    );

/// Pure ARU schedule calculator.
class AruScheduleCalculator {
  AruScheduleCalculator(this.config) {
    config.validateOrThrow();
  }

  final AruScheduleConfig config;

  /// Evaluate the deployment state at [now].
  AruScheduleSnapshot snapshotAt(DateTime now) {
    if (now.isBefore(config.startTime)) {
      return AruScheduleSnapshot(
        status: AruScheduleStatus.notStarted,
        skippedCycles: 0,
        nextWindow: _windowAt(0),
      );
    }

    final candidateIndex = _cycleIndexAt(now);
    final current = _windowAt(candidateIndex);
    final skipped = candidateIndex;

    if (current == null) {
      return AruScheduleSnapshot(
        status: AruScheduleStatus.completed,
        skippedCycles: skipped,
      );
    }

    if (current.contains(now)) {
      return AruScheduleSnapshot(
        status: AruScheduleStatus.recording,
        skippedCycles: skipped,
        currentWindow: current,
        nextWindow: _windowAt(candidateIndex + 1),
      );
    }

    final next =
        now.isBefore(current.start) ? current : _windowAt(candidateIndex + 1);
    if (next == null) {
      return AruScheduleSnapshot(
        status: AruScheduleStatus.completed,
        skippedCycles: skipped,
      );
    }

    return AruScheduleSnapshot(
      status: AruScheduleStatus.waiting,
      skippedCycles: skipped,
      nextWindow: next,
    );
  }

  /// Returns up to [count] future windows starting at or after [from].
  List<AruCycleWindow> nextWindows(DateTime from, {int count = 3}) {
    if (count <= 0) return const [];
    final windows = <AruCycleWindow>[];
    var index = from.isBefore(config.startTime) ? 0 : _cycleIndexAt(from);

    while (windows.length < count) {
      final window = _windowAt(index);
      if (window == null) break;
      if (window.end.isAfter(from)) {
        windows.add(window);
      }
      index++;
    }

    return windows;
  }

  int _cycleIndexAt(DateTime time) {
    if (config.dielPattern == AruDielPattern.anyTime) {
      return _cycleIndexAtAnyTime(time);
    }
    return _cycleIndexAtDiel(time);
  }

  int _cycleIndexAtAnyTime(DateTime time) {
    final testWindow = config.testCycleEnabled ? _windowAt(0) : null;
    if (testWindow != null && testWindow.end.isAfter(time)) return 0;

    final indexOffset = config.testCycleEnabled ? 1 : 0;
    final firstRegular = _firstClockAlignedStart();
    if (time.isBefore(firstRegular.add(config.cycleDuration))) {
      return indexOffset;
    }

    final elapsedMicros = time.difference(firstRegular).inMicroseconds;
    final intervalMicros = config.repeatInterval.inMicroseconds;
    final rawIndex = elapsedMicros ~/ intervalMicros;
    final rawStart = _regularCycleStart(rawIndex);
    final rawEnd = rawStart.add(config.cycleDuration);
    var index = indexOffset + (rawEnd.isAfter(time) ? rawIndex : rawIndex + 1);

    // A deployment end can clamp the current window earlier than
    // start+duration, so verify the computed candidate before returning.
    while (true) {
      final window = _windowAt(index);
      if (window == null || window.end.isAfter(time)) return index;
      index++;
    }
  }

  int _cycleIndexAtDiel(DateTime time) {
    var index = 0;
    if (config.testCycleEnabled) {
      final testWindow = _windowAt(0);
      if (testWindow != null && testWindow.end.isAfter(time)) return 0;
      index = 1;
    }

    var acceptedRegular = 0;
    var rawIndex = 0;
    while (true) {
      if (config.maxCycles != null && acceptedRegular >= config.maxCycles!) {
        return index;
      }

      final candidate = _candidateWindow(
        rawIndex: rawIndex,
        windowIndex: index,
      );
      if (candidate == null) return index;
      if (_isAllowedStart(candidate.start)) {
        if (candidate.end.isAfter(time)) return index;
        acceptedRegular++;
        index++;
      }
      rawIndex++;
    }
  }

  AruCycleWindow? _windowAt(int index) {
    if (index < 0) return null;
    if (config.testCycleEnabled && index == 0) {
      final plannedEnd = config.startTime.add(AruDefaults.testCycleDuration);
      final deploymentEnd = config.endTime;
      if (deploymentEnd != null && !config.startTime.isBefore(deploymentEnd)) {
        return null;
      }
      final end =
          deploymentEnd != null && deploymentEnd.isBefore(plannedEnd)
              ? deploymentEnd
              : plannedEnd;
      if (!end.isAfter(config.startTime)) return null;
      return AruCycleWindow(
        index: 0,
        start: config.startTime,
        end: end,
        plannedEnd: plannedEnd,
      );
    }

    final regularIndex = config.testCycleEnabled ? index - 1 : index;
    if (config.maxCycles != null && regularIndex >= config.maxCycles!) {
      return null;
    }

    if (config.dielPattern == AruDielPattern.anyTime) {
      return _candidateWindow(rawIndex: regularIndex, windowIndex: index);
    }

    var accepted = 0;
    var rawIndex = 0;
    while (true) {
      final candidate = _candidateWindow(
        rawIndex: rawIndex,
        windowIndex: config.testCycleEnabled ? accepted + 1 : accepted,
      );
      if (candidate == null) return null;
      if (_isAllowedStart(candidate.start)) {
        if (accepted == regularIndex) return candidate;
        accepted++;
      }
      rawIndex++;
    }
  }

  AruCycleWindow? _candidateWindow({
    required int rawIndex,
    required int windowIndex,
  }) {
    final start = _regularCycleStart(rawIndex);
    final plannedEnd = start.add(config.cycleDuration);
    final deploymentEnd = config.endTime;
    if (deploymentEnd != null && !start.isBefore(deploymentEnd)) return null;

    final end =
        deploymentEnd != null && deploymentEnd.isBefore(plannedEnd)
            ? deploymentEnd
            : plannedEnd;
    if (!end.isAfter(start)) return null;

    return AruCycleWindow(
      index: windowIndex,
      start: start,
      end: end,
      plannedEnd: plannedEnd,
    );
  }

  DateTime _regularCycleStart(int rawIndex) =>
      aruRegularCycleStart(config, rawIndex);

  DateTime _firstClockAlignedStart() => aruFirstClockAlignedStart(config);

  bool _isAllowedStart(DateTime start) => aruIsStartAllowed(config, start);
}
