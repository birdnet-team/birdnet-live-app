// =============================================================================
// Detection Sampler — Controls which survey detection clips are kept on disk
// =============================================================================
//
// On a multi-hour survey the detection *records* themselves are cheap (a few
// hundred bytes each) — we always keep every merged detection in the session
// so the user has a complete log. What is expensive is the per-detection WAV
// clip on disk. The sampler decides which clips survive; the records remain.
//
// Three modes operate on **merged detections** (one record per continuous
// appearance, closed when the species disappears or the session ends):
//
//   * **All** — keep every clip. The sampler is a no-op.
//   * **Top N** — keep the N highest-confidence clips per species. When a
//     better detection arrives, the weakest's clip is deleted (its record
//     stays, with `audioClipPath` cleared). When a new detection is worse
//     than the weakest existing clip, the new one's clip is dropped on
//     arrival.
//   * **Smart** — same per-species cap of N, but with spatial distribution.
//     If a new detection lands at the same "spot" as an already-kept clip
//     (within distance + time thresholds: 250 m **or** 2 min), only the
//     higher-confidence clip survives — even if there's still a free slot.
//     This prevents one stationary singer from grabbing all N slots.
//
//     A floor of [minKeepPerSpecies] (default 3) clips per species is
//     always honored: until that many clips are retained for a species,
//     same-spot rivalry is bypassed and clips are admitted via the normal
//     Top N path. This guarantees a few representative recordings even for
//     birds that only call from one spot.
//
// Records always live in the session. Only `audioClipPath` is affected.
// =============================================================================

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../live/live_session.dart';

/// Detection sampling mode.
enum SamplingMode { all, topN, smart }

/// Parses a [SamplingMode] from its persisted string representation.
SamplingMode samplingModeFromString(String value) {
  return switch (value) {
    'topN' => SamplingMode.topN,
    'smart' => SamplingMode.smart,
    _ => SamplingMode.all,
  };
}

/// Controls which detection audio clips are retained during a survey.
///
/// All [DetectionRecord]s are kept in the session regardless of mode; the
/// sampler only chooses whether each record's `audioClipPath` is preserved
/// (file kept on disk) or cleared (file deleted, record stays without audio).
class DetectionSampler {
  DetectionSampler({
    required this.mode,
    this.topN = 10,
    this.distanceThresholdMeters = 250,
    this.timeThresholdSeconds = 120,
    this.minKeepPerSpecies = 3,
  });

  /// Active sampling mode.
  final SamplingMode mode;

  /// Maximum number of clips to retain per species (Top N and Smart modes).
  final int topN;

  /// Same-spot distance threshold in meters (Smart mode only). Two
  /// detections of the same species closer than this *and* within
  /// [timeThresholdSeconds] are considered the same spot.
  final double distanceThresholdMeters;

  /// Same-spot time threshold in seconds (Smart mode only). Two detections
  /// closer than [distanceThresholdMeters] **and** within this time window
  /// are considered the same spot.
  final int timeThresholdSeconds;

  /// Smart mode only: minimum number of clips to retain per species before
  /// same-spot rivalry kicks in. Until a species has this many kept clips,
  /// new detections fall through to the standard Top N admission path even
  /// if a same-spot neighbor exists.
  final int minKeepPerSpecies;

  /// Per-species lists of records whose clips are currently kept on disk,
  /// sorted ascending by confidence (weakest at index 0).
  final Map<String, List<DetectionRecord>> _keptClips = {};

  /// Total number of clips currently retained on disk.
  int get keptClipCount => _keptClips.values.fold(0, (s, l) => s + l.length);

  /// Number of clips that have been dropped (records kept, audio deleted).
  int get droppedClipCount => _droppedClipCount;
  int _droppedClipCount = 0;

  /// Notify the sampler that a merged detection has just closed (i.e. the
  /// species disappeared or the session is ending). The record's
  /// `audioClipPath` may be cleared in place if its clip is dropped, and
  /// other previously-kept records may have their clips evicted to make
  /// room.
  ///
  /// Returns `true` if the record's own clip was retained, `false` if it
  /// was dropped on arrival (file already deleted, path cleared).
  Future<bool> onRecordClosed(DetectionRecord record) async {
    // All mode: keep every clip, no work to do.
    if (mode == SamplingMode.all) return record.audioClipPath != null;

    // No clip on this record â†’ nothing to manage.
    if (record.audioClipPath == null) return false;

    final species = record.scientificName;
    final kept = _keptClips.putIfAbsent(species, () => []);

    // Smart mode: check for a same-spot rival first. If one exists, the
    // contest is between just those two regardless of free slots — but
    // only after the per-species minimum has been met, so the first few
    // clips of a species always survive.
    if (mode == SamplingMode.smart && kept.length >= minKeepPerSpecies) {
      final neighbor = _findSameSpot(record, kept);
      if (neighbor != null) {
        if (record.confidence > neighbor.confidence) {
          // New record wins the spot; evict the neighbor's clip.
          kept.remove(neighbor);
          await _evictClip(neighbor);
          _insertSorted(kept, record);
          return true;
        } else {
          // Existing record wins; drop the new one's clip.
          await _evictClip(record);
          return false;
        }
      }
      // No same-spot rival â†’ fall through to standard Top N logic.
    }

    // Top N admission (shared by Top N and Smart-with-no-rival).
    if (kept.length < topN) {
      _insertSorted(kept, record);
      return true;
    }

    // Heap full — compare against the weakest.
    final weakest = kept.first;
    if (record.confidence > weakest.confidence) {
      kept.removeAt(0);
      await _evictClip(weakest);
      _insertSorted(kept, record);
      return true;
    }

    // New record is no better than the weakest kept clip — drop it.
    await _evictClip(record);
    return false;
  }

  /// Delete a record's audio file and clear its `audioClipPath`.
  ///
  /// Mutates the record in place so existing references in the session list
  /// reflect the change without needing a list-replace.
  Future<void> _evictClip(DetectionRecord record) async {
    final path = record.audioClipPath;
    record.audioClipPath = null;
    _droppedClipCount++;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[DetectionSampler] failed to delete clip: $e');
    }
  }

  /// Find an already-kept record at the "same spot" as [candidate], or null.
  DetectionRecord? _findSameSpot(
    DetectionRecord candidate,
    List<DetectionRecord> kept,
  ) {
    for (final existing in kept) {
      if (_isSameSpot(candidate, existing)) return existing;
    }
    return null;
  }

  /// Whether two detections are at the same spot (close in space and time).
  ///
  /// If GPS is missing on either record, falls back to a time-only check —
  /// missing-GPS records are never silently treated as identical location.
  bool _isSameSpot(DetectionRecord a, DetectionRecord b) {
    final timeDiff = a.timestamp.difference(b.timestamp).inSeconds.abs();
    if (timeDiff > timeThresholdSeconds) return false;

    if (a.latitude == null ||
        a.longitude == null ||
        b.latitude == null ||
        b.longitude == null) {
      // No GPS on at least one side: time alone decides.
      return true;
    }

    final dist = _haversineMeters(
      a.latitude!,
      a.longitude!,
      b.latitude!,
      b.longitude!,
    );
    return dist <= distanceThresholdMeters;
  }

  /// Haversine distance in meters between two GPS coordinates.
  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  /// Insert into a list sorted ascending by confidence.
  static void _insertSorted(List<DetectionRecord> list, DetectionRecord item) {
    var i = 0;
    while (i < list.length && list[i].confidence <= item.confidence) {
      i++;
    }
    list.insert(i, item);
  }
}
