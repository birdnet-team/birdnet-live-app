import 'package:birdnet_live/features/history/services/share_export_config.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const settings = SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 25,
    inferenceRate: 1,
    speciesFilterMode: 'off',
  );

  DetectionRecord detection({String? clipPath}) => DetectionRecord(
    scientificName: 'Troglodytes troglodytes',
    commonName: 'Eurasian Wren',
    confidence: 0.9,
    timestamp: DateTime(2026, 10, 24, 8),
    audioClipPath: clipPath,
  );

  group('ShareExportConfig.withChoices', () {
    const saved = ShareExportConfig(
      formats: {'raven', 'csv'},
      includeAudio: true,
      shareAudioAsWav: true,
      includeHtmlReport: true,
      includeAppMetadata: true,
    );

    test('keeps the saved preferences when both boxes stay ticked', () {
      final result = saved.withChoices(audio: true, metadata: true);
      expect(result.formats, {'raven', 'csv'});
      expect(result.includeAudio, isTrue);
      expect(result.shareAudioAsWav, isTrue);
      expect(result.includeHtmlReport, isTrue);
      expect(result.includeAppMetadata, isTrue);
    });

    test('audio off drops audio but keeps every metadata artifact', () {
      final result = saved.withChoices(audio: false, metadata: true);
      expect(result.includeAudio, isFalse);
      expect(result.formats, {'raven', 'csv'});
      expect(result.includeHtmlReport, isTrue);
      expect(result.includeAppMetadata, isTrue);
    });

    test('metadata off clears formats, report, and side-file', () {
      final result = saved.withChoices(audio: true, metadata: false);
      expect(result.includeAudio, isTrue);
      expect(result.shareAudioAsWav, isTrue);
      expect(result.formats, isEmpty);
      expect(result.includeHtmlReport, isFalse);
      expect(result.includeAppMetadata, isFalse);
      expect(result.includesMetadata, isFalse);
    });

    test('metadata on with nothing enabled falls back to Raven', () {
      const bare = ShareExportConfig(formats: {}, includeAudio: true);
      expect(bare.includesMetadata, isFalse);
      final result = bare.withChoices(audio: true, metadata: true);
      expect(result.formats, ShareExportConfig.fallbackFormats);
      expect(result.includeHtmlReport, isFalse);
      expect(result.includeAppMetadata, isFalse);
    });

    test('an HTML-only preference does not trigger the Raven fallback', () {
      const htmlOnly = ShareExportConfig(
        formats: {},
        includeAudio: false,
        includeHtmlReport: true,
      );
      final result = htmlOnly.withChoices(audio: false, metadata: true);
      expect(result.formats, isEmpty);
      expect(result.includeHtmlReport, isTrue);
    });

    test('both off is an empty share', () {
      expect(saved.withChoices(audio: false, metadata: false).isEmpty, isTrue);
    });
  });

  group('ShareExportConfig.metadataTokens', () {
    test('lists formats in Settings order, then report and side-file', () {
      const config = ShareExportConfig(
        formats: {'gpx', 'csv'},
        includeAudio: true,
        includeHtmlReport: true,
        includeAppMetadata: true,
      );
      expect(config.metadataTokens, ['csv', 'gpx', 'html', 'app']);
    });

    test('describes the Raven fallback when nothing is enabled', () {
      const config = ShareExportConfig(formats: {}, includeAudio: true);
      expect(config.metadataTokens, ['raven']);
    });
  });

  group('audio availability guesses', () {
    LiveSession session({String? recordingPath, List<DetectionRecord>? dets}) =>
        LiveSession(
          id: 's',
          startTime: DateTime(2026, 10, 24, 8),
          settings: settings,
          recordingPath: recordingPath,
          detections: dets,
        );

    test('a session with a recording path may have audio', () {
      expect(
        sessionMayHaveAudio(session(recordingPath: '/x/full.flac')),
        isTrue,
      );
    });

    test('a session with only a detection clip may have audio', () {
      expect(
        sessionMayHaveAudio(
          session(dets: [detection(clipPath: '/x/clip.wav')]),
        ),
        isTrue,
      );
    });

    test('a session with neither has no audio', () {
      expect(sessionMayHaveAudio(session(dets: [detection()])), isFalse);
    });

    test(
      'a detection falls back to its own clip when the session has none',
      () {
        expect(
          detectionMayHaveAudio(detection(clipPath: '/x/c.wav'), null),
          isTrue,
        );
        expect(detectionMayHaveAudio(detection(), session()), isFalse);
        expect(
          detectionMayHaveAudio(
            detection(),
            session(recordingPath: '/x/f.wav'),
          ),
          isTrue,
        );
      },
    );
  });
}
