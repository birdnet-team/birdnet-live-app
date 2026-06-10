// =============================================================================
// timestamp_format.dart
// =============================================================================
// Single source of truth for rendering per-detection timestamps in the UI.
//
// Storage policy: every persisted DateTime is a UTC instant.  This helper is
// the only place that converts back to a wall-clock string at render time.
// The active mode is controlled by [PrefKeys.timestampDisplayMode] and read
// via [timestampDisplayModeProvider].
//
// Two modes:
//   * relative — `MM:SS` or `H:MM:SS`, measured from the session start.
//                Useful when reviewing a single session in isolation
//                (matches the spectrogram playhead at sub-second precision).
//   * absolute — `HH:mm:ss` local clock time.  Useful for cross-referencing
//                paper field notes, weather logs, or other recordings.  When
//                the detection falls on a different calendar day from the
//                session start, a `+Nd` suffix is appended so reviewers
//                don't accidentally read tomorrow's dawn chorus as today's.
//
// The helper never throws; negative offsets clamp to zero so a slightly
// out-of-order detection still renders sensibly.
// =============================================================================

/// Modes for [formatDetectionTime].
enum TimestampDisplayMode {
  /// Session-relative offset (`MM:SS` or `H:MM:SS`).
  relative,

  /// Local-clock wall time (`HH:mm:ss`, with `+Nd` if past midnight).
  absolute;

  /// Parses the string stored under [PrefKeys.timestampDisplayMode].
  /// Unknown values fall back to [TimestampDisplayMode.relative].
  static TimestampDisplayMode fromString(String? value) {
    switch (value) {
      case 'absolute':
        return TimestampDisplayMode.absolute;
      case 'relative':
      default:
        return TimestampDisplayMode.relative;
    }
  }
}

/// Renders [timestamp] for display, using [sessionStart] as the zero point
/// for relative mode.  Both timestamps are treated as instants — they may
/// be in any timezone (UTC or local); the render is always done in the
/// device's current local timezone for absolute mode.
///
/// [absoluteToRelative] can map an absolute timestamp to session-relative
/// seconds when recording has pause/resume gaps.
///
/// [clipOffset] shifts the relative zero forward when the underlying audio
/// has been trimmed (so the rendered offset stays aligned with the
/// spectrogram playhead).  It does NOT affect absolute mode — wall-clock
/// time is independent of how the clip was cropped.
///
/// [showSeconds] toggles the trailing `:ss` component for **absolute mode
/// only** (`HH:mm:ss` vs `HH:mm`).  Relative mode always renders seconds —
/// reviewers expect sub-minute precision when correlating offsets to the
/// spectrogram playhead.  This is a UI-only preference; exports always
/// include seconds regardless.
String formatDetectionTime(
  DateTime timestamp,
  DateTime sessionStart,
  TimestampDisplayMode mode, {
  double Function(DateTime timestamp)? absoluteToRelative,
  Duration clipOffset = Duration.zero,
  bool showSeconds = true,
}) {
  switch (mode) {
    case TimestampDisplayMode.relative:
      final double relativeSec =
          absoluteToRelative != null
              ? absoluteToRelative(timestamp)
              : timestamp.difference(sessionStart).inMicroseconds / 1e6;
      return _formatRelative(
        Duration(microseconds: (relativeSec * 1e6).round()) - clipOffset,
      );
    case TimestampDisplayMode.absolute:
      return _formatAbsolute(
        timestamp.toLocal(),
        sessionStart.toLocal(),
        showSeconds: showSeconds,
      );
  }
}

String _formatRelative(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final totalSeconds = d.inSeconds;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$mm:$ss';
}

String _formatAbsolute(
  DateTime localTs,
  DateTime localStart, {
  required bool showSeconds,
}) {
  final h = localTs.hour.toString().padLeft(2, '0');
  final m = localTs.minute.toString().padLeft(2, '0');
  final base =
      showSeconds
          ? '$h:$m:${localTs.second.toString().padLeft(2, '0')}'
          : '$h:$m';
  // Day-rollover suffix (e.g. session started 23:50, detection at 00:05 next
  // day → "00:05:00 +1d").  Compare calendar dates, not raw differences.
  final tsDay = DateTime(localTs.year, localTs.month, localTs.day);
  final startDay = DateTime(localStart.year, localStart.month, localStart.day);
  final dayDelta = tsDay.difference(startDay).inDays;
  if (dayDelta == 0) return base;
  final sign = dayDelta > 0 ? '+' : '-';
  return '$base $sign${dayDelta.abs()}d';
}
