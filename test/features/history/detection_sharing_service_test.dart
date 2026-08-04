// =============================================================================
// detection_sharing_service_test.dart
// =============================================================================
// Validates the slice extraction used by the live-session "share detection"
// cascade for both WAV and FLAC full recordings. The platform `Share.share*`
// calls themselves are not exercised here (they require a real platform
// channel); instead we drive [extractClipFromFullAudio] end-to-end against
// synthetic recordings produced by the real [WavWriter] and [FlacEncoder]
// so any framing or header bug surfaces as a failed assertion on the
// staged file.
// =============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:birdnet_live/features/history/services/detection_sharing_service.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/recording/audio_decoder.dart';
import 'package:birdnet_live/features/recording/flac_encoder.dart';
import 'package:birdnet_live/features/recording/wav_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tmp);
  final String tmp;

  @override
  Future<String?> getTemporaryPath() async => tmp;

  @override
  Future<String?> getApplicationDocumentsPath() async => tmp;

  @override
  Future<String?> getApplicationSupportPath() async => tmp;
}

class _FakeSharePlatform extends SharePlatform with MockPlatformInterfaceMixin {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

LiveSession _session({
  required String recordingPath,
  required DateTime start,
  int windowDuration = 3,
  int clipContextSeconds = 1,
}) {
  return LiveSession(
    id: 'test',
    startTime: start,
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

DetectionRecord _det(DateTime ts, {DateTime? endTimestamp}) {
  return DetectionRecord(
    scientificName: 'Troglodytes troglodytes',
    commonName: 'Eurasian Wren',
    confidence: 0.9,
    timestamp: ts,
    endTimestamp: endTimestamp,
  );
}

/// Writes a synthetic 16-bit PCM WAV file with [seconds] of audio at
/// 32 kHz mono via the real [WavWriter], so the on-disk header layout
/// matches what live recordings produce.
Future<File> _writeFakeWav(Directory dir, double seconds) async {
  const sampleRate = 32000;
  final path = p.join(dir.path, 'full.wav');
  final writer = WavWriter(filePath: path, sampleRate: sampleRate);
  await writer.open();
  // Push samples in 0.5-second chunks so we exercise the streaming path
  // (header placeholder + multiple flushes) just like live recordings do.
  final chunk = Float32List((sampleRate * 0.5).round());
  for (var i = 0; i < chunk.length; i++) {
    // Triangle wave at ~441 Hz so the bytes aren't all-zero (a silent
    // file would still pass the slicer but is harder to debug).
    chunk[i] = ((i % 73) / 73.0) * 2.0 - 1.0;
  }
  final totalChunks = (seconds / 0.5).round();
  for (var i = 0; i < totalChunks; i++) {
    await writer.writeSamples(chunk);
  }
  await writer.close();
  return File(path);
}

Future<File> _writeQuietWav(Directory dir, double seconds) async {
  const sampleRate = 32000;
  final path = p.join(dir.path, 'full.wav');
  await WavWriter.writeFile(
    filePath: path,
    samples: _quietFloatSamples((seconds * sampleRate).round()),
    sampleRate: sampleRate,
  );
  return File(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late SharePlatform originalSharePlatform;
  final fakeSharePlatform = _FakeSharePlatform();

  setUpAll(() {
    originalSharePlatform = SharePlatform.instance;
    SharePlatform.instance = fakeSharePlatform;
  });

  tearDownAll(() {
    SharePlatform.instance = originalSharePlatform;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('share_extract_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    fakeSharePlatform.lastParams = null;
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  group('shareDetection', () {
    test('shares a saved FLAC detection clip as valid WAV', () async {
      final clip = File(p.join(tmp.path, 'kept_clip.flac'));
      final sourceSamples = _pcmLikeFloatSamples(32000);
      await FlacEncoder.writeFile(filePath: clip.path, samples: sourceSamples);
      final detection = _det(DateTime.utc(2026, 5, 11, 10, 0, 0))
        ..audioClipPath = clip.path;

      await shareDetection(detection, shareAudioAsWav: true);

      final params = fakeSharePlatform.lastParams;
      expect(params, isNotNull);
      expect(params!.files, hasLength(1));
      expect(params.files!.single.mimeType, 'audio/wav');
      expect(params.fileNameOverrides, hasLength(1));
      expect(params.fileNameOverrides!.single, endsWith('.wav'));
      expect(params.fileNameOverrides!.single, params.files!.single.name);
      expect(params.title, params.fileNameOverrides!.single);
      expect(params.text, isNull);
      expect(params.subject, isNull);

      final sharedFile = File(params.files!.single.path);
      final header = await sharedFile
          .openRead(0, 12)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      expect(String.fromCharCodes(header.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(header.sublist(8, 12)), 'WAVE');

      final decoded = await AudioDecoder.decodeFile(sharedFile.path);
      expect(decoded.sampleRate, 32000);
      expect(decoded.samples, _expectedPcm16(sourceSamples));
    });

    test('adds a detected extension when the saved clip has none', () async {
      final clip = File(p.join(tmp.path, 'kept_clip'));
      final encoded = File(p.join(tmp.path, 'kept_clip.flac'));
      await FlacEncoder.writeFile(
        filePath: encoded.path,
        samples: _pcmLikeFloatSamples(32000),
      );
      await encoded.copy(clip.path);
      final detection = _det(DateTime.utc(2026, 5, 11, 10, 0, 0))
        ..audioClipPath = clip.path;

      await shareDetection(detection);

      final params = fakeSharePlatform.lastParams;
      expect(params, isNotNull);
      expect(params!.files, hasLength(1));
      expect(params.files!.single.mimeType, 'audio/flac');
      expect(params.files!.single.name, endsWith('.flac'));
      expect(params.fileNameOverrides, [params.files!.single.name]);
      expect(params.title, params.files!.single.name);
      expect(params.text, isNull);
      expect(params.subject, isNull);
      expect(File(params.files!.single.path).path, endsWith('.flac'));
    });

    test('normalizes quiet WAV detection clips on share', () async {
      final clip = File(p.join(tmp.path, 'quiet_clip.wav'));
      await WavWriter.writeFile(
        filePath: clip.path,
        samples: _quietFloatSamples(32000),
      );
      final detection = _det(DateTime.utc(2026, 5, 11, 10, 0, 0))
        ..audioClipPath = clip.path;

      await shareDetection(detection);

      final params = fakeSharePlatform.lastParams;
      expect(params, isNotNull);
      expect(params!.files, hasLength(1));
      expect(params.files!.single.name, endsWith('.wav'));

      final decoded = await AudioDecoder.decodeFile(params.files!.single.path);
      expect(_peak(decoded.samples), greaterThan(0.9));
    });

    test('normalizes quiet FLAC detection clips on share', () async {
      final clip = File(p.join(tmp.path, 'quiet_clip.flac'));
      await FlacEncoder.writeFile(
        filePath: clip.path,
        samples: _quietFloatSamples(32000),
      );
      final detection = _det(DateTime.utc(2026, 5, 11, 10, 0, 0))
        ..audioClipPath = clip.path;

      await shareDetection(detection);

      final params = fakeSharePlatform.lastParams;
      expect(params, isNotNull);
      expect(params!.files, hasLength(1));
      expect(params.files!.single.name, endsWith('.flac'));
      expect(params.files!.single.mimeType, 'audio/flac');

      final decoded = await AudioDecoder.decodeFile(params.files!.single.path);
      expect(_peak(decoded.samples), greaterThan(0.9));
    });

    // Regression guard for issue #203: iPad presents the share sheet as a
    // popover and the iOS plugin refuses to show it without an anchor
    // rect, so sharePositionOrigin has to survive every branch of the
    // cascade — saved clip, slice extracted from the full recording, and
    // the text-only fallback.
    group('sharePositionOrigin', () {
      const origin = Rect.fromLTWH(12, 34, 56, 78);

      test('is forwarded when sharing a saved clip', () async {
        final clip = File(p.join(tmp.path, 'anchored_clip.wav'));
        await WavWriter.writeFile(
          filePath: clip.path,
          samples: _pcmLikeFloatSamples(32000),
        );
        final detection = _det(DateTime.utc(2026, 5, 11, 10, 0, 0))
          ..audioClipPath = clip.path;

        await shareDetection(detection, sharePositionOrigin: origin);

        final params = fakeSharePlatform.lastParams;
        expect(params!.files, hasLength(1));
        expect(params.sharePositionOrigin, origin);
      });

      test('is forwarded when slicing the full recording', () async {
        final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
        final sessionDir =
            await Directory(p.join(tmp.path, 'rec_anchored')).create();
        await _writeFakeWav(sessionDir, 10.0);
        final session = _session(recordingPath: sessionDir.path, start: start);
        final detection = _det(start.add(const Duration(seconds: 4)));

        await shareDetection(
          detection,
          session: session,
          sharePositionOrigin: origin,
        );

        final params = fakeSharePlatform.lastParams;
        expect(params!.files, hasLength(1));
        expect(params.sharePositionOrigin, origin);
      });

      test('is forwarded on the text-only fallback', () async {
        final detection = _det(DateTime.utc(2026, 5, 11, 10, 0, 0));

        await shareDetection(detection, sharePositionOrigin: origin);

        final params = fakeSharePlatform.lastParams;
        expect(params!.files, anyOf(isNull, isEmpty));
        expect(params.text, isNotNull);
        expect(params.sharePositionOrigin, origin);
      });
    });
  });

  group('extractClipFromFullAudio', () {
    test('extracts a window from a finalized full.wav', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(p.join(tmp.path, 'rec')).create();
      // 10 seconds of audio total.
      final wav = await _writeFakeWav(sessionDir, 10.0);
      expect(wav.existsSync(), isTrue);
      expect(await wav.length(), greaterThan(44 + 32000 * 2 * 9));

      // Recording path can be either the session directory (mid-recording)
      // or the file itself (post-stop). Cover both shapes.
      final session = _session(
        recordingPath: sessionDir.path,
        start: start,
        windowDuration: 3,
        clipContextSeconds: 1,
      );
      final detection = _det(start.add(const Duration(seconds: 5)));

      final out = await extractClipFromFullAudio(session, detection);
      expect(out, isNotNull, reason: 'extractor should find session dir');
      expect(out!.existsSync(), isTrue);

      // Expected slice: detOffset=5s, clipContext=1s, window=3s
      // → start=4s, duration=5s → 5 * 32000 * 2 = 320_000 PCM bytes
      // → file size = 44 + 320_000 = 320_044 bytes.
      final length = await out.length();
      expect(length, 44 + 5 * 32000 * 2);

      // Header sanity: RIFF / WAVE / fmt  / data tags in the right slots.
      final header = await out
          .openRead(0, 44)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      expect(String.fromCharCodes(header.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(header.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(header.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(header.sublist(36, 40)), 'data');
      // Sample rate at offset 24 (uint32 LE) should be 32000.
      final view = ByteData.sublistView(Uint8List.fromList(header));
      expect(view.getUint32(24, Endian.little), 32000);
      expect(view.getUint16(22, Endian.little), 1); // channels
      expect(view.getUint16(34, Endian.little), 16); // bits per sample
    });

    test(
      'shares the full continuous detection duration from full.wav',
      () async {
        final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
        final sessionDir =
            await Directory(p.join(tmp.path, 'rec_long_detection')).create();
        await _writeFakeWav(sessionDir, 30.0);
        final session = _session(
          recordingPath: sessionDir.path,
          start: start,
          windowDuration: 3,
          clipContextSeconds: 0,
        );
        final detection = _det(
          start.add(const Duration(seconds: 5)),
          endTimestamp: start.add(const Duration(seconds: 19)),
        );

        await shareDetection(detection, session: session);

        final params = fakeSharePlatform.lastParams;
        expect(params, isNotNull);
        expect(params!.files, hasLength(1));
        expect(params.files!.single.name, endsWith('.wav'));

        final decoded = await AudioDecoder.decodeFile(
          params.files!.single.path,
        );
        expect(decoded.sampleRate, 32000);
        expect(decoded.totalSamples, 32000 * 14);
      },
    );

    test('normalizes quiet slices from full.wav on share', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir =
          await Directory(p.join(tmp.path, 'rec_quiet_slice')).create();
      await _writeQuietWav(sessionDir, 10.0);
      final session = _session(
        recordingPath: sessionDir.path,
        start: start,
        windowDuration: 3,
        clipContextSeconds: 0,
      );
      final detection = _det(start.add(const Duration(seconds: 2)));

      await shareDetection(detection, session: session);

      final params = fakeSharePlatform.lastParams;
      expect(params, isNotNull);
      expect(params!.files, hasLength(1));
      expect(params.files!.single.name, endsWith('.wav'));

      final decoded = await AudioDecoder.decodeFile(params.files!.single.path);
      expect(decoded.totalSamples, 32000 * 3);
      expect(_peak(decoded.samples), greaterThan(0.9));
    });

    test('accepts a direct file path (post-stop shape)', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(p.join(tmp.path, 'rec2')).create();
      final wav = await _writeFakeWav(sessionDir, 8.0);

      final session = _session(
        recordingPath: wav.path, // file, not directory
        start: start,
      );
      final detection = _det(start.add(const Duration(seconds: 4)));

      final out = await extractClipFromFullAudio(session, detection);
      expect(out, isNotNull);
      expect(await out!.length(), greaterThan(44));
    });

    test('clamps when the requested window runs past EOF', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(p.join(tmp.path, 'rec3')).create();
      // Only 4 seconds recorded so far.
      await _writeFakeWav(sessionDir, 4.0);

      final session = _session(
        recordingPath: sessionDir.path,
        start: start,
        windowDuration: 3,
        clipContextSeconds: 1,
      );
      // Detection at t=3.5s → window would want [2.5, 7.5), only [2.5, 4.0)
      // is available.
      final detection = _det(start.add(const Duration(milliseconds: 3500)));

      final out = await extractClipFromFullAudio(session, detection);
      expect(out, isNotNull, reason: 'partial slice is better than nothing');
      // 1.5 seconds × 32000 × 2 = 96_000 bytes of PCM.
      expect(await out!.length(), 44 + (1.5 * 32000).floor() * 2);
    });

    test('returns null when recordingPath is null', () async {
      final session = _session(
        recordingPath: '',
        start: DateTime.utc(2026, 5, 11),
      );
      // Manually clear the field — the constructor required a non-null
      // path above to set up the rest of the object.
      session.recordingPath = null;
      final out = await extractClipFromFullAudio(
        session,
        _det(session.startTime),
      );
      expect(out, isNull);
    });

    test('extracts a window from a finalized full.flac', () async {
      // Mirror the WAV path but with a real FLAC encoder so we exercise
      // the FLAC slicing branch end-to-end. The output is still WAV
      // (we always re-wrap PCM as WAV for the share sheet).
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(p.join(tmp.path, 'rec_flac')).create();
      const sampleRate = 32000;
      final flacPath = p.join(sessionDir.path, 'full.flac');
      final encoder = FlacEncoder(filePath: flacPath, sampleRate: sampleRate);
      await encoder.open();
      final chunk = Float32List((sampleRate * 0.5).round());
      for (var i = 0; i < chunk.length; i++) {
        chunk[i] = ((i % 73) / 73.0) * 2.0 - 1.0;
      }
      for (var i = 0; i < 20; i++) {
        // 10 seconds total
        await encoder.writeSamples(chunk);
      }
      await encoder.close();
      expect(File(flacPath).existsSync(), isTrue);

      final session = _session(
        recordingPath: sessionDir.path,
        start: start,
        windowDuration: 3,
        clipContextSeconds: 1,
      );
      // Detection at t=5s → window [4, 9) → 5 s slice.
      final detection = _det(start.add(const Duration(seconds: 5)));

      final out = await extractClipFromFullAudio(session, detection);
      expect(out, isNotNull, reason: 'FLAC full recordings must slice');
      expect(out!.existsSync(), isTrue);

      // Output container matches source: FLAC in → FLAC out.
      expect(p.extension(out.path), '.flac');
      // FLAC magic number 'fLaC' at file start.
      final magic = await out
          .openRead(0, 4)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      expect(String.fromCharCodes(magic), 'fLaC');
      // Re-decode and confirm we got the requested ~5 s back.
      final roundTrip = await AudioDecoder.decodeFlacRange(
        out.path,
        startSample: 0,
        count: 32000 * 6, // ask for more than we wrote; decoder clips to EOF
      );
      expect(roundTrip.sampleRate, 32000);
      // Allow a small tolerance for end-of-stream block alignment.
      expect(
        roundTrip.totalSamples,
        inInclusiveRange(32000 * 5 - 4096, 32000 * 5 + 4096),
      );
    });

    test('FLAC: accepts a direct file path (post-stop shape)', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir =
          await Directory(p.join(tmp.path, 'rec_flac2')).create();
      const sampleRate = 32000;
      final flacPath = p.join(sessionDir.path, 'full.flac');
      final encoder = FlacEncoder(filePath: flacPath, sampleRate: sampleRate);
      await encoder.open();
      final chunk = Float32List(sampleRate);
      for (var i = 0; i < chunk.length; i++) {
        chunk[i] = ((i % 91) / 91.0) * 2.0 - 1.0;
      }
      for (var i = 0; i < 8; i++) {
        await encoder.writeSamples(chunk);
      }
      await encoder.close();

      final session = _session(
        recordingPath: flacPath, // file, not directory (post-stop shape)
        start: start,
      );
      final detection = _det(start.add(const Duration(seconds: 4)));

      final out = await extractClipFromFullAudio(session, detection);
      expect(out, isNotNull);
      expect(p.extension(out!.path), '.flac');
      final magic = await out
          .openRead(0, 4)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      expect(String.fromCharCodes(magic), 'fLaC');
    });

    test('converts a full FLAC slice to valid WAV when requested', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir =
          await Directory(p.join(tmp.path, 'rec_flac_wav')).create();
      const sampleRate = 32000;
      final flacPath = p.join(sessionDir.path, 'full.flac');
      final sourceSamples = _pcmLikeFloatSamples(sampleRate * 10);
      await FlacEncoder.writeFile(filePath: flacPath, samples: sourceSamples);

      final session = _session(
        recordingPath: sessionDir.path,
        start: start,
        windowDuration: 3,
        clipContextSeconds: 1,
      );
      final detection = _det(start.add(const Duration(seconds: 5)));

      final out = await extractClipFromFullAudio(
        session,
        detection,
        shareAudioAsWav: true,
      );
      expect(out, isNotNull);
      expect(p.extension(out!.path), '.wav');

      final header = await out
          .openRead(0, 12)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      expect(String.fromCharCodes(header.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(header.sublist(8, 12)), 'WAVE');

      final decoded = await AudioDecoder.decodeFile(out.path);
      expect(decoded.sampleRate, sampleRate);
      expect(decoded.totalSamples, sampleRate * 5);
      expect(
        decoded.samples,
        _expectedPcm16(
          Float32List.sublistView(
            sourceSamples,
            sampleRate * 4,
            sampleRate * 9,
          ),
        ),
      );
    });

    test('returns null when no full recording exists at all', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir =
          await Directory(p.join(tmp.path, 'rec_empty')).create();
      // Empty session dir — no full.wav and no full.flac.
      final session = _session(recordingPath: sessionDir.path, start: start);
      final out = await extractClipFromFullAudio(session, _det(start));
      expect(out, isNull);
    });

    test('extracts while the writer is still open (mid-recording)', () async {
      // Reproduces the live-survey path: WavWriter is still holding the
      // file open with placeholder header sizes, the slicer must trust
      // file length on disk rather than the header field.
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(p.join(tmp.path, 'rec5')).create();
      const sampleRate = 32000;
      final path = p.join(sessionDir.path, 'full.wav');
      final writer = WavWriter(filePath: path, sampleRate: sampleRate);
      await writer.open();
      try {
        // 6 seconds of audio in 0.5 s chunks, no close() yet.
        final chunk = Float32List((sampleRate * 0.5).round())
          ..fillRange(0, (sampleRate * 0.5).round(), 0.5);
        for (var i = 0; i < 12; i++) {
          await writer.writeSamples(chunk);
        }

        final session = _session(
          recordingPath: sessionDir.path,
          start: start,
          windowDuration: 3,
          clipContextSeconds: 1,
        );
        // Detection at t=3s → window [2, 7) → clamped to [2, ~6).
        final detection = _det(start.add(const Duration(seconds: 3)));

        final out = await extractClipFromFullAudio(session, detection);
        expect(
          out,
          isNotNull,
          reason: 'mid-recording slice must succeed despite placeholder header',
        );
        expect(await out!.length(), greaterThan(44));
      } finally {
        await writer.close();
      }
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

Float32List _quietFloatSamples(int count) {
  final samples = Float32List(count);
  for (var i = 0; i < count; i++) {
    samples[i] = (((i % 97) / 96.0) * 2.0 - 1.0) * 0.05;
  }
  return samples;
}

double _peak(Int16List samples) {
  var peak = 0;
  for (final sample in samples) {
    final abs = sample < 0 ? -sample : sample;
    if (abs > peak) peak = abs;
  }
  return peak / 32768.0;
}

Int16List _expectedPcm16(Float32List samples) {
  final pcm = Int16List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    pcm[i] = (samples[i] * 32767.0).round().clamp(-32768, 32767);
  }
  return pcm;
}
