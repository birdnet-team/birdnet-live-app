// =============================================================================
// Session Export Tests â€” Raven selection table and ZIP bundle
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:birdnet_live/features/history/session_export.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/recording/audio_decoder.dart';
import 'package:birdnet_live/features/recording/flac_encoder.dart';
import 'package:birdnet_live/features/recording/wav_writer.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

LiveSession _makeSession({
  List<DetectionRecord>? detections,
  String? recordingPath,
  int windowDuration = 3,
  int clipContextSeconds = 0,
  String? recordingMode,
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
      recordingMode: recordingMode,
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
  Duration? endOffset,
}) {
  return DetectionRecord(
    scientificName: sci,
    commonName: common,
    confidence: conf,
    timestamp: start.add(offset),
    endTimestamp: endOffset == null ? null : start.add(endOffset),
    audioClipPath: audioClipPath,
  );
}

TaxonomyService _localizedTaxonomy() {
  return TaxonomyService()..loadFromCsv(
    'scientific_name,common_name,common_name_de\n'
    'Turdus merula,Eurasian Blackbird,Amsel',
  );
}

/// The expected BirdNET_Live export prefix for the test session
/// (2025-06-15 08:00:00 UTC, no session number). Built from local time so
/// the test stays timezone-agnostic â€” export filenames are always rendered
/// in the user's local time so they sort sensibly in their file browser.
final _prefix =
    'BirdNET_Live_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.utc(2025, 6, 15, 8, 0, 0).toLocal())}';

void main() {
  test('common names are localized consistently in every export format', () {
    final start = DateTime.utc(2025, 6, 15, 8);
    final session = _makeSession(
      detections: [
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.9,
          timestamp: start,
          latitude: 52.52,
          longitude: 13.405,
        ),
      ],
    );
    final taxonomy = _localizedTaxonomy();

    expect(
      buildRavenSelectionTable(
        session,
        taxonomy: taxonomy,
        speciesLocale: 'de',
      ),
      contains('Amsel'),
    );
    expect(
      buildCsvExport(session, taxonomy: taxonomy, speciesLocale: 'de'),
      contains('Amsel'),
    );
    expect(
      buildJsonExport(session, taxonomy: taxonomy, speciesLocale: 'de'),
      contains('"commonName": "Amsel"'),
    );
    expect(
      buildGpxExport(session, taxonomy: taxonomy, speciesLocale: 'de'),
      contains('<name>Amsel</name>'),
    );
  });

  group('buildRavenSelectionTable', () {
    test('header row has correct columns including Begin File', () {
      final session = _makeSession();
      final table = buildRavenSelectionTable(session);
      final header = table.split('\n').first;

      expect(header.split('\t').take(8), [
        'Selection',
        'View',
        'Channel',
        'Begin Time (s)',
        'End Time (s)',
        'Low Freq (Hz)',
        'High Freq (Hz)',
        'Begin File',
      ]);
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

    test('resumed session: Begin Time uses gap-removed audio offset', () {
      // Run 1: 08:00:00–08:05:00 (300 s recorded). Stopped, then resumed.
      // Run 2: 08:35:00–08:40:00 (30-minute gap while stopped). A detection
      // 10 s into run 2 must map to 310 s in the gap-removed recording
      // (300 s of run 1 + 10 s), NOT 2110 s of wall-clock since start.
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final seg2Start = start.add(const Duration(minutes: 35));
      final session = LiveSession(
        id: '2025-06-15T08-00-00',
        startTime: start,
        endTime: start.add(const Duration(minutes: 40)),
        type: SessionType.survey,
        recordedDurationSeconds: 600,
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.95,
            const Duration(seconds: 10),
            seg2Start,
          ),
        ],
        settings: SessionSettings(
          windowDuration: 3,
          confidenceThreshold: 25,
          inferenceRate: 1.0,
          speciesFilterMode: 'off',
          clipContextSeconds: 0,
        ),
        segments: [
          SessionSegment(
            startTime: start,
            endTime: start.add(const Duration(minutes: 5)),
          ),
          SessionSegment(
            startTime: seg2Start,
            endTime: start.add(const Duration(minutes: 40)),
          ),
        ],
      );

      final table = buildRavenSelectionTable(
        session,
        audioFileName: '$_prefix.wav',
      );
      final cols = table
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList()[1]
          .split('\t');

      expect(cols[3], '310.000'); // Begin Time (gap removed)
      expect(cols[4], '313.000'); // End Time (310 + 3)

      session.detections.insert(
        0,
        _det('Parus major', 'Great Tit', 0.8, Duration.zero, start),
      );
      final clipRows = buildRavenSelectionTable(
        session,
        clipFileMap: {0: 'first.wav', 1: 'resumed.wav'},
        clipContextSecondsOverride: 1,
      ).split('\n');
      expect(clipRows[2].split('\t').sublist(3, 5), ['6.000', '9.000']);
      expect(clipRows[2].split('\t')[11], '2025-06-15T08:35:10.000Z');
    });

    test('resumed session: global annotation ends at recorded duration', () {
      final start = DateTime.utc(2025, 6, 15, 8);
      final resumedAt = start.add(const Duration(minutes: 35));
      final session = LiveSession(
        id: 'resumed',
        startTime: start,
        endTime: start.add(const Duration(minutes: 40)),
        type: SessionType.survey,
        detections: [
          DetectionRecord(
            scientificName: 'Global',
            commonName: 'Global',
            confidence: 1,
            timestamp: start,
            source: DetectionSource.manualGlobal,
          ),
        ],
        settings: const SessionSettings(
          windowDuration: 3,
          confidenceThreshold: 25,
          inferenceRate: 1,
          speciesFilterMode: 'off',
        ),
        segments: [
          SessionSegment(
            startTime: start,
            endTime: start.add(const Duration(minutes: 5)),
          ),
          SessionSegment(
            startTime: resumedAt,
            endTime: start.add(const Duration(minutes: 40)),
          ),
        ],
      );

      final cols = buildRavenSelectionTable(session).split('\n')[1].split('\t');
      expect(cols[3], '0.000');
      expect(cols[4], '600.000');
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

      // First detection.
      final cols1 = lines[1].split('\t');
      expect(cols1[0], '1'); // Selection
      expect(cols1[1], 'Spectrogram 1'); // View
      expect(cols1[2], '1'); // Channel
      expect(cols1[7], '$_prefix.wav'); // Begin File
      expect(cols1[3], '10.000'); // Begin Time
      expect(cols1[4], '13.000'); // End Time (10 + 3)
      expect(cols1[5], '0'); // Low Freq
      expect(cols1[6], '16000'); // High Freq
      expect(cols1[8], 'Eurasian Blackbird'); // Common Name
      expect(cols1[9], 'Turdus merula'); // Scientific Name
      expect(cols1[10], '0.9500'); // Confidence

      // Second detection.
      final cols2 = lines[2].split('\t');
      expect(cols2[0], '2');
      expect(cols2[7], '$_prefix.wav');
      expect(cols2[3], '25.500'); // 25.5 seconds
      expect(cols2[4], '28.500'); // 25.5 + 3
      expect(cols2[8], 'European Robin');
    });

    test('clip mode: Begin/End Time follow the sound-file sequence', () {
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

      expect(lines.first, contains('Survey Time (UTC)'));

      final cols1 = lines[1].split('\t');
      expect(cols1[7], '${_prefix}_clip_001_Eurasian_Blackbird.flac');
      // Detection sits at [clipContext, clipContext + window] inside the clip.
      expect(cols1[3], '1.000');
      expect(cols1[4], '4.000');
      // Survey Time retains the absolute detection timestamp.
      expect(cols1[11], '2025-06-15T08:00:10.000Z');

      final cols2 = lines[2].split('\t');
      expect(cols2[7], '${_prefix}_clip_002_European_Robin.flac');
      expect(cols2[3], '6.000');
      expect(cols2[4], '9.000');
      expect(cols2[11], '2025-06-15T08:00:25.000Z');
    });

    test('clip sequence follows map order and the context override', () {
      final start = DateTime.utc(2025, 6, 15, 8);
      final session = _makeSession(
        windowDuration: 5,
        detections: List.generate(
          4,
          (i) => _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.9,
            Duration(seconds: i * 20),
            start,
            endOffset: Duration(seconds: i * 20 + 15),
          ),
        ),
      );
      session.trimStartSec = 10;
      session.trimEndSec = 50;
      final rows = buildRavenSelectionTable(
        session,
        clipFileMap: {3: 'first.wav', 0: 'second.wav'},
        clipContextSecondsOverride: 2,
      ).split('\n');
      expect(rows[1].split('\t').sublist(3, 5), ['2.000', '7.000']);
      expect(rows[2].split('\t').sublist(3, 5), ['11.000', '16.000']);
      expect(rows[1].split('\t')[7], 'first.wav');
      expect(rows[2].split('\t')[7], 'second.wav');
      expect(rows.where((row) => row.isNotEmpty).length, 3);
      expect(
        buildRavenSelectionTable(
          session,
          clipFileMap: {},
        ).split('\n').where((row) => row.isNotEmpty).length,
        1,
      );
    });

    test('optional fields keep every Raven row structurally valid', () {
      final start = DateTime.utc(2025, 6, 15, 8);
      final plain = _det('Parus major', 'Great Tit', 0.8, Duration.zero, start);
      final annotated = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: 0.9,
        timestamp: start.add(const Duration(seconds: 10)),
        latitude: 52.52,
        longitude: 13.405,
        note: ' first\tsecond\r\nthird\nfourth ',
        evidence: DetectionEvidence.heardAndSeen,
        reviewStatus: ReviewStatus.confirmed,
        reviewedAt: start,
      );
      for (final detections in [
        [plain],
        [annotated, plain],
      ]) {
        final table = buildRavenSelectionTable(
          _makeSession(detections: detections),
        );
        final lines = table.split('\n');
        expect(lines.removeLast(), ''); // One final line terminator.
        final header = lines.first.split('\t');
        for (final line in lines) {
          expect(line, isNotEmpty);
          expect(line.split('\t').length, header.length);
        }
        for (final line in lines.skip(1)) {
          final fields = line.split('\t');
          for (final index in [0, 2, 3, 4, 5, 6]) {
            expect(double.parse(fields[index]).isFinite, isTrue);
          }
        }
        if (header.contains('Note')) {
          expect(
            lines[1].split('\t')[header.indexOf('Note')],
            'first second third fourth',
          );
          final empty = lines[2].split('\t');
          for (final column in [
            'Latitude',
            'Longitude',
            'Note',
            'Evidence',
            'Reviewed At (UTC)',
          ]) {
            expect(empty[header.indexOf(column)], '');
          }
        }
      }
    });

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
      expect(cols[7], ''); // Begin File empty
      expect(cols[3], '7.000'); // Begin Time still works
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

      expect(cols[3], '7.000'); // Begin
      expect(cols[4], '12.000'); // End (7 + 5)
    });

    test('uses endTimestamp for continuous detections in full recordings', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        windowDuration: 3,
        detections: [
          _det(
            'Certhia familiaris',
            'Eurasian Treecreeper',
            0.90,
            const Duration(seconds: 5),
            start,
            endOffset: const Duration(seconds: 19),
          ),
        ],
      );

      final table = buildRavenSelectionTable(
        session,
        audioFileName: '$_prefix.wav',
      );
      final cols = table.split('\n')[1].split('\t');

      expect(cols[3], '5.000');
      expect(cols[4], '19.000');
    });

    test('clip rows cover one analysis window for continuous detections', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        windowDuration: 3,
        clipContextSeconds: 1,
        detections: [
          _det(
            'Certhia familiaris',
            'Eurasian Treecreeper',
            0.90,
            const Duration(seconds: 5),
            start,
            endOffset: const Duration(seconds: 19),
          ),
        ],
      );

      final table = buildRavenSelectionTable(
        session,
        clipFileMap: {0: '${_prefix}_clip_001_Eurasian_Treecreeper.wav'},
      );
      final cols = table.split('\n')[1].split('\t');

      expect(cols[3], '1.000');
      expect(cols[4], '4.000');
      expect(cols[11], '2025-06-15T08:00:05.000Z');
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
      expect(table.split('\n').first, contains('Survey Time (UTC)'));
      final cols = table.split('\n')[1].split('\t');
      expect(cols[11], '2025-06-15T08:00:10.000Z');
    });

    test('Survey Time emits ISO UTC without a display preference', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0).toLocal();
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

    test('uses endTimestamp for continuous detection ranges', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        windowDuration: 3,
        detections: [
          _det(
            'Certhia familiaris',
            'Eurasian Treecreeper',
            0.90,
            const Duration(seconds: 5),
            start,
            endOffset: const Duration(seconds: 19),
          ),
        ],
      );

      final csv = buildCsvExport(session, audioFileName: '$_prefix.wav');
      final cols = csv.split('\n')[1].split(',');

      expect(cols[1], '5.000');
      expect(cols[2], '19.000');
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

    test('clip mode without saved paths exports a Raven header only', () async {
      final session = _makeSession(
        recordingMode: 'detections',
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.9,
            Duration.zero,
            DateTime.utc(2025, 6, 15, 8),
          ),
        ],
      );
      final path = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
      );
      expect(path, isNotNull);
      final lines =
          File(path!)
              .readAsStringSync()
              .split('\n')
              .where((row) => row.isNotEmpty)
              .toList();
      expect(lines, hasLength(1));
      expect(lines.single, startsWith('Selection\t'));
    });

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

    for (final retained in [
      List.generate(10, (i) => i),
      [0, 3, 8],
      <int>[],
    ]) {
      test('Raven ZIP sequence with ${retained.length} of 10 clips', () async {
        final start = DateTime.utc(2025, 6, 15, 8);
        final detections = <DetectionRecord>[];
        for (var i = 0; i < 10; i++) {
          final path = p.join(tempDir.path, 'source_${10 - i}.wav');
          if (retained.contains(i)) {
            await WavWriter.writePcm16File(
              filePath: path,
              samples: Int16List(32000 * 5),
              sampleRate: 32000,
            );
          }
          detections.add(
            _det(
              'Turdus merula',
              'Eurasian Blackbird',
              0.9,
              Duration(seconds: i * 10),
              start,
              audioClipPath: i == 1 && !retained.contains(i) ? null : path,
            ),
          );
        }
        final session = _makeSession(
          recordingPath: tempDir.path,
          clipContextSeconds: 1,
          detections: detections,
        );
        String? previousTable;
        for (final absolute in [false, true]) {
          final zipPath = await buildSessionExport(
            session,
            formats: const {'raven', 'csv', 'json'},
            includeAudio: true,
            useAbsoluteSurveyTime: absolute,
          );
          expect(zipPath, isNotNull);
          final archive = ZipDecoder().decodeBytes(
            File(zipPath!).readAsBytesSync(),
          );
          String document(String extension) => utf8.decode(
            archive.firstWhere((f) => f.name.endsWith(extension)).content
                as List<int>,
          );
          final table = document('.selections.txt');
          if (previousTable != null) expect(table, previousTable);
          previousTable = table;
          final rows =
              table
                  .split('\n')
                  .where((row) => row.isNotEmpty)
                  .map((row) => row.split('\t'))
                  .toList();
          final header = rows.removeAt(0);
          expect(rows.length, retained.length);
          final audioNames =
              archive
                  .where((f) => f.name.endsWith('.wav'))
                  .map((f) => f.name)
                  .toList();
          expect(rows.map((row) => row[7]).toList(), audioNames);
          expect(header[11], 'Survey Time (UTC)');
          for (var i = 0; i < rows.length; i++) {
            final row = rows[i];
            expect(row.length, header.length);
            expect(row[0], '${i + 1}');
            expect(row[3], (i * 5 + 1).toStringAsFixed(3));
            expect(row[4], (i * 5 + 4).toStringAsFixed(3));
            expect(
              row[7],
              '${_prefix}_clip_${(i + 1).toString().padLeft(3, '0')}_Eurasian_Blackbird.wav',
            );
            expect(
              row[11],
              detections[retained[i]].timestamp.toUtc().toIso8601String(),
            );
            final audio = archive.firstWhere((f) => f.name == row[7]);
            final extracted = File(p.join(tempDir.path, 'check.wav'))
              ..writeAsBytesSync(audio.content as List<int>);
            final info = await AudioDecoder.inspectFile(extracted.path);
            expect(info.totalSamples / info.sampleRate, 5);
          }
          if (retained.length == 10) {
            expect(rows.last.sublist(3, 5), ['46.000', '49.000']);
          }
          final csv =
              document(
                '.csv',
              ).split('\n').where((row) => row.isNotEmpty).toList();
          expect(csv.length, 11);
          expect(
            csv.first,
            contains(absolute ? 'Survey Time (UTC)' : 'Survey Time (s)'),
          );
          expect(
            (jsonDecode(document('.json')) as Map)['detections'],
            hasLength(10),
          );
        }
      });
    }

    test('converts FLAC clips to valid WAV files in ZIP exports', () async {
      final clipDir = '${tempDir.path}/clips_wav';
      Directory(clipDir).createSync();
      final clipPath = '$clipDir/clip_1000.flac';
      final sourceSamples = _pcmLikeFloatSamples(32000);
      await FlacEncoder.writeFile(filePath: clipPath, samples: sourceSamples);

      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        recordingPath: clipDir,
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
            audioClipPath: clipPath,
          ),
        ],
      );

      final zipPath = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
        shareAudioAsWav: true,
      );
      expect(zipPath, isNotNull);

      final archive = ZipDecoder().decodeBytes(
        File(zipPath!).readAsBytesSync(),
      );
      final wavEntry = archive.firstWhere((f) => f.name.endsWith('.wav'));
      final wavBytes = Uint8List.fromList(wavEntry.content as List<int>);
      expect(String.fromCharCodes(wavBytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wavBytes.sublist(8, 12)), 'WAVE');

      final wavFile = File(p.join(tempDir.path, 'converted_clip.wav'));
      await wavFile.writeAsBytes(wavBytes);
      final decoded = await AudioDecoder.decodeFile(wavFile.path);
      expect(decoded.sampleRate, 32000);
      expect(decoded.samples, _expectedPcm16(sourceSamples));

      final tableFile = archive.firstWhere(
        (f) => f.name.endsWith('.selections.txt'),
      );
      final tableContent = String.fromCharCodes(tableFile.content as List<int>);
      expect(tableContent, contains('_clip_001_Eurasian_Blackbird.wav'));
      expect(tableContent, isNot(contains('.flac')));
    });

    test('adds detected extensions for clips that have none', () async {
      final clipDir = '${tempDir.path}/clips_no_ext';
      Directory(clipDir).createSync();
      final clipPath = '$clipDir/clip_1000';
      await FlacEncoder.writeFile(
        filePath: clipPath,
        samples: _pcmLikeFloatSamples(32000),
      );

      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        recordingPath: clipDir,
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
            audioClipPath: clipPath,
          ),
        ],
      );

      final zipPath = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
      );
      expect(zipPath, isNotNull);

      final archive = ZipDecoder().decodeBytes(
        File(zipPath!).readAsBytesSync(),
      );
      expect(
        archive.any(
          (f) => f.name.endsWith('_clip_001_Eurasian_Blackbird.flac'),
        ),
        isTrue,
      );
      final tableFile = archive.firstWhere(
        (f) => f.name.endsWith('.selections.txt'),
      );
      final tableContent = String.fromCharCodes(tableFile.content as List<int>);
      expect(tableContent, contains('_clip_001_Eurasian_Blackbird.flac'));
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

    test(
      'honors selected GPX and audio when metadata and HTML are enabled',
      () async {
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
          formats: const {'raven', 'gpx'},
          includeAudio: true,
          includeHtmlReport: true,
          includeAppMetadata: true,
          metadata: const {'app': 'birdnet-live'},
        );
        expect(zipPath, isNotNull);

        final archive = ZipDecoder().decodeBytes(
          File(zipPath!).readAsBytesSync(),
        );
        final names = archive.map((f) => f.name).toList();

        expect(names, contains('$_prefix.wav'));
        expect(names, contains('$_prefix.selections.txt'));
        expect(names, contains('$_prefix.gpx'));
        expect(names, contains('$_prefix.metadata.json'));
        expect(names, contains('${_prefix}_report.html'));
      },
    );

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

    test(
      'includes full recording when recordingPath points at session directory',
      () async {
        final sessionDir = Directory('${tempDir.path}/recording');
        sessionDir.createSync();
        final flacPath = p.join(sessionDir.path, 'full.flac');
        File(flacPath).writeAsBytesSync([0x66, 0x4C, 0x61, 0x43]);

        final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
        final session = _makeSession(
          recordingPath: sessionDir.path,
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
          formats: const {'gpx'},
          includeAudio: true,
          includeHtmlReport: false,
          includeAppMetadata: false,
        );
        expect(zipPath, isNotNull);

        final archive = ZipDecoder().decodeBytes(
          File(zipPath!).readAsBytesSync(),
        );
        final names = archive.map((f) => f.name).toList();

        expect(names, contains('$_prefix.flac'));
        expect(names, contains('$_prefix.gpx'));
      },
    );

    test(
      'converts full FLAC recording to a valid WAV in ZIP exports',
      () async {
        final sessionDir = Directory('${tempDir.path}/recording_wav');
        sessionDir.createSync();
        final flacPath = p.join(sessionDir.path, 'full.flac');
        final sourceSamples = _pcmLikeFloatSamples(32000);
        await FlacEncoder.writeFile(filePath: flacPath, samples: sourceSamples);

        final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
        final session = _makeSession(
          recordingPath: sessionDir.path,
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
          shareAudioAsWav: true,
        );
        expect(zipPath, isNotNull);

        final archive = ZipDecoder().decodeBytes(
          File(zipPath!).readAsBytesSync(),
        );
        final wavEntry = archive.firstWhere((f) => f.name == '$_prefix.wav');
        final wavBytes = Uint8List.fromList(wavEntry.content as List<int>);
        expect(String.fromCharCodes(wavBytes.sublist(0, 4)), 'RIFF');

        final wavFile = File(p.join(tempDir.path, 'converted_full.wav'));
        await wavFile.writeAsBytes(wavBytes);
        final decoded = await AudioDecoder.decodeFile(wavFile.path);
        expect(decoded.sampleRate, 32000);
        expect(decoded.samples, _expectedPcm16(sourceSamples));
      },
    );

    test('audio-only export returns raw audio file (no ZIP) when every '
        'companion is disabled', () async {
      final wavPath = '${tempDir.path}/full.wav';
      File(wavPath).writeAsBytesSync([0x52, 0x49, 0x46, 0x46]);

      final session = _makeSession(
        recordingPath: wavPath,
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            DateTime.utc(2025, 6, 15, 8, 0, 0),
          ),
        ],
      );

      final result = await buildSessionExport(
        session,
        formats: const <String>{},
        includeAudio: true,
        includeHtmlReport: false,
        includeAppMetadata: false,
      );

      expect(result, isNotNull);
      expect(result!.endsWith('.wav'), isTrue);
      expect(p.basename(result), '$_prefix.wav');
      expect(File(result).existsSync(), isTrue);
    });

    test(
      'audio-only export adds a detected extension when source has none',
      () async {
        final flacPath = '${tempDir.path}/full';
        final encodedPath = '${tempDir.path}/full.flac';
        await FlacEncoder.writeFile(
          filePath: encodedPath,
          samples: _pcmLikeFloatSamples(32000),
        );
        await File(encodedPath).copy(flacPath);

        final session = _makeSession(
          recordingPath: flacPath,
          detections: [
            _det(
              'Turdus merula',
              'Eurasian Blackbird',
              0.91,
              const Duration(seconds: 5),
              DateTime.utc(2025, 6, 15, 8, 0, 0),
            ),
          ],
        );

        final result = await buildSessionExport(
          session,
          formats: const <String>{},
          includeAudio: true,
          includeHtmlReport: false,
          includeAppMetadata: false,
        );

        expect(result, isNotNull);
        expect(p.basename(result!), '$_prefix.flac');
        expect(File(result).existsSync(), isTrue);
      },
    );

    test(
      'audio-only WAV conversion fallback keeps original FLAC extension',
      () async {
        final flacPath = '${tempDir.path}/full.flac';
        File(flacPath).writeAsBytesSync([0x66, 0x4C, 0x61, 0x43]);

        final session = _makeSession(
          recordingPath: flacPath,
          detections: [
            _det(
              'Turdus merula',
              'Eurasian Blackbird',
              0.91,
              const Duration(seconds: 5),
              DateTime.utc(2025, 6, 15, 8, 0, 0),
            ),
          ],
        );

        final result = await buildSessionExport(
          session,
          formats: const <String>{},
          includeAudio: true,
          shareAudioAsWav: true,
          includeHtmlReport: false,
          includeAppMetadata: false,
        );

        expect(result, isNotNull);
        expect(result!.endsWith('.flac'), isTrue);
        expect(p.basename(result), '$_prefix.flac');
        expect(File(result).existsSync(), isTrue);
      },
    );

    test(
      'disabling app metadata drops the .metadata.json side-file from the ZIP',
      () async {
        final wavPath = '${tempDir.path}/full.wav';
        File(wavPath).writeAsBytesSync([0x52, 0x49, 0x46, 0x46]);

        final session = _makeSession(
          recordingPath: wavPath,
          detections: [
            _det(
              'Turdus merula',
              'Eurasian Blackbird',
              0.91,
              const Duration(seconds: 5),
              DateTime.utc(2025, 6, 15, 8, 0, 0),
            ),
          ],
        );

        final zipPath = await buildSessionExport(
          session,
          formats: const {'raven'},
          includeAudio: true,
          includeAppMetadata: false,
          metadata: {'app': 'birdnet-live'},
        );

        expect(zipPath, isNotNull);
        final archive = ZipDecoder().decodeBytes(
          File(zipPath!).readAsBytesSync(),
        );
        final names = archive.map((f) => f.name).toList();
        expect(names, contains('$_prefix.wav'));
        expect(names, contains('$_prefix.selections.txt'));
        expect(names.any((n) => n.endsWith('.metadata.json')), isFalse);
      },
    );
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

    test('includes ARU metadata and segments when present', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(type: SessionType.aru);
      session.segments.add(
        SessionSegment(
          startTime: start,
          endTime: start.add(const Duration(minutes: 10)),
        ),
      );
      session.aruMetadata = AruDeploymentMetadata(
        deploymentName: 'Wetland ARU',
        stationId: 'ARU-01',
        scheduleStart: start,
        eachCycleIsSession: false,
        cycleDurationSeconds: 600,
        repeatIntervalSeconds: 3600,
        maxCycles: 2,
        cycles: [
          AruCycleMetadata(
            index: 0,
            plannedStart: start,
            plannedEnd: start.add(const Duration(minutes: 10)),
            status: AruCycleStatus.completed,
          ),
        ],
      );

      final map = jsonDecode(buildJsonExport(session)) as Map<String, dynamic>;

      expect(map['type'], 'aru');
      expect(map['segments'], isA<List<dynamic>>());
      expect((map['aru'] as Map<String, dynamic>)['stationId'], 'ARU-01');
      expect(
        ((map['aru'] as Map<String, dynamic>)['cycles'] as List).single,
        containsPair('status', 'completed'),
      );
    });
  });

  group('ARU segmented recording export', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('aru_export_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('bundles cycle recordings under aru_cycles', () async {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final cyclePath = p.join(tempDir.path, 'cycle_000.flac');
      File(cyclePath).writeAsBytesSync([0x66, 0x4c, 0x61, 0x43]);

      final session = _makeSession(type: SessionType.aru);
      session.aruMetadata = AruDeploymentMetadata(
        deploymentName: 'Wetland ARU',
        scheduleStart: start,
        eachCycleIsSession: false,
        cycleDurationSeconds: 600,
        repeatIntervalSeconds: 3600,
        maxCycles: 1,
        cycles: [
          AruCycleMetadata(
            index: 0,
            plannedStart: start,
            plannedEnd: start.add(const Duration(minutes: 10)),
            status: AruCycleStatus.completed,
            recordingPath: cyclePath,
          ),
        ],
      );

      final zipPath = await buildSessionExport(
        session,
        formats: const {'json'},
        includeAudio: true,
      );

      expect(zipPath, isNotNull);
      final archive = ZipDecoder().decodeBytes(
        File(zipPath!).readAsBytesSync(),
      );
      final names = archive.map((f) => f.name).toList();

      expect(names, contains(startsWith('aru_cycles/')));
      expect(names, contains(endsWith('_cycle_000.flac')));
      expect(names, contains(endsWith('.json')));
      expect(names, contains(endsWith('.metadata.json')));

      final metaFile = archive.firstWhere(
        (f) => f.name.endsWith('.metadata.json'),
      );
      final meta =
          jsonDecode(String.fromCharCodes(metaFile.content as List<int>))
              as Map<String, dynamic>;
      expect(
        (meta['aruCycleAudioFiles'] as Map<String, dynamic>)['0'],
        startsWith('aru_cycles/'),
      );
    });

    test('keeps ARU metadata sidecar for non-JSON exports', () async {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(type: SessionType.aru);
      session.aruMetadata = AruDeploymentMetadata(
        deploymentName: 'Wetland ARU',
        stationId: 'ARU-01',
        scheduleStart: start,
        eachCycleIsSession: false,
        cycleDurationSeconds: 600,
        repeatIntervalSeconds: 3600,
        maxCycles: 1,
      );

      final zipPath = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: false,
      );

      expect(zipPath, isNotNull);
      expect(p.extension(zipPath!), '.zip');

      final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
      final names = archive.map((f) => f.name).toList();

      expect(names, contains(endsWith('.selections.txt')));
      expect(names, contains(endsWith('.metadata.json')));

      final metaFile = archive.firstWhere(
        (f) => f.name.endsWith('.metadata.json'),
      );
      final meta =
          jsonDecode(String.fromCharCodes(metaFile.content as List<int>))
              as Map<String, dynamic>;
      final sessionMeta = meta['session'] as Map<String, dynamic>;
      expect(sessionMeta['type'], 'aru');
      expect(sessionMeta['displayName'], session.displayName);
      final typeMetadata = meta['typeMetadata'] as Map<String, dynamic>;
      final aru = typeMetadata['aru'] as Map<String, dynamic>;
      expect(aru['stationId'], 'ARU-01');
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

  group('review status in exports', () {
    DetectionRecord makeReviewed(
      String sci,
      String common,
      double conf,
      Duration offset,
      DateTime start, {
      ReviewStatus reviewStatus = ReviewStatus.unreviewed,
      DateTime? reviewedAt,
      double? lat,
      double? lon,
    }) {
      return DetectionRecord(
        scientificName: sci,
        commonName: common,
        confidence: conf,
        timestamp: start.add(offset),
        reviewStatus: reviewStatus,
        reviewedAt: reviewedAt,
        latitude: lat,
        longitude: lon,
      );
    }

    test('Raven table emits Review Status columns and per-row values', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final stamp = DateTime.utc(2025, 6, 15, 9, 30);
      final session = _makeSession(
        detections: [
          makeReviewed(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
            reviewStatus: ReviewStatus.confirmed,
            reviewedAt: stamp,
          ),
          makeReviewed(
            'Erithacus rubecula',
            'European Robin',
            0.80,
            const Duration(seconds: 10),
            start,
          ),
          makeReviewed(
            'Parus major',
            'Great Tit',
            0.75,
            const Duration(seconds: 15),
            start,
            reviewStatus: ReviewStatus.rejected,
            reviewedAt: stamp,
          ),
        ],
      );

      final table = buildRavenSelectionTable(session);
      final lines = table.split('\n');
      final header = lines.first.split('\t');
      expect(header, contains('Review Status'));
      expect(header, contains('Reviewed At (UTC)'));
      final cIdx = header.indexOf('Review Status');
      final cAtIdx = header.indexOf('Reviewed At (UTC)');

      final row1 = lines[1].split('\t');
      expect(row1[cIdx], 'confirmed');
      expect(row1[cAtIdx], '2025-06-15T09:30:00.000Z');

      // The point of the whole exercise: a detection nobody reviewed says so,
      // rather than reporting a verdict it never received.
      final row2 = lines[2].split('\t');
      expect(row2[cIdx], 'unreviewed');
      expect(row2[cAtIdx], '');

      final row3 = lines[3].split('\t');
      expect(row3[cIdx], 'rejected');
      expect(row3[cAtIdx], '2025-06-15T09:30:00.000Z');
    });

    test('CSV emits Review Status columns and per-row values', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final stamp = DateTime.utc(2025, 6, 15, 9, 30);
      final session = _makeSession(
        detections: [
          makeReviewed(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
            reviewStatus: ReviewStatus.confirmed,
            reviewedAt: stamp,
          ),
          makeReviewed(
            'Erithacus rubecula',
            'European Robin',
            0.80,
            const Duration(seconds: 10),
            start,
          ),
          makeReviewed(
            'Parus major',
            'Great Tit',
            0.75,
            const Duration(seconds: 15),
            start,
            reviewStatus: ReviewStatus.rejected,
            reviewedAt: stamp,
          ),
        ],
      );

      final csv = buildCsvExport(session);
      final lines = csv.split('\n');
      final header = lines.first.split(',');
      expect(header, contains('Review Status'));
      expect(header, contains('Reviewed At (UTC)'));
      final cIdx = header.indexOf('Review Status');
      final cAtIdx = header.indexOf('Reviewed At (UTC)');

      final row1 = lines[1].split(',');
      expect(row1[cIdx], 'confirmed');
      expect(row1[cAtIdx], '2025-06-15T09:30:00.000Z');

      // The point of the whole exercise: a detection nobody reviewed says so,
      // rather than reporting a verdict it never received.
      final row2 = lines[2].split(',');
      expect(row2[cIdx], 'unreviewed');
      expect(row2[cAtIdx], '');

      final row3 = lines[3].split(',');
      expect(row3[cIdx], 'rejected');
      expect(row3[cAtIdx], '2025-06-15T09:30:00.000Z');
    });

    test('JSON emits reviewStatus (always) and reviewedAt (only when set)', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final stamp = DateTime.utc(2025, 6, 15, 9, 30);
      final session = _makeSession(
        detections: [
          makeReviewed(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 5),
            start,
            reviewStatus: ReviewStatus.confirmed,
            reviewedAt: stamp,
          ),
          makeReviewed(
            'Erithacus rubecula',
            'European Robin',
            0.80,
            const Duration(seconds: 10),
            start,
          ),
          makeReviewed(
            'Parus major',
            'Great Tit',
            0.75,
            const Duration(seconds: 15),
            start,
            reviewStatus: ReviewStatus.rejected,
            reviewedAt: stamp,
          ),
        ],
      );

      final map = jsonDecode(buildJsonExport(session)) as Map<String, dynamic>;
      final dets = map['detections'] as List;
      final d0 = dets[0] as Map<String, dynamic>;
      final d1 = dets[1] as Map<String, dynamic>;
      final d2 = dets[2] as Map<String, dynamic>;
      expect(d0['reviewStatus'], 'confirmed');
      expect(d0['reviewedAt'], '2025-06-15T09:30:00.000Z');
      expect(d1['reviewStatus'], 'unreviewed');
      expect(d1.containsKey('reviewedAt'), isFalse);
      expect(d2['reviewStatus'], 'rejected');
      expect(d2['reviewedAt'], '2025-06-15T09:30:00.000Z');
      // The old boolean is gone; nothing should still be asserting a verdict
      // about the unreviewed detection.
      expect(d1.containsKey('confirmed'), isFalse);
    });

    test(
      'GPX adds <sym>confirmed</sym> + <cmt> only for confirmed waypoints',
      () {
        final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
        final stamp = DateTime.utc(2025, 6, 15, 9, 30);
        final session = _makeSession(
          type: SessionType.survey,
          detections: [
            makeReviewed(
              'Turdus merula',
              'Eurasian Blackbird',
              0.91,
              const Duration(seconds: 5),
              start,
              reviewStatus: ReviewStatus.confirmed,
              reviewedAt: stamp,
              lat: 52.52,
              lon: 13.40,
            ),
            makeReviewed(
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

    test('GPX tags rejected waypoints distinctly from confirmed ones', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final stamp = DateTime.utc(2025, 6, 15, 9, 30);
      final session = _makeSession(
        type: SessionType.survey,
        detections: [
          makeReviewed(
            'Parus major',
            'Great Tit',
            0.75,
            const Duration(seconds: 15),
            start,
            reviewStatus: ReviewStatus.rejected,
            reviewedAt: stamp,
            lat: 52.54,
            lon: 13.42,
          ),
          makeReviewed(
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
      expect(gpx, contains('<sym>rejected</sym>'));
      expect(gpx, contains('<cmt>Rejected at 2025-06-15T09:30:00.000Z</cmt>'));
      expect(gpx, isNot(contains('<sym>confirmed</sym>')));
      // The unreviewed waypoint stays untagged.
      expect('<sym>'.allMatches(gpx).length, 1);
    });
  });

  group('heard/seen evidence in exports', () {
    DetectionRecord makeEvidence(
      String sci,
      String common,
      Duration offset,
      DateTime start, {
      DetectionEvidence? evidence,
    }) {
      return DetectionRecord(
        scientificName: sci,
        commonName: common,
        confidence: 1.0,
        timestamp: start.add(offset),
        source: DetectionSource.manual,
        evidence: evidence,
      );
    }

    LiveSession mixedSession() {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      return _makeSession(
        detections: [
          makeEvidence(
            'Turdus merula',
            'Eurasian Blackbird',
            const Duration(seconds: 5),
            start,
            evidence: DetectionEvidence.heardAndSeen,
          ),
          makeEvidence(
            'Erithacus rubecula',
            'European Robin',
            const Duration(seconds: 10),
            start,
            evidence: DetectionEvidence.seen,
          ),
          // No evidence recorded — the column must stay empty rather than
          // implying the bird was neither heard nor seen.
          _det(
            'Parus major',
            'Great Tit',
            0.8,
            const Duration(seconds: 15),
            start,
          ),
        ],
      );
    }

    test('CSV emits an Evidence column with per-row values', () {
      final csv = buildCsvExport(mixedSession());
      final lines = csv.trim().split('\n');
      final header = lines.first.split(',');
      expect(header, contains('Evidence'));
      final idx = header.indexOf('Evidence');

      expect(lines[1].split(',')[idx], 'heard+seen');
      expect(lines[2].split(',')[idx], 'seen');
      expect(lines[3].split(',')[idx], '');
    });

    test('Raven table emits an Evidence column with per-row values', () {
      final table = buildRavenSelectionTable(mixedSession());
      // Split without trimming: the last row ends in empty tab-separated
      // cells, and trimming would eat them along with the trailing newline.
      final lines = table.split('\n');
      final header = lines.first.split('\t');
      expect(header, contains('Evidence'));
      final idx = header.indexOf('Evidence');

      expect(lines[1].split('\t')[idx], 'heard+seen');
      expect(lines[2].split('\t')[idx], 'seen');
      expect(lines[3].split('\t')[idx], '');
    });

    test('the Evidence column is omitted when no detection carries it', () {
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

      expect(
        buildCsvExport(session).split('\n').first,
        isNot(contains('Evidence')),
      );
      expect(
        buildRavenSelectionTable(session).split('\n').first,
        isNot(contains('Evidence')),
      );
    });

    test('JSON export round-trips evidence and omits it when unset', () {
      final map =
          jsonDecode(buildJsonExport(mixedSession())) as Map<String, dynamic>;
      final dets = (map['detections'] as List).cast<Map<String, dynamic>>();

      expect(dets[0]['evidence'], 'heardAndSeen');
      expect(dets[1]['evidence'], 'seen');
      expect(dets[2].containsKey('evidence'), isFalse);
    });
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

  // ── Trimmed sessions (issue #177) ───────────────────────────────────────

  group('buildSessionExport with a trimmed recording', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('session_export_trim_');
    });
    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    /// A 60 s mono 32 kHz WAV whose sample values encode their own index,
    /// so a slice can be located in the original.
    Future<String> writeWav(Directory dir) async {
      const rate = 32000;
      final samples = Int16List(rate * 60);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = (i % 30000) - 15000;
      }
      final path = '${dir.path}/full.wav';
      await WavWriter.writePcm16File(
        filePath: path,
        samples: samples,
        sampleRate: rate,
      );
      return path;
    }

    LiveSession trimmedSession(String wavPath) {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        recordingPath: wavPath,
        detections: [
          // Dropped by the user's trim in review, kept here to prove the
          // export never emits a negative offset if one survives.
          _det(
            'Erithacus rubecula',
            'European Robin',
            0.8,
            const Duration(seconds: 4),
            start,
          ),
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 30),
            start,
          ),
        ],
      );
      session.trimStartSec = 10.0;
      session.trimEndSec = 40.0;
      return session;
    }

    test('ZIP audio is the trimmed extent, not the full recording', () async {
      final wavPath = await writeWav(tempDir);
      final session = trimmedSession(wavPath);

      final zipPath = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
      );
      expect(zipPath, isNotNull);

      final archive = ZipDecoder().decodeBytes(
        File(zipPath!).readAsBytesSync(),
      );
      final audio = archive.firstWhere((f) => f.name == '$_prefix.wav');
      final audioPath = '${tempDir.path}/from_zip.wav';
      File(audioPath).writeAsBytesSync(audio.content as List<int>);

      final decoded = await AudioDecoder.decodeFile(audioPath);
      expect(decoded.sampleRate, 32000);
      expect(decoded.totalSamples, 32000 * 30);
      // First sample of the export is the first sample of second 10.
      expect(decoded.samples.first, ((32000 * 10) % 30000) - 15000);

      // The untrimmed recording is left alone on disk.
      final original = await AudioDecoder.inspectFile(wavPath);
      expect(original.totalSamples, 32000 * 60);
    });

    test('Raven and CSV offsets index the trimmed audio', () async {
      final wavPath = await writeWav(tempDir);
      final session = trimmedSession(wavPath);

      final raven = buildRavenSelectionTable(
        session,
        audioFileName: '$_prefix.wav',
      );
      final ravenRow = raven
          .split('\n')
          .firstWhere((l) => l.contains('Turdus merula'))
          .split('\t');
      // Detection at 30 s of the recording is 20 s into a trim at 10 s.
      expect(double.parse(ravenRow[3]), closeTo(20.0, 0.001));

      final csv = buildCsvExport(session, audioFileName: '$_prefix.wav');
      final csvRow = csv
          .split('\n')
          .firstWhere((l) => l.contains('Turdus merula'))
          .split(',');
      expect(double.parse(csvRow[1]), closeTo(20.0, 0.001));

      // A detection before the trim start clamps to zero instead of
      // pointing before the start of the file.
      final earlyRow = raven
          .split('\n')
          .firstWhere((l) => l.contains('Erithacus rubecula'))
          .split('\t');
      expect(double.parse(earlyRow[3]), 0.0);
    });

    test('JSON offsets and trimmed duration follow the trim', () async {
      final wavPath = await writeWav(tempDir);
      final session = trimmedSession(wavPath);
      session.annotations.addAll([
        SessionAnnotation(
          text: 'Before trim',
          createdAt: DateTime.utc(2025),
          offsetInRecording: 5,
        ),
        SessionAnnotation(
          text: 'Inside trim',
          createdAt: DateTime.utc(2025),
          offsetInRecording: 15,
        ),
      ]);

      final map = jsonDecode(buildJsonExport(session)) as Map<String, dynamic>;
      expect(map['trimStartSec'], 10.0);
      expect(map['trimEndSec'], 40.0);
      expect(map['trimmedDurationSec'], closeTo(30.0, 0.001));

      final detections = map['detections'] as List<dynamic>;
      final blackbird =
          detections.firstWhere(
                (d) => (d as Map)['scientificName'] == 'Turdus merula',
              )
              as Map<String, dynamic>;
      expect(blackbird['beginTimeSec'], closeTo(20.0, 0.001));

      final annotations = map['annotations'] as List<dynamic>;
      expect((annotations[0] as Map).containsKey('offsetInRecording'), isFalse);
      expect((annotations[1] as Map)['offsetInRecording'], 5.0);
    });

    test('does not export full audio with trim-rebased offsets', () async {
      final path = '${tempDir.path}/unsupported.mp3';
      File(path).writeAsBytesSync(List<int>.filled(4096, 7));
      final session = trimmedSession(path);

      final exportPath = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
      );

      expect(exportPath, isNull);
    });

    test('an untrimmed session still ships the recording verbatim', () async {
      final wavPath = await writeWav(tempDir);
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _makeSession(
        recordingPath: wavPath,
        detections: [
          _det(
            'Turdus merula',
            'Eurasian Blackbird',
            0.91,
            const Duration(seconds: 30),
            start,
          ),
        ],
      );

      final zipPath = await buildSessionExport(
        session,
        formats: const {'raven'},
        includeAudio: true,
      );
      final archive = ZipDecoder().decodeBytes(
        File(zipPath!).readAsBytesSync(),
      );
      final audio = archive.firstWhere((f) => f.name == '$_prefix.wav');
      expect((audio.content as List<int>).length, File(wavPath).lengthSync());
    });

    test('sweeps stale staged trims but spares recent ones', () async {
      final staging = Directory(
        p.join(Directory.systemTemp.path, 'birdnet_export_trim'),
      )..createSync(recursive: true);
      // The audio-only share path returns its staged file to the share sheet
      // and can't delete it; the next export is what reclaims the space.
      final stale =
          File(p.join(staging.path, 'sweep_test_stale.wav'))
            ..writeAsBytesSync(List<int>.filled(2048, 1))
            ..setLastModifiedSync(
              DateTime.now().subtract(const Duration(hours: 6)),
            );
      final recent = File(p.join(staging.path, 'sweep_test_recent.wav'))
        ..writeAsBytesSync(List<int>.filled(2048, 1));
      addTearDown(() {
        for (final f in [stale, recent]) {
          if (f.existsSync()) f.deleteSync();
        }
      });

      final wavPath = await writeWav(tempDir);
      final zipPath = await buildSessionExport(
        trimmedSession(wavPath),
        formats: const {'raven'},
        includeAudio: true,
      );
      expect(zipPath, isNotNull);

      expect(stale.existsSync(), isFalse);
      // Still inside the grace period — a share sheet could be reading it.
      expect(recent.existsSync(), isTrue);
    });

    test('audio-only share returns the trimmed file', () async {
      final wavPath = await writeWav(tempDir);
      final session = trimmedSession(wavPath);

      final path = await buildSessionExport(
        session,
        formats: const {},
        includeAudio: true,
        includeAppMetadata: false,
      );
      expect(path, isNotNull);
      expect(path!.endsWith('.wav'), isTrue);
      final decoded = await AudioDecoder.decodeFile(path);
      expect(decoded.totalSamples, 32000 * 30);
      addTearDown(() {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      });
    });
  });
}

Float32List _pcmLikeFloatSamples(int count) {
  final samples = Float32List(count);
  for (var i = 0; i < count; i++) {
    final pcm = ((i * 997) % 60001) - 30000;
    samples[i] = pcm / 32767.0;
  }
  return samples;
}

Int16List _expectedPcm16(Float32List samples) {
  final pcm = Int16List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    pcm[i] = (samples[i] * 32767.0).round().clamp(-32768, 32767);
  }
  return pcm;
}
