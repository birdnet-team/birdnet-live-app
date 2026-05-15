// =============================================================================
// AnnouncementBucket
// =============================================================================
//
// The eight phrasing buckets (§3.3 of dev/announcements.md) plus the
// pure-function bucket selector that maps an [AnnouncementSignals]
// snapshot to one bucket. Kept as a separate file from the engine
// itself so the routing logic — which is the most likely thing to
// need iteration after field testing — can be reasoned about and
// unit-tested in isolation.
//
//                          high          medium         low
//   first / new (recent)    A             D              F
//   again (not recent)      B             E              G
//   streak ≥ 2              C             (folds into C — see §3.4)
//   coalesced multi         H_two / H_three / H_many depending on count
//
// Bucket H is special: it is selected at the multi-species coalesce
// layer above the per-detection engine, so this selector never returns
// it directly.
// =============================================================================

import 'announcement_signals.dart';

/// One of the eight phrasing buckets. See file header for the routing
/// table and §3.3 of dev/announcements.md for the design rationale.
enum AnnouncementBucket {
  /// High-confidence, fresh detection ("There's a Robin calling.").
  a,

  /// High-confidence, recently heard ("The Robin is back.").
  b,

  /// High-confidence, mid-streak ("Robin still calling.").
  c,

  /// Medium-confidence, fresh detection ("Sounds like a Robin.").
  d,

  /// Medium-confidence, recently heard ("Robin might be back.").
  e,

  /// Low-confidence, fresh detection ("Maybe a Robin, hard to tell.").
  f,

  /// Low-confidence, recently heard ("Could be the Robin again.").
  g,

  /// Multi-species coalesce, exactly two names ("Two birds at once: …").
  hTwo,

  /// Multi-species coalesce, three names ("A few at once: …").
  hThree,

  /// Multi-species coalesce, four-plus names ("Lots happening: …").
  hMany;

  /// JSON key used in the template files (`templates_<locale>.json`).
  /// Keeps the on-disk format readable and avoids an extra mapping
  /// table in the loader.
  String get jsonKey {
    switch (this) {
      case AnnouncementBucket.hTwo:
        return 'H_two';
      case AnnouncementBucket.hThree:
        return 'H_three';
      case AnnouncementBucket.hMany:
        return 'H_many';
      default:
        return name.toUpperCase();
    }
  }
}

/// Pure function: pick the right bucket for a single-species detection.
///
/// Streak takes precedence over recency (a bird that's been calling
/// continuously routes into [AnnouncementBucket.c] regardless of the
/// confidence bin — once we're in "still calling" territory we don't
/// flip back to "I'm not sure" just because one frame happened to dip).
AnnouncementBucket selectBucket(AnnouncementSignals s) {
  if (s.streakLength >= 2) return AnnouncementBucket.c;
  switch (s.confidence) {
    case ConfidenceBin.high:
      return s.isRecent ? AnnouncementBucket.b : AnnouncementBucket.a;
    case ConfidenceBin.medium:
      return s.isRecent ? AnnouncementBucket.e : AnnouncementBucket.d;
    case ConfidenceBin.low:
      return s.isRecent ? AnnouncementBucket.g : AnnouncementBucket.f;
  }
}

/// Pick the multi-species coalesce bucket for a batch of [count] birds.
/// Two-bird batches get their own [AnnouncementBucket.hTwo] templates
/// (which only have `{name1}` and `{name2}` slots) so we never speak a
/// half-filled "…A, B, and ." phrase. Anything ≥ 4 collapses to
/// [AnnouncementBucket.hMany] so the utterance stays short.
AnnouncementBucket selectCoalesceBucket(int count) {
  if (count <= 2) return AnnouncementBucket.hTwo;
  if (count == 3) return AnnouncementBucket.hThree;
  return AnnouncementBucket.hMany;
}
