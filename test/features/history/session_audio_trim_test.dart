// =============================================================================
// Session Audio Trim Tests
// =============================================================================
// Covers the two halves of `session_audio_trim.dart`: the trim-aware view of
// a session's timeline, and the streaming WAV/FLAC slicer that turns a stored
// trim range into a real audio file.
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:birdnet_live/features/history/services/session_audio_trim.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/recording/audio_decoder.dart';
import 'package:birdnet_live/features/recording/flac_encoder.dart';
import 'package:birdnet_live/features/recording/wav_writer.dart';
import 'package:flutter_test/flutter_test.dart';

const int _rate = 32000;

/// A deterministic ramp so slices can be checked sample-for-sample.
Int16List _ramp(int count, {int from = 0}) {
  final out = Int16List(count);
  for (var i = 0; i < count; i++) {
    out[i] = ((from + i) % 30000) - 15000;
  }
  return out;
}

LiveSession _session({
  required Duration length,
  double? trimStartSec,
  double? trimEndSec,
  List<SessionSegment> segments = const [],
  List<DetectionRecord> detections = const [],
}) {
  final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
  return LiveSession(
    id: 'trim-test',
    startTime: start,
    endTime: start.add(length),
    detections: List.of(detections),
    segments: List.of(segments),
    trimStartSec: trimStartSec,
    trimEndSec: trimEndSec,
    settings: SessionSettings(
      windowDuration: 3,
      confidenceThreshold: 25,
      inferenceRate: 1.0,
      speciesFilterMode: 'off',
    ),
  );
}

void main() {
  group('SessionTrimTimeline', () {
    test('untrimmed session reports the full recorded timeline', () {
      final session = _session(length: const Duration(minutes: 5));
      expect(session.hasAudioTrim, isFalse);
      expect(session.trimStartSeconds, 0.0);
      expect(session.trimEndSeconds, isNull);
      expect(session.trimmedTimelineSeconds, closeTo(300.0, 0.001));
    });

    test('trimmed session reports the trimmed extent', () {
      final session = _session(
        length: const Duration(minutes: 5),
        trimStartSec: 60.0,
        trimEndSec: 200.0,
      );
      expect(session.hasAudioTrim, isTrue);
      expect(session.trimStartSeconds, 60.0);
      expect(session.trimEndSeconds, 200.0);
      expect(session.trimmedTimelineSeconds, closeTo(140.0, 0.001));
    });

    test('supports a legacy end-only trim', () {
      final session = _session(
        length: const Duration(minutes: 5),
        trimEndSec: 120.0,
      );
      expect(session.hasAudioTrim, isTrue);
      expect(session.trimStartSeconds, 0.0);
      expect(session.trimmedTimelineSeconds, closeTo(120.0, 0.001));
    });

    test('a degenerate range is not treated as a trim', () {
      final session = _session(
        length: const Duration(minutes: 5),
        trimStartSec: 60.0,
        trimEndSec: 60.05,
      );
      expect(session.hasAudioTrim, isFalse);
      expect(session.trimStartSeconds, 0.0);
      expect(session.trimmedTimelineSeconds, closeTo(300.0, 0.001));
    });

    test('trimmedRelative rebases detections onto the trimmed audio', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      final session = _session(
        length: const Duration(minutes: 5),
        trimStartSec: 60.0,
        trimEndSec: 200.0,
      );
      expect(
        session.trimmedRelative(start.add(const Duration(seconds: 90))),
        closeTo(30.0, 0.001),
      );
      // Anything before the trim start clamps to zero rather than going
      // negative — a Raven row must never index before the file.
      expect(
        session.trimmedRelative(start.add(const Duration(seconds: 10))),
        0.0,
      );
    });

    test('trimmedRelative collapses resume gaps before applying the trim', () {
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      // 60 s recorded, 120 s stopped, then 60 s more: the second segment's
      // audio starts at 60 s in the file, not at 180 s of wall clock.
      final session = _session(
        length: const Duration(minutes: 4),
        trimStartSec: 30.0,
        segments: [
          SessionSegment(
            startTime: start,
            endTime: start.add(const Duration(seconds: 60)),
          ),
          SessionSegment(
            startTime: start.add(const Duration(seconds: 180)),
            endTime: start.add(const Duration(seconds: 240)),
          ),
        ],
      );
      // Wall clock 200 s → 80 s of recorded audio → 50 s after the trim.
      expect(
        session.trimmedRelative(start.add(const Duration(seconds: 200))),
        closeTo(50.0, 0.001),
      );
      expect(session.trimmedTimelineSeconds, closeTo(90.0, 0.001));
    });
  });

  group('detectionsOverlappingTrim', () {
    test('uses half-open boundaries and preserves capture timestamps', () {
      final start = DateTime.utc(2025, 6, 15, 8);
      DetectionRecord detection(int from, int to) => DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Common Blackbird',
        confidence: 0.8,
        timestamp: start.add(Duration(seconds: from)),
        endTimestamp: start.add(Duration(seconds: to)),
      );

      final endingAtStart = detection(5, 10);
      final crossingStart = detection(8, 12);
      final crossingEnd = detection(18, 22);
      final startingAtEnd = detection(20, 23);
      final session = _session(
        length: const Duration(seconds: 30),
        detections: [endingAtStart, crossingStart, crossingEnd, startingAtEnd],
      );

      final retained = detectionsOverlappingTrim(
        session: session,
        detections: session.detections,
        startSec: 10,
        endSec: 20,
      );

      expect(retained, [same(crossingStart), same(crossingEnd)]);
      expect(retained.first.timestamp, start.add(const Duration(seconds: 8)));
      expect(
        retained.last.endTimestamp,
        start.add(const Duration(seconds: 22)),
      );
    });

    test('keeps detections in a short recorder tail', () {
      final start = DateTime.utc(2025, 6, 15, 8);
      final tailDetection = DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Common Blackbird',
        confidence: 0.8,
        timestamp: start.add(const Duration(milliseconds: 30500)),
        endTimestamp: start.add(const Duration(milliseconds: 31500)),
      );
      final session = _session(
        length: const Duration(seconds: 30),
        detections: [tailDetection],
        segments: [
          SessionSegment(
            startTime: start,
            endTime: start.add(const Duration(seconds: 30)),
          ),
        ],
      );

      final retained = detectionsOverlappingTrim(
        session: session,
        detections: session.detections,
        startSec: 30,
        endSec: 32,
      );

      expect(retained, [same(tailDetection)]);
    });
  });

  group('commitSessionTrim', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trim_commit_test_');
    });
    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Future<String> writeWav(String name, int seconds) async {
      final path = '${tempDir.path}/$name';
      await WavWriter.writePcm16File(
        filePath: path,
        samples: _ramp(_rate * seconds),
        sampleRate: _rate,
      );
      return path;
    }

    Future<String> writeFlac(String name, int seconds) async {
      final path = '${tempDir.path}/$name';
      final samples = _ramp(_rate * seconds);
      final floats = Float32List(samples.length);
      for (var i = 0; i < samples.length; i++) {
        floats[i] = samples[i] / 32768.0;
      }
      await FlacEncoder.writeFile(
        filePath: path,
        samples: floats,
        sampleRate: _rate,
      );
      return path;
    }

    test('cuts a WAV recording in place and rebases the session', () async {
      final path = await writeWav('full.wav', 60);
      final originalBytes = File(path).lengthSync();
      final session = _session(
        length: const Duration(seconds: 60),
        trimStartSec: 10.0,
        trimEndSec: 40.0,
      )..recordingPath = path;

      expect(await commitSessionTrim(session), SessionTrimCommit.applied);

      // The recording on disk is now the trim, and the space is reclaimed.
      final decoded = await AudioDecoder.decodeFile(path);
      expect(decoded.totalSamples, _rate * 30);
      expect(decoded.samples.first, ((_rate * 10) % 30000) - 15000);
      expect(File(path).lengthSync(), lessThan(originalBytes));

      // No pending trim is left, and offsets now index the shorter file.
      expect(session.hasAudioTrim, isFalse);
      expect(session.trimStartSec, isNull);
      expect(session.trimEndSec, isNull);
      expect(session.trimmedTimelineSeconds, closeTo(30.0, 0.01));
      expect(session.duration.inSeconds, 30);
      expect(
        session.absoluteToRelative(
          session.startTime.add(const Duration(seconds: 30)),
        ),
        closeTo(20.0, 0.01),
      );

      // Staging artifacts are cleaned up.
      expect(File('$path.trimming.wav').existsSync(), isFalse);
      expect(File('$path.previous.wav').existsSync(), isFalse);
    });

    test('rebases retained annotations and preserves removed notes', () async {
      final path = await writeWav('annotations.wav', 30);
      final session = _session(
        length: const Duration(seconds: 30),
        trimStartSec: 10.0,
        trimEndSec: 20.0,
      )..recordingPath = path;
      session.annotations.addAll([
        SessionAnnotation(
          text: 'Before',
          createdAt: DateTime.utc(2025),
          offsetInRecording: 5,
        ),
        SessionAnnotation(
          text: 'Inside',
          createdAt: DateTime.utc(2025),
          offsetInRecording: 14,
        ),
        SessionAnnotation(text: 'Global', createdAt: DateTime.utc(2025)),
      ]);

      expect(await commitSessionTrim(session), SessionTrimCommit.applied);
      expect(session.annotations[0].offsetInRecording, isNull);
      expect(session.annotations[0].text, 'Before');
      expect(session.annotations[1].offsetInRecording, 4);
      expect(session.annotations[2].offsetInRecording, isNull);
    });

    test('cuts a FLAC recording in place', () async {
      final path = await writeFlac('full.flac', 20);
      final session = _session(
        length: const Duration(seconds: 20),
        trimStartSec: 5.0,
        trimEndSec: 15.0,
      )..recordingPath = path;

      expect(await commitSessionTrim(session), SessionTrimCommit.applied);

      expect(await AudioDecoder.isWav(path), isFalse);
      final decoded = await AudioDecoder.decodeFile(path);
      expect(decoded.totalSamples, _rate * 10);
      expect(session.hasAudioTrim, isFalse);
      expect(File('$path.previous.flac').existsSync(), isFalse);
    });

    test('resolves a session directory to its full recording', () async {
      final dir = Directory('${tempDir.path}/session')..createSync();
      await WavWriter.writePcm16File(
        filePath: '${dir.path}/full.wav',
        samples: _ramp(_rate * 12),
        sampleRate: _rate,
      );
      final session = _session(
        length: const Duration(seconds: 12),
        trimStartSec: 2.0,
        trimEndSec: 8.0,
      )..recordingPath = dir.path;

      expect(await commitSessionTrim(session), SessionTrimCommit.applied);
      final decoded = await AudioDecoder.decodeFile('${dir.path}/full.wav');
      expect(decoded.totalSamples, _rate * 6);
    });

    test('recovers an original left behind by an interrupted swap', () async {
      final path = await writeWav('interrupted.wav', 10);
      final backupPath = '$path.previous.wav';
      File(path).renameSync(backupPath);
      // The staged cut the interrupted commit had already written.
      final stagedPath = '$path.trimming.wav';
      File(stagedPath).writeAsBytesSync(List<int>.filled(64, 0));

      final resolved = await resolveSessionRecordingFile(path);

      expect(resolved, path);
      expect(File(path).existsSync(), isTrue);
      expect(File(backupPath).existsSync(), isFalse);
      // Nothing else would ever clean the staged file up.
      expect(File(stagedPath).existsSync(), isFalse);
      final decoded = await AudioDecoder.decodeFile(path);
      expect(decoded.totalSamples, _rate * 10);
    });

    test('recovers a backup whose suffix disagrees with the name', () async {
      // The commit names its artifacts from the container it sniffed, which
      // need not match a mislabeled recording's filename.
      final wavPath = await writeWav('mislabeled.wav', 6);
      final path = '${tempDir.path}/mislabeled.flac';
      File(wavPath).renameSync('$path.previous.wav');

      final resolved = await resolveSessionRecordingFile(path);

      expect(resolved, path);
      expect(File('$path.previous.wav').existsSync(), isFalse);
      final decoded = await AudioDecoder.decodeFile(path);
      expect(decoded.totalSamples, _rate * 6);
    });

    test('drops detections whose audio the cut removed', () async {
      final path = await writeWav('detections.wav', 30);
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      DetectionRecord detection(int atSec) => DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Common Blackbird',
        confidence: 0.8,
        timestamp: start.add(Duration(seconds: atSec)),
      );
      final removed = detection(2);
      final kept = detection(12);
      final session = _session(
        length: const Duration(seconds: 30),
        trimStartSec: 10.0,
        trimEndSec: 20.0,
        detections: [removed, kept],
      )..recordingPath = path;

      expect(await commitSessionTrim(session), SessionTrimCommit.applied);

      // The retained record keeps its real capture time and now indexes the
      // shorter file; the one with no audio left is gone rather than piling
      // up at offset zero.
      expect(session.detections, [same(kept)]);
      expect(session.detections.single.timestamp, kept.timestamp);
      expect(session.absoluteToRelative(kept.timestamp), closeTo(2.0, 0.01));
    });

    test('refuses to cut a stereo FLAC', () async {
      // The pure-Dart FLAC decoder is mono-only and ignores the frame
      // header's channel assignment, so a stereo stream would decode to
      // plausible nonsense — which the commit would write over the original.
      final path = '${tempDir.path}/stereo.flac';
      final encoder = FlacEncoder(
        filePath: path,
        sampleRate: _rate,
        channels: 2,
      );
      await encoder.open();
      await encoder.writeSamplesPcm16(_ramp(_rate * 4));
      await encoder.close();
      final originalBytes = File(path).readAsBytesSync();

      final session = _session(
        length: const Duration(seconds: 4),
        trimStartSec: 1.0,
        trimEndSec: 3.0,
      )..recordingPath = path;

      expect(await commitSessionTrim(session), SessionTrimCommit.unsupported);
      // The recording is byte-for-byte untouched and the trim survives as an
      // editable range.
      expect(File(path).readAsBytesSync(), originalBytes);
      expect(session.hasAudioTrim, isTrue);
      expect(session.trimStartSec, 1.0);
      expect(File('$path.trimming.flac').existsSync(), isFalse);
      expect(File('$path.previous.flac').existsSync(), isFalse);
    });

    test('collapses resume gaps onto the retained segments', () async {
      final path = await writeWav('resumed.wav', 120);
      final start = DateTime.utc(2025, 6, 15, 8, 0, 0);
      // 60 s recorded, 120 s stopped, 60 s more → 120 s of audio.
      final session = _session(
        length: const Duration(seconds: 240),
        trimStartSec: 30.0,
        trimEndSec: 90.0,
        segments: [
          SessionSegment(
            startTime: start,
            endTime: start.add(const Duration(seconds: 60)),
          ),
          SessionSegment(
            startTime: start.add(const Duration(seconds: 180)),
            endTime: start.add(const Duration(seconds: 240)),
          ),
        ],
      )..recordingPath = path;

      expect(await commitSessionTrim(session), SessionTrimCommit.applied);

      // Both segments survive, each clipped to the retained stretch.
      expect(session.segments.length, 2);
      expect(
        session.segments.first.startTime,
        start.add(const Duration(seconds: 30)),
      );
      expect(
        session.segments.first.endTime,
        start.add(const Duration(seconds: 60)),
      );
      expect(
        session.segments.last.startTime,
        start.add(const Duration(seconds: 180)),
      );
      expect(
        session.segments.last.endTime,
        start.add(const Duration(seconds: 210)),
      );

      // A detection at wall clock 200 s sat at 80 s of audio, now at 50 s.
      expect(
        session.absoluteToRelative(start.add(const Duration(seconds: 200))),
        closeTo(50.0, 0.01),
      );
      expect(session.trimmedTimelineSeconds, closeTo(60.0, 0.01));
    });

    test('does nothing when the session has no trim', () async {
      final path = await writeWav('full.wav', 10);
      final session = _session(length: const Duration(seconds: 10))
        ..recordingPath = path;

      expect(await commitSessionTrim(session), SessionTrimCommit.notNeeded);
      final decoded = await AudioDecoder.decodeFile(path);
      expect(decoded.totalSamples, _rate * 10);
    });

    test('leaves the trim in place for an uncuttable recording', () async {
      final path = '${tempDir.path}/recording.mp3';
      File(path).writeAsBytesSync(List<int>.filled(4096, 3));
      final session = _session(
        length: const Duration(seconds: 30),
        trimStartSec: 5.0,
        trimEndSec: 20.0,
      )..recordingPath = path;

      expect(await commitSessionTrim(session), SessionTrimCommit.unsupported);
      // The trim survives so playback and exports keep honouring it.
      expect(session.hasAudioTrim, isTrue);
      expect(session.trimStartSec, 5.0);
      expect(File(path).lengthSync(), 4096);
    });

    test('leaves the trim in place when there is no recording', () async {
      final session = _session(
        length: const Duration(seconds: 30),
        trimStartSec: 5.0,
        trimEndSec: 20.0,
      )..recordingPath = null;

      expect(await commitSessionTrim(session), SessionTrimCommit.unsupported);
      expect(session.hasAudioTrim, isTrue);
    });

    test('a second commit is a no-op', () async {
      final path = await writeWav('full.wav', 30);
      final session = _session(
        length: const Duration(seconds: 30),
        trimStartSec: 5.0,
        trimEndSec: 20.0,
      )..recordingPath = path;

      expect(await commitSessionTrim(session), SessionTrimCommit.applied);
      expect(await commitSessionTrim(session), SessionTrimCommit.notNeeded);
      final decoded = await AudioDecoder.decodeFile(path);
      expect(decoded.totalSamples, _rate * 15);
    });
  });

  group('writeTrimmedAudioFile — WAV', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trim_wav_test_');
    });
    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Future<String> writeSourceWav(int sampleCount) async {
      final path = '${tempDir.path}/full.wav';
      await WavWriter.writePcm16File(
        filePath: path,
        samples: _ramp(sampleCount),
        sampleRate: _rate,
      );
      return path;
    }

    test('slices the requested range sample-for-sample', () async {
      final source = await writeSourceWav(_rate * 10);
      final result = await writeTrimmedAudioFile(
        sourcePath: source,
        destPath: '${tempDir.path}/out.wav',
        startSec: 2.0,
        endSec: 5.0,
      );

      expect(result, isNotNull);
      expect(result!.extension, '.wav');
      expect(result.durationSeconds, closeTo(3.0, 0.001));

      final decoded = await AudioDecoder.decodeFile(result.file.path);
      expect(decoded.sampleRate, _rate);
      expect(decoded.totalSamples, _rate * 3);

      final expected = _ramp(_rate * 3, from: _rate * 2);
      for (var i = 0; i < decoded.totalSamples; i += 997) {
        expect(decoded.samples[i], expected[i], reason: 'sample $i');
      }
    });

    test('a null end runs to the end of the recording', () async {
      final source = await writeSourceWav(_rate * 8);
      final result = await writeTrimmedAudioFile(
        sourcePath: source,
        destPath: '${tempDir.path}/out.wav',
        startSec: 6.5,
      );

      expect(result, isNotNull);
      expect(result!.durationSeconds, closeTo(1.5, 0.001));
      final decoded = await AudioDecoder.decodeFile(result.file.path);
      expect(decoded.samples.first, _ramp(1, from: (6.5 * _rate).floor())[0]);
    });

    test('a range past the end of the recording is clamped', () async {
      final source = await writeSourceWav(_rate * 4);
      final result = await writeTrimmedAudioFile(
        sourcePath: source,
        destPath: '${tempDir.path}/out.wav',
        startSec: 3.0,
        endSec: 60.0,
      );
      expect(result, isNotNull);
      expect(result!.durationSeconds, closeTo(1.0, 0.001));
    });

    test('a range entirely past the recording yields null', () async {
      final source = await writeSourceWav(_rate * 4);
      final result = await writeTrimmedAudioFile(
        sourcePath: source,
        destPath: '${tempDir.path}/out.wav',
        startSec: 30.0,
        endSec: 40.0,
      );
      expect(result, isNull);
    });

    test('an unsupported container yields null', () async {
      final path = '${tempDir.path}/weird.bin';
      File(path).writeAsBytesSync(List<int>.filled(1024, 7));
      final result = await writeTrimmedAudioFile(
        sourcePath: path,
        destPath: '${tempDir.path}/out.wav',
        startSec: 1.0,
        endSec: 2.0,
      );
      expect(result, isNull);
    });

    test('a missing source yields null', () async {
      final result = await writeTrimmedAudioFile(
        sourcePath: '${tempDir.path}/gone.wav',
        destPath: '${tempDir.path}/out.wav',
        startSec: 1.0,
        endSec: 2.0,
      );
      expect(result, isNull);
    });

    test('refuses to overwrite the source path', () async {
      final path = '${tempDir.path}/same.wav';
      await WavWriter.writePcm16File(
        filePath: path,
        samples: _ramp(_rate * 2),
        sampleRate: _rate,
      );
      final original = File(path).readAsBytesSync();

      final result = await writeTrimmedAudioFile(
        sourcePath: path,
        destPath: path,
        startSec: 0.5,
        endSec: 1.5,
      );

      expect(result, isNull);
      expect(File(path).readAsBytesSync(), original);
    });

    test('overwrites a stale file at the destination', () async {
      final source = await writeSourceWav(_rate * 6);
      final dest = '${tempDir.path}/out.wav';
      File(dest).writeAsBytesSync(List<int>.filled(999999, 0));

      final result = await writeTrimmedAudioFile(
        sourcePath: source,
        destPath: dest,
        startSec: 1.0,
        endSec: 2.0,
      );
      expect(result, isNotNull);
      final decoded = await AudioDecoder.decodeFile(dest);
      expect(decoded.totalSamples, _rate);
    });
  });

  group('writeTrimmedAudioFile — FLAC', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trim_flac_test_');
    });
    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Future<String> writeSourceFlac(int sampleCount) async {
      final path = '${tempDir.path}/full.flac';
      final samples = _ramp(sampleCount);
      final floats = Float32List(sampleCount);
      for (var i = 0; i < sampleCount; i++) {
        floats[i] = samples[i] / 32768.0;
      }
      await FlacEncoder.writeFile(
        filePath: path,
        samples: floats,
        sampleRate: _rate,
      );
      return path;
    }

    test('re-encodes the requested range as FLAC', () async {
      final source = await writeSourceFlac(_rate * 10);
      final full = await AudioDecoder.decodeFile(source);

      final result = await writeTrimmedAudioFile(
        sourcePath: source,
        destPath: '${tempDir.path}/out.flac',
        startSec: 2.0,
        endSec: 5.0,
      );

      expect(result, isNotNull);
      expect(result!.extension, '.flac');
      expect(result.durationSeconds, closeTo(3.0, 0.001));

      final decoded = await AudioDecoder.decodeFile(result.file.path);
      expect(decoded.sampleRate, _rate);
      expect(decoded.totalSamples, _rate * 3);
      // The slice must be bit-identical to the same window of the source —
      // trimming a lossless recording may not quietly requantize it.
      for (var i = 0; i < decoded.totalSamples; i += 997) {
        expect(
          decoded.samples[i],
          full.samples[_rate * 2 + i],
          reason: 'sample $i',
        );
      }
    });

    test('writes WAV instead when asWav is set', () async {
      final source = await writeSourceFlac(_rate * 6);
      final full = await AudioDecoder.decodeFile(source);

      final result = await writeTrimmedAudioFile(
        sourcePath: source,
        destPath: '${tempDir.path}/out.wav',
        startSec: 1.0,
        endSec: 4.0,
        asWav: true,
      );

      expect(result, isNotNull);
      expect(result!.extension, '.wav');
      expect(await AudioDecoder.isWav(result.file.path), isTrue);

      final decoded = await AudioDecoder.decodeFile(result.file.path);
      expect(decoded.totalSamples, _rate * 3);
      for (var i = 0; i < decoded.totalSamples; i += 997) {
        expect(
          decoded.samples[i],
          full.samples[_rate + i],
          reason: 'sample $i',
        );
      }
    });

    test('a null end runs to the end of the recording', () async {
      final source = await writeSourceFlac(_rate * 5);
      final result = await writeTrimmedAudioFile(
        sourcePath: source,
        destPath: '${tempDir.path}/out.flac',
        startSec: 3.5,
      );
      expect(result, isNotNull);
      expect(result!.durationSeconds, closeTo(1.5, 0.01));
    });

    test('slices that do not fall on frame boundaries stay exact', () async {
      final source = await writeSourceFlac(_rate * 4);
      final full = await AudioDecoder.decodeFile(source);

      const startSample = 12345;
      const endSample = 54321;
      final result = await writeTrimmedAudioFile(
        sourcePath: source,
        destPath: '${tempDir.path}/out.flac',
        startSec: startSample / _rate,
        endSec: endSample / _rate,
      );

      expect(result, isNotNull);
      final decoded = await AudioDecoder.decodeFile(result!.file.path);
      final expectedCount = endSample - startSample;
      // Sub-sample rounding of the boundaries may cost a single sample.
      expect(
        (decoded.totalSamples - expectedCount).abs(),
        lessThanOrEqualTo(1),
      );
      final compare = math.min(decoded.totalSamples, expectedCount);
      for (var i = 0; i < compare; i += 101) {
        expect(
          decoded.samples[i],
          full.samples[startSample + i],
          reason: 'sample $i',
        );
      }
    });

    test('a range entirely past the recording yields null', () async {
      final source = await writeSourceFlac(_rate * 3);
      final result = await writeTrimmedAudioFile(
        sourcePath: source,
        destPath: '${tempDir.path}/out.flac',
        startSec: 20.0,
        endSec: 25.0,
      );
      expect(result, isNull);
      expect(File('${tempDir.path}/out.flac').existsSync(), isFalse);
    });
  });
}
