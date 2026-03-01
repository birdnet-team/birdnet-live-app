// =============================================================================
// Custom Species List — User-defined species filtering
// =============================================================================
//
// Allows users to upload a plain-text species list from their device and
// persist it in app storage for later use.  Each list is a set of scientific
// names (one per line), stored as a `.txt` file under the app's documents
// directory.
//
// ### File format
//
// ```
// Parus major
// Cyanistes caeruleus
// Turdus merula
// ```
//
// Lines that are blank or start with `#` are ignored (comments).  Leading
// and trailing whitespace is trimmed.  Duplicate names are silently merged.
//
// ### Storage
//
// Lists are saved under `<appDocDir>/species_lists/<name>.txt` so they
// survive app updates and are accessible via USB/MTP on Android.
// =============================================================================

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Manages user-defined custom species lists.
///
/// Species lists are simple text files with one scientific name per line,
/// stored in the app's documents directory.
abstract final class CustomSpeciesList {
  /// Sub-directory under app documents where lists are stored.
  static const String _subDir = 'species_lists';

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  /// Parse a plain-text species list into a set of scientific names.
  ///
  /// Blank lines and lines starting with `#` are ignored.
  static Set<String> parse(String content) {
    return content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toSet();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Save a species list with the given [name].
  ///
  /// Overwrites any existing list with the same name.
  static Future<void> save(String name, Set<String> species) async {
    final dir = await _listDir();
    final file = File('${dir.path}/$name.txt');
    await file.writeAsString(species.join('\n'));
  }

  /// Load a previously saved species list by [name].
  ///
  /// Returns an empty set if the list does not exist.
  static Future<Set<String>> load(String name) async {
    final dir = await _listDir();
    final file = File('${dir.path}/$name.txt');
    if (!file.existsSync()) return {};
    final content = await file.readAsString();
    return parse(content);
  }

  /// Delete a previously saved species list by [name].
  ///
  /// No-op if the list does not exist.
  static Future<void> delete(String name) async {
    final dir = await _listDir();
    final file = File('${dir.path}/$name.txt');
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// List the names of all saved species lists.
  ///
  /// Returns an empty list if no lists have been saved yet.
  static Future<List<String>> listSaved() async {
    final dir = await _listDir();
    if (!dir.existsSync()) return [];

    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))
        .map((f) {
      final name = f.uri.pathSegments.last;
      return name.substring(0, name.length - 4); // strip .txt
    }).toList()
      ..sort();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Resolve (and create if necessary) the species lists directory.
  static Future<Directory> _listDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_subDir');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
