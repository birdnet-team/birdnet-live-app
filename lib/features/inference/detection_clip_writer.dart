// =============================================================================
// Detection clip writer — cutting and attaching clips, once
// =============================================================================
//
// A detection record is published the moment inference finishes. Its audio
// clip cannot be: cutting one means waiting for post-roll to be captured and
// then encoding a file, and doing that inside the inference cycle would push
// the next analysis window later. So clips are written off to the side and
// attached to the canonical record when they land.
//
// That leaves a handful of things to get right — which detections deserve a
// clip, what happens when a stronger window arrives before the previous write
// finished, and which file to delete when a clip is replaced. Live and Survey
// need identical answers, so they share this.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../live/live_session.dart';
import '../recording/recording_service.dart';
import 'detection_accumulator.dart';

/// Cuts detection clips outside the inference critical path and attaches them
/// to the records the accumulator owns.
class DetectionClipWriter {
  DetectionClipWriter({
    required this.recordingService,
    required this.debugLabel,
    required this.accumulatorOf,
    required this.isCurrentSession,
    required this.onRecordsChanged,
    this.onClipsSettled,
  });

  final RecordingService recordingService;

  /// Prefix for this writer's debug output, e.g. `LiveController`.
  final String debugLabel;

  /// The accumulator owning the canonical records, or null once the session
  /// is gone.
  final DetectionAccumulator? Function() accumulatorOf;

  /// Whether the session a clip was requested for is still the live one.
  final bool Function() isCurrentSession;

  /// Called after a clip is attached, so the mode can republish its list.
  final VoidCallback onRecordsChanged;

  /// Called once no further clip writes are outstanding for a record.
  ///
  /// Survey hands closed records to its sampler here rather than when they
  /// close, because the sampler may delete a clip and clear the path on the
  /// record instance it is given — doing that while a write is still in flight
  /// would act on a record that is about to be replaced.
  final void Function(DetectionRecord record)? onClipsSettled;

  final DetectionClipPeakTracker _peakTracker = DetectionClipPeakTracker();
  final Set<Future<void>> _tasks = {};

  /// Confidence of the strongest clip write currently in flight per record.
  final Map<String, double> _pendingConfidence = {};

  /// How many writes are still in flight per record.
  final Map<String, int> _pendingTaskCounts = {};

  /// Whether a clip write is still outstanding for [record].
  bool hasPendingWrite(DetectionRecord record) =>
      _pendingConfidence.containsKey(_key(record));

  /// Stop tracking a detection that has closed.
  void forget(DetectionRecord record) => _peakTracker.forget(_key(record));

  /// Drop all state at a session boundary.
  void reset() {
    _peakTracker.clear();
    _pendingConfidence.clear();
    _pendingTaskCounts.clear();
  }

  /// Wait for every outstanding write to finish.
  ///
  /// Called while capture and recording are still alive, so a clip requested
  /// just before the session ended still gets its audio.
  Future<void> drain() async {
    while (_tasks.isNotEmpty) {
      await Future.wait(_tasks.toList());
    }
  }

  /// Request clips for whichever of [changes] have earned one.
  ///
  /// Returns immediately; the write runs on its own. [clipTimestamp] dates the
  /// audio and [windowEndSample] pins the read to it, so a write that lands
  /// late still stores the window that produced the score.
  void requestClips({
    required List<DetectionRecordChange> changes,
    required DateTime clipTimestamp,
    required int windowEndSample,
  }) {
    if (changes.isEmpty) return;

    final selected = <DetectionRecordChange>[];
    for (final change in changes) {
      if (!_needsClip(change)) continue;
      final key = _key(change.record);
      _pendingConfidence[key] = change.detection.confidence;
      _pendingTaskCounts[key] = (_pendingTaskCounts[key] ?? 0) + 1;
      selected.add(change);
    }
    if (selected.isEmpty) return;

    late Future<void> task;
    task = _writeAndAttach(
      selected,
      clipTimestamp: clipTimestamp,
      windowEndSample: windowEndSample,
    ).whenComplete(() => _tasks.remove(task));
    _tasks.add(task);
  }

  /// Whether this change should have a clip cut for it now.
  ///
  /// While a write is in flight the record on disk does not yet reflect it, so
  /// the decision is made against the confidence being written rather than
  /// against the peak tracker — otherwise a burst of rising scores would queue
  /// a write per cycle and each would delete the one before it.
  bool _needsClip(DetectionRecordChange change) {
    final key = _key(change.record);
    final pending = _pendingConfidence[key];
    if (pending != null) {
      // Same margin the peak tracker applies, including its epsilon for
      // boundaries such as 0.60 - 0.55 landing just under 0.05.
      return change.detection.confidence - pending + 1e-12 >=
          kClipPeakImprovementDelta;
    }
    return _peakTracker.needsClip(
      key: key,
      candidateConfidence: change.detection.confidence,
      currentConfidence: change.previousConfidence,
      hasClip: change.record.audioClipPath != null,
      isNew: change.isNew,
    );
  }

  Future<void> _writeAndAttach(
    List<DetectionRecordChange> changes, {
    required DateTime clipTimestamp,
    required int windowEndSample,
  }) async {
    try {
      final paths = await saveDetectionClipsFor<DetectionRecordChange>(
        recordingService: recordingService,
        items: changes,
        speciesOf: (change) => change.record.scientificName,
        windowEndSample: windowEndSample,
      );
      for (final change in changes) {
        await _attach(change, paths[change], clipTimestamp);
      }
    } catch (error, stackTrace) {
      debugPrint('[$debugLabel] clip save error: $error\n$stackTrace');
    } finally {
      _settle(changes);
    }
  }

  Future<void> _attach(
    DetectionRecordChange change,
    String? path,
    DateTime clipTimestamp,
  ) async {
    final record = change.record;
    final key = _key(record);
    final confidence = change.detection.confidence;
    final accumulator = accumulatorOf();

    // A stronger window was queued while this one was being written, so this
    // file is already obsolete on arrival.
    final superseded = (_pendingConfidence[key] ?? confidence) > confidence;
    if (path == null ||
        superseded ||
        accumulator == null ||
        !isCurrentSession()) {
      if (path != null) await recordingService.deleteClip(path);
      return;
    }

    // Look the record up by identity of the detection rather than by object:
    // a confidence update may have replaced the instance while we encoded.
    String? replacedPath;
    final updated = accumulator.updateRecord(
      scientificName: record.scientificName,
      timestamp: record.timestamp,
      update: (current) {
        replacedPath = current.audioClipPath;
        return copyDetectionRecord(
          current,
          audioClipPath: path,
          clipTimestamp: clipTimestamp,
        );
      },
    );
    if (updated == null) {
      await recordingService.deleteClip(path);
      return;
    }

    // Publish the replacement before deleting anything, so a teardown racing
    // us can never persist a record pointing at a file we already removed.
    _peakTracker.recordSaved(key, confidence);
    onRecordsChanged();
    if (replacedPath != null && replacedPath != path) {
      await recordingService.deleteClip(replacedPath);
    }
  }

  void _settle(List<DetectionRecordChange> changes) {
    for (final change in changes) {
      final key = _key(change.record);
      final remaining = (_pendingTaskCounts[key] ?? 1) - 1;
      if (remaining > 0) {
        _pendingTaskCounts[key] = remaining;
        continue;
      }
      _pendingTaskCounts.remove(key);
      _pendingConfidence.remove(key);

      final settled = onClipsSettled;
      if (settled == null) continue;
      // Re-read the canonical record: this write may have replaced it, and
      // the detection may have closed while we were encoding.
      final current = accumulatorOf()?.recordFor(
        scientificName: change.record.scientificName,
        timestamp: change.record.timestamp,
      );
      if (current?.endTimestamp != null) settled(current!);
    }
  }

  /// Records are keyed by the detection they belong to, not by species: a
  /// species that stops and starts again is a new detection and gets its own
  /// clip rather than inheriting the previous one's peak.
  String _key(DetectionRecord record) =>
      '${record.scientificName}|${record.timestamp.microsecondsSinceEpoch}';
}
