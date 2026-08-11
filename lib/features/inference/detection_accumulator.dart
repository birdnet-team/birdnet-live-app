// =============================================================================
// Detection accumulator — shared continuous-detection semantics for all modes
// =============================================================================

import 'package:flutter/foundation.dart';

import 'models/detection.dart';
import '../live/live_session.dart';

typedef DetectionRecordFactory =
    DetectionRecord Function(Detection detection, DateTime timestamp);

/// A newly-created or confidence-updated continuous detection.
class DetectionRecordChange {
  const DetectionRecordChange({
    required this.detection,
    required this.record,
    required this.previousConfidence,
    required this.isNew,
  });

  final Detection detection;
  final DetectionRecord record;
  final double previousConfidence;
  final bool isNew;
}

/// Changes produced by one ordered inference window.
class DetectionCycleResult {
  const DetectionCycleResult({
    required this.changes,
    required this.closedRecords,
  });

  final List<DetectionRecordChange> changes;
  final List<DetectionRecord> closedRecords;
}

class _ActiveDetection {
  _ActiveDetection(this.record, this.lastSeenWindowEnd);

  DetectionRecord record;
  DateTime lastSeenWindowEnd;
}

/// Converts per-window detections into canonical continuous session records.
///
/// Live, Point Count, Survey, and File Analysis deliberately present records
/// differently, but they must agree on when a detection begins, how its peak
/// changes, and when it ends. Keeping those rules here prevents mode-specific
/// controllers from drifting apart.
class DetectionAccumulator {
  DetectionAccumulator({
    required this.sessionStart,
    required this.records,
    this.maxRecords = 10000,
  }) {
    for (var index = 0; index < records.length; index++) {
      _recordIndexes.putIfAbsent(_keyOf(records[index]), () => index);
    }
  }

  final DateTime sessionStart;
  final List<DetectionRecord> records;

  /// Ceiling on new detections, or null for none.
  ///
  /// The live modes cap at the same 10000 records [LiveSession.addDetection]
  /// has always enforced — they run until the user stops them, so the list has
  /// to be bounded. File Analysis passes null: its input is a file of known
  /// length, and truncating its results would silently under-report what the
  /// recording contains.
  final int? maxRecords;
  final Map<String, _ActiveDetection> _active = {};

  /// Stable canonical index by species and start timestamp.
  ///
  /// File Analysis has no record cap, so repeatedly scanning its complete
  /// result list for every confidence update becomes quadratic on long files.
  /// Records are only appended or replaced in normal operation; [_indexOf]
  /// still validates cached entries and repairs them with a fallback scan so
  /// manual/external list mutations cannot make the index return a wrong row.
  final Map<(String, int), int> _recordIndexes = {};

  /// Whether the cap has already been reported, so a full session logs once
  /// rather than on every window.
  bool _reportedFull = false;

  Map<String, DetectionRecord> get activeRecords => Map.unmodifiable({
    for (final entry in _active.entries) entry.key: entry.value.record,
  });

  DetectionRecord? activeRecord(String scientificName) =>
      _active[scientificName]?.record;

  DetectionCycleResult processCycle({
    required List<Detection> detections,
    required DateTime windowEnd,
    DetectionRecordFactory? createRecord,
  }) {
    final currentNames = <String>{
      for (final detection in detections) detection.species.scientificName,
    };
    final closed = <DetectionRecord>[];

    for (final name in _active.keys.toList()) {
      if (currentNames.contains(name)) continue;
      final active = _active.remove(name)!;
      final replacement = copyDetectionRecord(
        active.record,
        endTimestamp: active.lastSeenWindowEnd,
      );
      _replaceCanonical(active.record, replacement);
      closed.add(replacement);
    }

    final changes = <DetectionRecordChange>[];
    for (final detection in detections) {
      final name = detection.species.scientificName;
      final active = _active[name];
      if (active == null) {
        if (_isFull) continue;
        final timestamp = _uniqueTimestamp(
          name,
          _clampTimestamp(detection.timestamp ?? windowEnd),
        );
        final record =
            createRecord?.call(detection, timestamp) ??
            DetectionRecord(
              scientificName: name,
              commonName: detection.species.commonName,
              confidence: detection.confidence,
              timestamp: timestamp,
            );
        records.add(record);
        _recordIndexes[_keyOf(record)] = records.length - 1;
        _active[name] = _ActiveDetection(record, windowEnd);
        changes.add(
          DetectionRecordChange(
            detection: detection,
            record: record,
            previousConfidence: detection.confidence,
            isNew: true,
          ),
        );
        continue;
      }

      active.lastSeenWindowEnd = windowEnd;
      final existing = active.record;
      if (detection.confidence <= existing.confidence) continue;

      final replacement = copyDetectionRecord(
        existing,
        confidence: detection.confidence,
      );
      _replaceCanonical(existing, replacement);
      active.record = replacement;
      changes.add(
        DetectionRecordChange(
          detection: detection,
          record: replacement,
          previousConfidence: existing.confidence,
          isNew: false,
        ),
      );
    }

    return DetectionCycleResult(changes: changes, closedRecords: closed);
  }

  /// Close every active record at its last analyzed supporting window.
  List<DetectionRecord> closeAll() {
    final closed = <DetectionRecord>[];
    for (final active in _active.values) {
      final replacement = copyDetectionRecord(
        active.record,
        endTimestamp: active.lastSeenWindowEnd,
      );
      _replaceCanonical(active.record, replacement);
      closed.add(replacement);
    }
    _active.clear();
    return closed;
  }

  /// The canonical record for a detection, identified the same way
  /// [updateRecord] identifies it: by species and start, not by instance.
  DetectionRecord? recordFor({
    required String scientificName,
    required DateTime timestamp,
  }) {
    final index = _indexOf(scientificName, timestamp);
    return index == -1 ? null : records[index];
  }

  /// Update a canonical record after asynchronous mode-specific work.
  ///
  /// The lookup uses the stable detection start rather than object identity,
  /// because confidence updates may have replaced the record while a clip was
  /// being encoded.
  DetectionRecord? updateRecord({
    required String scientificName,
    required DateTime timestamp,
    required DetectionRecord Function(DetectionRecord current) update,
  }) {
    final index = _indexOf(scientificName, timestamp);
    if (index == -1) return null;
    final current = records[index];
    final replacement = update(current);
    records[index] = replacement;
    final active = _active[scientificName];
    if (active != null && active.record.timestamp == timestamp) {
      active.record = replacement;
    }
    return replacement;
  }

  /// Whether the record ceiling has been reached, logging the first time so a
  /// session that stops recording new species says so instead of going quiet.
  bool get _isFull {
    final limit = maxRecords;
    if (limit == null || records.length < limit) return false;
    if (!_reportedFull) {
      _reportedFull = true;
      debugPrint(
        '[DetectionAccumulator] reached $limit records; further new species '
        'in this session will not be recorded',
      );
    }
    return true;
  }

  /// Keep species-and-start unique across the session.
  ///
  /// Pooling dates a detection at its *earliest supporting window*, and
  /// support is a lower gate than the confidence threshold. So a species that
  /// drops below threshold and comes back while its opening windows are still
  /// pooled is handed the same start as the record that just closed — as is a
  /// detection that survives a pause with the pool intact. Two records would
  /// then share the identity [updateRecord], [recordFor] and the clip writer
  /// all treat as unique, and a clip cut for the new detection would land on
  /// the old one, deleting the audio that record still points at.
  ///
  /// Nudging the later start keeps them distinct. A microsecond is far below
  /// anything the UI, exports, or session timeline render.
  DateTime _uniqueTimestamp(String scientificName, DateTime timestamp) {
    var candidate = timestamp;
    while (_indexOf(scientificName, candidate) != -1) {
      candidate = candidate.add(const Duration(microseconds: 1));
    }
    return candidate;
  }

  int _indexOf(String scientificName, DateTime timestamp) {
    final key = (scientificName, timestamp.microsecondsSinceEpoch);
    final cached = _recordIndexes[key];
    if (cached != null &&
        cached < records.length &&
        _keyOf(records[cached]) == key) {
      return cached;
    }

    final index = records.indexWhere((record) => _keyOf(record) == key);
    if (index == -1) {
      _recordIndexes.remove(key);
    } else {
      _recordIndexes[key] = index;
    }
    return index;
  }

  (String, int) _keyOf(DetectionRecord record) => (
    record.scientificName,
    record.timestamp.microsecondsSinceEpoch,
  );

  DateTime _clampTimestamp(DateTime timestamp) =>
      timestamp.isBefore(sessionStart) ? sessionStart : timestamp;

  void _replaceCanonical(
    DetectionRecord previous,
    DetectionRecord replacement,
  ) {
    final key = _keyOf(previous);
    var index = _recordIndexes[key];
    if (index == null ||
        index >= records.length ||
        !identical(records[index], previous)) {
      index = records.indexWhere((record) => identical(record, previous));
    }
    if (index == -1) return;
    records[index] = replacement;
    _recordIndexes[_keyOf(replacement)] = index;
  }
}

/// Copy a detection record while retaining every review and mode-specific
/// field. Nullable fields use their existing value; fields that need explicit
/// clearing (clip path/timestamp) are handled by [withoutClip].
DetectionRecord copyDetectionRecord(
  DetectionRecord existing, {
  double? confidence,
  DateTime? endTimestamp,
  String? audioClipPath,
  DateTime? clipTimestamp,
  bool withoutClip = false,
}) {
  final nextClipPath =
      withoutClip ? null : audioClipPath ?? existing.audioClipPath;
  final nextClipTimestamp =
      nextClipPath == null ? null : (clipTimestamp ?? existing.clipTimestamp);
  return DetectionRecord(
    scientificName: existing.scientificName,
    commonName: existing.commonName,
    confidence: confidence ?? existing.confidence,
    timestamp: existing.timestamp,
    endTimestamp: endTimestamp ?? existing.endTimestamp,
    audioClipPath: nextClipPath,
    clipTimestamp: nextClipTimestamp,
    source: existing.source,
    evidence: existing.evidence,
    latitude: existing.latitude,
    longitude: existing.longitude,
    reviewStatus: existing.reviewStatus,
    reviewedAt: existing.reviewedAt,
    note: existing.note,
    voiceMemoPath: existing.voiceMemoPath,
  );
}
