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
    this.poolingMode,
    this.poolingWindows,
    this.gainLinear,
    this.highPassHz,
  });

  /// Window duration in seconds.
  final int windowDuration;

  /// Confidence threshold (0–100 scale).
  final int confidenceThreshold;

  /// Inference rate in Hz.
  final double inferenceRate;

  /// Species filter mode ('off', 'geoExclude', 'geoMerge', 'customList').
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

  /// Sensitivity multiplier applied to model logits (1.0 = neutral).
  final double? sensitivity;

  /// Score pooling mode (`avg`, `max`, `lme`, …) applied to the rolling
  /// detection window.
  final String? poolingMode;

  /// Number of inference windows pooled together (`null` = unlimited /
  /// session-wide).
  final int? poolingWindows;

  /// Linear input gain applied before model inference (1.0 = unity).
  final double? gainLinear;

  /// High-pass filter cutoff in Hz (0 disables the filter).
  final double? highPassHz;

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
      poolingMode: json['poolingMode'] as String?,
      poolingWindows: (json['poolingWindows'] as num?)?.toInt(),
      gainLinear: (json['gainLinear'] as num?)?.toDouble(),
      highPassHz: (json['highPassHz'] as num?)?.toDouble(),
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
    if (poolingMode != null) 'poolingMode': poolingMode,
    if (poolingWindows != null) 'poolingWindows': poolingWindows,
    if (gainLinear != null) 'gainLinear': gainLinear,
    if (highPassHz != null) 'highPassHz': highPassHz,
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
    this.source = DetectionSource.auto,
    this.latitude,
    this.longitude,
    this.confirmedAt,
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

  /// Wall-clock time when this detection first appeared.
  final DateTime timestamp;

  /// Wall-clock time when the species' card disappeared from the live
  /// view (i.e. when continuous detection ended). May be `null` for:
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

  /// How this detection was created.
  final DetectionSource source;

  /// GPS latitude at the time of detection (null if unavailable).
  final double? latitude;

  /// GPS longitude at the time of detection (null if unavailable).
  final double? longitude;

  /// UTC wall-clock time when a reviewer marked this detection as visually
  /// or acoustically confirmed. `null` means the detection has not been
  /// confirmed (the default state — confirmation is opt-in).
  ///
  /// Mutable: toggled from the session-review UI. Persisted in JSON
  /// sessions and propagated to all export formats so external pipelines
  /// can filter on confirmed-only detections.
  DateTime? confirmedAt;

  /// Convenience: whether this detection has been marked confirmed.
  bool get isConfirmed => confirmedAt != null;

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
  }) {
    return DetectionRecord(
      scientificName: detection.species.scientificName,
      commonName: detection.species.commonName,
      confidence: detection.confidence,
      timestamp: detection.timestamp ?? DateTime.now(),
      audioClipPath: audioClipPath,
    );
  }

  /// Deserialize from JSON.
  factory DetectionRecord.fromJson(Map<String, dynamic> json) {
    return DetectionRecord(
      scientificName: json['scientificName'] as String,
      commonName: json['commonName'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      endTimestamp:
          json['endTimestamp'] != null
              ? DateTime.parse(json['endTimestamp'] as String)
              : null,
      audioClipPath: json['audioClipPath'] as String?,
      source: switch (json['source'] as String?) {
        'manual' => DetectionSource.manual,
        'manualGlobal' => DetectionSource.manualGlobal,
        'userSpecified' => DetectionSource.userSpecified,
        _ => DetectionSource.auto,
      },
      latitude: (json['detLat'] as num?)?.toDouble(),
      longitude: (json['detLon'] as num?)?.toDouble(),
      confirmedAt:
          json['confirmedAt'] != null
              ? DateTime.parse(json['confirmedAt'] as String)
              : null,
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
    if (source != DetectionSource.auto) 'source': source.name,
    if (latitude != null) 'detLat': latitude,
    if (longitude != null) 'detLon': longitude,
    if (confirmedAt != null)
      'confirmedAt': confirmedAt!.toUtc().toIso8601String(),
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
      if (segments.isNotEmpty) {
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
      source: r.source,
      latitude: r.latitude,
      longitude: r.longitude,
      confirmedAt: r.confirmedAt,
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
    if (segments.isNotEmpty)
      'segments': segments.map((s) => s.toJson()).toList(),
  };

  @override
  String toString() =>
      'LiveSession($id, ${detections.length} detections, '
      '$uniqueSpeciesCount species)';

  /// Starts a new active recording segment.
  void startSegment() {
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

  /// Closes the currently active recording segment.
  void closeSegment() {
    if (segments.isNotEmpty) {
      final last = segments.last;
      last.endTime ??= DateTime.now();
    }
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
      final end = seg.endTime ?? DateTime.now();

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
      final end = seg.endTime ?? DateTime.now();
      final segDurationMicros = end.difference(start).inMicroseconds;

      if (accumulatedMicros + segDurationMicros >= targetMicros) {
        final remainingMicros = targetMicros - accumulatedMicros;
        return start.add(Duration(microseconds: remainingMicros.round()));
      }

      accumulatedMicros += segDurationMicros;
    }

    if (segments.isNotEmpty) {
      final last = segments.last;
      final end = last.endTime ?? DateTime.now();
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
