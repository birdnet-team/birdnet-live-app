// =============================================================================
// PlaybackNormalizer Tests
// =============================================================================
//
// The decode now runs in a background isolate and the cache is probed before
// it, so a reopened clip never decodes at all. These pin the observable
// contract that reordering must not change: quiet clips get a boosted copy,
// healthy clips are handed back untouched, and any failure still yields a
// playable path.
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/recording/audio_decoder.dart';
import 'package:birdnet_live/features/recording/playback_normalizer.dart';
import 'package:birdnet_live/features/recording/wav_writer.dart';

const int _rate = 32000;

Float32List _tone({required int samples, required double amplitude}) {
  final out = Float32List(samples);
  for (var i = 0; i < samples; i++) {
    out[i] = amplitude * math.sin(2 * math.pi * 440 * i / _rate);
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('norm_test_');
    // resolveSource asks path_provider for the cache location on the calling
    // isolate; the isolate itself only touches plain files.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              call.method == 'getTemporaryDirectory' ? tempDir.path : null,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<String> writeWav(String name, Float32List samples) async {
    final path = '${tempDir.path}${Platform.pathSeparator}$name';
    await WavWriter.writeFile(
      filePath: path,
      samples: samples,
      sampleRate: _rate,
    );
    return path;
  }

  group('PlaybackNormalizer.resolveSource', () {
    test('boosts a quiet clip into a separate cached copy', () async {
      final quiet = await writeWav(
        'quiet.wav',
        _tone(samples: _rate, amplitude: 0.05),
      );

      final resolved = await PlaybackNormalizer.resolveSource(quiet);

      expect(resolved, isNot(quiet));
      expect(File(resolved).existsSync(), isTrue);

      final boosted = await AudioDecoder.decodeFile(resolved);
      var peak = 0;
      for (final s in boosted.samples) {
        final abs = s < 0 ? -s : s;
        if (abs > peak) peak = abs;
      }
      // Normalized to just under full scale.
      expect(peak / 32768.0, closeTo(0.95, 0.02));

      // The original is never touched — a lossless field recording must keep
      // its real dynamics.
      final original = await AudioDecoder.decodeFile(quiet);
      var originalPeak = 0;
      for (final s in original.samples) {
        final abs = s < 0 ? -s : s;
        if (abs > originalPeak) originalPeak = abs;
      }
      expect(originalPeak / 32768.0, closeTo(0.05, 0.01));
    });

    test('hands back a healthy clip unchanged', () async {
      final loud = await writeWav(
        'loud.wav',
        _tone(samples: _rate, amplitude: 0.8),
      );

      expect(await PlaybackNormalizer.resolveSource(loud), loud);
    });

    test('silence is left alone rather than amplified to noise', () async {
      final silent = await writeWav('silent.wav', Float32List(_rate));

      expect(await PlaybackNormalizer.resolveSource(silent), silent);
    });

    test('a second resolve reuses the cached copy', () async {
      final quiet = await writeWav(
        'quiet2.wav',
        _tone(samples: _rate, amplitude: 0.05),
      );

      final first = await PlaybackNormalizer.resolveSource(quiet);
      final firstStat = await File(first).stat();

      final second = await PlaybackNormalizer.resolveSource(quiet);

      expect(second, first);
      // Same file, not a rewrite: the cache is probed before the decode now.
      expect((await File(second).stat()).modified, firstStat.modified);
    });

    test('re-normalizes after the source changes', () async {
      final path = await writeWav(
        'changing.wav',
        _tone(samples: _rate, amplitude: 0.05),
      );
      final first = await PlaybackNormalizer.resolveSource(path);

      // A different length gives a different cache key even if the mtime
      // resolution is too coarse to notice the rewrite.
      await WavWriter.writeFile(
        filePath: path,
        samples: _tone(samples: _rate * 2, amplitude: 0.05),
        sampleRate: _rate,
      );
      final second = await PlaybackNormalizer.resolveSource(path);

      expect(second, isNot(first));
      final decoded = await AudioDecoder.decodeFile(second);
      expect(decoded.totalSamples, _rate * 2);
    });

    test('skips normalization for a large source', () async {
      // Above the 30 MB guard: playback must start on the original rather
      // than wait on a decode that would take seconds.
      final big = await writeWav(
        'big.wav',
        _tone(samples: 16 * 1024 * 1024, amplitude: 0.05),
      );
      expect(await File(big).length(), greaterThan(30 * 1024 * 1024));

      expect(await PlaybackNormalizer.resolveSource(big), big);
    });

    test('falls back to the original when the file is missing', () async {
      final missing = '${tempDir.path}${Platform.pathSeparator}nope.wav';
      expect(await PlaybackNormalizer.resolveSource(missing), missing);
    });

    test('falls back to the original for an undecodable file', () async {
      final junk = '${tempDir.path}${Platform.pathSeparator}junk.mp3';
      await File(junk).writeAsBytes(List<int>.filled(2048, 0x42));

      expect(await PlaybackNormalizer.resolveSource(junk), junk);
    });

    test('uses caller-supplied samples without re-decoding', () async {
      final quiet = await writeWav(
        'preload.wav',
        _tone(samples: _rate, amplitude: 0.05),
      );
      final decoded = await AudioDecoder.decodeFile(quiet);

      final resolved = await PlaybackNormalizer.resolveSource(
        quiet,
        decoded: decoded,
      );

      expect(resolved, isNot(quiet));
      expect(File(resolved).existsSync(), isTrue);
    });
  });
}
