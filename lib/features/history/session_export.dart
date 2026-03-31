// =============================================================================
// Session Export
// =============================================================================
//
// Generates export artifacts for a live session:
//
//   • **Raven selection table** (.txt): Tab-delimited annotation file
//     compatible with Raven Pro / Raven Lite.
//
//   • **CSV Export** (.csv): Standard comma-separated values.
//
//   • **JSON Export** (.json): Machine-readable JSON structured data.
//
//   • **ZIP bundle** (.zip): Optionally archives the full WAV/FLAC recording
//     together with the export document for convenient sharing.
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../live/live_session.dart';

/// Upper frequency bound for Raven annotations (Nyquist of 32 kHz).
const int _highFreqHz = 16000;

/// Generates a Raven Pro-compatible selection table from session detections.
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

/// Generates a standard CSV representation of session detections.
String buildCsvExport(LiveSession session) {
  final buf = StringBuffer();

  // Header row.
  buf.writeln(
      'Timestamp,Begin Time (s),Common Name,Scientific Name,Confidence');

  for (final d in session.detections) {
    final beginSec =
        d.timestamp.difference(session.startTime).inMilliseconds / 1000.0;

    // Simple CSV escaping for species names
    final commonName =
        d.commonName.contains(',') ? '"${d.commonName}"' : d.commonName;
    final sciName = d.scientificName.contains(',')
        ? '"${d.scientificName}"'
        : d.scientificName;

    buf.writeln(
      '${d.timestamp.toIso8601String()},'
      '${beginSec.toStringAsFixed(3)},'
      '$commonName,'
      '$sciName,'
      '${d.confidence.toStringAsFixed(4)}',
    );
  }

  return buf.toString();
}

/// Generates a JSON representation of the session and its detections.
String buildJsonExport(LiveSession session) {
  final map = {
    'session': session.displayName,
    'startTime': session.startTime.toIso8601String(),
    'endTime': session.endTime?.toIso8601String(),
    'recordingPath': session.recordingPath,
    'settings': {
      'windowDuration': session.settings.windowDuration,
      'confidenceThreshold': session.settings.confidenceThreshold,
      'inferenceRate': session.settings.inferenceRate,
      'speciesFilterMode': session.settings.speciesFilterMode,
    },
    'detections': session.detections.map((d) {
      final beginSec =
          d.timestamp.difference(session.startTime).inMilliseconds / 1000.0;
      return {
        'timestamp': d.timestamp.toIso8601String(),
        'beginTimeSec': num.parse(beginSec.toStringAsFixed(3)),
        'commonName': d.commonName,
        'scientificName': d.scientificName,
        'confidence': num.parse(d.confidence.toStringAsFixed(4)),
      };
    }).toList(),
  };

  return const JsonEncoder.withIndent('  ').convert(map);
}

/// Creates an export bundle containing the session data and optionally audio.
///
/// If [includeAudio] is true and audio exists, returns a path to a .zip file.
/// If [includeAudio] is false or no audio exists, returns a path to the raw
/// text/json file.
Future<String?> buildSessionExport(
  LiveSession session, {
  required String format,
  required bool includeAudio,
}) async {
  final baseName = session.displayName;
  final audioPath = session.recordingPath;
  final hasAudio = audioPath != null && File(audioPath).existsSync();

  String fileContent;
  String extension;

  switch (format) {
    case 'csv':
      fileContent = buildCsvExport(session);
      extension = '.csv';
      break;
    case 'json':
      fileContent = buildJsonExport(session);
      extension = '.json';
      break;
    case 'raven':
    default:
      fileContent = buildRavenSelectionTable(session);
      extension = '.selections.txt';
      break;
  }

  final bytes = Uint8List.fromList(utf8.encode(fileContent));

  if (includeAudio && hasAudio) {
    final archive = Archive();
    final audioExt = p.extension(audioPath);
    final audioBytes = await File(audioPath).readAsBytes();

    archive.addFile(
      ArchiveFile('$baseName$audioExt', audioBytes.length, audioBytes),
    );
    archive.addFile(
      ArchiveFile('$baseName$extension', bytes.length, bytes),
    );

    final zipBytes = ZipEncoder().encode(archive);

    final zipName = '$baseName.zip';
    final zipPath = p.join(p.dirname(audioPath), zipName);
    await File(zipPath).writeAsBytes(zipBytes!);

    return zipPath;
  } else {
    // If no audio or user opted out of including audio, just write and share the doc file.
    final dir = hasAudio ? p.dirname(audioPath) : Directory.systemTemp.path;
    final filePath = p.join(dir, '$baseName$extension');
    await File(filePath).writeAsBytes(bytes);

    return filePath;
  }
}
