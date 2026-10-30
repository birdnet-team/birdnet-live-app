// =============================================================================
// Audio Export Normalizer Tests
// =============================================================================
// The streaming normalizer must produce exactly the file the previous
// whole-file implementation did: decode everything, scan the peak, scale,
// re-encode. That reference is reproduced here from the same public helpers.
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:birdnet_live/features/history/services/audio_export_normalizer.dart';
import 'package:birdnet_live/features/recording/audio_decoder.dart';
import 'package:birdnet_live/features/recording/flac_encoder.dart';
import 'package:birdnet_live/features/recording/wav_writer.dart';
import 'package:flutter_test/flutter_test.dart';

const int _rate = 32000;

/// A quiet, varied signal: a slow chirp at a fraction of full scale, long
/// enough to span several FLAC blocks and more than one WAV chunk boundary
/// would need at a small chunk size.
Float32List _quietSignal(int count, {double amplitude = 0.2}) {
  final out = Float32List(count);
  for (var i = 0; i < count; i++) {
    final t = i / _rate;
    out[i] = amplitude * math.sin(2 * math.pi * (300 + 2000 * (t % 1)) * t);
  }
  return out;
}

/// The previous implementation, kept as the reference.
Future<void> _referenceNormalize(String source, String dest, String ext) async {
  final decoded = await AudioDecoder.decodeFile(source);
  final peak = AudioExportNormalizer.computePeak(decoded.samples);
  if (peak == 0.0 || peak >= AudioExportNormalizer.quietThreshold) {
    await File(source).copy(dest);
    return;
  }
  final normalized = AudioExportNormalizer.normalizedFloat32(
    decoded.samples,
    peak,
  );
  if (ext == '.flac') {
    await FlacEncoder.writeFile(
      filePath: dest,
      samples: normalized,
      sampleRate: decoded.sampleRate,
    );
  } else {
    await WavWriter.writeFile(
      filePath: dest,
      samples: normalized,
      sampleRate: decoded.sampleRate,
    );
  }
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('normalizer_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  for (final ext in ['.wav', '.flac']) {
    test('a quiet $ext file is boosted exactly like the reference', () async {
      final source = '${tmp.path}/quiet$ext';
      final signal = _quietSignal(_rate * 5);
      if (ext == '.flac') {
        await FlacEncoder.writeFile(filePath: source, samples: signal);
      } else {
        await WavWriter.writeFile(filePath: source, samples: signal);
      }
      final reference = '${tmp.path}/reference$ext';
      await _referenceNormalize(source, reference, ext);

      await AudioExportNormalizer.normalizeFileInPlace(File(source), ext);

      expect(File(source).readAsBytesSync(), File(reference).readAsBytesSync());
      final boosted = await AudioDecoder.decodeFile(source);
      expect(
        AudioExportNormalizer.computePeak(boosted.samples),
        closeTo(AudioExportNormalizer.targetPeak, 0.001),
      );
      expect(File('$source.normalizing.tmp').existsSync(), isFalse);
    });

    test('a loud $ext file is left untouched', () async {
      final source = '${tmp.path}/loud$ext';
      final signal = _quietSignal(_rate * 2, amplitude: 0.8);
      if (ext == '.flac') {
        await FlacEncoder.writeFile(filePath: source, samples: signal);
      } else {
        await WavWriter.writeFile(filePath: source, samples: signal);
      }
      final before = File(source).readAsBytesSync();

      await AudioExportNormalizer.normalizeFileInPlace(File(source), ext);

      expect(File(source).readAsBytesSync(), before);
    });
  }

  test('silence is left untouched', () async {
    final source = '${tmp.path}/silent.wav';
    await WavWriter.writeFile(filePath: source, samples: Float32List(_rate));
    final before = File(source).readAsBytesSync();

    await AudioExportNormalizer.normalizeFileInPlace(File(source), '.wav');

    expect(File(source).readAsBytesSync(), before);
  });

  test('other containers and missing files are ignored', () async {
    final source = '${tmp.path}/clip.mp3';
    File(source).writeAsBytesSync([1, 2, 3, 4]);

    await AudioExportNormalizer.normalizeFileInPlace(File(source), '.mp3');
    await AudioExportNormalizer.normalizeFileInPlace(
      File('${tmp.path}/missing.wav'),
      '.wav',
    );

    expect(File(source).readAsBytesSync(), [1, 2, 3, 4]);
  });
}
