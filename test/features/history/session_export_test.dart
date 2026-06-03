// =============================================================================
// Session Export Tests â€” Raven selection table and ZIP bundle
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:birdnet_live/features/history/session_export.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

LiveSession _makeSession({
  List<DetectionRecord>? detections,
  String? recordingPath,
  int windowDuration = 3,
  int clipContextSeconds = 0,
  SessionType type = SessionType.live,
}) {
  final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
  return LiveSession(
    id: '2025-06-15T08-00-00',
    startTime: start,
    endTime: start.add(const Duration(minutes: 5)),
    type: type,
    detections: detections,
    recordingPath: recordingPath,
    settings: SessionSettings(
      windowDuration: windowDuration,
      confidenceThreshold: 25,
      inferenceRate: 1.0,
      speciesFilterMode: 'off',
      clipContextSeconds: clipContextSeconds,
    ),
  );
}

DetectionRecord _det(
  String sci,
  String common,
  double conf,
  Duration offset,
  DateTime start, {
  String? audioClipPath,
}) {
  return DetectionRecord(
    scientificName: sci,
    commonName: common,
    confidence: conf,
    timestamp: start.add(offset),
    audioClipPath: audioClipPath,
  );
}

/// The expected BirdNET_Live export prefix for the test session
/// (2025-06-15 08:00:00 UTC, no session number). Built from local time so
/// the test stays timezone-agnostic â€” export filenames are always rendered
/// in the user's local time so they sort sensibly in their file browser.
final _prefix =
    'BirdNET_Live_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.utc(2025, 6, 15, 8, 0, 0).toLocal())}';

void main() {
  group('buildRavenSelectionTable', () {
    test('header row has correct columns including Begin File', () {
      final session = _makeSession();
      final table = buildRavenSelectionTable(session);
      final header = table.split('\n').first;

      expect(header, contains('Selection'));
      expect(header, contains('View'));
      expect(header, contains('Channel'));
      expect(header, contains('Begin File'));
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

    test('single-file mode: rows reference the audio file', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        windowDuration: 3,
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.95,
            const Duration(seconds: 10),
            start,
          ),
          _det(
            'Erithacus rubecula',
            'European Robin',
            0.72,
            const Duration(seconds: 25, milliseconds: 500),
            start,
          ),
        ],
      );

      final table = buildRavenSelectionTable(
        session,
        audioFileName: '$_prefix.wav',
      );
      final lines = table.split('\n').where((l) => l.isNotEmpty).toList();

      expect(lines.length, 3); // header + 2 detections

      // First detection â€” columns shifted by Begin File.
      final cols1 = lines[1].split('\t');
      expect(cols1[0], '1'); // Selection
      expect(cols1[1], 'Spectrogram 1'); // View
      expect(cols1[2], '1'); // Channel
      expect(cols1[3], '$_prefix.wav'); // Begin File
      expect(cols1[4], '10.000'); // Begin Time
      expect(cols1[5], '13.000'); // End Time (10 + 3)
      expect(cols1[6], '0'); // Low Freq
      expect(cols1[7], '16000'); // High Freq
      expect(cols1[8], 'Eurasian Blackbird'); // Common Name
      expect(cols1[9], 'Turdus merula'); // Scientific Name
      expect(cols1[10], '0.9500'); // Confidence

      // Second detection.
      final cols2 = lines[2].split('\t');
      expect(cols2[0], '2');
      expect(cols2[3], '$_prefix.wav');
      expect(cols2[4], '25.500'); // 25.5 seconds
      expect(cols2[5], '28.500'); // 25.5 + 3
      expect(cols2[8], 'European Robin');
    });

    test(
      'clip mode: Begin/End Time are in-clip offsets and a Survey Time column is added',
      () {
        final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
        final session = _makeSession(
          windowDuration: 3,
          clipContextSeconds: 1,
          detections: [
            _det(
              'Turdus merula',
              'Eurasian Blackbird',
              0.95,
              const Duration(seconds: 10),
              start,
            ),
            _det(
              'Erithacus rubecula',
              'European Robin',
              0.72,
              const Duration(seconds: 25),
              start,
            ),
          ],
        );

        final table = buildRavenSelectionTable(
          session,
          clipFileMap: {
            0: '${_prefix}_clip_001_Eurasian_Blackbird.flac',
            1: '${_prefix}_clip_002_European_Robin.flac',
          },
        );
        final lines = table.split('\n').where((l) => l.isNotEmpty).toList();

        // Header gains 'Survey Time (s)' when any row references a clip.
        expect(lines.first, contains('Survey Time (s)'));

        final cols1 = lines[1].split('\t');
        expect(cols1[3], '${_prefix}_clip_001_Eurasian_Blackbird.flac');
        // Detection sits at [clipContext, clipContext + window] inside the clip.
        expect(cols1[4], '1.000');
        expect(cols1[5], '4.000');
        // Survey Time column carries the session-relative offset.
        expect(cols1[11], '10.000');

        final cols2 = lines[2].split('\t');
        expect(cols2[3], '${_prefix}_clip_002_European_Robin.flac');
        expect(cols2[4], '1.000');
        expect(cols2[5], '4.000');
        expect(cols2[11], '25.000');
      },
    );

    test('no file refs: Begin File column is empty', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        detections: [
          _det(
            'Parus major',
            'Great Tit',
            0.80,
            const Duration(seconds: 7),
            start,
          ),
        ],
      );

      final table = buildRavenSelectionTable(session);
      final cols = table.split('\n')[1].split('\t');
      expect(cols[3], ''); // Begin File empty
      expect(cols[4], '7.000'); // Begin Time still works
    });

    test('uses session window duration for end time', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        windowDuration: 5,
        detections: [
          _det(
            'Parus major',
            'Great Tit',
            0.80,
            const Duration(seconds: 7),
            start,
          ),
        ],
      );

      final table = buildRavenSelectionTable(session);
      final lines = table.split('\n').where((l) => l.isNotEmpty).toList();
      final cols = lines[1].split('\t');

      expect(cols[4], '7.000'); // Begin
      expect(cols[5], '12.000'); // End (7 + 5)
    });

    test('includes Latitude/Longitude when detections have coordinates', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        detections: [
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.90,
            timestamp: start.add(const Duration(seconds: 10)),
            latitude: 52.520008,
            longitude: 13.404954,
          ),
        ],
      );

      final table = buildRavenSelectionTable(session);
      final lines = table.split('\n');
      final header = lines.first.split('\t');
      expect(header, contains('Latitude'));
      expect(header, contains('Longitude'));

      final cols = lines[1].split('\t');
      final latIdx = header.indexOf('Latitude');
      final lonIdx = header.indexOf('Longitude');
      expect(cols[latIdx], '52.520008');
      expect(cols[lonIdx], '13.404954');
    });

    test('omits Latitude/Longitude when no detections have coordinates', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.90,
            const Duration(seconds: 10),
            start,
          ),
        ],
      );

      final table = buildRavenSelectionTable(session);
      final header = table.split('\n').first;
      expect(header, isNot(contains('Latitude')));
    });

    test('Survey Time column is always present (single-file mode)', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.95,
            const Duration(seconds: 10),
            start,
          ),
        ],
      );

      final table = buildRavenSelectionTable(
        session,
        audioFileName: '$_prefix.wav',
      );
      expect(table.split('\n').first, contains('Survey Time (s)'));
      final cols = table.split('\n')[1].split('\t');
      expect(cols[11], '10.000');
    });

    test('useAbsoluteSurveyTime renames column and emits ISO UTC value', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.95,
            const Duration(seconds: 10),
            start,
          ),
        ],
      );

      final table = buildRavenSelectionTable(
        session,
        audioFileName: '$_prefix.wav',
        useAbsoluteSurveyTime: true,
      );
      final header = table.split('\n').first;
      expect(header, contains('Survey Time (UTC)'));
      expect(header, isNot(contains('Survey Time (s)')));
      final cols = table.split('\n')[1].split('\t');
      expect(cols[11], '2025-06-15T08:00:10.000Z');
    });
  });

  // â”€â”€ CSV export â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('buildCsvExport', () {
    test('includes File column when audioFileName provided', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
          ),
        ],
      );

      final csv = buildCsvExport(session, audioFileName: '$_prefix.flac');
      final header = csv.split('\n').first;
      // File column appears before the always-present Survey Time column.
      expect(header, contains(',File,'));

      final row = csv.split('\n')[1];
      expect(row, contains(',$_prefix.flac,'));
    });

    test('omits File column when no audio references', () {
      final session = _makeSession();
      final csv = buildCsvExport(session);
      final header = csv.split('\n').first;
      expect(header, isNot(contains('File')));
    });

    test('Survey Time column is always present', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
          ),
        ],
      );
      final csv = buildCsvExport(session);
      final lines = csv.split('\n');
      final header = lines.first.split(',');
      expect(header, contains('Survey Time (s)'));
      final idx = header.indexOf('Survey Time (s)');
      final cols = lines[1].split(',');
      expect(cols[idx], '5.000');
    });

    test('useAbsoluteSurveyTime renames CSV column and emits ISO UTC', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
          ),
        ],
      );
      final csv = buildCsvExport(session, useAbsoluteSurveyTime: true);
      final lines = csv.split('\n');
      final header = lines.first.split(',');
      expect(header, contains('Survey Time (UTC)'));
      expect(header, isNot(contains('Survey Time (s)')));
      final idx = header.indexOf('Survey Time (UTC)');
      final cols = lines[1].split(',');
      expect(cols[idx], '2025-06-15T08:00:05.000Z');
    });
  });

  // â”€â”€ ZIP bundle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
      final result = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
      );
      expect(result, isNotNull);
      expect(result!.endsWith('.txt'), isTrue);
      expect(p.basename(result), startsWith('BirdNET_Live_'));
    });

    test(
      'returns file without ZIP when recording file does not exist',
      () async {
        final session = _makeSession(
          recordingPath: '${tempDir.path}/nonexistent.wav',
        );
        final result = await buildSessionExport(
          session,
          formats: const {'raven'},
          includeAudio: true,
        );
        expect(result, isNotNull);
        expect(result!.endsWith('.txt'), isTrue);
      },
    );

    test(
      'creates a ZIP with wav and selection table (full recording)',
      () async {
        final wavPath = '${tempDir.path}/full.wav';
        File(wavPath).writeAsBytesSync([0x52, 0x49, 0x46, 0x46]); // "RIFF"

        final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
        final session = _makeSession(
          recordingPath: wavPath,
          detections: [
            _det(
              'Turdus merula',
              'Eurasian Blackbird',
              0.91,
              const Duration(seconds: 5),
              start,
            ),
          ],
        );

        final zipPath = await buildSessionExport(
          session,
          formats: const {'raven'},
          includeAudio: true,
        );
        expect(zipPath, isNotNull);
        expect(File(zipPath!).existsSync(), isTrue);

        final zipBytes = File(zipPath).readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(zipBytes);

        final names = archive.map((f) => f.name).toList();
        expect(names, contains('$_prefix.wav'));
        expect(names, contains('$_prefix.selections.txt'));

        // Selection table inside ZIP references the audio file.
        final tableFile = archive.firstWhere(
          (f) => f.name.endsWith('.selections.txt'),
        );
        final tableContent = String.fromCharCodes(
          tableFile.content as List<int>,
        );
        expect(tableContent, contains('Begin File'));
        expect(tableContent, contains('$_prefix.wav'));
        expect(tableContent, contains('Turdus merula'));
      },
    );

    test('creates a ZIP with detection clips (clips mode)', () async {
      // Create clip files on disk.
      final clipDir = '${tempDir.path}/clips';
      Directory(clipDir).createSync();
      final clip1Path = '$clipDir/clip_1000.flac';
      final clip2Path = '$clipDir/clip_2000.flac';
      File(clip1Path).writeAsBytesSync([0x66, 0x4C, 0x61, 0x43]); // "fLaC"
      File(clip2Path).writeAsBytesSync([0x66, 0x4C, 0x61, 0x43]);

      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        // recordingPath is a directory (detectionsOnly mode).
        recordingPath: clipDir,
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
            audioClipPath: clip1Path,
          ),
          _det(
            'Erithacus rubecula',
            'European Robin',
            0.72,
            const Duration(seconds: 25),
            start,
            audioClipPath: clip2Path,
          ),
        ],
      );

      final zipPath = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
      );
      expect(zipPath, isNotNull);
      expect(File(zipPath!).existsSync(), isTrue);

      final zipBytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      final names = archive.map((f) => f.name).toList();
      // Clips include sequential number + species common name.
      expect(names, contains('${_prefix}_clip_001_Eurasian_Blackbird.flac'));
      expect(names, contains('${_prefix}_clip_002_European_Robin.flac'));
      expect(names, contains('$_prefix.selections.txt'));

      // Selection table references clip filenames.
      final tableFile = archive.firstWhere(
        (f) => f.name.endsWith('.selections.txt'),
      );
      final tableContent = String.fromCharCodes(tableFile.content as List<int>);
      expect(tableContent, contains('_clip_001_Eurasian_Blackbird.flac'));
      expect(tableContent, contains('_clip_002_European_Robin.flac'));
    });

    test('includes custom name in export filenames', () async {
      final wavPath = '${tempDir.path}/full.wav';
      File(wavPath).writeAsBytesSync([0x52, 0x49, 0x46, 0x46]);

      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        recordingPath: wavPath,
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
          ),
        ],
      );
      session.customName = 'Morning walk';

      final zipPath = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
      );
      expect(zipPath, isNotNull);

      final zipBytes = File(zipPath!).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      final names = archive.map((f) => f.name).toList();
      // Custom name is appended after the timestamp.
      expect(names, contains('${_prefix}_Morning_walk.wav'));
      expect(names, contains('${_prefix}_Morning_walk.selections.txt'));
    });

    test('auto-includes GPX in survey ZIP bundles', () async {
      final wavPath = '${tempDir.path}/full.wav';
      File(wavPath).writeAsBytesSync([0x52, 0x49, 0x46, 0x46]);

      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        recordingPath: wavPath,
        type: SessionType.survey,
        detections: [
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.90,
            timestamp: start.add(const Duration(seconds: 10)),
            latitude: 52.520008,
            longitude: 13.404954,
          ),
        ],
      );

      final zipPath = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
      );
      expect(zipPath, isNotNull);

      final zipBytes = File(zipPath!).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      final names = archive.map((f) => f.name).toList();
      expect(names, contains('$_prefix.selections.txt'));
      expect(names, contains('$_prefix.gpx'));

      // GPX contains the detection waypoint.
      final gpxFile = archive.firstWhere((f) => f.name.endsWith('.gpx'));
      final gpxContent = String.fromCharCodes(gpxFile.content as List<int>);
      expect(gpxContent, contains('<wpt'));
      expect(gpxContent, contains('Eurasian Blackbird'));
    });
  });

  // â”€â”€ JSON export: new fields â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('buildJsonExport new fields', () {
    test('includes trim offsets when set', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
          ),
        ],
      );
      session.trimStartSec = 2.0;
      session.trimEndSec = 250.0;

      final jsonStr = buildJsonExport(session);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['trimStartSec'], 2.0);
      expect(map['trimEndSec'], 250.0);
    });

    test('omits trim offsets when null', () {
      final session = _makeSession();

      final jsonStr = buildJsonExport(session);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map.containsKey('trimStartSec'), isFalse);
      expect(map.containsKey('trimEndSec'), isFalse);
    });

    test('includes source for manual detections', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        detections: [
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 1.0,
            timestamp: start.add(const Duration(seconds: 10)),
            source: DetectionSource.manual,
          ),
        ],
      );

      final jsonStr = buildJsonExport(session);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final det = (map['detections'] as List).first as Map<String, dynamic>;

      expect(det['source'], 'manual');
    });

    test('omits source for auto detections', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
          ),
        ],
      );

      final jsonStr = buildJsonExport(session);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final det = (map['detections'] as List).first as Map<String, dynamic>;

      expect(det.containsKey('source'), isFalse);
    });

    test('includes annotations when present', () {
      final session = _makeSession();
      session.annotations.addAll([
        SessionAnnotation(
          text: 'Global note',
          createdAt: DateTime.utc(2025, 6, 15, 8, 1),
        ),
        SessionAnnotation(
          text: 'Timed note',
          createdAt: DateTime.utc(2025, 6, 15, 8, 2),
          offsetInRecording: 30.0,
        ),
      ]);

      final jsonStr = buildJsonExport(session);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map.containsKey('annotations'), isTrue);
      final annotations = map['annotations'] as List;
      expect(annotations.length, 2);
      expect((annotations[0] as Map)['text'], 'Global note');
      expect((annotations[1] as Map)['offsetInRecording'], 30.0);
    });

    test('omits annotations when empty', () {
      final session = _makeSession();

      final jsonStr = buildJsonExport(session);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map.containsKey('annotations'), isFalse);
    });
  });

  // â”€â”€ ZIP bundle: annotations file â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('ZIP bundle with annotations', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('session_export_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('includes annotations.txt when annotations present', () async {
      final wavPath = '${tempDir.path}/full.wav';
      File(wavPath).writeAsBytesSync([0x52, 0x49, 0x46, 0x46]);

      final session = _makeSession(recordingPath: wavPath);
      session.annotations.addAll([
        SessionAnnotation(
          text: 'Clear morning',
          createdAt: DateTime.utc(2025, 6, 15, 8, 0),
        ),
        SessionAnnotation(
          text: 'Robin singing nearby',
          createdAt: DateTime.utc(2025, 6, 15, 8, 1),
          offsetInRecording: 65.0,
        ),
      ]);

      final zipPath = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
      );
      expect(zipPath, isNotNull);

      final zipBytes = File(zipPath!).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      final names = archive.map((f) => f.name).toList();
      expect(names, contains(endsWith('.annotations.txt')));

      final annotFile = archive.firstWhere(
        (f) => f.name.endsWith('.annotations.txt'),
      );
      final content = String.fromCharCodes(annotFile.content as List<int>);

      expect(content, contains('[Global] Clear morning'));
      expect(content, contains('[01:05] Robin singing nearby'));
    });

    test('no annotations.txt when annotations empty', () async {
      final wavPath = '${tempDir.path}/full.wav';
      File(wavPath).writeAsBytesSync([0x52, 0x49, 0x46, 0x46]);

      final session = _makeSession(recordingPath: wavPath);

      final zipPath = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
      );
      expect(zipPath, isNotNull);

      final zipBytes = File(zipPath!).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      final names = archive.map((f) => f.name).toList();
      expect(names.any((n) => n.contains('annotations')), isFalse);
    });
  });

  // â”€â”€ Confirmed-detection flag in exports (#33) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('confirmed-detection flag in exports', () {
    DetectionRecord makeConfirmed(
      String sci,
      String common,
      double conf,
      Duration offset,
      DateTime start, {
      DateTime? confirmedAt,
      double? lat,
      double? lon,
    }) {
      return DetectionRecord(
        scientificName: sci,
        commonName: common,
        confidence: conf,
        timestamp: start.add(offset),
        confirmedAt: confirmedAt,
        latitude: lat,
        longitude: lon,
      );
    }

    test('Raven table emits Confirmed columns and per-row values', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final stamp = DateTime.utc(2025, 6, 15, 9, 30);
      final session = _makeSession(
        detections: [
          makeConfirmed(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
            confirmedAt: stamp,
          ),
          makeConfirmed(
            'Erithacus rubecula',
            'European Robin',
            0.80,
            const Duration(seconds: 10),
            start,
          ),
        ],
      );

      final table = buildRavenSelectionTable(session);
      final lines = table.split('\n');
      final header = lines.first.split('\t');
      expect(header, contains('Confirmed'));
      expect(header, contains('Confirmed At (UTC)'));
      final cIdx = header.indexOf('Confirmed');
      final cAtIdx = header.indexOf('Confirmed At (UTC)');

      final row1 = lines[1].split('\t');
      expect(row1[cIdx], 'true');
      expect(row1[cAtIdx], '2025-06-15T09:30:00.000Z');

      final row2 = lines[2].split('\t');
      expect(row2[cIdx], 'false');
      expect(row2[cAtIdx], '');
    });

    test('CSV emits Confirmed columns and per-row values', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final stamp = DateTime.utc(2025, 6, 15, 9, 30);
      final session = _makeSession(
        detections: [
          makeConfirmed(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
            confirmedAt: stamp,
          ),
          makeConfirmed(
            'Erithacus rubecula',
            'European Robin',
            0.80,
            const Duration(seconds: 10),
            start,
          ),
        ],
      );

      final csv = buildCsvExport(session);
      final lines = csv.split('\n');
      final header = lines.first.split(',');
      expect(header, contains('Confirmed'));
      expect(header, contains('Confirmed At (UTC)'));
      final cIdx = header.indexOf('Confirmed');
      final cAtIdx = header.indexOf('Confirmed At (UTC)');

      final row1 = lines[1].split(',');
      expect(row1[cIdx], 'true');
      expect(row1[cAtIdx], '2025-06-15T09:30:00.000Z');

      final row2 = lines[2].split(',');
      expect(row2[cIdx], 'false');
      expect(row2[cAtIdx], '');
    });

    test('JSON emits confirmed (always) and confirmedAt (only when set)', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final stamp = DateTime.utc(2025, 6, 15, 9, 30);
      final session = _makeSession(
        detections: [
          makeConfirmed(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
            confirmedAt: stamp,
          ),
          makeConfirmed(
            'Erithacus rubecula',
            'European Robin',
            0.80,
            const Duration(seconds: 10),
            start,
          ),
        ],
      );

      final map = jsonDecode(buildJsonExport(session)) as Map<String, dynamic>;
      final dets = map['detections'] as List;
      final d0 = dets[0] as Map<String, dynamic>;
      final d1 = dets[1] as Map<String, dynamic>;
      expect(d0['confirmed'], true);
      expect(d0['confirmedAt'], '2025-06-15T09:30:00.000Z');
      expect(d1['confirmed'], false);
      expect(d1.containsKey('confirmedAt'), isFalse);
    });

    test(
      'GPX adds <sym>confirmed</sym> + <cmt> only for confirmed waypoints',
      () {
        final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
        final stamp = DateTime.utc(2025, 6, 15, 9, 30);
        final session = _makeSession(
          type: SessionType.survey,
          detections: [
            makeConfirmed(
              'Turdus merula',
              'Eurasian Blackbird',
              0.91,
              const Duration(seconds: 5),
              start,
              confirmedAt: stamp,
              lat: 52.52,
              lon: 13.40,
            ),
            makeConfirmed(
              'Erithacus rubecula',
              'European Robin',
              0.80,
              const Duration(seconds: 10),
              start,
              lat: 52.53,
              lon: 13.41,
            ),
          ],
        );

        final gpx = buildGpxExport(session);
        // Confirmed waypoint carries the badge + audit comment.
        expect(gpx, contains('<sym>confirmed</sym>'));
        expect(
          gpx,
          contains('<cmt>Confirmed at 2025-06-15T09:30:00.000Z</cmt>'),
        );
        // Exactly one of each â€” the unconfirmed waypoint must not emit them.
        expect('<sym>confirmed</sym>'.allMatches(gpx).length, 1);
        expect('<cmt>'.allMatches(gpx).length, 1);
      },
    );
  });

  group('buildMultiSessionExport', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bulk_export_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('returns null for empty sessions', () async {
      final result = await buildMultiSessionExport(
        [],
        formats: const {'json'},
        includeAudio: false,
      );
      expect(result, isNull);
    });

    test('creates a bulk zip containing multiple session exports', () async {
      final start1 = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session1 = _makeSession(
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.95,
            const Duration(seconds: 10),
            start1,
          ),
        ],
      );

      final start2 = DateTime.utc(2025, 6, 16, 9, 30, 0);
      final session2 = LiveSession(
        id: '2025-06-16T09-30-00',
        startTime: start2,
        endTime: start2.add(const Duration(minutes: 5)),
        type: SessionType.live,
        detections: [
          _det(
            'Parus major',
            'Great Tit',
            0.85,
            const Duration(seconds: 5),
            start2,
          ),
        ],
        settings: SessionSettings(
          windowDuration: 3,
          confidenceThreshold: 25,
          inferenceRate: 1.0,
          speciesFilterMode: 'off',
        ),
      );

      final bulkZipPath = await buildMultiSessionExport(
        [session1, session2],
        formats: const {'json'},
        includeAudio: false,
      );

      expect(bulkZipPath, isNotNull);
      final file = File(bulkZipPath!);
      expect(file.existsSync(), isTrue);
      expect(p.basename(file.path), startsWith('BirdNET_Live_Bulk_Export_'));

      final zipBytes = file.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final names = archive.map((f) => f.name).toList();

      expect(names.length, 2);
      expect(
        names.any((n) => n.contains('2025-06-15') && n.endsWith('.json')),
        isTrue,
      );
      expect(
        names.any((n) => n.contains('2025-06-16') && n.endsWith('.json')),
        isTrue,
      );
    });
  });
}
