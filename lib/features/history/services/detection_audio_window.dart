import 'dart:math' as math;

import '../../live/live_session.dart';

double detectionDurationSeconds(
  DetectionRecord detection,
  SessionSettings settings,
) {
  final end = detection.endTimestamp;
  if (end != null && end.isAfter(detection.timestamp)) {
    return end.difference(detection.timestamp).inMicroseconds /
        Duration.microsecondsPerSecond;
  }
  return settings.windowDuration.toDouble();
}

DetectionAudioWindow detectionAudioWindow(
  LiveSession session,
  DetectionRecord detection, {
  double? clipContextSeconds,
  // Export staging can reference a detection clip by index even when the
  // record's original path is not attached to the in-memory test/copy.
  bool? referencesDetectionClip,
}) {
  final context = math.max(0.0, clipContextSeconds ?? 0.0);
  // Offset into the *recorded* audio timeline, which is a gap-removed
  // concatenation of the session's segments. absoluteToRelative collapses
  // any pause/resume gaps so a resumed session's detections line up with
  // the actual audio position (matching in-app playback). For single-run
  // sessions (no segments) this reduces to timestamp - startTime.
  final start = session.absoluteToRelative(detection.timestamp);
  final duration = detectionDurationSeconds(detection, session.settings);

  // Where the clip file itself sits. A detection-clip session holds one
  // analysis window per record, re-cut as the detection climbed to its
  // confidence peak, so the clip generally starts well after the detection
  // did — anchoring it at [DetectionRecord.timestamp] would misplace the
  // detection inside the clip in Raven/CSV exports. Records without a
  // [DetectionRecord.clipTimestamp] predate peak-following clips and were
  // cut on arrival, so the detection start is their correct anchor.
  final clipWindowStart = detection.clipTimestamp;
  final clipAnchor =
      clipWindowStart == null
          ? start
          : session.absoluteToRelative(clipWindowStart);
  // A per-detection clip has always held exactly one analysis window plus its
  // padding, including legacy clips without a peak timestamp. Full-recording
  // extraction still uses the complete detection span.
  final hasDetectionClip =
      referencesDetectionClip ?? (detection.audioClipPath ?? '').isNotEmpty;
  final clipWindowDuration =
      hasDetectionClip ? session.settings.windowDuration.toDouble() : duration;

  final clipStart = math.max(0.0, clipAnchor - context);
  // Detection clip files keep their zero-padded pre-roll even when the
  // analysis window begins at the session boundary.
  final detectionStartInClip =
      hasDetectionClip ? context : clipAnchor - clipStart;
  return DetectionAudioWindow(
    detectionStartSec: start,
    detectionDurationSec: duration,
    clipStartSec: clipStart,
    clipDurationSec: clipWindowDuration + context * 2,
    clipDetectionStartSec: detectionStartInClip,
    clipDetectionEndSec: detectionStartInClip + clipWindowDuration,
  );
}

class DetectionAudioWindow {
  const DetectionAudioWindow({
    required this.detectionStartSec,
    required this.detectionDurationSec,
    required this.clipStartSec,
    required this.clipDurationSec,
    required this.clipDetectionStartSec,
    required this.clipDetectionEndSec,
  });

  final double detectionStartSec;
  final double detectionDurationSec;
  final double clipStartSec;
  final double clipDurationSec;
  final double clipDetectionStartSec;
  final double clipDetectionEndSec;

  double get detectionEndSec => detectionStartSec + detectionDurationSec;
}
