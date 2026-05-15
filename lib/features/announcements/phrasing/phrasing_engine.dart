// =============================================================================
// PhrasingEngine
// =============================================================================
//
// Turns a detection (or a coalesced batch) into a string the TTS layer
// can speak. Pure Dart, no Flutter, no async, no I/O — the
// [TemplateLibrary] does the loading and hands a ready [TemplateBundle]
// to the engine at construction time.
//
// Responsibilities (§3 of dev/announcements.md):
//
//   • Bucket selection delegated to [selectBucket] / [selectCoalesceBucket].
//   • Verbosity-aware template *picking*:
//       - minimal → speak just "{name}." (templates bypassed entirely).
//       - balanced → uniform pick from the bucket's balanced list.
//       - chatty   → uniform pick from the bucket's chatty list, falling
//                    back to balanced when chatty is empty (handled by
//                    the bundle, see TemplateLibrary).
//   • Anti-repeat: a 3-slot ring buffer per bucket so the same template
//     can't fire three times in a row even if the picker happens to
//     prefer it (§3.5).
//   • Locale fallback: handled at the TemplateLibrary layer; if the
//     active bundle is empty for a bucket the engine speaks the bare
//     name as a graceful last-resort.
// =============================================================================

import 'dart:math';

import '../domain/announcement_buckets.dart';
import '../domain/announcement_presets.dart';
import '../domain/announcement_signals.dart';
import 'template_library.dart';

/// Maximum number of recently-used template indices remembered per
/// bucket for anti-repeat. Three matches the §3.5 spec.
const int _antiRepeatHistory = 3;

class PhrasingEngine {
  final TemplateBundle _bundle;
  final Random _random;

  /// Per-bucket ring buffer of recently-used indices. Bounded to
  /// [_antiRepeatHistory] entries; oldest entry is dropped on push.
  final Map<AnnouncementBucket, List<int>> _recent = {};

  /// Per-commonness-bin ring buffer for the Chatty addendum phrases.
  /// Kept separate from [_recent] so a fresh commonness phrase doesn't
  /// crowd out the bucket variants and vice versa.
  final Map<CommonnessBin, List<int>> _recentCommonness = {};

  /// Ring buffer for the optional seasonal-tail phrase (single bin).
  final List<int> _recentSeasonal = <int>[];

  PhrasingEngine({required TemplateBundle bundle, Random? random})
    : _bundle = bundle,
      _random = random ?? Random();

  /// Speak a single-species detection. Returns the rendered string,
  /// e.g. *"There's a Robin calling."*
  ///
  /// [name] is the localized common name (already in the user's
  /// species-language preference). The engine never touches taxonomy.
  String speakOne({
    required String name,
    required AnnouncementSignals signals,
    required AnnouncementVerbosity verbosity,
  }) {
    if (verbosity == AnnouncementVerbosity.minimal) {
      return '$name.';
    }
    final bucket = selectBucket(signals);
    final template = _pickTemplate(bucket, verbosity);
    if (template == null) return '$name.';
    final base = template.replaceAll('{name}', name);
    // Chatty + first time we're actually speaking this species in the
    // session = the one moment we add a commonness/season tag-on. The
    // signal is gated on geo data being present, so this is silently
    // skipped for users without a location fix or for species missing
    // from the geo-model labels.
    if (verbosity != AnnouncementVerbosity.chatty) return base;
    if (!signals.isFirstAnnouncement) return base;
    final bin = signals.commonness;
    if (bin == null) return base;
    final commonnessPhrase = _pickCommonness(bin);
    if (commonnessPhrase == null) return base;
    final tail = signals.isOutOfSeason ? _pickSeasonalTail() : null;
    return tail == null
        ? '$base $commonnessPhrase'
        : '$base $commonnessPhrase $tail';
  }

  /// Speak a coalesced multi-species batch. [names] should already be
  /// trimmed / deduped by the caller. The bucket is picked by count:
  /// two names → `H_two` (slots `{name1}` / `{name2}`), three →
  /// `H_three` (`{name1}` / `{name2}` / `{name3}`), four-plus →
  /// `H_many` (three slots plus an implicit "and more").
  ///
  /// Falls back to a plain comma-joined list if no template is
  /// available (defensive — only happens with a corrupted bundle).
  String speakMany({
    required List<String> names,
    required AnnouncementVerbosity verbosity,
  }) {
    if (names.isEmpty) return '';
    if (names.length == 1) {
      return '${names.first}.';
    }
    final bucket = selectCoalesceBucket(names.length);
    final slots = bucket == AnnouncementBucket.hTwo ? 2 : 3;
    if (verbosity == AnnouncementVerbosity.minimal) {
      // Minimal mode never hedges; just list the names.
      return '${names.take(slots).join(', ')}.';
    }
    final template = _pickTemplate(bucket, verbosity);
    if (template == null) {
      return '${names.take(slots).join(', ')}.';
    }
    final picks = names.take(slots).toList();
    var out = template
        .replaceAll('{name1}', picks[0])
        .replaceAll('{name2}', picks[1]);
    if (slots >= 3) {
      out = out.replaceAll('{name3}', picks[2]);
    }
    return out;
  }

  /// Reset the per-bucket anti-repeat memory. Called at session start
  /// and from the unit tests.
  void reset() {
    _recent.clear();
    _recentCommonness.clear();
    _recentSeasonal.clear();
  }

  String? _pickTemplate(
    AnnouncementBucket bucket,
    AnnouncementVerbosity verbosity,
  ) {
    final variants = _bundle.variantsFor(bucket, verbosity);
    if (variants.isEmpty) return null;
    final history = _recent.putIfAbsent(bucket, () => <int>[]);
    final candidates = <int>[];
    for (var i = 0; i < variants.length; i++) {
      if (!history.contains(i)) candidates.add(i);
    }
    // If every variant is in the history (small lists ≤ 3), allow
    // anything except the most-recent one. If the bucket has only one
    // variant we can do nothing about repetition — speak it anyway.
    final pool =
        candidates.isNotEmpty
            ? candidates
            : (variants.length > 1
                ? [
                  for (var i = 0; i < variants.length; i++)
                    if (i != history.last) i,
                ]
                : [0]);
    final picked = pool[_random.nextInt(pool.length)];
    history.add(picked);
    if (history.length > _antiRepeatHistory) history.removeAt(0);
    return variants[picked];
  }

  String? _pickCommonness(CommonnessBin bin) {
    final variants = _bundle.commonnessVariantsFor(bin);
    if (variants.isEmpty) return null;
    final history = _recentCommonness.putIfAbsent(bin, () => <int>[]);
    return _pickFrom(variants, history);
  }

  String? _pickSeasonalTail() {
    final variants = _bundle.seasonalAddendumVariants();
    if (variants.isEmpty) return null;
    return _pickFrom(variants, _recentSeasonal);
  }

  /// Shared anti-repeat picker. Same 3-slot ring buffer as
  /// [_pickTemplate] but parameterised so it can drive both the
  /// commonness and seasonal addendum lists.
  String _pickFrom(List<String> variants, List<int> history) {
    final candidates = <int>[
      for (var i = 0; i < variants.length; i++)
        if (!history.contains(i)) i,
    ];
    final pool =
        candidates.isNotEmpty
            ? candidates
            : (variants.length > 1
                ? [
                  for (var i = 0; i < variants.length; i++)
                    if (i != history.last) i,
                ]
                : [0]);
    final picked = pool[_random.nextInt(pool.length)];
    history.add(picked);
    if (history.length > _antiRepeatHistory) history.removeAt(0);
    return variants[picked];
  }
}
