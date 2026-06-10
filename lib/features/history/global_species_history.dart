// =============================================================================
// Global Species History — Lifetime list of every species ever detected
// =============================================================================
//
// Tracks the set of scientific names that have ever appeared in *any*
// session recorded by this app on this device. Used by the Survey species
// alert engine in "first-ever" mode to fire a notification only when a
// detection is genuinely new across the user's entire history (i.e., a new
// life-list species).
//
// ### Storage
//
// One JSON-encoded list of strings under the SharedPreferences key
// [PrefKeys.globalSpeciesHistory]. The set is small (~5 k species max,
// typically far fewer) so a single key works fine — no need for a database.
//
// ### Backfill
//
// On first launch of v0.7.0 the set is empty. We seed it once by scanning
// every persisted session via [SessionRepository.listAll] and collecting
// the distinct scientific names. The completion is recorded under
// [PrefKeys.globalSpeciesHistorySeeded] so we never re-scan.
//
// Backfill is idempotent and cheap (sessions are JSON files), but for very
// large libraries (hundreds of sessions) it is run off the critical path
// at app startup, after the first frame.
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';

/// Lifetime set of scientific names ever detected by this app on this
/// device, persisted in SharedPreferences.
///
/// This is intentionally a thin wrapper: the in-memory set is the source of
/// truth during the session, and writes go to disk on every [add]. Failures
/// to persist are logged but never thrown — alert behavior degrades to
/// "treat all species as not-yet-seen" rather than crashing.
///
/// Extends [ChangeNotifier] so widgets that gate UI on "has the user ever
/// detected this species?" (e.g. the Explore checkmark badges) rebuild
/// the moment a new detection lands or the one-time backfill seed
/// completes — without the user having to leave and re-enter the screen.
class GlobalSpeciesHistory extends ChangeNotifier {
  GlobalSpeciesHistory(this._prefs);

  final SharedPreferences _prefs;
  Set<String> _seen = const {};

  /// Loads the persisted set into memory. Call once during construction.
  void load() {
    final raw = _prefs.getString(PrefKeys.globalSpeciesHistory);
    if (raw == null || raw.isEmpty) {
      _seen = <String>{};
      return;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        _seen = decoded.whereType<String>().toSet();
        return;
      }
    } catch (_) {
      /* fall through to empty */
    }
    _seen = <String>{};
  }

  /// Whether [scientificName] has ever been detected.
  bool contains(String scientificName) => _seen.contains(scientificName);

  /// Total number of distinct species ever detected.
  int get length => _seen.length;

  /// Snapshot of all known species (defensive copy).
  Set<String> get all => Set.unmodifiable(_seen);

  /// Records [scientificName] and persists. Returns `true` iff this was a
  /// new entry (i.e., the species had never been seen before).
  Future<bool> add(String scientificName) async {
    if (!_seen.add(scientificName)) return false;
    notifyListeners();
    await _persist();
    return true;
  }

  /// Records every name in [names] and persists once. Returns the subset
  /// of [names] that were newly added (useful for backfill diagnostics).
  Future<Set<String>> addAll(Iterable<String> names) async {
    final added = <String>{};
    for (final n in names) {
      if (_seen.add(n)) added.add(n);
    }
    if (added.isNotEmpty) {
      notifyListeners();
      await _persist();
    }
    return added;
  }

  /// Wipes the persisted set. Used by the "Clear all data" diagnostic
  /// action and by tests.
  Future<void> clear() async {
    _seen = <String>{};
    notifyListeners();
    await _prefs.remove(PrefKeys.globalSpeciesHistory);
  }

  Future<void> _persist() async {
    // Sort for stable on-disk diffs (helps when inspecting the JSON file
    // for debugging) and to keep the encoded string deterministic.
    final list = _seen.toList()..sort();
    await _prefs.setString(PrefKeys.globalSpeciesHistory, json.encode(list));
  }
}

/// Seeds [history] from every persisted session if not already done.
///
/// Iterates [sessions] once, collects distinct scientific names, and
/// merges them into [history]. Sets [PrefKeys.globalSpeciesHistorySeeded]
/// to `true` so subsequent launches skip the scan.
///
/// Safe to call repeatedly — does nothing once the seed flag is set.
Future<void> seedGlobalSpeciesHistory({
  required GlobalSpeciesHistory history,
  required SharedPreferences prefs,
  required List<LiveSession> sessions,
}) async {
  if (prefs.getBool(PrefKeys.globalSpeciesHistorySeeded) ?? false) return;
  final names = <String>{};
  for (final session in sessions) {
    for (final d in session.detections) {
      if (d.scientificName.isNotEmpty) names.add(d.scientificName);
    }
  }
  await history.addAll(names);
  await prefs.setBool(PrefKeys.globalSpeciesHistorySeeded, true);
}

/// Riverpod provider exposing the singleton [GlobalSpeciesHistory].
///
/// The instance is loaded synchronously from SharedPreferences. The seed
/// pass is kicked off lazily the first time the provider is read so
/// startup is not blocked on session scans.
/// Uses [ChangeNotifierProvider] so `ref.watch(globalSpeciesHistoryProvider)`
/// triggers a rebuild whenever species are added (post-detection) or the
/// one-time backfill seed completes. Without this the Explore screen's
/// "detected" checkmarks would only appear after a manual refresh.
final globalSpeciesHistoryProvider =
    ChangeNotifierProvider<GlobalSpeciesHistory>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final history = GlobalSpeciesHistory(prefs)..load();

      // Fire-and-forget backfill. The repo provider is independent of prefs so
      // this does not introduce a circular dependency. We resolve the future
      // off the synchronous path; alerts that fire before seeding completes
      // will see an empty history (false positives biased toward MORE alerts,
      // which is the safe direction for a one-time migration).
      if (!(prefs.getBool(PrefKeys.globalSpeciesHistorySeeded) ?? false)) {
        final repo = ref.read(sessionRepositoryProvider);
        Future(() async {
          try {
            final sessions = await repo.listAll();
            await seedGlobalSpeciesHistory(
              history: history,
              prefs: prefs,
              sessions: sessions,
            );
          } catch (_) {
            /* non-fatal */
          }
        });
      }

      return history;
    });

/// Set of every scientific name found in any saved session, derived live
/// from [sessionListProvider].
///
/// Used by the Explore screen's "detected" checkmark badges (on species
/// thumbnails and in the species info overlay). We deliberately do NOT
/// reuse [globalSpeciesHistoryProvider] for this purpose because that
/// store is only mutated by the Survey alert engine — detections from
/// Live, Point Count, and File Analysis sessions never reach it. By
/// recomputing from the on-disk session list we guarantee the badges
/// always reflect what the user actually has saved, and they refresh
/// automatically whenever a session is saved or deleted (which
/// invalidates [sessionListProvider]).
final detectedSpeciesSetProvider = Provider<Set<String>>((ref) {
  final asyncSessions = ref.watch(sessionListProvider);
  return asyncSessions.maybeWhen(
    data: (sessions) {
      final names = <String>{};
      for (final s in sessions) {
        for (final d in s.detections) {
          if (d.scientificName.isNotEmpty) names.add(d.scientificName);
        }
      }
      return names;
    },
    orElse: () => const <String>{},
  );
});
