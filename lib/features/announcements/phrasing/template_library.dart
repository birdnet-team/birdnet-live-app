// =============================================================================
// TemplateLibrary
// =============================================================================
//
// Loads the per-locale phrasing JSON from `assets/announcements/` and
// exposes it as a typed lookup the [PhrasingEngine] can use without
// touching JSON parsing or asset I/O at speak time.
//
// File shape (see dev/announcements.md §3.8):
//
//   {
//     "locale": "en",
//     "version": 1,
//     "buckets": {
//       "A":       { "balanced": [...], "chatty": [...] },
//       ...
//       "H_three": { "balanced": [...], "chatty": [...] },
//       "H_many":  { "balanced": [...], "chatty": [...] }
//     }
//   }
//
// Locale resolution order at lookup time (caller's responsibility to
// build the chain): exact (`de_DE`), language-only (`de`), then `en` as
// the always-available fallback. EN is the only locale guaranteed to be
// present; if a JSON file is missing or malformed we silently degrade to
// EN so the runtime is robust against translator typos.
// =============================================================================

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/announcement_buckets.dart';
import '../domain/announcement_presets.dart';
import '../domain/announcement_signals.dart';

/// In-memory representation of one locale's templates. Each bucket holds
/// the variants for [AnnouncementVerbosity.balanced] (always present)
/// and [AnnouncementVerbosity.chatty] (optional — falls back to
/// balanced if absent or empty).
class TemplateBundle {
  final String locale;
  final Map<AnnouncementBucket, _BucketTemplates> _buckets;
  final Map<CommonnessBin, List<String>> _commonness;
  final List<String> _seasonalAddendum;

  const TemplateBundle._(
    this.locale,
    this._buckets, {
    Map<CommonnessBin, List<String>> commonness = const {},
    List<String> seasonalAddendum = const [],
  }) : _commonness = commonness,
       _seasonalAddendum = seasonalAddendum;

  /// Returns the template variants to choose from for [bucket] given
  /// the user's [verbosity]. Falls back to the balanced list when a
  /// bucket has no chatty entries, and to an empty list when the
  /// bucket itself is missing. Callers (the engine) handle the empty
  /// case by speaking the bare species name — see §3 minimal mode.
  List<String> variantsFor(
    AnnouncementBucket bucket,
    AnnouncementVerbosity verbosity,
  ) {
    final entry = _buckets[bucket];
    if (entry == null) return const [];
    if (verbosity == AnnouncementVerbosity.chatty && entry.chatty.isNotEmpty) {
      return entry.chatty;
    }
    return entry.balanced;
  }

  /// Variants for the Chatty first-announcement commonness phrase. Used
  /// only when verbosity is Chatty, the species is being spoken for the
  /// first time in the session, and a [CommonnessBin] is available.
  /// Returns an empty list when the locale doesn't define commonness
  /// phrases, in which case the engine simply skips the addendum.
  List<String> commonnessVariantsFor(CommonnessBin bin) =>
      _commonness[bin] ?? const [];

  /// Variants for the optional out-of-season tail appended after the
  /// commonness phrase when the species is currently below its annual
  /// peak at this location. Empty list = locale opts out and the
  /// engine skips the tail.
  List<String> seasonalAddendumVariants() => _seasonalAddendum;

  /// Parse one JSON document. Bucket entries that don't match the
  /// expected shape are skipped quietly; the engine's locale-fallback
  /// path covers any gaps.
  factory TemplateBundle.fromJson(Map<String, dynamic> json) {
    final locale = (json['locale'] as String?) ?? '';
    final raw = json['buckets'] as Map<String, dynamic>? ?? const {};
    final out = <AnnouncementBucket, _BucketTemplates>{};
    for (final bucket in AnnouncementBucket.values) {
      final node = raw[bucket.jsonKey];
      if (node is! Map) continue;
      final balanced = _stringList(node['balanced']);
      final chatty = _stringList(node['chatty']);
      if (balanced.isEmpty) continue;
      out[bucket] = _BucketTemplates(balanced: balanced, chatty: chatty);
    }
    final commonnessRaw =
        json['commonness'] as Map<String, dynamic>? ?? const {};
    final commonness = <CommonnessBin, List<String>>{};
    for (final bin in CommonnessBin.values) {
      final list = _stringList(commonnessRaw[bin.name]);
      if (list.isNotEmpty) commonness[bin] = list;
    }
    final seasonalAddendum = _stringList(commonnessRaw['seasonalAddendum']);
    return TemplateBundle._(
      locale,
      out,
      commonness: commonness,
      seasonalAddendum: seasonalAddendum,
    );
  }

  /// Empty bundle used as a last-resort fallback so the engine never
  /// crashes on a missing locale.
  factory TemplateBundle.empty(String locale) =>
      TemplateBundle._(locale, const {});
}

class _BucketTemplates {
  final List<String> balanced;
  final List<String> chatty;
  const _BucketTemplates({required this.balanced, required this.chatty});
}

List<String> _stringList(Object? node) {
  if (node is! List) return const [];
  return [
    for (final e in node)
      if (e is String && e.isNotEmpty) e,
  ];
}

/// Loads template bundles from the asset bundle.
///
/// Construct once and keep around — JSON parsing happens lazily on
/// first lookup per locale, results are cached.
class TemplateLibrary {
  final AssetBundle _bundle;
  final Map<String, TemplateBundle> _cache = {};

  TemplateLibrary({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Resolve the best available bundle for [locale]. Tries the exact
  /// tag, then the language subtag, then `en`. Always returns
  /// non-null — at worst an empty bundle (engine handles that by
  /// speaking the bare species name).
  Future<TemplateBundle> load(String locale) async {
    final candidates = _candidatesFor(locale);
    for (final tag in candidates) {
      final cached = _cache[tag];
      if (cached != null) return cached;
      final bundle = await _tryLoad(tag);
      if (bundle != null) {
        _cache[tag] = bundle;
        return bundle;
      }
    }
    return TemplateBundle.empty(locale);
  }

  Future<TemplateBundle?> _tryLoad(String tag) async {
    try {
      final raw = await _bundle.loadString(
        'assets/announcements/templates_$tag.json',
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TemplateBundle.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static List<String> _candidatesFor(String locale) {
    final normalized = locale.replaceAll('-', '_');
    final out = <String>[];
    if (normalized.isNotEmpty) out.add(normalized);
    final underscore = normalized.indexOf('_');
    if (underscore > 0) {
      out.add(normalized.substring(0, underscore));
    }
    if (!out.contains('en')) out.add('en');
    return out;
  }
}
