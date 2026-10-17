// =============================================================================
// Large FLAC Decoder Regression Tests
// =============================================================================
//
// Uses an optional real-world hour-long FLAC fixture under dev/ to catch
// frame layouts that our app-generated FLAC fixtures do not exercise.
// The test is skipped automatically when the large fixture is not present.
// =============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/recording/audio_decoder.dart';

void main() {
  const fixturePath = 'dev/SSW_020_20170304_070004Z.flac';
  final fixture = File(fixturePath);

  group('large real-world FLAC fixture', () {
    test(
      'inspects metadata and decodes an analysis-sized range',
      () async {
        final metadata = await AudioDecoder.inspectFile(fixture.path);

        expect(metadata.format, 'FLAC');
        expect(metadata.sampleRate, 32000);
        expect(metadata.totalSamples, 115200000);
        expect(metadata.duration, const Duration(hours: 1));

        final chunk = await AudioDecoder.decodeRange(
          fixture.path,
          startSample: 0,
          count: 32000 * 3,
        );

        expect(chunk.sampleRate, 32000);
        expect(chunk.totalSamples, 32000 * 3);

        final starts = <int>[];
        await AudioDecoder.decodeFlacWindows(
          fixture.path,
          windowSamples: 32000 * 3,
          stepSamples: 32000 * 3,
          maxWindows: 3,
          onWindow: (windowIndex, startSample, window) async {
            starts.add(startSample);
            expect(windowIndex, starts.length - 1);
            expect(window.sampleRate, 32000);
            expect(window.totalSamples, 32000 * 3);
            return true;
          },
        );

        expect(starts, [0, 32000 * 3, 32000 * 6]);
      },
      skip: fixture.existsSync()
          ? false
          : 'Optional large FLAC fixture not found at $fixturePath',
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
