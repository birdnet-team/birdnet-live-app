import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';

/// Compresses and writes an export off the UI isolate.
///
/// Pass paths for existing files so recordings and nested ZIPs are read in the
/// worker instead of being loaded into memory and copied between isolates.
/// Only generated documents and converted audio need in-memory entries.
Future<void> writeExportZip({
  required String outputPath,
  required Map<String, String> files,
  required Archive contents,
}) => Isolate.run(() {
  final output = OutputFileStream(outputPath);
  var completed = false;
  try {
    final encoder = ZipEncoder()..startEncode(output);
    for (final entry in files.entries) {
      final input = InputFileStream(entry.value);
      try {
        encoder.add(ArchiveFile.stream(entry.key, input));
      } finally {
        input.closeSync();
      }
    }
    for (final entry in contents) {
      encoder.add(entry);
    }
    encoder.endEncode();
    completed = true;
  } finally {
    output.closeSync();
    if (!completed) {
      try {
        File(outputPath).deleteSync();
      } catch (_) {
        // Preserve the original export error if cleanup fails.
      }
    }
  }
}, debugName: 'session-export-zip');
