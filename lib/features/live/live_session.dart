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

import '../inference/models/detection.dart';
import '../inference/models/species.dart';

/// A snapshot of inference settings active when a session was started.
class SessionSettings {
  const SessionSettings({
    required this.windowDuration,
    required this.confidenceThreshold,
    required this.inferenceRate,
    required this.speciesFilterMode,
  });

  /// Window duration in seconds.
  final int windowDuration;

  /// Confidence threshold (0–100 scale).
  final int confidenceThreshold;

  /// Inference rate in Hz.
  final double inferenceRate;

  /// Species filter mode ('off', 'geoExclude', 'geoMerge', 'customList').
  final String speciesFilterMode;

  /// Deserialize from JSON.
  factory SessionSettings.fromJson(Map<String, dynamic> json) {
    return SessionSettings(
      windowDuration: json['windowDuration'] as int? ?? 3,
      confidenceThreshold: json['confidenceThreshold'] as int? ?? 25,
      inferenceRate: (json['inferenceRate'] as num?)?.toDouble() ?? 1.0,
      speciesFilterMode: json['speciesFilterMode'] as String? ?? 'off',
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'windowDuration': windowDuration,
        'confidenceThreshold': confidenceThreshold,
        'inferenceRate': inferenceRate,
        'speciesFilterMode': speciesFilterMode,
      };
}

/// A timestamped detection record for session persistence.
///
/// Unlike [Detection] (which holds a full [Species] object), this stores
/// only the essential fields needed for history display and export.
class DetectionRecord {
  const DetectionRecord({
    required this.scientificName,
    required this.commonName,
    required this.confidence,
    required this.timestamp,
    this.audioClipPath,
  });

  /// Scientific name of the detected species.
  final String scientificName;

  /// Common (vernacular) name of the detected species.
  final String commonName;

  /// Confidence score (0.0–1.0).
  final double confidence;

  /// Wall-clock time of the detection.
  final DateTime timestamp;

  /// Path to the saved audio clip for this detection (if available).
  final String? audioClipPath;

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
      audioClipPath: json['audioClipPath'] as String?,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'scientificName': scientificName,
        'commonName': commonName,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
        if (audioClipPath != null) 'audioClipPath': audioClipPath,
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

/// A complete live identification session.
class LiveSession {
  LiveSession({
    required this.id,
    required this.startTime,
    this.endTime,
    List<DetectionRecord>? detections,
    this.recordingPath,
    required this.settings,
  }) : detections = detections ?? [];

  /// Unique session identifier (ISO 8601 timestamp-based).
  final String id;

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

  /// Whether this session is still active (no end time).
  bool get isActive => endTime == null;

  /// Duration of the session.
  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  /// Number of unique species detected.
  int get uniqueSpeciesCount =>
      detections.map((d) => d.scientificName).toSet().length;

  /// Add a detection to the session.
  void addDetection(DetectionRecord record) {
    detections.add(record);
  }

  /// Add multiple detections from a single inference cycle.
  void addDetections(List<DetectionRecord> records) {
    detections.addAll(records);
  }

  /// End the session.
  void end() {
    endTime ??= DateTime.now();
  }

  /// Deserialize from JSON.
  factory LiveSession.fromJson(Map<String, dynamic> json) {
    return LiveSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      detections: (json['detections'] as List<dynamic>?)
              ?.map((d) => DetectionRecord.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      recordingPath: json['recordingPath'] as String?,
      settings: SessionSettings.fromJson(
        json['settings'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        'detections': detections.map((d) => d.toJson()).toList(),
        if (recordingPath != null) 'recordingPath': recordingPath,
        'settings': settings.toJson(),
      };

  @override
  String toString() => 'LiveSession($id, ${detections.length} detections, '
      '$uniqueSpeciesCount species)';
}
