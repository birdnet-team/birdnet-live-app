// =============================================================================
// Session Export — Raven selection table and ZIP bundle for sharing
// =============================================================================
//
// Generates export artifacts for a live session:
//
//   • **Raven selection table** (.txt): Tab-delimited annotation file
//     compatible with Raven Pro / Raven Lite (Cornell Lab). Each detection
//     becomes a row with begin/end time offsets, frequency bounds, species
//     names, and confidence.
//
//   • **ZIP bundle** (.zip): Archives the full WAV recording together with
//     the selection table for convenient sharing.
//
// The selection table follows the standard Raven format with BirdNET-specific
// columns (Common Name, Scientific Name, Confidence) appended after the core
// columns (Selection, View, Channel, Begin Time, End Time, Low Freq, High
// Freq).
// =============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../live/live_session.dart';

/// Upper frequency bound for Raven annotations (Nyquist of 32 kHz).
const int _highFreqHz = 16000;

/// Generates a Raven Pro–compatible selection table from session detections.
///
/// Returns the table as a UTF-8 string with tab-separated columns:
///   Selection, View, Channel, Begin Time (s), End Time (s),
///   Low Freq (Hz), High Freq (Hz), Common Name, Scientific Name, Confidence
String buildRavenSelectionTable(LiveSession session) {
  final buf = StringBuffer();

  // Header row.
  buf.writeln(
    'Selection\tView\tChannel\t'
    'Begin Time (s)\tEnd Time (s)\t'
    'Low Freq (Hz)\tHigh Freq (Hz)\t'
    'Common Name\tScientific Name\tConfidence',
  );

  final windowSeconds = session.settings.windowDuration;

  for (var i = 0; i < session.detections.length; i++) {
    final d = session.detections[i];

    // Offset from recording start in seconds.
    final beginSec =
        d.timestamp.difference(session.startTime).inMilliseconds / 1000.0;
    final endSec = beginSec + windowSeconds;

    buf.writeln(
      '${i + 1}\t'
      'Spectrogram 1\t'
      '1\t'
      '${beginSec.toStringAsFixed(3)}\t'
      '${endSec.toStringAsFixed(3)}\t'
      '0\t'
      '$_highFreqHz\t'
      '${d.commonName}\t'
      '${d.scientificName}\t'
      '${d.confidence.toStringAsFixed(4)}',
    );
  }

  return buf.toString();
}

/// Creates a ZIP archive containing the session audio (WAV or FLAC) and a
/// Raven selection table, and writes it to a temporary file.
///
/// Returns the path to the ZIP file, or `null` if the recording does not exist.
Future<String?> buildSessionZip(LiveSession session) async {
  final audioPath = session.recordingPath;
  if (audioPath == null || !File(audioPath).existsSync()) return null;

  final archive = Archive();

  // Use the session display name for all exported filenames.
  final baseName = session.displayName;
  final audioExt = p.extension(audioPath); // .wav or .flac

  // Add the audio file (WAV or FLAC).
  final audioBytes = await File(audioPath).readAsBytes();
  archive.addFile(
    ArchiveFile('$baseName$audioExt', audioBytes.length, audioBytes),
  );

  // Add the Raven selection table.
  final table = buildRavenSelectionTable(session);
  final tableBytes = Uint8List.fromList(table.codeUnits);
  archive.addFile(
    ArchiveFile('$baseName.selections.txt', tableBytes.length, tableBytes),
  );

  // Encode and write to a temp file alongside the audio.
  final zipBytes = ZipEncoder().encode(archive);

  final zipName = '$baseName.zip';
  final zipPath = p.join(p.dirname(audioPath), zipName);
  await File(zipPath).writeAsBytes(zipBytes);

  return zipPath;
}
