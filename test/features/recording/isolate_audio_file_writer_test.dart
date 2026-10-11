// =============================================================================
// Isolate Audio File Writer Tests
// =============================================================================
// The worker-hosted writer must produce byte-for-byte the file the in-process
// encoder writes, report the same sample count, and fail loudly rather than
// silently when the worker cannot write.
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:birdnet_live/features/recording/flac_encoder.dart';
import 'package:birdnet_live/features/recording/isolate_audio_file_writer.dart';
import 'package:birdnet_live/features/recording/wav_writer.dart';
import 'package:flutter_test/flutter_test.dart';

Float32List _tone(int count, {int seed = 3}) {
  final out = Float32List(count);
  var state = seed;
  for (var i = 0; i < count; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    final noise = (state / 0x7FFFFFFF) * 2 - 1;
    out[i] = 0.6 * math.sin(2 * math.pi * 440 * i / 32000) + 0.05 * noise;
  }
  return out;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('isolate_writer_test');
  });

  tearDown(() async {
    // A killed worker gives its file handle back only once the VM has torn
    // the isolate down, which can land after its exit message; on Windows
    // the delete fails until then.
    for (var attempt = 0; attempt < 40; attempt++) {
      try {
        if (tmp.existsSync()) await tmp.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  for (final format in ['flac', 'wav']) {
    test(
      '$format output matches the in-process writer byte for byte',
      () async {
        final chunks = [_tone(32000), _tone(5000, seed: 7), _tone(12345)];

        final direct = '${tmp.path}/direct.$format';
        final directWriter = format == 'flac'
            ? FlacEncoder(filePath: direct)
            : WavWriter(filePath: direct);
        await directWriter.open();
        for (final chunk in chunks) {
          await directWriter.writeSamples(chunk);
        }
        await directWriter.close();

        final proxied = '${tmp.path}/proxied.$format';
        final writer = IsolateAudioFileWriter(
          filePath: proxied,
          format: format,
        );
        expect(writer.isOpen, isFalse);
        await writer.open();
        expect(writer.isOpen, isTrue);
        for (final chunk in chunks) {
          await writer.writeSamples(chunk);
        }
        await writer.close();
        expect(writer.isOpen, isFalse);

        expect(File(proxied).readAsBytesSync(), File(direct).readAsBytesSync());
        expect(writer.samplesWritten, 32000 + 5000 + 12345);
      },
    );
  }

  test('writing before open or after close throws', () async {
    final writer = IsolateAudioFileWriter(
      filePath: '${tmp.path}/x.wav',
      format: 'wav',
    );
    expect(() => writer.writeSamples(_tone(10)), throwsStateError);
    await writer.open();
    await writer.close();
    expect(() => writer.writeSamples(_tone(10)), throwsStateError);
    // A second close is a no-op.
    await writer.close();
  });

  test('an unwritable path fails open instead of hanging', () async {
    final blocker = File('${tmp.path}/blocker')..writeAsStringSync('x');
    final writer = IsolateAudioFileWriter(
      filePath: '${blocker.path}/inside/x.flac',
      format: 'flac',
    );
    await expectLater(writer.open(), throwsA(isA<AudioWriterException>()));
    expect(writer.isOpen, isFalse);
  });

  test(
    'a worker that dies closes the writer instead of failing every write',
    () async {
      final path = '${tmp.path}/dead.wav';
      final writer = IsolateAudioFileWriter(filePath: path, format: 'wav');
      await writer.open();
      await writer.writeSamples(_tone(1000));

      writer.killWorkerForTesting();
      // The exit reaches the writer as a message, not synchronously.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (writer.isOpen && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(writer.isOpen, isFalse);
      expect(writer.failure, isNotNull);
      expect(
        () => writer.writeSamples(_tone(10)),
        throwsA(isA<AudioWriterException>()),
      );
      // The recording service's final close must not fail on top of it.
      await writer.close();
      expect(writer.samplesWritten, 1000);
    },
  );

  test('an empty recording closes with zero samples', () async {
    final path = '${tmp.path}/empty.flac';
    final writer = IsolateAudioFileWriter(filePath: path, format: 'flac');
    await writer.open();
    await writer.close();
    expect(writer.samplesWritten, 0);
    expect(File(path).existsSync(), isTrue);
  });
}
