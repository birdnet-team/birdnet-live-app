// =============================================================================
// Session Export Tests — Raven selection table and ZIP bundle
// =============================================================================

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:birdnet_live/features/history/session_export.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:flutter_test/flutter_test.dart';

LiveSession _makeSession({
  List<DetectionRecord>? detections,
  String? recordingPath,
  int windowDuration = 3,
}) {
  final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
  return LiveSession(
    id: '2025-06-15T08-00-00',
    startTime: start,
    endTime: start.add(const Duration(minutes: 5)),
    detections: detections,
    recordingPath: recordingPath,
    settings: SessionSettings(
      windowDuration: windowDuration,
      confidenceThreshold: 25,
      inferenceRate: 1.0,
      speciesFilterMode: 'off',
    ),
  );
}

DetectionRecord _det(
  String sci,
  String common,
  double conf,
  Duration offset,
  DateTime start,
) {
  return DetectionRecord(
    scientificName: sci,
    commonName: common,
    confidence: conf,
    timestamp: start.add(offset),
  );
}

void main() {
  group('buildRavenSelectionTable', () {
    test('header row has correct columns', () {
      final session = _makeSession();
      final table = buildRavenSelectionTable(session);
      final header = table.split('\n').first;

      expect(header, contains('Selection'));
      expect(header, contains('View'));
      expect(header, contains('Channel'));
      expect(header, contains('Begin Time (s)'));
      expect(header, contains('End Time (s)'));
      expect(header, contains('Low Freq (Hz)'));
      expect(header, contains('High Freq (Hz)'));
      expect(header, contains('Common Name'));
      expect(header, contains('Scientific Name'));
      expect(header, contains('Confidence'));
    });

    test('empty detections produces header only', () {
      final session = _makeSession();
      final table = buildRavenSelectionTable(session);
      final lines = table.split('\n').where((l) => l.isNotEmpty).toList();

      expect(lines.length, 1); // header only
    });

    test('detection rows have correct values', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        windowDuration: 3,
        detections: [
          _det('Turdus merula', 'Eurasian Blackbird', 0.95,
              const Duration(seconds: 10), start),
          _det('Erithacus rubecula', 'European Robin', 0.72,
              const Duration(seconds: 25, milliseconds: 500), start),
        ],
      );

      final table = buildRavenSelectionTable(session);
      final lines = table.split('\n').where((l) => l.isNotEmpty).toList();

      expect(lines.length, 3); // header + 2 detections

      // First detection.
      final cols1 = lines[1].split('\t');
      expect(cols1[0], '1'); // Selection
      expect(cols1[1], 'Spectrogram 1'); // View
      expect(cols1[2], '1'); // Channel
      expect(cols1[3], '10.000'); // Begin Time
      expect(cols1[4], '13.000'); // End Time (10 + 3)
      expect(cols1[5], '0'); // Low Freq
      expect(cols1[6], '16000'); // High Freq
      expect(cols1[7], 'Eurasian Blackbird'); // Common Name
      expect(cols1[8], 'Turdus merula'); // Scientific Name
      expect(cols1[9], '0.9500'); // Confidence

      // Second detection.
      final cols2 = lines[2].split('\t');
      expect(cols2[0], '2');
      expect(cols2[3], '25.500'); // 25.5 seconds
      expect(cols2[4], '28.500'); // 25.5 + 3
      expect(cols2[7], 'European Robin');
      expect(cols2[8], 'Erithacus rubecula');
      expect(cols2[9], '0.7200');
    });

    test('uses session window duration for end time', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        windowDuration: 5,
        detections: [
          _det('Parus major', 'Great Tit', 0.80, const Duration(seconds: 7),
              start),
        ],
      );

      final table = buildRavenSelectionTable(session);
      final lines = table.split('\n').where((l) => l.isNotEmpty).toList();
      final cols = lines[1].split('\t');

      expect(cols[3], '7.000'); // Begin
      expect(cols[4], '12.000'); // End (7 + 5)
    });
  });

  group('buildSessionExport', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('session_export_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('returns file without ZIP when recording path is null', () async {
      final session = _makeSession(recordingPath: null);
      final result = await buildSessionExport(session, format: 'raven', includeAudio: true);
      expect(result, isNotNull);
      expect(result!.endsWith('.txt'), isTrue);
    });

    test('returns file without ZIP when recording file does not exist', () async {
      final session = _makeSession(
        recordingPath: '${tempDir.path}/nonexistent.wav',
      );
      final result = await buildSessionExport(session, format: 'raven', includeAudio: true);
      expect(result, isNotNull);
      expect(result!.endsWith('.txt'), isTrue);
    });

    test('creates a ZIP with wav and selection table', () async {
      // Create a dummy WAV file.
      final wavPath = '${tempDir.path}/full.wav';
      File(wavPath).writeAsBytesSync([0x52, 0x49, 0x46, 0x46]); // "RIFF"

      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        recordingPath: wavPath,
        detections: [
          _det('Turdus merula', 'Eurasian Blackbird', 0.91,
              const Duration(seconds: 5), start),
        ],
      );

      final zipPath = await buildSessionExport(session, format: 'raven', includeAudio: true);
      expect(zipPath, isNotNull);
      expect(File(zipPath!).existsSync(), isTrue);

      // Verify ZIP contents.
      final zipBytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      final names = archive.map((f) => f.name).toList();
      expect(names, contains('BirdNET-Live_Session_2025-06-15_08-00-00.wav'));
      expect(
        names,
        contains('BirdNET-Live_Session_2025-06-15_08-00-00.selections.txt'),
      );

      // Verify the selection table inside the ZIP.
      final tableFile =
          archive.firstWhere((f) => f.name.endsWith('.selections.txt'));
      final tableContent = String.fromCharCodes(tableFile.content as List<int>);
      expect(tableContent, contains('Selection\t'));
      expect(tableContent, contains('Turdus merula'));
    });
  });
}
