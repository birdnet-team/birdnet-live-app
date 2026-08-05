// =============================================================================
// FLAC Seek Index Tests
// =============================================================================
//
// [FlacSeekIndex] exists because FLAC has no random access and our encoder
// writes no SEEKTABLE, which made `decodeFlacRange` cost O(offset) — the
// reason scrubbing a long session review used to crawl. These tests pin both
// halves of that contract:
//
//   • Correctness — a seeked read must return exactly what an unseeked read
//     returns, at every offset and stride, including the awkward cases
//     (target inside the first frame, ranges spanning the tail, an index
//     built with a stride that never aligns to a frame boundary).
//
//   • Complexity — a read near the end of a file must not scale with the
//     offset. That is the whole point, and it regresses silently (correct
//     output, terrible latency), so it needs an explicit guard.
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/recording/audio_decoder.dart';
import 'package:birdnet_live/features/recording/flac_encoder.dart';
import 'package:birdnet_live/features/recording/wav_writer.dart';

const int _sr = 32000;

/// Deterministic pseudo-audio with enough entropy that FLAC actually has to
/// Rice-code residuals — a pure tone compresses into frame layouts that hide
/// scanner bugs.
Float32List _testSignal(int sampleCount, {int seed = 1}) {
  final samples = Float32List(sampleCount);
  var state = seed;
  for (var i = 0; i < sampleCount; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    final noise = (state / 0x7FFFFFFF) * 2 - 1;
    samples[i] = 0.4 * ((i % 512) / 256.0 - 1.0) + 0.25 * noise;
  }
  return samples;
}

void main() {
  group('FlacSeekIndex', () {
    late Directory dir;
    late String flacPath;
    late DecodedAudio full;

    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('flac_seek_');
      flacPath = '${dir.path}${Platform.pathSeparator}seek.flac';
      // 60 s: long enough for many frames and a measurable walk, short
      // enough to encode once per run.
      await FlacEncoder.writeFile(
        filePath: flacPath,
        samples: _testSignal(_sr * 60),
        sampleRate: _sr,
      );
      full = await AudioDecoder.decodeFile(flacPath);
    });

    tearDownAll(() async {
      await dir.delete(recursive: true);
    });

    test('indexes the stream and counts every sample', () async {
      final index = await AudioDecoder.buildFlacSeekIndex(flacPath);

      expect(index.isEmpty, isFalse);
      expect(index.totalSamples, full.totalSamples);
      expect(index.sampleOffsets.length, index.byteOffsets.length);

      // Entries must be strictly ascending in both dimensions, otherwise the
      // binary search in seekPointFor is meaningless.
      for (var i = 1; i < index.entryCount; i++) {
        expect(index.sampleOffsets[i], greaterThan(index.sampleOffsets[i - 1]));
        expect(index.byteOffsets[i], greaterThan(index.byteOffsets[i - 1]));
      }
      // First entry is the first frame of the stream.
      expect(index.sampleOffsets[0], 0);
    });

    test('every indexed byte offset is a real frame start', () async {
      // Decoding a range that begins exactly at an indexed sample must line up
      // with the full decode. If an offset pointed into the middle of a frame
      // (a false-positive sync the CRC check should have rejected) the samples
      // would be garbage rather than merely shifted.
      final index = await AudioDecoder.buildFlacSeekIndex(
        flacPath,
        sampleStride: _sr * 2,
      );

      for (var i = 0; i < index.entryCount; i++) {
        final start = index.sampleOffsets[i];
        final count = 1000;
        if (start + count > full.totalSamples) break;
        final ranged = await AudioDecoder.decodeFlacRange(
          flacPath,
          startSample: start,
          count: count,
          seekIndex: index,
        );
        expect(
          ranged.samples,
          full.samples.sublist(start, start + count),
          reason: 'index entry $i (sample $start) decoded wrong',
        );
      }
    });

    test('seeked reads match unseeked reads at every offset', () async {
      final index = await AudioDecoder.buildFlacSeekIndex(flacPath);

      // Deliberately unaligned starts and lengths, spread across the file.
      const starts = [0, 1, 4095, 4096, 4097, 100000, 999999, 1500000];
      const counts = [1, 999, 4096, 50000];

      for (final start in starts) {
        for (final count in counts) {
          if (start >= full.totalSamples) continue;
          final seeked = await AudioDecoder.decodeFlacRange(
            flacPath,
            startSample: start,
            count: count,
            seekIndex: index,
          );
          final plain = await AudioDecoder.decodeFlacRange(
            flacPath,
            startSample: start,
            count: count,
          );
          expect(
            seeked.samples,
            plain.samples,
            reason: 'seeked read differs at start=$start count=$count',
          );
          expect(seeked.sampleRate, plain.sampleRate);
        }
      }
    });

    test('a coarse stride still lands on the right samples', () async {
      // One entry every ~7.3 s — deliberately not a multiple of the 4096-sample
      // block size, so most seeks land well before their target and the decoder
      // has to walk forward.
      final index = await AudioDecoder.buildFlacSeekIndex(
        flacPath,
        sampleStride: 234567,
      );
      expect(index.entryCount, lessThan(12));

      for (final start in [50000, 234566, 234567, 700000, 1700000]) {
        final seeked = await AudioDecoder.decodeFlacRange(
          flacPath,
          startSample: start,
          count: 8000,
          seekIndex: index,
        );
        expect(seeked.samples, full.samples.sublist(start, start + 8000));
      }
    });

    test('a range running past the end is truncated, not zero-padded', () async {
      final index = await AudioDecoder.buildFlacSeekIndex(flacPath);
      final start = full.totalSamples - 1000;

      final seeked = await AudioDecoder.decodeFlacRange(
        flacPath,
        startSample: start,
        count: 50000,
        seekIndex: index,
      );

      expect(seeked.totalSamples, 1000);
      expect(seeked.samples, full.samples.sublist(start));
    });

    test('a start beyond the end yields nothing', () async {
      final index = await AudioDecoder.buildFlacSeekIndex(flacPath);
      final seeked = await AudioDecoder.decodeFlacRange(
        flacPath,
        startSample: full.totalSamples + 10000,
        count: 4096,
        seekIndex: index,
      );
      expect(seeked.totalSamples, 0);
    });

    test('decodeRange forwards the index for FLAC', () async {
      final index = await AudioDecoder.buildFlacSeekIndex(flacPath);
      final viaDecodeRange = await AudioDecoder.decodeRange(
        flacPath,
        startSample: 1200000,
        count: 20000,
        seekIndex: index,
      );
      expect(
        viaDecodeRange.samples,
        full.samples.sublist(1200000, 1200000 + 20000),
      );
    });

    test('seekPointFor picks the last entry at or before the target', () async {
      final index = await AudioDecoder.buildFlacSeekIndex(
        flacPath,
        sampleStride: _sr * 5,
      );

      // Before the first entry there is nothing to seek to.
      expect(index.seekPointFor(-1), isNull);

      for (var i = 0; i < index.entryCount; i++) {
        final at = index.sampleOffsets[i];
        expect(index.seekPointFor(at)!.sampleOffset, at);
        if (i + 1 < index.entryCount) {
          // Anything short of the next entry resolves back to this one.
          final justBeforeNext = index.sampleOffsets[i + 1] - 1;
          expect(index.seekPointFor(justBeforeNext)!.sampleOffset, at);
        }
      }
      // Past the last entry, clamp to the last entry.
      final last = index.sampleOffsets[index.entryCount - 1];
      expect(index.seekPointFor(last + 10_000_000)!.sampleOffset, last);
    });

    test('decodeFlacFrames can start mid-stream', () async {
      final index = await AudioDecoder.buildFlacSeekIndex(flacPath);
      const from = 1_000_000;

      final seen = <int, Int16List>{};
      await AudioDecoder.decodeFlacFrames(
        flacPath,
        seekIndex: index,
        fromSample: from,
        onFrame: (startSample, samples) async {
          seen[startSample] = samples;
          return startSample < from + 200000;
        },
      );

      expect(seen, isNotEmpty);
      // Frames are reported at absolute positions, and the walk starts at the
      // indexed frame at or before the requested sample — never after it, or
      // the caller would silently lose the head of its range.
      final firstReported = seen.keys.reduce(math.min);
      expect(firstReported, lessThanOrEqualTo(from));
      expect(firstReported, index.seekPointFor(from)!.sampleOffset);

      // Every reported frame must carry the samples the full decode has at
      // that position.
      for (final entry in seen.entries) {
        final start = entry.key;
        final samples = entry.value;
        final end = math.min(start + samples.length, full.totalSamples);
        expect(
          samples.sublist(0, end - start),
          full.samples.sublist(start, end),
          reason: 'frame at $start',
        );
      }
    });

    test('decodeFlacFrames without an index still starts at zero', () async {
      var firstReported = -1;
      await AudioDecoder.decodeFlacFrames(
        flacPath,
        fromSample: 1_000_000,
        onFrame: (startSample, samples) async {
          firstReported = startSample;
          return false;
        },
      );
      // fromSample is only a hint for the index; with no index the walk is
      // unchanged, so existing callers that skip frames themselves are safe.
      expect(firstReported, 0);
    });

    test('an empty index decodes from the start, unchanged', () async {
      final seeked = await AudioDecoder.decodeFlacRange(
        flacPath,
        startSample: 500000,
        count: 4096,
        seekIndex: FlacSeekIndex.empty,
      );
      expect(seeked.samples, full.samples.sublist(500000, 500000 + 4096));
    });

    test('a non-FLAC file yields an empty index instead of throwing', () async {
      final wavPath = '${dir.path}${Platform.pathSeparator}not.wav';
      await WavWriter.writeFile(
        filePath: wavPath,
        samples: _testSignal(1000),
        sampleRate: _sr,
      );
      final index = await AudioDecoder.buildFlacSeekIndex(wavPath);
      expect(index.isEmpty, isTrue);
      expect(index.seekPointFor(0), isNull);
    });

    test('a missing file yields an empty index instead of throwing', () async {
      final index = await AudioDecoder.buildFlacSeekIndex(
        '${dir.path}${Platform.pathSeparator}nope.flac',
      );
      expect(index.isEmpty, isTrue);
    });

    // The regression that matters: without an index, a read near the end of
    // the file re-decodes everything before it. This asserts the shape of the
    // cost curve rather than an absolute time, so it holds on slow CI too.
    test('seeking removes the O(offset) cost of a late read', () async {
      final index = await AudioDecoder.buildFlacSeekIndex(flacPath);
      const count = 4096;
      final lateStart = full.totalSamples - count - 1;

      Future<int> timeUs(Future<void> Function() body) async {
        final sw = Stopwatch()..start();
        await body();
        return sw.elapsedMicroseconds;
      }

      // Warm the file cache so the comparison is CPU, not first-read I/O.
      await AudioDecoder.decodeFlacRange(
        flacPath,
        startSample: 0,
        count: count,
        seekIndex: index,
      );

      final earlySeeked = await timeUs(
        () => AudioDecoder.decodeFlacRange(
          flacPath,
          startSample: 0,
          count: count,
          seekIndex: index,
        ),
      );
      final lateSeeked = await timeUs(
        () => AudioDecoder.decodeFlacRange(
          flacPath,
          startSample: lateStart,
          count: count,
          seekIndex: index,
        ),
      );
      final lateUnseeked = await timeUs(
        () => AudioDecoder.decodeFlacRange(
          flacPath,
          startSample: lateStart,
          count: count,
        ),
      );

      // A seeked late read costs about what a seeked early read costs: both
      // decode a couple of frames. Allow generous slack for timer noise on a
      // loaded machine — the unseeked case is an order of magnitude away.
      expect(
        lateSeeked,
        lessThan(earlySeeked * 10 + 20000),
        reason:
            'late seeked read ($lateSeeked us) should cost about what an '
            'early one does ($earlySeeked us)',
      );
      expect(
        lateSeeked * 5,
        lessThan(lateUnseeked),
        reason:
            'seeking should be far cheaper than walking the stream '
            '(seeked $lateSeeked us vs unseeked $lateUnseeked us)',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  // Our own encoder emits one fixed frame layout. A file from a different
  // encoder exercises different block sizes, coded-number widths and metadata
  // blocks — exactly where a hand-rolled frame scanner goes wrong.
  group('FlacSeekIndex on a foreign-encoder fixture', () {
    const fixturePath = 'dev/SSW_020_20170304_070004Z.flac';
    final fixture = File(fixturePath);

    test(
      'seeked reads match unseeked reads in an hour-long file',
      () async {
        final index = await AudioDecoder.buildFlacSeekIndex(fixture.path);
        final metadata = await AudioDecoder.inspectFile(fixture.path);

        expect(index.isEmpty, isFalse);
        expect(index.totalSamples, metadata.totalSamples);

        // Half an hour in — the offset where the unseeked path was spending
        // tens of seconds per spectrogram tile.
        for (final startSec in [0, 600, 1800, 3500]) {
          final start = startSec * metadata.sampleRate;
          final seeked = await AudioDecoder.decodeFlacRange(
            fixture.path,
            startSample: start,
            count: 32000,
            seekIndex: index,
          );
          final plain = await AudioDecoder.decodeFlacRange(
            fixture.path,
            startSample: start,
            count: 32000,
          );
          expect(
            seeked.samples,
            plain.samples,
            reason: 'mismatch at ${startSec}s',
          );
          expect(seeked.totalSamples, 32000);
        }
      },
      skip:
          fixture.existsSync()
              ? false
              : 'Optional large FLAC fixture not found at $fixturePath',
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}
