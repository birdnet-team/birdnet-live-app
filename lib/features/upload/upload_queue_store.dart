// =============================================================================
// Upload Queue Store — pending and finished jobs on disk
// =============================================================================
//
// `<appDir>/uploads.json` holds every job: pending ones are the queue,
// finished ones are the upload log that the library chips and the Share
// dialog read ("Uploaded on …"). Written atomically like the destination
// list. Never contains credentials.
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'upload_job.dart';

class UploadQueueStore {
  UploadQueueStore({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  static const String fileName = 'uploads.json';
  static const int schemaVersion = 1;

  final Future<Directory> Function() _documentsDirectory;

  Future<File> _file() async {
    final dir = await _documentsDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<List<UploadJob>> load() async {
    final file = await _file();
    if (!await file.exists()) return const [];
    try {
      final json = jsonDecode(await file.readAsString());
      final list = json is Map<String, dynamic> ? json['jobs'] : null;
      if (list is! List) return const [];
      return [
        for (final entry in list)
          if (entry is Map<String, dynamic>) UploadJob.fromJson(entry),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(List<UploadJob> jobs) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'version': schemaVersion,
        'jobs': [for (final j in jobs) j.toJson()],
      }),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  Future<void> deleteAll() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }

  static const String lockFileName = 'uploads.lock';

  /// A lock older than this is a leftover of a killed process.
  static const Duration staleLock = Duration(minutes: 15);

  /// Claims the queue for one run. The foreground app and the background
  /// worker (upload_background.dart) each run their own isolate; whoever
  /// holds the lock processes jobs, the other backs off. Returns false when
  /// another live run holds it.
  Future<bool> tryLock() async {
    final dir = await _documentsDirectory();
    final lock = File('${dir.path}/$lockFileName');
    try {
      if (await lock.exists()) {
        final age = DateTime.now().difference(await lock.lastModified());
        if (age < staleLock) return false;
        await lock.delete();
      }
      await lock.create(exclusive: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  Future<void> unlock() async {
    final dir = await _documentsDirectory();
    try {
      await File('${dir.path}/$lockFileName').delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}
