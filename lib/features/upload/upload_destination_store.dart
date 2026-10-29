// =============================================================================
// Upload Destination Store — the destination list on disk
// =============================================================================
//
// Destinations are kept in `<appDir>/upload_destinations.json`, next to the
// `sessions/` and `recordings/` directories. The file never contains a
// secret; those live in the keychain (secret_store.dart). Writes go to a
// temporary file first and are renamed into place, so a crash mid-write
// leaves the previous list intact.
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'upload_destination.dart';

/// Reads and writes the destination list.
class UploadDestinationStore {
  UploadDestinationStore({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  static const String fileName = 'upload_destinations.json';
  static const int schemaVersion = 1;

  final Future<Directory> Function() _documentsDirectory;

  Future<File> _file() async {
    final dir = await _documentsDirectory();
    return File('${dir.path}/$fileName');
  }

  /// Returns the stored destinations, or an empty list when none were saved
  /// or the file cannot be read.
  Future<List<UploadDestination>> load() async {
    final file = await _file();
    if (!await file.exists()) return const [];
    try {
      final json = jsonDecode(await file.readAsString());
      final list = json is Map<String, dynamic> ? json['destinations'] : json;
      if (list is! List) return const [];
      return [
        for (final entry in list)
          if (entry is Map<String, dynamic>) UploadDestination.fromJson(entry),
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Replaces the stored list.
  Future<void> save(List<UploadDestination> destinations) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    final data = {
      'version': schemaVersion,
      'destinations': [for (final d in destinations) d.toJson()],
    };
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  /// Removes the list file entirely (used by Clear All Data).
  Future<void> deleteAll() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
