// =============================================================================
// NativePcmTranscode Tests
// =============================================================================
//
// Session Review reads the compressed→PCM cache file while the platform
// decoder is still writing it, so it can draw the decoded prefix instead of
// waiting minutes for a long MP3. That only works if [NativePcmTranscode]
// reports availability honestly as the file grows, and never turns a decoder
// failure into an unhandled async error while the caller is still polling.
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/recording/native_audio_decoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('transcode_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String pcmPath(String name) =>
      '${tempDir.path}${Platform.pathSeparator}$name';

  group('NativePcmTranscode', () {
    test('reports the header duration before anything is decoded', () async {
      final path = pcmPath('pending.pcm');
      final completer = Completer<NativePcmFileDecodeResult>();
      final transcode = NativePcmTranscode(
        pcmPath: path,
        sampleRate: 44100,
        expectedTotalSamples: 44100 * 60,
        completed: completer.future,
      );

      // The timeline can be laid out from the container header alone — that is
      // what lets the strip appear before the decoder has produced a sample.
      expect(transcode.sampleRate, 44100);
      expect(transcode.expectedTotalSamples, 44100 * 60);
      // The file does not exist yet; that is not an error, just nothing ready.
      expect(await transcode.availableSamples(), 0);

      completer.complete(
        NativePcmFileDecodeResult(
          pcmPath: path,
          sampleRate: 44100,
          totalSamples: 0,
        ),
      );
      await transcode.completed;
    });

    test('availability tracks the file as it grows', () async {
      final path = pcmPath('growing.pcm');
      final file = File(path);
      final completer = Completer<NativePcmFileDecodeResult>();
      final transcode = NativePcmTranscode(
        pcmPath: path,
        sampleRate: 32000,
        expectedTotalSamples: 32000 * 10,
        completed: completer.future,
      );

      final sink = file.openWrite();
      addTearDown(() async {
        try {
          await sink.close();
        } catch (_) {}
      });

      // Two bytes per mono sample.
      sink.add(Uint8List(2000));
      await sink.flush();
      expect(await transcode.availableSamples(), 1000);

      sink.add(Uint8List(500));
      await sink.flush();
      expect(await transcode.availableSamples(), 1250);

      await sink.close();
      completer.complete(
        NativePcmFileDecodeResult(
          pcmPath: path,
          sampleRate: 32000,
          totalSamples: 1250,
        ),
      );
      expect((await transcode.completed).totalSamples, 1250);
    });

    test('an odd trailing byte never reports a half sample', () async {
      final path = pcmPath('odd.pcm');
      await File(path).writeAsBytes(Uint8List(2001));
      final transcode = NativePcmTranscode(
        pcmPath: path,
        sampleRate: 32000,
        expectedTotalSamples: 32000,
        completed: Future.value(
          NativePcmFileDecodeResult(
            pcmPath: path,
            sampleRate: 32000,
            totalSamples: 1000,
          ),
        ),
      );

      // A partially flushed sample must round down, or a tile would read one
      // byte past what has actually been written.
      expect(await transcode.availableSamples(), 1000);
    });

    test('a decoder failure does not escape as an unhandled error', () async {
      final path = pcmPath('failing.pcm');
      final completer = Completer<NativePcmFileDecodeResult>();
      final transcode = NativePcmTranscode(
        pcmPath: path,
        sampleRate: 32000,
        expectedTotalSamples: 32000,
        completed: completer.future,
      );

      completer.completeError(StateError('decoder died'));
      // Callers poll for a while before they get around to awaiting; the
      // failure must sit there quietly until then rather than crashing the
      // zone in between.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await transcode.availableSamples(), 0);

      // And it is still delivered to whoever does await it.
      await expectLater(transcode.completed, throwsStateError);
    });

    test('stale transcode caches are swept, live ones are not', () async {
      // A crash or force-stop mid-decode strands the cache file, and each one
      // is hundreds of megabytes.
      final stale = File(pcmPath('temp_decoded_111.pcm'))
        ..writeAsBytesSync(Uint8List(16));
      final fresh = File(pcmPath('temp_decoded_222.pcm'))
        ..writeAsBytesSync(Uint8List(16));
      final unrelated = File(pcmPath('something_else.pcm'))
        ..writeAsBytesSync(Uint8List(16));
      stale.setLastModifiedSync(
        DateTime.now().subtract(const Duration(hours: 6)),
      );

      // The sweep is fired from the temp-path allocation, so exercise it the
      // way production does.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async =>
                call.method == 'getTemporaryDirectory' ? tempDir.path : null,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            );
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.birdnet/audio_decoder'),
            (call) async => throw PlatformException(code: 'no decoder'),
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.birdnet/audio_decoder'),
              null,
            );
      });

      final started = await NativeAudioDecoder.startDecodeToTempPcmFile(
        'whatever.mp3',
        sampleRate: 32000,
        expectedTotalSamples: 32000,
      );
      await started.completed.catchError(
        (Object _) => NativePcmFileDecodeResult(
          pcmPath: '',
          sampleRate: 0,
          totalSamples: 0,
        ),
      );
      // Give the fire-and-forget sweep a turn.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(stale.existsSync(), isFalse, reason: 'old cache should be swept');
      expect(fresh.existsSync(), isTrue, reason: 'recent cache is in use');
      expect(unrelated.existsSync(), isTrue, reason: 'not ours to delete');
    });

    test('completion can report a count the header did not predict', () async {
      final path = pcmPath('drift.pcm');
      await File(path).writeAsBytes(Uint8List(400));
      final transcode = NativePcmTranscode(
        pcmPath: path,
        sampleRate: 44100,
        // Container durations are rounded, so the real count usually differs
        // slightly; the caller re-reads it from the result.
        expectedTotalSamples: 1000,
        completed: Future.value(
          NativePcmFileDecodeResult(
            pcmPath: path,
            sampleRate: 44100,
            totalSamples: 200,
          ),
        ),
      );

      expect(transcode.expectedTotalSamples, 1000);
      expect((await transcode.completed).totalSamples, 200);
      expect(await transcode.availableSamples(), 200);
    });
  });
}
