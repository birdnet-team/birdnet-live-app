// =============================================================================
// Live Session — Data model for a real-time identification session
// =============================================================================
//
// Captures everything that happens during a Live Mode session:
//
//   - **Metadata**: unique id, start / end timestamps.
//   - **Detections**: accumulated species detections with timestamps.
//   - **Recording path**: optional filesystem path to the recorded WAV file.
//   - **Settings snapshot**: inference settings active during the session.
//
// Sessions are serializable to / from JSON for persistence via the session
// repository.
// =============================================================================

import 'package:intl/intl.dart';

import '../../shared/models/weather_snapshot.dart';

import '../../shared/models/gps_point.dart';
import '../aru/aru_schedule.dart';
import '../inference/models/detection.dart';
import '../inference/models/species.dart';

/// A snapshot of inference settings active when a session was started.
class SessionSettings {
  const SessionSettings({
    required this.windowDuration,
    required this.confidenceThreshold,
    required this.inferenceRate,
    required this.speciesFilterMode,
    this.clipContextSeconds = 0,
    this.alertMode = 0,
    this.alertRareThreshold = 0.05,
    this.alertWatchlistName = '',
    this.alertMinConfidence = 0.5,
    this.alertStartupGraceSeconds = 60,
    this.alertMinIntervalSeconds = 15,
    this.alertMaxPerMinute = 3,
    this.alertCoalesce = true,
    this.sensitivity,
    this.ignoreBirds,
    this.ignoreMammals,
    this.ignoreAmphibians,
    this.ignoreInsects,
    this.ignoreCommonGeoScoreCutoff,
    this.poolingMode,
    this.poolingWindows,
    this.poolingMaxAgeSeconds,
    this.poolingAlpha,
    this.poolingMinSupportWindows,
    this.poolingSupportThresholdFraction,
    this.poolingSupportThresholdFloor,
    this.poolingVeryHighImmediateThreshold,
    this.gainLinear,
    this.highPassHz,
    this.recordingMode,
    this.recordingFormat,
    this.detectionSamplingMode,
    this.topNPerSpecies,
    this.gpsIntervalSeconds,
    this.maxDurationHours,
    this.targetDurationSeconds,
    this.autoStopBatteryPercent,
    this.backgroundGps,
  });

  /// Window duration in seconds.
  final int windowDuration;

  /// Confidence threshold (0–100 scale).
  final int confidenceThreshold;

  /// Inference rate in Hz.
  final double inferenceRate;

  /// Species filter mode ('off', 'geoExclude', 'geoAdaptive', 'geoMerge',
  /// 'customList').
  final String speciesFilterMode;

  /// Seconds of audio captured before AND after each detection window when
  /// per-detection clips are recorded (survey mode and similar). The clip
  /// duration is therefore `windowDuration + 2 * clipContextSeconds`, with
  /// the actual detection sitting at offsets
  /// `[clipContextSeconds, clipContextSeconds + windowDuration]` within
  /// the clip file.
  ///
  /// Stored on the session so exports can compute in-clip detection times
  /// for selection tables, even if the user later changes the global
  /// clip-context setting. Defaults to 0 for sessions that record one
  /// continuous file (live, point count, file analysis).
  final int clipContextSeconds;

  // ── Survey species alerts (v0.7.0+) ─────────────────────────────────
  // All snapshot fields default to safe values so legacy sessions
  // deserialized from disk produce a fully-populated `SessionSettings`
  // and the export bundle's metadata.json is always self-describing.

  /// Alert mode index. See `AlertMode` (0=off, 1=session, 2=ever, 3=rare,
  /// 4=watchlist).
  final int alertMode;

  /// Geo-model probability cutoff for the "rare" mode.
  final double alertRareThreshold;

  /// Selected watchlist name (empty if none).
  final String alertWatchlistName;

  /// Confidence floor below which alerts never fire.
  final double alertMinConfidence;

  /// Startup grace window in seconds.
  final int alertStartupGraceSeconds;

  /// Hard cooldown between any two delivered alerts.
  final int alertMinIntervalSeconds;

  /// Max delivered alerts per minute (`0` = unlimited).
  final int alertMaxPerMinute;

  /// Whether over-cap alerts are queued for a summary notification.
  final bool alertCoalesce;

  // ── Applied inference / DSP knobs (v0.11.4+) ─────────────────────
  // These mirror the values the controller actually applied to the
  // inference isolate / capture pipeline, so exports faithfully record
  // what produced the detections instead of pretending the user never
  // touched the defaults. All nullable so legacy sessions round-trip.

  /// Sensitivity offset applied to model probabilities in logit space
  /// (1.0 = neutral).
  final double? sensitivity;

  /// Inference-time binary species mask captured at session start.
  final bool? ignoreBirds;
  final bool? ignoreMammals;
  final bool? ignoreAmphibians;
  final bool? ignoreInsects;
  final double? ignoreCommonGeoScoreCutoff;

  /// Score pooling mode (`avg`, `max`, `lme`, `adaptive_lme_peak`, etc.)
  /// applied to the rolling
  /// detection window.
  final String? poolingMode;

  /// Number of inference windows pooled together (`null` = unlimited /
  /// session-wide).
  final int? poolingWindows;

  /// Maximum real-time age in seconds for windows included in score pooling.
  final double? poolingMaxAgeSeconds;

  // ── Advanced temporal-pooling knobs (LME alpha + support gate) ──────
  // Snapshot of the applied overrides so exports record exactly how the
  // temporal support gate was configured. All nullable so legacy sessions
  // round-trip and factory-default sessions can stay silent if desired.

  /// LME alpha applied to temporal pooling (higher weights recent peaks).
  final double? poolingAlpha;

  /// Recent windows required to clear the temporal support gate (`1` = gate
  /// disabled).
  final int? poolingMinSupportWindows;

  /// Fraction of the confidence threshold used as the per-window support
  /// threshold, before the floor.
  final double? poolingSupportThresholdFraction;

  /// Lower bound on the per-window support threshold.
  final double? poolingSupportThresholdFloor;

  /// Raw current-window score that bypasses multi-window support.
  final double? poolingVeryHighImmediateThreshold;

  /// Linear input gain applied before model inference (1.0 = unity).
  final double? gainLinear;

  /// High-pass filter cutoff in Hz (0 disables the filter).
  final double? highPassHz;

  /// Recording behavior applied for this session (`full`, `detections`, `off`).
  final String? recordingMode;

  /// Recording container/codec format applied for this session (`flac`, `wav`).
  final String? recordingFormat;

  /// Detection retention/sampling mode applied by survey-like workflows.
  final String? detectionSamplingMode;

  /// Per-species retention cap when [detectionSamplingMode] uses Top N/Smart.
  final int? topNPerSpecies;

  /// GPS sampling interval applied by Survey Mode.
  final int? gpsIntervalSeconds;

  /// Maximum survey duration applied by Survey Mode.
  final int? maxDurationHours;

  /// Target protocol duration applied by timer-based sessions.
  final int? targetDurationSeconds;

  /// Battery percentage threshold applied by Survey Mode (`0` disables).
  final int? autoStopBatteryPercent;

  /// Whether Survey Mode used background GPS tracking.
  final bool? backgroundGps;

  /// Deserialize from JSON.
  factory SessionSettings.fromJson(Map<String, dynamic> json) {
    return SessionSettings(
      windowDuration: json['windowDuration'] as int? ?? 3,
      confidenceThreshold: json['confidenceThreshold'] as int? ?? 25,
      inferenceRate: (json['inferenceRate'] as num?)?.toDouble() ?? 1.0,
      speciesFilterMode: json['speciesFilterMode'] as String? ?? 'off',
      clipContextSeconds: json['clipContextSeconds'] as int? ?? 0,
      alertMode: json['alertMode'] as int? ?? 0,
      alertRareThreshold:
          (json['alertRareThreshold'] as num?)?.toDouble() ?? 0.05,
      alertWatchlistName: json['alertWatchlistName'] as String? ?? '',
      alertMinConfidence:
          (json['alertMinConfidence'] as num?)?.toDouble() ?? 0.5,
      alertStartupGraceSeconds: json['alertStartupGraceSeconds'] as int? ?? 60,
      alertMinIntervalSeconds: json['alertMinIntervalSeconds'] as int? ?? 15,
      alertMaxPerMinute: json['alertMaxPerMinute'] as int? ?? 3,
      alertCoalesce: json['alertCoalesce'] as bool? ?? true,
      sensitivity: (json['sensitivity'] as num?)?.toDouble(),
      ignoreBirds: json['ignoreBirds'] as bool?,
      ignoreMammals: json['ignoreMammals'] as bool?,
      ignoreAmphibians: json['ignoreAmphibians'] as bool?,
      ignoreInsects: json['ignoreInsects'] as bool?,
      ignoreCommonGeoScoreCutoff:
          (json['ignoreCommonGeoScoreCutoff'] as num?)?.toDouble(),
      poolingMode: json['poolingMode'] as String?,
      poolingWindows: (json['poolingWindows'] as num?)?.toInt(),
      poolingMaxAgeSeconds: (json['poolingMaxAgeSeconds'] as num?)?.toDouble(),
      poolingAlpha: (json['poolingAlpha'] as num?)?.toDouble(),
      poolingMinSupportWindows:
          (json['poolingMinSupportWindows'] as num?)?.toInt(),
      poolingSupportThresholdFraction:
          (json['poolingSupportThresholdFraction'] as num?)?.toDouble(),
      poolingSupportThresholdFloor:
          (json['poolingSupportThresholdFloor'] as num?)?.toDouble(),
      poolingVeryHighImmediateThreshold:
          (json['poolingVeryHighImmediateThreshold'] as num?)?.toDouble(),
      gainLinear: (json['gainLinear'] as num?)?.toDouble(),
      highPassHz: (json['highPassHz'] as num?)?.toDouble(),
      recordingMode: json['recordingMode'] as String?,
      recordingFormat: json['recordingFormat'] as String?,
      detectionSamplingMode: json['detectionSamplingMode'] as String?,
      topNPerSpecies: (json['topNPerSpecies'] as num?)?.toInt(),
      gpsIntervalSeconds: (json['gpsIntervalSeconds'] as num?)?.toInt(),
      maxDurationHours: (json['maxDurationHours'] as num?)?.toInt(),
      targetDurationSeconds: (json['targetDurationSeconds'] as num?)?.toInt(),
      autoStopBatteryPercent: (json['autoStopBatteryPercent'] as num?)?.toInt(),
      backgroundGps: json['backgroundGps'] as bool?,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'windowDuration': windowDuration,
    'confidenceThreshold': confidenceThreshold,
    'inferenceRate': inferenceRate,
    'speciesFilterMode': speciesFilterMode,
    'clipContextSeconds': clipContextSeconds,
    'alertMode': alertMode,
    'alertRareThreshold': alertRareThreshold,
    'alertWatchlistName': alertWatchlistName,
    'alertMinConfidence': alertMinConfidence,
    'alertStartupGraceSeconds': alertStartupGraceSeconds,
    'alertMinIntervalSeconds': alertMinIntervalSeconds,
    'alertMaxPerMinute': alertMaxPerMinute,
    'alertCoalesce': alertCoalesce,
    if (sensitivity != null) 'sensitivity': sensitivity,
    if (ignoreBirds != null) 'ignoreBirds': ignoreBirds,
    if (ignoreMammals != null) 'ignoreMammals': ignoreMammals,
    if (ignoreAmphibians != null) 'ignoreAmphibians': ignoreAmphibians,
    if (ignoreInsects != null) 'ignoreInsects': ignoreInsects,
    if (ignoreCommonGeoScoreCutoff != null)
      'ignoreCommonGeoScoreCutoff': ignoreCommonGeoScoreCutoff,
    if (poolingMode != null) 'poolingMode': poolingMode,
    if (poolingWindows != null) 'poolingWindows': poolingWindows,
    if (poolingMaxAgeSeconds != null)
      'poolingMaxAgeSeconds': poolingMaxAgeSeconds,
    if (poolingAlpha != null) 'poolingAlpha': poolingAlpha,
    if (poolingMinSupportWindows != null)
      'poolingMinSupportWindows': poolingMinSupportWindows,
    if (poolingSupportThresholdFraction != null)
      'poolingSupportThresholdFraction': poolingSupportThresholdFraction,
    if (poolingSupportThresholdFloor != null)
      'poolingSupportThresholdFloor': poolingSupportThresholdFloor,
    if (poolingVeryHighImmediateThreshold != null)
      'poolingVeryHighImmediateThreshold': poolingVeryHighImmediateThreshold,
    if (gainLinear != null) 'gainLinear': gainLinear,
    if (highPassHz != null) 'highPassHz': highPassHz,
    if (recordingMode != null) 'recordingMode': recordingMode,
    if (recordingFormat != null) 'recordingFormat': recordingFormat,
    if (detectionSamplingMode != null)
      'detectionSamplingMode': detectionSamplingMode,
    if (topNPerSpecies != null) 'topNPerSpecies': topNPerSpecies,
    if (gpsIntervalSeconds != null) 'gpsIntervalSeconds': gpsIntervalSeconds,
    if (maxDurationHours != null) 'maxDurationHours': maxDurationHours,
    if (targetDurationSeconds != null)
      'targetDurationSeconds': targetDurationSeconds,
    if (autoStopBatteryPercent != null)
      'autoStopBatteryPercent': autoStopBatteryPercent,
    if (backgroundGps != null) 'backgroundGps': backgroundGps,
  };
}

/// The type of session (maps to one of the four app modes).
enum SessionType {
  /// Real-time microphone-based identification session.
  live,

  /// Offline analysis of an uploaded audio file.
  fileUpload,

  /// Timed point-count survey at a fixed location.
  pointCount,

  /// Background survey session with GPS tracking.
  survey,

  /// Bulk processing of audio files.
  batchAnalysis,

  /// Autonomous Recording Unit mode.
  aru,
}

/// Why a session ended.
///
/// Used primarily for survey sessions that can auto-stop on max duration
/// or low battery, but applicable to any session type. `null` means the
/// session was stopped manually or pre-dates this field.
enum SessionStopReason {
  /// User tapped Stop.
  manual,

  /// Configured maximum duration was reached.
  maxDuration,

  /// Battery dropped below the configured auto-stop threshold.
  lowBattery,
}

/// How a detection was created.
enum DetectionSource {
  /// Automatically detected by the inference model.
  auto,

  /// Manually added by the user in session review at a specific timestamp.
  manual,

  /// Manually added as a session-wide (global) annotation — not tied to a
  /// specific time window.
  manualGlobal,

  /// Free-text "Other (specify)" species typed by the user (e.g. "dog",
  /// "frog", "helicopter") rather than picked from the taxonomy. The
  /// scientific name is empty by convention; the user-supplied label
  /// lives in [DetectionRecord.commonName]. Treated like [manual] /
  /// [manualGlobal] for filtering and exports.
  userSpecified,
}

/// What the user based a manually-entered observation on.
///
/// Only ever set on records the user added by hand (any of the manual
/// [DetectionSource] values). Model detections leave it `null` — the model
/// only ever "hears" a bird, so tagging them would add no information — and
/// so do sessions recorded before this field existed.
enum DetectionEvidence {
  /// The user heard the bird but did not see it.
  heard,

  /// The user saw the bird but did not hear it.
  seen,

  /// The user both heard and saw the bird.
  heardAndSeen;

  /// Whether this evidence includes an acoustic observation.
  bool get includesHeard => this != seen;

  /// Whether this evidence includes a visual observation.
  bool get includesSeen => this != heard;

  /// Collapse two independent checkbox states into an evidence value.
  ///
  /// Returns `null` when neither box is ticked — "evidence not specified",
  /// which is the same state legacy manual records are in.
  static DetectionEvidence? fromFlags({
    required bool heard,
    required bool seen,
  }) {
    if (heard && seen) return DetectionEvidence.heardAndSeen;
    if (heard) return DetectionEvidence.heard;
    if (seen) return DetectionEvidence.seen;
    return null;
  }

  /// Parse a persisted [name], tolerating null / unknown values.
  static DetectionEvidence? fromName(String? name) => switch (name) {
    'heard' => DetectionEvidence.heard,
    'seen' => DetectionEvidence.seen,
    'heardAndSeen' => DetectionEvidence.heardAndSeen,
    _ => null,
  };
}

/// What a reviewer has decided about a detection's species identification.
///
/// Deliberately three-valued: "nobody has looked at this yet" is a different
/// claim from "a reviewer looked and judged the ID wrong", and collapsing the
/// two into a boolean makes every export assert the latter about detections
/// that are merely untouched.
enum ReviewStatus {
  /// No reviewer has passed judgement. The default for every detection, and
  /// the only honest answer for the vast majority of them.
  unreviewed,

  /// A reviewer confirmed the species identification, visually or
  /// acoustically.
  confirmed,

  /// A reviewer judged the species identification to be wrong.
  ///
  /// Fully persisted and exported, but no UI currently produces it — the
  /// review screen still toggles between [unreviewed] and [confirmed]. It
  /// exists so the export schema does not have to change again when an
  /// invalidate action lands.
  rejected;

  /// Parse a persisted [name], tolerating null / unknown values.
  ///
  /// Unknown values fall back to [unreviewed] rather than throwing, so a
  /// session written by a future build with more states still loads.
  static ReviewStatus fromName(String? name) => switch (name) {
    'confirmed' => ReviewStatus.confirmed,
    'rejected' => ReviewStatus.rejected,
    _ => ReviewStatus.unreviewed,
  };
}

/// A timestamped detection record for session persistence.
///
/// Unlike [Detection] (which holds a full [Species] object), this stores
/// only the essential fields needed for history display and export.
class DetectionRecord {
  DetectionRecord({
    required this.scientificName,
    required this.commonName,
    required this.confidence,
    required this.timestamp,
    this.endTimestamp,
    this.audioClipPath,
    this.clipTimestamp,
    this.source = DetectionSource.auto,
    this.evidence,
    this.latitude,
    this.longitude,
    this.reviewStatus = ReviewStatus.unreviewed,
    this.reviewedAt,
    this.note,
    this.voiceMemoPath,
  });

  /// Scientific name of the detected species.
  ///
  /// Use [unknownSpeciesName] for unknown / unidentifiable detections.
  final String scientificName;

  /// Common (vernacular) name of the detected species.
  final String commonName;

  /// Confidence score (0.0–1.0).
  final double confidence;

  /// Wall-clock time when this detection first crossed the active inference
  /// threshold.
  final DateTime timestamp;

  /// Wall-clock time when this species stopped appearing in active inference
  /// results (i.e. when the continuous detection window ended). May be `null`
  /// for:
  ///   * detections still in progress,
  ///   * legacy sessions saved before this field existed,
  ///   * manual annotations.
  ///
  /// When `null`, consumers should treat the detection as a single
  /// inference window starting at [timestamp].
  final DateTime? endTimestamp;

  /// Path to the saved audio clip for this detection (if available).
  ///
  /// Mutable: the survey detection sampler may clear this (and delete the
  /// underlying file) when an audio clip is dropped to enforce per-species
  /// or spatial caps. The detection record itself is always retained.
  String? audioClipPath;

  /// Start of the analysis window [audioClipPath] was cut from.
  ///
  /// [timestamp] and [endTimestamp] describe when the *bird* was heard — the
  /// full span the species stayed above threshold, which is the ecologically
  /// meaningful number and often far longer than any clip. This describes
  /// where the *audio* came from instead: a clip holds one analysis window,
  /// re-cut as the detection climbs to its confidence peak, so it generally
  /// sits somewhere in the middle of that span rather than at its start.
  ///
  /// Always kept in step with [audioClipPath], so it describes the file
  /// currently on disk. Only meaningful while [audioClipPath] is non-null.
  ///
  /// `null` for sessions recorded before clips followed the peak, where the
  /// clip was cut on arrival and [timestamp] is the correct fallback.
  DateTime? clipTimestamp;

  /// How this detection was created.
  final DetectionSource source;

  /// What the user based this observation on — heard, seen, or both.
  ///
  /// Only meaningful for manually-entered records; `null` for model
  /// detections, for legacy manual records saved before the heard/seen
  /// checkboxes existed, and whenever the user left both boxes unticked.
  /// Consumers must treat `null` as "not specified" rather than "not
  /// heard and not seen".
  final DetectionEvidence? evidence;

  /// Convenience: whether the user recorded an acoustic observation.
  bool get wasHeard => evidence?.includesHeard ?? false;

  /// Convenience: whether the user recorded a visual observation.
  bool get wasSeen => evidence?.includesSeen ?? false;

  /// GPS latitude at the time of detection (null if unavailable).
  final double? latitude;

  /// GPS longitude at the time of detection (null if unavailable).
  final double? longitude;

  /// What a reviewer has decided about this detection's identification.
  ///
  /// Defaults to [ReviewStatus.unreviewed] — review is opt-in, and most
  /// detections in a session are never touched. Consumers must not read
  /// "not confirmed" as "judged incorrect"; only [ReviewStatus.rejected]
  /// carries that claim.
  ///
  /// Mutable: set from the session-review UI via [markConfirmed],
  /// [markRejected] and [clearReview]. Persisted in JSON sessions and
  /// propagated to all export formats so external pipelines can filter on
  /// review state.
  ReviewStatus reviewStatus;

  /// UTC wall-clock time when the reviewer made the decision recorded in
  /// [reviewStatus]. `null` while [reviewStatus] is
  /// [ReviewStatus.unreviewed].
  DateTime? reviewedAt;

  /// Convenience: whether a reviewer confirmed this identification.
  bool get isConfirmed => reviewStatus == ReviewStatus.confirmed;

  /// Convenience: whether a reviewer judged this identification wrong.
  bool get isRejected => reviewStatus == ReviewStatus.rejected;

  /// Convenience: whether any reviewer decision has been recorded.
  bool get isReviewed => reviewStatus != ReviewStatus.unreviewed;

  /// Record that a reviewer confirmed this identification.
  ///
  /// [at] defaults to now; callers pass it explicitly when stamping a whole
  /// cluster so every record shares one timestamp.
  void markConfirmed({DateTime? at}) {
    reviewStatus = ReviewStatus.confirmed;
    reviewedAt = (at ?? DateTime.now()).toUtc();
  }

  /// Record that a reviewer judged this identification wrong.
  void markRejected({DateTime? at}) {
    reviewStatus = ReviewStatus.rejected;
    reviewedAt = (at ?? DateTime.now()).toUtc();
  }

  /// Drop any reviewer decision, returning the record to
  /// [ReviewStatus.unreviewed].
  void clearReview() {
    reviewStatus = ReviewStatus.unreviewed;
    reviewedAt = null;
  }

  /// Free-form text note attached to this detection by the reviewer.
  ///
  /// Mutable: edited from the session-review UI. Persisted in JSON sessions
  /// and surfaced in CSV / Raven exports so external tools can carry the
  /// reviewer's commentary alongside the detection. `null` (rather than an
  /// empty string) when no note has ever been set, so legacy sessions
  /// round-trip cleanly.
  String? note;

  /// Convenience: whether this detection has a non-empty note.
  bool get hasNote => note != null && note!.trim().isNotEmpty;

  /// Path to the voice-memo audio file attached to this detection by the
  /// reviewer (e.g. an AAC/M4A recording of spoken commentary). Lives in
  /// the session's `recordings/<sessionId>/memos/` directory and is included
  /// in ZIP bundle exports under `memos/`.
  ///
  /// Mutable: set / cleared from the session-review UI. `null` (rather than
  /// an empty string) when no memo has ever been recorded, so legacy
  /// sessions round-trip cleanly.
  String? voiceMemoPath;

  /// Convenience: whether this detection has a voice memo attached.
  bool get hasVoiceMemo => voiceMemoPath != null && voiceMemoPath!.isNotEmpty;

  /// Scientific name placeholder for unknown / unidentifiable species.
  static const String unknownSpeciesName = 'Unknown species';

  /// Common name placeholder for unknown / unidentifiable species.
  static const String unknownCommonName = 'Unknown / Other';

  /// Whether this represents an unknown species.
  bool get isUnknown => scientificName == unknownSpeciesName;

  /// Create from a live [Detection].
  factory DetectionRecord.fromDetection(
    Detection detection, {
    String? audioClipPath,
    DateTime? clipTimestamp,
  }) {
    return DetectionRecord(
      scientificName: detection.species.scientificName,
      commonName: detection.species.commonName,
      confidence: detection.confidence,
      timestamp: detection.timestamp ?? DateTime.now(),
      audioClipPath: audioClipPath,
      clipTimestamp: audioClipPath == null ? null : clipTimestamp,
    );
  }

  /// Deserialize from JSON.
  factory DetectionRecord.fromJson(Map<String, dynamic> json) {
    final audioClipPath = json['audioClipPath'] as String?;
    return DetectionRecord(
      scientificName: json['scientificName'] as String,
      commonName: json['commonName'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      endTimestamp:
          json['endTimestamp'] != null
              ? DateTime.parse(json['endTimestamp'] as String)
              : null,
      audioClipPath: audioClipPath,
      clipTimestamp:
          audioClipPath != null && json['clipTimestamp'] != null
              ? DateTime.parse(json['clipTimestamp'] as String)
              : null,
      source: switch (json['source'] as String?) {
        'manual' => DetectionSource.manual,
        'manualGlobal' => DetectionSource.manualGlobal,
        'userSpecified' => DetectionSource.userSpecified,
        _ => DetectionSource.auto,
      },
      evidence: DetectionEvidence.fromName(json['evidence'] as String?),
      latitude: (json['detLat'] as num?)?.toDouble(),
      longitude: (json['detLon'] as num?)?.toDouble(),
      // Sessions written before review became three-valued carry only
      // `confirmedAt`, where a non-null value meant confirmed. Prefer the
      // explicit status when present and fall back to that legacy shape so
      // older sessions keep their confirmations.
      reviewStatus:
          json['reviewStatus'] != null
              ? ReviewStatus.fromName(json['reviewStatus'] as String?)
              : (json['confirmedAt'] != null
                  ? ReviewStatus.confirmed
                  : ReviewStatus.unreviewed),
      reviewedAt: switch (json['reviewedAt'] ?? json['confirmedAt']) {
        final String stamp => DateTime.parse(stamp),
        _ => null,
      },
      note: json['note'] as String?,
      voiceMemoPath: json['voiceMemoPath'] as String?,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'scientificName': scientificName,
    'commonName': commonName,
    'confidence': confidence,
    'timestamp': timestamp.toUtc().toIso8601String(),
    if (endTimestamp != null)
      'endTimestamp': endTimestamp!.toUtc().toIso8601String(),
    if (audioClipPath != null) 'audioClipPath': audioClipPath,
    if (audioClipPath != null && clipTimestamp != null)
      'clipTimestamp': clipTimestamp!.toUtc().toIso8601String(),
    if (source != DetectionSource.auto) 'source': source.name,
    if (evidence != null) 'evidence': evidence!.name,
    if (latitude != null) 'detLat': latitude,
    if (longitude != null) 'detLon': longitude,
    if (isReviewed) 'reviewStatus': reviewStatus.name,
    if (reviewedAt != null) 'reviewedAt': reviewedAt!.toUtc().toIso8601String(),
    // Legacy mirror: a build older than the three-state change reads only
    // `confirmedAt`, so keep writing it for confirmed records. Without this,
    // rolling back to such a build silently drops every confirmation. Safe to
    // remove a couple of releases after 1.1.1.
    if (isConfirmed && reviewedAt != null)
      'confirmedAt': reviewedAt!.toUtc().toIso8601String(),
    if (hasNote) 'note': note,
    if (hasVoiceMemo) 'voiceMemoPath': voiceMemoPath,
  };

  /// Confidence expressed as a percentage string, e.g. "87.3 %".
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)} %';

  @override
  String toString() => 'DetectionRecord($commonName, $confidencePercent)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectionRecord &&
          runtimeType == other.runtimeType &&
          scientificName == other.scientificName &&
          confidence == other.confidence &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(scientificName, confidence, timestamp);
}

/// A user-created annotation associated with a session.
///
/// Annotations can describe environmental conditions, location context,
/// or any observation the user wants to record alongside the audio. They
/// may carry free-form text, a recorded voice memo (`.m4a`), or both —
/// memo-only annotations have an empty [text] and a non-null
/// [voiceMemoPath].
class SessionAnnotation {
  const SessionAnnotation({
    required this.text,
    required this.createdAt,
    this.title = '',
    this.offsetInRecording,
    this.voiceMemoPath,
  });

  /// Optional short label shown on the annotation chip in Session Review
  /// and in exports. Especially useful for voice-memo-only entries (which
  /// have an empty [text]) and for global text annotations whose body
  /// would otherwise overflow the chip. May be empty.
  final String title;

  /// Free-form annotation text. May be empty when the annotation is a
  /// memo-only entry (in that case [voiceMemoPath] is non-null).
  final String text;

  /// When the annotation was created.
  final DateTime createdAt;

  /// Optional offset (seconds from session start) this annotation refers to.
  /// When null, the annotation is considered session-global.
  final double? offsetInRecording;

  /// Absolute path to a recorded voice-memo file (`.m4a`) attached to
  /// this annotation, or `null` when the annotation is text-only.
  final String? voiceMemoPath;

  /// Whether this annotation has an attached voice memo.
  bool get hasVoiceMemo =>
      voiceMemoPath != null && voiceMemoPath!.trim().isNotEmpty;

  factory SessionAnnotation.fromJson(Map<String, dynamic> json) {
    return SessionAnnotation(
      text: json['text'] as String,
      title: (json['title'] as String?) ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      offsetInRecording: (json['offsetInRecording'] as num?)?.toDouble(),
      voiceMemoPath: json['voiceMemoPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    if (title.isNotEmpty) 'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (offsetInRecording != null) 'offsetInRecording': offsetInRecording,
    if (voiceMemoPath != null) 'voiceMemoPath': voiceMemoPath,
  };
}

/// Status of an ARU recording cycle.
enum AruCycleStatus {
  /// Planned but not reached yet.
  scheduled,

  /// Currently recording.
  recording,

  /// Completed normally.
  completed,

  /// Partially recorded before a stop, crash, or deployment end.
  partial,

  /// Stopped by the user or an expected guard such as low battery/storage.
  stopped,

  /// Skipped without recording because the battery was below the pause
  /// threshold for the whole cycle window (see ARU low-battery pause/resume).
  skipped,
}

/// Persisted metadata for one ARU cycle.
class AruCycleMetadata {
  const AruCycleMetadata({
    required this.index,
    required this.plannedStart,
    required this.plannedEnd,
    this.actualStart,
    this.actualEnd,
    this.status = AruCycleStatus.scheduled,
    this.recordingPath,
    this.detectionCount = 0,
    this.retainedClipCount = 0,
    this.droppedClipCount = 0,
    this.note,
  });

  final int index;
  final DateTime plannedStart;
  final DateTime plannedEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final AruCycleStatus status;
  final String? recordingPath;
  final int detectionCount;
  final int retainedClipCount;
  final int droppedClipCount;
  final String? note;

  factory AruCycleMetadata.fromJson(Map<String, dynamic> json) {
    return AruCycleMetadata(
      index: (json['index'] as num).toInt(),
      plannedStart: DateTime.parse(json['plannedStart'] as String),
      plannedEnd: DateTime.parse(json['plannedEnd'] as String),
      actualStart:
          json['actualStart'] != null
              ? DateTime.parse(json['actualStart'] as String)
              : null,
      actualEnd:
          json['actualEnd'] != null
              ? DateTime.parse(json['actualEnd'] as String)
              : null,
      status: AruCycleStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String?),
        orElse: () => AruCycleStatus.scheduled,
      ),
      recordingPath: json['recordingPath'] as String?,
      detectionCount: (json['detectionCount'] as num?)?.toInt() ?? 0,
      retainedClipCount: (json['retainedClipCount'] as num?)?.toInt() ?? 0,
      droppedClipCount: (json['droppedClipCount'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'plannedStart': plannedStart.toUtc().toIso8601String(),
    'plannedEnd': plannedEnd.toUtc().toIso8601String(),
    if (actualStart != null)
      'actualStart': actualStart!.toUtc().toIso8601String(),
    if (actualEnd != null) 'actualEnd': actualEnd!.toUtc().toIso8601String(),
    if (status != AruCycleStatus.scheduled) 'status': status.name,
    if (recordingPath != null) 'recordingPath': recordingPath,
    if (detectionCount > 0) 'detectionCount': detectionCount,
    if (retainedClipCount > 0) 'retainedClipCount': retainedClipCount,
    if (droppedClipCount > 0) 'droppedClipCount': droppedClipCount,
    if (note != null && note!.trim().isNotEmpty) 'note': note,
  };
}

/// Persisted metadata for an ARU deployment session.
class AruDeploymentMetadata {
  AruDeploymentMetadata({
    required this.scheduleStart,
    required this.cycleDurationSeconds,
    required this.repeatIntervalSeconds,
    this.deploymentName,
    this.stationId,
    this.scheduleEnd,
    this.maxCycles,
    this.lowBatteryStopPercent,
    this.lowBatteryResumePercent,
    this.dielPattern = AruDielPattern.anyTime,
    this.latitude,
    this.longitude,
    this.recordingMode = 'full',
    this.recordingFormat = 'flac',
    this.samplingMode = 'smart',
    this.topNPerSpecies = 10,
    this.testCycleEnabled = false,
    required this.eachCycleIsSession,
    List<AruCycleMetadata>? cycles,
  }) : cycles = cycles ?? [];

  final String? deploymentName;
  final String? stationId;
  final DateTime scheduleStart;
  final int cycleDurationSeconds;
  final int repeatIntervalSeconds;
  final DateTime? scheduleEnd;
  final int? maxCycles;
  final int? lowBatteryStopPercent;
  final int? lowBatteryResumePercent;
  final AruDielPattern dielPattern;
  final double? latitude;
  final double? longitude;
  final String recordingMode;
  final String recordingFormat;
  final String samplingMode;
  final int topNPerSpecies;
  final bool testCycleEnabled;
  final bool eachCycleIsSession;
  final List<AruCycleMetadata> cycles;

  AruScheduleConfig toScheduleConfig() {
    return AruScheduleConfig(
      startTime: scheduleStart,
      cycleDuration: Duration(seconds: cycleDurationSeconds),
      repeatInterval: Duration(seconds: repeatIntervalSeconds),
      endTime: scheduleEnd,
      maxCycles: maxCycles,
      lowBatteryStopPercent: lowBatteryStopPercent,
      dielPattern: dielPattern,
      testCycleEnabled: testCycleEnabled,
      latitude: latitude,
      longitude: longitude,
    );
  }

  factory AruDeploymentMetadata.fromJson(Map<String, dynamic> json) {
    return AruDeploymentMetadata(
      deploymentName: json['deploymentName'] as String?,
      stationId: json['stationId'] as String?,
      scheduleStart: DateTime.parse(json['scheduleStart'] as String),
      cycleDurationSeconds: (json['cycleDurationSeconds'] as num).toInt(),
      repeatIntervalSeconds: (json['repeatIntervalSeconds'] as num).toInt(),
      scheduleEnd:
          json['scheduleEnd'] != null
              ? DateTime.parse(json['scheduleEnd'] as String)
              : null,
      maxCycles: (json['maxCycles'] as num?)?.toInt(),
      lowBatteryStopPercent: (json['lowBatteryStopPercent'] as num?)?.toInt(),
      lowBatteryResumePercent:
          (json['lowBatteryResumePercent'] as num?)?.toInt(),
      dielPattern: AruDielPattern.values.firstWhere(
        (p) => p.name == (json['dielPattern'] as String?),
        orElse: () => AruDielPattern.anyTime,
      ),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      recordingMode: json['recordingMode'] as String? ?? 'full',
      recordingFormat: json['recordingFormat'] as String? ?? 'flac',
      samplingMode: json['samplingMode'] as String? ?? 'smart',
      topNPerSpecies: (json['topNPerSpecies'] as num?)?.toInt() ?? 10,
      testCycleEnabled: json['testCycleEnabled'] as bool? ?? false,
      eachCycleIsSession: json['eachCycleIsSession'] as bool? ?? false,
      cycles:
          (json['cycles'] as List<dynamic>?)
              ?.map((c) => AruCycleMetadata.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    if (deploymentName != null && deploymentName!.trim().isNotEmpty)
      'deploymentName': deploymentName,
    if (stationId != null && stationId!.trim().isNotEmpty)
      'stationId': stationId,
    'scheduleStart': scheduleStart.toUtc().toIso8601String(),
    'cycleDurationSeconds': cycleDurationSeconds,
    'repeatIntervalSeconds': repeatIntervalSeconds,
    if (scheduleEnd != null)
      'scheduleEnd': scheduleEnd!.toUtc().toIso8601String(),
    if (maxCycles != null) 'maxCycles': maxCycles,
    if (lowBatteryStopPercent != null)
      'lowBatteryStopPercent': lowBatteryStopPercent,
    if (lowBatteryResumePercent != null)
      'lowBatteryResumePercent': lowBatteryResumePercent,
    if (dielPattern != AruDielPattern.anyTime) 'dielPattern': dielPattern.name,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    'recordingMode': recordingMode,
    'recordingFormat': recordingFormat,
    'samplingMode': samplingMode,
    'topNPerSpecies': topNPerSpecies,
    if (testCycleEnabled) 'testCycleEnabled': testCycleEnabled,
    if (eachCycleIsSession) 'eachCycleIsSession': eachCycleIsSession,
    if (cycles.isNotEmpty) 'cycles': cycles.map((c) => c.toJson()).toList(),
  };
}

/// A complete live identification session.
class LiveSession {
  LiveSession({
    required this.id,
    required this.startTime,
    this.type = SessionType.live,
    this.sessionNumber,
    this.customName,
    this.endTime,
    List<DetectionRecord>? detections,
    this.recordingPath,
    required this.settings,
    List<SessionAnnotation>? annotations,
    this.trimStartSec,
    this.trimEndSec,
    this.latitude,
    this.longitude,
    this.locationName,
    List<GpsPoint>? gpsTrack,
    this.distanceMeters,
    this.transectId,
    this.observerName,
    this.stopReason,
    this.stopReasonValue,
    this.weather,
    this.aruMetadata,
    int? recordedDurationSeconds,
    List<SessionSegment>? segments,
  }) : detections = detections ?? [],
       annotations = annotations ?? [],
       gpsTrack = gpsTrack ?? [],
       segments = segments ?? [],
       _recordedDurationSeconds = recordedDurationSeconds;

  /// Unique session identifier (ISO 8601 timestamp-based).
  final String id;

  /// The type of session (live, file upload, point count, survey).
  SessionType type;

  /// Sequential session number within this [type] (starting at 1).
  ///
  /// Assigned when the session is first saved.  Legacy sessions that
  /// pre-date this field will have `null`.
  int? sessionNumber;

  /// User-defined session name (e.g. "Morning walk").
  ///
  /// When set, overrides the auto-generated numbered title for display
  /// and export filenames.
  String? customName;

  /// When the session started.
  final DateTime startTime;

  /// When the session ended (`null` while active).
  DateTime? endTime;

  /// All detections recorded during this session.
  final List<DetectionRecord> detections;

  /// Path to the full recording file (if recording was enabled).
  String? recordingPath;

  /// Inference settings that were active during this session.
  final SessionSettings settings;

  /// User annotations (environmental notes, observations, etc.).
  final List<SessionAnnotation> annotations;

  /// Trim start offset in seconds from the original recording start.
  ///
  /// When non-null, audio and detections before this offset are excluded
  /// from exports and the review timeline.
  double? trimStartSec;

  /// Trim end offset in seconds from the original recording start.
  ///
  /// When non-null, audio and detections after this offset are excluded.
  double? trimEndSec;

  /// Recording location latitude (null if location unavailable).
  double? latitude;

  /// Recording location longitude (null if location unavailable).
  double? longitude;

  /// Reverse-geocoded location name (e.g. "Berlin, Germany").
  ///
  /// Populated on first review when internet is available.
  String? locationName;

  /// GPS track recorded during a survey (empty for other session types).
  final List<GpsPoint> gpsTrack;

  /// Total distance walked in meters (computed from gpsTrack).
  double? distanceMeters;

  /// Transect / route identifier for repeat surveys.
  String? transectId;

  /// Name of the observer (remembered across sessions).
  String? observerName;

  /// Why the session ended. `null` for legacy sessions or sessions still
  /// active. Surveys set this when they auto-stop.
  SessionStopReason? stopReason;

  /// Numeric value associated with [stopReason] (e.g. battery % for
  /// [SessionStopReason.lowBattery], or duration hours for
  /// [SessionStopReason.maxDuration]). `null` when not applicable.
  num? stopReasonValue;

  /// Optional weather snapshot captured once at session save time when
  /// the user has consented to weather lookups (see
  /// `PrefKeys.privacyAllowWeather`) and a recording location is
  /// available. `null` for legacy sessions, sessions without a
  /// location, or when the Open-Meteo lookup failed; the UI must
  /// degrade gracefully.
  WeatherSnapshot? weather;

  /// Optional ARU deployment metadata. Present only for [SessionType.aru]
  /// sessions created by ARU Mode.
  AruDeploymentMetadata? aruMetadata;

  /// Persisted total of seconds during which the session was actively
  /// recording, **excluding** any pause/resume gaps. `null` for legacy
  /// sessions saved before this field existed; in that case [duration] is
  /// used as an approximation. Accumulated by the controller via
  /// [accumulateRecordedSeconds] each time a recording segment ends.
  /// List of active recording segments during this session.
  final List<SessionSegment> segments;

  int? _recordedDurationSeconds;

  /// Total recorded seconds, or `null` if not yet tracked.
  int? get recordedDurationSeconds => _recordedDurationSeconds;

  /// Add [seconds] to the accumulated recorded duration. Called by the
  /// controller whenever a recording segment ends (manual stop, pause,
  /// auto-stop, or right before a resume opens a new segment).
  void accumulateRecordedSeconds(int seconds) {
    if (seconds <= 0) return;
    _recordedDurationSeconds = (_recordedDurationSeconds ?? 0) + seconds;
  }

  /// Whether this session is still active (no end time).
  bool get isActive => endTime == null;

  /// Human-readable session name for display in the UI.
  ///
  /// Format: `Session_2026-03-30_14-30-00_#123`
  /// Falls back to timestamp only for legacy sessions without a number.
  String get displayName {
    if (customName != null && customName!.isNotEmpty) {
      return customName!;
    }
    final dt = DateFormat('yyyy-MM-dd_HH-mm-ss').format(startTime.toLocal());
    final suffix = sessionNumber != null ? '_#$sessionNumber' : '';
    return 'Session_$dt$suffix';
  }

  /// Duration of the session.
  ///
  /// Prefers the accumulated [recordedDurationSeconds] when available so
  /// that resumed sessions report their *actual recorded* time rather than
  /// wall-clock time spanning resume gaps. Falls back to wall-clock for
  /// legacy sessions and for active sessions before the first segment is
  /// accumulated.
  Duration get duration {
    final recorded = _recordedDurationSeconds;
    if (recorded != null) {
      // Include the currently active segment (if any). Without this,
      // resumed sessions show a static elapsed time until the next pause/stop
      // persists another closed segment.
      Duration activeSegment = Duration.zero;
      if (endTime == null && segments.isNotEmpty) {
        final last = segments.last;
        if (last.endTime == null) {
          activeSegment = DateTime.now().difference(last.startTime);
          if (activeSegment.isNegative) activeSegment = Duration.zero;
        }
      }
      return Duration(seconds: recorded) + activeSegment;
    }
    return (endTime ?? DateTime.now()).difference(startTime);
  }

  /// Expected length of the concatenated recorded audio in seconds, with
  /// pause/resume gaps removed.
  ///
  /// Used to detect a truncated recording (an audio file that ends before the
  /// session's latest event) without falsely flagging resumed sessions, whose
  /// wall-clock span includes the stopped gap. Shared by the export and
  /// Session Review integrity checks so both agree.
  double get expectedRecordedAudioSeconds {
    if (segments.isNotEmpty) {
      // Segment timestamps retain sub-second precision and collapse resume
      // gaps, so they are the closest model of the concatenated audio.
      return absoluteToRelative(endTime ?? DateTime.now());
    }
    // No segments: fall back to the accumulated recorded seconds, else the
    // wall-clock span, then extend to cover any detection that ends later.
    final recorded = _recordedDurationSeconds?.toDouble();
    final end = endTime;
    var expected =
        recorded != null && recorded > 0
            ? recorded
            : end == null
            ? 0.0
            : end.difference(startTime).inMicroseconds / 1e6;
    for (final detection in detections) {
      final eventEnd = detection.endTimestamp ?? detection.timestamp;
      final rel = absoluteToRelative(eventEnd);
      if (rel > expected) expected = rel;
    }
    return expected;
  }

  /// Number of unique species detected.
  int get uniqueSpeciesCount =>
      detections.map((d) => d.scientificName).toSet().length;

  // Maximum number of detection records kept in memory per session.
  // At ~1 Hz inference this allows >2.7 hours of continuous recording.
  static const int _maxDetections = 10000;

  /// Add a detection to the session.
  void addDetection(DetectionRecord record) {
    if (detections.length < _maxDetections) {
      detections.add(_clampToSession(record));
    }
  }

  /// Add multiple detections from a single inference cycle.
  void addDetections(List<DetectionRecord> records) {
    final remaining = _maxDetections - detections.length;
    if (remaining > 0) {
      detections.addAll(records.take(remaining).map(_clampToSession));
    }
  }

  /// Clamp a record's timestamp(s) to be `>= startTime` so detections
  /// emitted slightly before the recorder fully spun up cannot produce
  /// negative session-relative offsets (e.g. "00:-1") downstream.
  DetectionRecord _clampToSession(DetectionRecord r) {
    // The clip's own window can start before the session when a detection
    // lands in the pre-roll; clamp it on the same rule so it can never
    // produce a negative offset downstream. Done in place — [clipTimestamp]
    // is mutable, and letting it trigger the copy below would hand back a
    // different instance than the detection sampler is holding, so a later
    // eviction would clear the clip on an orphan and leave the session's
    // record pointing at a deleted file.
    if (r.clipTimestamp != null && r.clipTimestamp!.isBefore(startTime)) {
      r.clipTimestamp = startTime;
    }
    final needsTs = r.timestamp.isBefore(startTime);
    final needsEnd =
        r.endTimestamp != null && r.endTimestamp!.isBefore(startTime);
    if (!needsTs && !needsEnd) return r;
    final clampedTs = needsTs ? startTime : r.timestamp;
    final clampedEnd = needsEnd ? startTime : r.endTimestamp;
    return DetectionRecord(
      scientificName: r.scientificName,
      commonName: r.commonName,
      confidence: r.confidence,
      timestamp: clampedTs,
      endTimestamp: clampedEnd,
      audioClipPath: r.audioClipPath,
      clipTimestamp: r.clipTimestamp,
      source: r.source,
      evidence: r.evidence,
      latitude: r.latitude,
      longitude: r.longitude,
      reviewStatus: r.reviewStatus,
      reviewedAt: r.reviewedAt,
      note: r.note,
      voiceMemoPath: r.voiceMemoPath,
    );
  }

  /// End the session.
  void end() {
    endTime ??= DateTime.now();
  }

  /// Deserialize from JSON.
  factory LiveSession.fromJson(Map<String, dynamic> json) {
    return LiveSession(
      id: json['id'] as String,
      type: SessionType.values.firstWhere(
        (t) => t.name == (json['type'] as String?),
        orElse: () => SessionType.live,
      ),
      sessionNumber: json['sessionNumber'] as int?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime:
          json['endTime'] != null
              ? DateTime.parse(json['endTime'] as String)
              : null,
      detections:
          (json['detections'] as List<dynamic>?)
              ?.map((d) => DetectionRecord.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      recordingPath: json['recordingPath'] as String?,
      settings: SessionSettings.fromJson(
        json['settings'] as Map<String, dynamic>? ?? {},
      ),
      annotations:
          (json['annotations'] as List<dynamic>?)
              ?.map(
                (a) => SessionAnnotation.fromJson(a as Map<String, dynamic>),
              )
              .toList() ??
          [],
      trimStartSec: (json['trimStartSec'] as num?)?.toDouble(),
      trimEndSec: (json['trimEndSec'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationName: json['locationName'] as String?,
      customName: json['customName'] as String?,
      gpsTrack:
          (json['gpsTrack'] as List<dynamic>?)
              ?.map((p) => GpsPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      transectId: json['transectId'] as String?,
      observerName: json['observerName'] as String?,
      stopReason:
          json['stopReason'] != null
              ? SessionStopReason.values.firstWhere(
                (r) => r.name == (json['stopReason'] as String),
                orElse: () => SessionStopReason.manual,
              )
              : null,
      stopReasonValue: json['stopReasonValue'] as num?,
      recordedDurationSeconds:
          (json['recordedDurationSeconds'] as num?)?.toInt(),
      segments:
          (json['segments'] as List<dynamic>?)
              ?.map((s) => SessionSegment.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      aruMetadata:
          json['aru'] != null
              ? AruDeploymentMetadata.fromJson(
                json['aru'] as Map<String, dynamic>,
              )
              : null,
    )..weather = WeatherSnapshot.fromJson(json['weather']);
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'id': id,
    if (type != SessionType.live) 'type': type.name,
    if (sessionNumber != null) 'sessionNumber': sessionNumber,
    'startTime': startTime.toUtc().toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toUtc().toIso8601String(),
    'detections': detections.map((d) => d.toJson()).toList(),
    if (recordingPath != null) 'recordingPath': recordingPath,
    'settings': settings.toJson(),
    if (annotations.isNotEmpty)
      'annotations': annotations.map((a) => a.toJson()).toList(),
    if (trimStartSec != null) 'trimStartSec': trimStartSec,
    if (trimEndSec != null) 'trimEndSec': trimEndSec,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (locationName != null) 'locationName': locationName,
    if (customName != null) 'customName': customName,
    if (gpsTrack.isNotEmpty)
      'gpsTrack': gpsTrack.map((p) => p.toJson()).toList(),
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (transectId != null) 'transectId': transectId,
    if (observerName != null) 'observerName': observerName,
    if (stopReason != null) 'stopReason': stopReason!.name,
    if (stopReasonValue != null) 'stopReasonValue': stopReasonValue,
    if (weather != null) 'weather': weather!.toJson(),
    if (_recordedDurationSeconds != null)
      'recordedDurationSeconds': _recordedDurationSeconds,
    if (segments.isNotEmpty) 'segments': segments.map(_segmentToJson).toList(),
    if (aruMetadata != null) 'aru': aruMetadata!.toJson(),
  };

  @override
  String toString() =>
      'LiveSession($id, ${detections.length} detections, '
      '$uniqueSpeciesCount species)';

  /// Starts a new active recording segment.
  void startSegment() {
    if (endTime != null) return;
    final now = DateTime.now();
    if (segments.isNotEmpty) {
      final last = segments.last;
      final lastEnd = last.endTime;
      if (lastEnd != null && now.difference(lastEnd).inSeconds <= 2) {
        // Resume/extend the last segment instead of starting a new one,
        // because it was closed just for a periodic persist tick or a very brief pause.
        last.endTime = null;
        return;
      }
    }
    segments.add(SessionSegment(startTime: now));
  }

  /// Reactivates an ended session and opens a distinct recording segment.
  ///
  /// A resume must never use [startSegment]'s short-gap merge behavior:
  /// [recordedDurationSeconds] already includes the closed segment, so
  /// reopening it would count that time twice. Legacy sessions without
  /// segment or accumulated-duration data are seeded from their original
  /// wall-clock span before the new segment starts.
  void resume() {
    final previousEnd = endTime;
    if (previousEnd == null) return;

    if (segments.isEmpty) {
      segments.add(SessionSegment(startTime: startTime, endTime: previousEnd));
    }
    _recordedDurationSeconds ??= segments.fold<int>(0, (total, segment) {
      final segmentEnd = segment.endTime ?? previousEnd;
      final seconds = segmentEnd.difference(segment.startTime).inSeconds;
      return total + (seconds > 0 ? seconds : 0);
    });

    endTime = null;
    segments.add(SessionSegment(startTime: DateTime.now()));
  }

  /// Closes the currently active recording segment.
  void closeSegment() {
    if (segments.isNotEmpty) {
      final last = segments.last;
      last.endTime ??= endTime ?? DateTime.now();
    }
  }

  /// Rebase this session's audio timeline after its recording file was
  /// physically cut down to `[startSec, endSec)` of the audio it used to
  /// hold.
  ///
  /// Detection timestamps are wall-clock instants and stay untouched — a bird
  /// sang when it sang, whatever we later did to the file. What changes is the
  /// *mapping* from those instants to offsets in the recording, and that lives
  /// entirely in [segments]: they are rewritten to describe only the stretches
  /// still on disk, so [absoluteToRelative] keeps returning the right offset
  /// without every caller having to learn about the trim.
  ///
  /// [startTime] is deliberately left alone. The session began when it began;
  /// it simply no longer keeps audio for all of it. That also keeps
  /// [displayName] and the library's ordering stable across a trim.
  ///
  /// Detections whose audio is entirely gone are dropped. Session Review
  /// already does this when the trim is applied, but a trim can also reach
  /// here straight from storage (saved by a build that only kept it as
  /// metadata), and a detection with no audio left would otherwise pile up
  /// at offset zero.
  ///
  /// Clears [trimStartSec] / [trimEndSec] — with the cut applied to the bytes,
  /// there is no pending trim left to describe.
  void applyDestructiveTrim({
    required double startSec,
    required double endSec,
  }) {
    final start = startSec < 0 ? 0.0 : startSec;
    final end = endSec < start ? start : endSec;

    // A session with no segments has the trivial timeline `ts - startTime`;
    // model it as one synthetic segment so both shapes share the walk below.
    final source =
        segments.isNotEmpty
            ? List<SessionSegment>.of(segments)
            : [SessionSegment(startTime: startTime, endTime: endTime)];

    // The recorder can flush a small tail beyond the session clock. The
    // caller passes the end of the audio that was actually written, so extend
    // the final timeline segment to cover that tail. Otherwise a valid cut
    // wholly inside those final samples would leave [retained] empty and the
    // already-shortened file would keep its old trim metadata.
    var sourceSeconds = 0.0;
    for (final segment in source) {
      final length =
          _effectiveSegmentEnd(
            segment,
          ).difference(segment.startTime).inMicroseconds /
          1e6;
      if (length > 0) sourceSeconds += length;
    }
    const maxRecorderClockTailSeconds = 5.0;
    final clockTailSeconds = end - sourceSeconds;
    if (source.isNotEmpty &&
        clockTailSeconds > 0 &&
        clockTailSeconds <= maxRecorderClockTailSeconds) {
      final lastIndex = source.length - 1;
      final last = source[lastIndex];
      final extendedEnd = _effectiveSegmentEnd(
        last,
      ).add(Duration(microseconds: (clockTailSeconds * 1e6).round()));
      source[lastIndex] = SessionSegment(
        startTime: last.startTime,
        endTime: extendedEnd,
      );
    }

    double sourceRelative(DateTime timestamp) {
      var offsetMicros = 0;
      for (final segment in source) {
        final segmentStart = segment.startTime;
        final segmentEnd = _effectiveSegmentEnd(segment);
        if (timestamp.isBefore(segmentStart)) break;
        if (!timestamp.isAfter(segmentEnd)) {
          offsetMicros += timestamp.difference(segmentStart).inMicroseconds;
          break;
        }
        offsetMicros += segmentEnd.difference(segmentStart).inMicroseconds;
      }
      return offsetMicros / 1e6;
    }

    final retained = <SessionSegment>[];
    var retainedSeconds = 0.0;
    var consumed = 0.0;
    for (final segment in source) {
      final segmentStart = segment.startTime;
      final segmentEnd = _effectiveSegmentEnd(segment);
      final length = segmentEnd.difference(segmentStart).inMicroseconds / 1e6;
      if (length <= 0) continue;

      final segmentFrom = consumed;
      final segmentTo = consumed + length;
      consumed = segmentTo;

      final from = segmentFrom > start ? segmentFrom : start;
      final to = segmentTo < end ? segmentTo : end;
      if (to <= from) continue;

      retainedSeconds += to - from;
      retained.add(
        SessionSegment(
          startTime: segmentStart.add(
            Duration(microseconds: ((from - segmentFrom) * 1e6).round()),
          ),
          endTime: segmentStart.add(
            Duration(microseconds: ((to - segmentFrom) * 1e6).round()),
          ),
        ),
      );
    }

    // Nothing survived the cut — leave the session alone rather than
    // publishing a timeline that maps every detection to zero.
    if (retained.isEmpty) return;

    // Resolve which detections keep audio *before* the segments are rewritten:
    // the overlap test reads offsets off the old timeline.
    final windowSec = settings.windowDuration.toDouble();
    final survivors = [
      for (final detection in detections)
        if (() {
          final detectionStart = sourceRelative(detection.timestamp);
          final detectionEnd =
              detection.endTimestamp == null
                  ? detectionStart + windowSec
                  : sourceRelative(detection.endTimestamp!);
          return detectionEnd > start && detectionStart < end;
        }())
          detection,
    ];

    segments
      ..clear()
      ..addAll(retained);
    if (survivors.length != detections.length) {
      detections
        ..clear()
        ..addAll(survivors);
    }
    for (var i = 0; i < annotations.length; i++) {
      final annotation = annotations[i];
      final offset = annotation.offsetInRecording;
      if (offset == null) continue;

      // Timed annotations index the recording rather than wall-clock time.
      // Keep retained markers aligned with the shorter file. Markers whose
      // audio was removed become session-global so their note or voice memo
      // is preserved without pointing at an unrelated sample.
      final rebasedOffset =
          offset >= start && offset < end ? offset - start : null;
      annotations[i] = SessionAnnotation(
        text: annotation.text,
        createdAt: annotation.createdAt,
        title: annotation.title,
        offsetInRecording: rebasedOffset,
        voiceMemoPath: annotation.voiceMemoPath,
      );
    }
    // Measure what the segments actually kept, not what the caller asked
    // for: a trim whose end runs past the recorded timeline retains less.
    _recordedDurationSeconds = retainedSeconds.round();
    trimStartSec = null;
    trimEndSec = null;
  }

  DateTime _effectiveSegmentEnd(SessionSegment segment) {
    return segment.endTime ?? endTime ?? DateTime.now();
  }

  Map<String, dynamic> _segmentToJson(SessionSegment segment) {
    final json = segment.toJson();
    if (endTime != null && segment.endTime == null) {
      json['endTime'] = endTime!.toUtc().toIso8601String();
    }
    return json;
  }

  /// Maps an absolute timestamp to a relative offset in seconds within the recorded audio.
  /// Returns 0.0 if the timestamp is before the session started or in a gap.
  double absoluteToRelative(DateTime timestamp) {
    if (segments.isEmpty) {
      final diff = timestamp.difference(startTime).inMicroseconds / 1e6;
      return diff < 0 ? 0.0 : diff;
    }

    double offsetMicros = 0;
    for (final seg in segments) {
      final start = seg.startTime;
      final end = _effectiveSegmentEnd(seg);

      if (timestamp.isBefore(start)) {
        break;
      }

      if (timestamp.isBefore(end) || timestamp == end) {
        offsetMicros += timestamp.difference(start).inMicroseconds;
        break;
      }

      offsetMicros += end.difference(start).inMicroseconds;
    }
    return offsetMicros / 1e6;
  }

  /// Maps a relative offset in seconds within the recorded audio back to an absolute timestamp.
  DateTime relativeToAbsolute(double relativeSec) {
    if (segments.isEmpty) {
      return startTime.add(Duration(microseconds: (relativeSec * 1e6).round()));
    }

    double targetMicros = relativeSec * 1e6;
    double accumulatedMicros = 0;

    for (final seg in segments) {
      final start = seg.startTime;
      final end = _effectiveSegmentEnd(seg);
      final segDurationMicros = end.difference(start).inMicroseconds;

      if (accumulatedMicros + segDurationMicros >= targetMicros) {
        final remainingMicros = targetMicros - accumulatedMicros;
        return start.add(Duration(microseconds: remainingMicros.round()));
      }

      accumulatedMicros += segDurationMicros;
    }

    if (segments.isNotEmpty) {
      final last = segments.last;
      final end = _effectiveSegmentEnd(last);
      final remainingMicros = targetMicros - accumulatedMicros;
      return end.add(Duration(microseconds: remainingMicros.round()));
    }

    return startTime.add(Duration(microseconds: (relativeSec * 1e6).round()));
  }
}

/// Represents an active recording segment during a live session.
class SessionSegment {
  final DateTime startTime;
  DateTime? endTime;

  SessionSegment({required this.startTime, this.endTime});

  factory SessionSegment.fromJson(Map<String, dynamic> json) {
    return SessionSegment(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime:
          json['endTime'] != null
              ? DateTime.parse(json['endTime'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toUtc().toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toUtc().toIso8601String(),
  };
}
