// =============================================================================
// eBird Life List — Species you've personally confirmed via eBird
// =============================================================================
//
// Lets a user import their eBird "My Life List" CSV export
// (ebird.org/lifelist?r=world&time=life&fmt=csv) so the app can flag species
// it hears that aren't on that list yet — a "lifer".
//
// This is intentionally a distinct concept from [GlobalSpeciesHistory]:
// that class tracks species this *app* has ever detected, while this class
// tracks species the *user* has personally logged via eBird. A species can
// be a lifer here even if the app detected it before but the user never
// confirmed the sighting.
//
// ### Storage
//
// One JSON-encoded list of scientific names under
// [PrefKeys.ebirdLifeList], plus an ISO-8601 timestamp of the last import
// under [PrefKeys.ebirdLifeListImportedAt].
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';

/// Thrown by [EbirdLifeList.importCsv] when the CSV doesn't look like an
/// eBird life list export (no "Scientific Name" column).
class EbirdCsvFormatException implements Exception {
  const EbirdCsvFormatException();
}

/// Scientific names the user has personally confirmed via an imported
/// eBird life list CSV, persisted in SharedPreferences.
///
/// Extends [ChangeNotifier] so widgets that show a "lifer" badge (Live
/// screen detection list, session review summary, Survey alerts) rebuild
/// the moment a new list is imported — mirrors [GlobalSpeciesHistory]'s
/// pattern for the Explore screen's detected checkmarks.
class EbirdLifeList extends ChangeNotifier {
  EbirdLifeList(this._prefs);

  final SharedPreferences _prefs;
  Set<String> _names = const {};
  DateTime? _importedAt;

  /// Loads the persisted list into memory. Call once during construction.
  void load() {
    final raw = _prefs.getString(PrefKeys.ebirdLifeList);
    _names = _decodeNames(raw);
    final importedAtRaw = _prefs.getString(PrefKeys.ebirdLifeListImportedAt);
    _importedAt = importedAtRaw == null ? null : DateTime.tryParse(importedAtRaw);
  }

  /// Whether [scientificName] is on the imported life list.
  bool contains(String scientificName) => _names.contains(scientificName);

  /// Total number of species on the imported list.
  int get length => _names.length;

  /// Whether a list has been imported yet.
  bool get isEmpty => _names.isEmpty;

  /// Snapshot of all species on the imported list (defensive copy).
  Set<String> get all => Set.unmodifiable(_names);

  /// When the current list was imported, or `null` if nothing's imported.
  DateTime? get importedAt => _importedAt;

  /// Parses [csvContent] as an eBird life list export and replaces the
  /// current list. Returns the number of species imported.
  ///
  /// Throws [EbirdCsvFormatException] if no "Scientific Name" column is
  /// found — matches columns by header name (not position) since eBird's
  /// export format isn't a documented/versioned contract.
  Future<int> importCsv(String csvContent) async {
    final names = _parseCsv(csvContent);
    if (names == null) throw const EbirdCsvFormatException();

    _names = names;
    _importedAt = DateTime.now();
    notifyListeners();
    await _persist();
    return names.length;
  }

  /// Wipes the persisted list. Used by the "Clear all data" diagnostic
  /// action and by tests.
  Future<void> clear() async {
    _names = <String>{};
    _importedAt = null;
    notifyListeners();
    await _prefs.remove(PrefKeys.ebirdLifeList);
    await _prefs.remove(PrefKeys.ebirdLifeListImportedAt);
  }

  Future<void> _persist() async {
    final list = _names.toList()..sort();
    await _prefs.setString(PrefKeys.ebirdLifeList, json.encode(list));
    await _prefs.setString(
      PrefKeys.ebirdLifeListImportedAt,
      _importedAt!.toIso8601String(),
    );
  }

  static Set<String> _decodeNames(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is List) return decoded.whereType<String>().toSet();
    } catch (_) {
      /* fall through to empty */
    }
    return {};
  }

  /// Returns `null` when the CSV has no "Scientific Name" column (not a
  /// recognizable eBird life list export).
  static Set<String>? _parseCsv(String content) {
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) return null;

    final header = _parseCsvLine(lines.first);
    final sciIndex = header.indexOf('Scientific Name');
    if (sciIndex == -1) return null;

    final names = <String>{};
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final fields = _parseCsvLine(line);
      if (sciIndex >= fields.length) continue;
      final name = fields[sciIndex].trim();
      if (name.isNotEmpty) names.add(name);
    }
    return names;
  }

  /// Splits a single CSV line into fields, respecting double-quoted fields
  /// that may contain commas.
  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }
}

/// Riverpod provider exposing the singleton [EbirdLifeList].
///
/// Uses [ChangeNotifierProvider] so `ref.watch(ebirdLifeListProvider)`
/// triggers a rebuild the moment a new list is imported, without the user
/// having to leave and re-enter the screen.
final ebirdLifeListProvider = ChangeNotifierProvider<EbirdLifeList>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return EbirdLifeList(prefs)..load();
});
