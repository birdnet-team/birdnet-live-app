// =============================================================================
// Native MP3 File Analysis Integration Test
// =============================================================================
//
// Exercises the native decoder path used by File Analysis review for
// compressed uploads. The fixture is a small head clip from the long
// XC561949 soundscape so the test catches truncated/overreported-duration MP3
// behavior without pushing the full 70 MB source file.
//
// Before running on a device:
//   adb push assets/test_fixtures/XC561949_soundscape_head.mp3 /data/local/tmp/test_fixtures/
//   flutter test integration_test/native_mp3_file_analysis_test.dart -d <device_id>
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fftea/fftea.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:birdnet_live/features/recording/audio_decoder.dart';
import 'package:birdnet_live/features/recording/native_audio_decoder.dart';

const _fixturePath =
    '/data/local/tmp/test_fixtures/XC561949_soundscape_head.mp3';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'copied MP3 upload remains spectrogram-readable through native ranges',
    (tester) async {
      final fixture = File(_fixturePath);
      expect(
        fixture.existsSync(),
        isTrue,
        reason:
            'Push the fixture first: adb push assets/test_fixtures/XC561949_soundscape_head.mp3 /data/local/tmp/test_fixtures/',
      );

      final metadata = await NativeAudioDecoder.inspectFile(
        _fixturePath,
        'MP3',
      );
      debugPrint(
        '[NativeMp3Test] metadata sampleRate=${metadata.sampleRate} '
        'totalSamples=${metadata.totalSamples} duration=${metadata.duration}',
      );
      expect(metadata.sampleRate, greaterThan(0));
      expect(metadata.totalSamples, greaterThan(0));

      final outputDir = Directory.systemTemp.createTempSync(
        'native_mp3_file_analysis_test_',
      );
      try {
        final copiedPath = '${outputDir.path}/full.mp3';
        await fixture.copy(copiedPath);

        await _expectNativeRangesReachEof(
          sourcePath: copiedPath,
          sourceSampleRate: metadata.sampleRate,
          sourceTotalSamples: metadata.totalSamples,
        );

        expect(File(copiedPath).lengthSync(), fixture.lengthSync());
        await _expectNativeSpectrogramReadable(copiedPath, metadata);
      } finally {
        if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _expectNativeRangesReachEof({
  required String sourcePath,
  required int sourceSampleRate,
  required int sourceTotalSamples,
}) async {
  const chunkSeconds = 5;
  final chunkSamples = sourceSampleRate * chunkSeconds;
  var start = 0;
  var chunks = 0;
  var totalWritten = 0;

  while (start < sourceTotalSamples) {
    chunks++;
    expect(
      chunks,
      lessThan(90),
      reason: 'Native range decode did not reach EOF or finish in time.',
    );

    final requested = math.min(chunkSamples, sourceTotalSamples - start);
    final result = await NativeAudioDecoder.decodeRangeWithStatus(
      sourcePath,
      startSample: start,
      count: requested,
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException(
          'decodeRangeWithStatus timed out at startSample=$start '
          'count=$requested',
        );
      },
    );

    final decoded = result.audio.totalSamples;
    debugPrint(
      '[NativeMp3Test] range chunk=$chunks start=$start requested=$requested '
      'decoded=$decoded reachedEnd=${result.reachedEnd}',
    );

    if (decoded <= 0) {
      expect(result.reachedEnd, isTrue);
      break;
    }

    totalWritten += decoded;
    start += decoded;

    if (result.reachedEnd) break;
  }

  debugPrint(
    '[NativeMp3Test] native ranges reached end after samples=$totalWritten '
    'chunks=$chunks metadataTotal=$sourceTotalSamples',
  );
  expect(totalWritten, greaterThan(sourceSampleRate * 5));
}

Future<void> _expectNativeSpectrogramReadable(
  String path,
  AudioMetadata metadata,
) async {
  final count = math.min(metadata.sampleRate * 10, metadata.totalSamples);
  final audio = await NativeAudioDecoder.decodeRange(
    path,
    startSample: 0,
    count: count,
  );
  expect(audio.totalSamples, greaterThan(2048));

  final columns = _countNonSilentFftColumns(
    audio.readFloat32(0, audio.totalSamples),
  );
  debugPrint('[NativeMp3Test] MP3 spectrogram columns with signal=$columns');
  expect(
    columns,
    greaterThan(0),
    reason: 'Copied MP3 decoded but produced no spectrogram signal.',
  );
}

int _countNonSilentFftColumns(Float32List samples) {
  const fftSize = 2048;
  const hop = 1024;
  if (samples.length < fftSize) return 0;

  final hann = Float64List(fftSize);
  final hannFactor = 2.0 * math.pi / fftSize;
  for (var i = 0; i < fftSize; i++) {
    hann[i] = 0.5 * (1.0 - math.cos(hannFactor * i));
  }

  final fft = FFT(fftSize);
  var columnsWithSignal = 0;
  for (var start = 0; start + fftSize <= samples.length; start += hop) {
    final input = Float64List(fftSize);
    for (var i = 0; i < fftSize; i++) {
      input[i] = samples[start + i] * hann[i];
    }
    final spectrum = fft.realFft(input);
    var power = 0.0;
    for (var bin = 1; bin < spectrum.length; bin++) {
      final re = spectrum[bin].x;
      final im = spectrum[bin].y;
      power += re * re + im * im;
    }
    if (power > 1e-8) columnsWithSignal++;
  }
  return columnsWithSignal;
}
