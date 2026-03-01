// =============================================================================
// WAV Writer Tests
// =============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/recording/wav_writer.dart';

void main() {
  // ── toBytes (in-memory) ────────────────────────────────────────────────

  group('WavWriter.toBytes', () {
    test('produces valid 44-byte header', () {
      final samples = Float32List.fromList([0.0, 0.0]);
      final bytes = WavWriter.toBytes(samples: samples);

      // Minimum size: 44 header + 4 data bytes (2 samples × 2 bytes).
      expect(bytes.length, 48);
    });

    test('starts with RIFF magic', () {
      final bytes = WavWriter.toBytes(
        samples: Float32List.fromList([0.0]),
      );

      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    });

    test('contains WAVE format', () {
      final bytes = WavWriter.toBytes(
        samples: Float32List.fromList([0.0]),
      );

      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    });

    test('fmt chunk is correct', () {
      final bytes = WavWriter.toBytes(
        samples: Float32List.fromList([0.0]),
        sampleRate: 32000,
        channels: 1,
      );
      final view = ByteData.view(bytes.buffer);

      // fmt sub-chunk size
      expect(view.getUint32(16, Endian.little), 16);
      // PCM format
      expect(view.getUint16(20, Endian.little), 1);
      // Channels
      expect(view.getUint16(22, Endian.little), 1);
      // Sample rate
      expect(view.getUint32(24, Endian.little), 32000);
      // Byte rate (32000 × 1 × 2)
      expect(view.getUint32(28, Endian.little), 64000);
      // Block align (1 × 2)
      expect(view.getUint16(32, Endian.little), 2);
      // Bits per sample
      expect(view.getUint16(34, Endian.little), 16);
    });

    test('data chunk header is correct', () {
      final samples = Float32List.fromList([0.5, -0.5, 1.0]);
      final bytes = WavWriter.toBytes(samples: samples);
      final view = ByteData.view(bytes.buffer);

      // "data"
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
      // Data size = 3 samples × 2 bytes
      expect(view.getUint32(40, Endian.little), 6);
    });

    test('file size in header is correct', () {
      final samples = Float32List.fromList([0.5, -0.5]);
      final bytes = WavWriter.toBytes(samples: samples);
      final view = ByteData.view(bytes.buffer);

      // RIFF size = file size - 8 = (44 + 4) - 8 = 40
      expect(view.getUint32(4, Endian.little), 40);
    });

    test('PCM data is correctly encoded', () {
      // silence → 0
      final silence = WavWriter.toBytes(
        samples: Float32List.fromList([0.0]),
      );
      final silenceView = ByteData.view(silence.buffer);
      expect(silenceView.getInt16(44, Endian.little), 0);

      // max positive → ~32767
      final maxPos = WavWriter.toBytes(
        samples: Float32List.fromList([1.0]),
      );
      final maxPosView = ByteData.view(maxPos.buffer);
      expect(maxPosView.getInt16(44, Endian.little), 32767);

      // max negative → ~-32767
      final maxNeg = WavWriter.toBytes(
        samples: Float32List.fromList([-1.0]),
      );
      final maxNegView = ByteData.view(maxNeg.buffer);
      expect(maxNegView.getInt16(44, Endian.little), -32767);
    });

    test('clamps values beyond [-1, 1]', () {
      final bytes = WavWriter.toBytes(
        samples: Float32List.fromList([2.0, -3.0]),
      );
      final view = ByteData.view(bytes.buffer);

      expect(view.getInt16(44, Endian.little), 32767);
      expect(view.getInt16(46, Endian.little), -32767);
    });

    test('empty samples produces header-only WAV', () {
      final bytes = WavWriter.toBytes(
        samples: Float32List(0),
      );

      expect(bytes.length, 44);
      final view = ByteData.view(bytes.buffer);
      expect(view.getUint32(40, Endian.little), 0); // data size = 0
    });

    test('stereo samples double the data size', () {
      final bytes = WavWriter.toBytes(
        samples: Float32List.fromList([0.5, -0.5]),
        channels: 2,
      );
      final view = ByteData.view(bytes.buffer);

      // Channels
      expect(view.getUint16(22, Endian.little), 2);
      // Data still 4 bytes (2 samples × 2 bytes), but block align = 4
      expect(view.getUint16(32, Endian.little), 4);
    });

    test('custom sample rate is encoded', () {
      final bytes = WavWriter.toBytes(
        samples: Float32List.fromList([0.0]),
        sampleRate: 44100,
      );
      final view = ByteData.view(bytes.buffer);

      expect(view.getUint32(24, Endian.little), 44100);
    });
  });

  // ── writeFile (filesystem) ─────────────────────────────────────────────

  group('WavWriter.writeFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wav_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes a valid WAV file', () async {
      final filePath = '${tempDir.path}/test.wav';
      final samples = Float32List.fromList([0.5, -0.5, 0.0, 1.0]);

      await WavWriter.writeFile(
        filePath: filePath,
        samples: samples,
        sampleRate: 32000,
      );

      final file = File(filePath);
      expect(await file.exists(), isTrue);

      final bytes = await file.readAsBytes();
      expect(bytes.length, 52); // 44 header + 8 data bytes

      // Verify RIFF header.
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    });

    test('creates parent directories', () async {
      final filePath = '${tempDir.path}/nested/dir/test.wav';
      final samples = Float32List.fromList([0.0]);

      await WavWriter.writeFile(filePath: filePath, samples: samples);

      expect(await File(filePath).exists(), isTrue);
    });
  });

  // ── Streaming writer ───────────────────────────────────────────────────

  group('WavWriter (streaming)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wav_stream_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('open + writeSamples + close produces valid WAV', () async {
      final filePath = '${tempDir.path}/stream.wav';
      final writer = WavWriter(filePath: filePath, sampleRate: 32000);

      await writer.open();
      expect(writer.isOpen, isTrue);
      expect(writer.samplesWritten, 0);

      await writer.writeSamples(Float32List.fromList([0.5, -0.5]));
      expect(writer.samplesWritten, 2);

      await writer.writeSamples(Float32List.fromList([1.0, -1.0]));
      expect(writer.samplesWritten, 4);

      await writer.close();
      expect(writer.isOpen, isFalse);

      // Verify the file.
      final bytes = await File(filePath).readAsBytes();
      expect(bytes.length, 52); // 44 header + 8 data bytes

      final view = ByteData.view(Uint8List.fromList(bytes).buffer);
      // Data size in header should be correct.
      expect(view.getUint32(40, Endian.little), 8);
      // RIFF size should be correct.
      expect(view.getUint32(4, Endian.little), 44);
    });

    test('duration calculates correctly', () async {
      final filePath = '${tempDir.path}/dur.wav';
      final writer = WavWriter(filePath: filePath, sampleRate: 32000);

      await writer.open();
      // Write 32000 samples = 1 second at 32kHz
      await writer.writeSamples(Float32List(32000));

      expect(writer.duration.inSeconds, 1);

      await writer.close();
    });

    test('writeSamples throws when not open', () async {
      final writer = WavWriter(filePath: 'unused');

      expect(
        () => writer.writeSamples(Float32List(1)),
        throwsA(isA<StateError>()),
      );
    });

    test('close is idempotent', () async {
      final filePath = '${tempDir.path}/close.wav';
      final writer = WavWriter(filePath: filePath, sampleRate: 32000);

      await writer.open();
      await writer.close();
      // Second close should not throw.
      await writer.close();
    });
  });
}
