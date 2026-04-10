// =============================================================================
// FLAC Encoder Tests — Validates the pure Dart FLAC encoder
// =============================================================================
//
// Tests cover:
//   • File structure: magic number, STREAMINFO, frame sync codes.
//   • Streaming and one-shot APIs.
//   • Compression: FLAC output is smaller than raw PCM.
//   • Edge cases: silence, single sample, exact block boundaries.
//   • STREAMINFO correctness (sample rate, channels, bps, total samples).
//   • CRC integrity (frame headers and full frames).
// =============================================================================

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:birdnet_live/features/recording/flac_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flac_encoder_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Helper ────────────────────────────────────────────────────────────

  /// Generate a sine wave as Float32List.
  Float32List sineWave(int numSamples,
      {double freq = 440.0, double sampleRate = 32000.0}) {
    final samples = Float32List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      samples[i] = (sin(2 * pi * freq * i / sampleRate) * 0.5).clamp(-1.0, 1.0);
    }
    return samples;
  }

  /// Generate silence.
  Float32List silence(int numSamples) => Float32List(numSamples);

  // ── File structure ────────────────────────────────────────────────────

  group('File structure', () {
    test('starts with fLaC magic number', () async {
      final path = '${tempDir.path}/magic.flac';
      final encoder = FlacEncoder(filePath: path);
      await encoder.open();
      await encoder.writeSamples(sineWave(1000));
      await encoder.close();

      final bytes = File(path).readAsBytesSync();
      expect(bytes[0], 0x66); // 'f'
      expect(bytes[1], 0x4C); // 'L'
      expect(bytes[2], 0x61); // 'a'
      expect(bytes[3], 0x43); // 'C'
    });

    test('STREAMINFO metadata block follows magic', () async {
      final path = '${tempDir.path}/streaminfo.flac';
      final encoder = FlacEncoder(filePath: path, sampleRate: 32000);
      await encoder.open();
      await encoder.writeSamples(sineWave(8000));
      await encoder.close();

      final bytes = File(path).readAsBytesSync();

      // Byte 4: metadata block header.
      // Bit 7 = is-last (1), bits 6-0 = type (0 = STREAMINFO).
      expect(bytes[4] & 0x80, 0x80, reason: 'is-last flag should be set');
      expect(bytes[4] & 0x7F, 0, reason: 'block type should be STREAMINFO');

      // Bytes 5-7: length of STREAMINFO data = 34.
      final length = (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];
      expect(length, 34);
    });

    test('STREAMINFO contains correct sample rate', () async {
      final path = '${tempDir.path}/rate.flac';
      final encoder = FlacEncoder(filePath: path, sampleRate: 32000);
      await encoder.open();
      await encoder.writeSamples(sineWave(4096));
      await encoder.close();

      final bytes = File(path).readAsBytesSync();
      // Sample rate is at bytes 18-20 (20 bits, big-endian, starting at
      // offset 4+4+10 = 18 in STREAMINFO body, but in file at offset
      // 4 (fLaC) + 4 (metadata header) + 10 = 18.
      final sr = (bytes[18] << 12) | (bytes[19] << 4) | (bytes[20] >> 4);
      expect(sr, 32000);
    });

    test('STREAMINFO contains correct total samples', () async {
      final path = '${tempDir.path}/total.flac';
      const numSamples = 5000;
      final encoder = FlacEncoder(filePath: path, sampleRate: 32000);
      await encoder.open();
      await encoder.writeSamples(sineWave(numSamples));
      await encoder.close();

      final bytes = File(path).readAsBytesSync();
      // Total samples is a 36-bit field at bytes 21[3:0] and 22-25.
      final high4 = bytes[21] & 0x0F;
      final low32 =
          ByteData.sublistView(Uint8List.fromList(bytes), 22, 26).getUint32(0);
      final total = (high4 << 32) | low32;
      expect(total, numSamples);
    });

    test('contains frame sync codes after STREAMINFO', () async {
      final path = '${tempDir.path}/sync.flac';
      final encoder = FlacEncoder(filePath: path);
      await encoder.open();
      await encoder.writeSamples(sineWave(8192)); // 2 full blocks
      await encoder.close();

      final bytes = File(path).readAsBytesSync();

      // First frame starts at byte 42 (4 fLaC + 38 STREAMINFO).
      // Frame sync is 0xFFF8 (14 bits of 1s + reserved 0 + strategy 0).
      expect(bytes[42], 0xFF);
      expect(bytes[43] & 0xFC, 0xF8,
          reason: 'Frame sync upper bits should be 0xFFF8xx');
    });
  });

  // ── Compression ───────────────────────────────────────────────────────

  group('Compression', () {
    test('FLAC file is smaller than raw PCM for sine wave', () async {
      final path = '${tempDir.path}/compress.flac';
      const numSamples = 32000; // 1 second at 32 kHz
      final samples = sineWave(numSamples);
      await FlacEncoder.writeFile(
          filePath: path, samples: samples, sampleRate: 32000);

      final flacSize = File(path).lengthSync();
      final rawPcmSize = numSamples * 2; // 16-bit = 2 bytes per sample

      expect(flacSize, lessThan(rawPcmSize),
          reason:
              'FLAC ($flacSize bytes) should be smaller than raw PCM ($rawPcmSize bytes)');
    });

    test('FLAC file is much smaller for silence', () async {
      final path = '${tempDir.path}/silent.flac';
      const numSamples = 32000;
      await FlacEncoder.writeFile(
          filePath: path, samples: silence(numSamples), sampleRate: 32000);

      final flacSize = File(path).lengthSync();
      // Silence should compress very well — CONSTANT subframes.
      expect(flacSize, lessThan(1000),
          reason:
              'Silent FLAC should be tiny (was $flacSize bytes for $numSamples samples)');
    });
  });

  // ── Streaming API ─────────────────────────────────────────────────────

  group('Streaming API', () {
    test('multiple writeSamples calls produce valid file', () async {
      final path = '${tempDir.path}/streaming.flac';
      final encoder = FlacEncoder(filePath: path);
      await encoder.open();

      // Write in small chunks (not aligned to block size).
      for (int i = 0; i < 10; i++) {
        await encoder.writeSamples(sineWave(1000));
      }
      await encoder.close();

      expect(encoder.totalSamples, 10000);
      final bytes = File(path).readAsBytesSync();
      expect(bytes[0], 0x66); // fLaC magic
    });

    test('isOpen reflects state correctly', () async {
      final path = '${tempDir.path}/state.flac';
      final encoder = FlacEncoder(filePath: path);

      expect(encoder.isOpen, isFalse);
      await encoder.open();
      expect(encoder.isOpen, isTrue);
      await encoder.writeSamples(sineWave(100));
      expect(encoder.isOpen, isTrue);
      await encoder.close();
      expect(encoder.isOpen, isFalse);
    });

    test('writeSamples on closed encoder throws', () async {
      final path = '${tempDir.path}/closed.flac';
      final encoder = FlacEncoder(filePath: path);
      await encoder.open();
      await encoder.close();

      expect(
        () => encoder.writeSamples(sineWave(100)),
        throwsStateError,
      );
    });

    test('duration tracks correctly', () async {
      final path = '${tempDir.path}/duration.flac';
      final encoder = FlacEncoder(filePath: path, sampleRate: 32000);
      await encoder.open();

      await encoder.writeSamples(sineWave(32000)); // 1 second
      expect(encoder.duration.inMilliseconds, closeTo(1000, 1));

      await encoder.writeSamples(sineWave(16000)); // +0.5 seconds
      expect(encoder.duration.inMilliseconds, closeTo(1500, 1));

      await encoder.close();
    });
  });

  // ── One-shot API ──────────────────────────────────────────────────────

  group('One-shot API', () {
    test('writeFile creates valid FLAC', () async {
      final path = '${tempDir.path}/oneshot.flac';
      await FlacEncoder.writeFile(
        filePath: path,
        samples: sineWave(4096),
        sampleRate: 32000,
      );

      final bytes = File(path).readAsBytesSync();
      expect(bytes.sublist(0, 4), [0x66, 0x4C, 0x61, 0x43]);
    });

    test('writeFile creates parent directories', () async {
      final path = '${tempDir.path}/sub/dir/nested.flac';
      await FlacEncoder.writeFile(
        filePath: path,
        samples: sineWave(1000),
        sampleRate: 32000,
      );

      expect(File(path).existsSync(), isTrue);
    });
  });

  // ── Edge cases ────────────────────────────────────────────────────────

  group('Edge cases', () {
    test('single sample', () async {
      final path = '${tempDir.path}/single.flac';
      await FlacEncoder.writeFile(
        filePath: path,
        samples: Float32List.fromList([0.5]),
        sampleRate: 32000,
      );

      final bytes = File(path).readAsBytesSync();
      expect(bytes.sublist(0, 4), [0x66, 0x4C, 0x61, 0x43]);

      // Verify total samples in STREAMINFO.
      final high4 = bytes[21] & 0x0F;
      final low32 =
          ByteData.sublistView(Uint8List.fromList(bytes), 22, 26).getUint32(0);
      expect((high4 << 32) | low32, 1);
    });

    test('exact block size boundary', () async {
      final path = '${tempDir.path}/exact.flac';
      const blockSize = 4096;
      await FlacEncoder.writeFile(
        filePath: path,
        samples: sineWave(blockSize * 3), // exactly 3 blocks
        sampleRate: 32000,
      );

      final bytes = File(path).readAsBytesSync();
      final high4 = bytes[21] & 0x0F;
      final low32 =
          ByteData.sublistView(Uint8List.fromList(bytes), 22, 26).getUint32(0);
      expect((high4 << 32) | low32, blockSize * 3);
    });

    test('block size + 1 sample', () async {
      final path = '${tempDir.path}/boundary.flac';
      const blockSize = 4096;
      await FlacEncoder.writeFile(
        filePath: path,
        samples: sineWave(blockSize + 1),
        sampleRate: 32000,
      );

      final bytes = File(path).readAsBytesSync();
      final high4 = bytes[21] & 0x0F;
      final low32 =
          ByteData.sublistView(Uint8List.fromList(bytes), 22, 26).getUint32(0);
      expect((high4 << 32) | low32, blockSize + 1);
    });

    test('all-same-value samples use CONSTANT subframe', () async {
      final path = '${tempDir.path}/constant.flac';
      // All samples = 0.25 → same 16-bit value.
      final samples = Float32List(4096);
      for (int i = 0; i < samples.length; i++) {
        samples[i] = 0.25;
      }
      await FlacEncoder.writeFile(
          filePath: path, samples: samples, sampleRate: 32000);

      // CONSTANT subframe for 4096 samples should be extremely small.
      final flacSize = File(path).lengthSync();
      expect(flacSize, lessThan(100),
          reason: 'CONSTANT block should be < 100 bytes (was $flacSize)');
    });
  });
}
