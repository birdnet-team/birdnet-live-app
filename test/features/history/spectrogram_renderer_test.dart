// =============================================================================
// Spectrogram Renderer Tests
// =============================================================================
//
// The renderer resamples per column rather than resampling the tile up front,
// which is what makes a wide-zoom tile cost the same as a narrow one. These
// pin the two things that optimization could quietly break: the image must
// stay the same as the resample-first version produced, and the geometry must
// stay tied to the *target* sample rate so tiles from sources at different
// rates line up on the same timeline.
// =============================================================================

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/history/services/spectrogram_renderer.dart';
import 'package:birdnet_live/features/recording/audio_decoder.dart';
import 'package:birdnet_live/features/spectrogram/color_maps.dart';

const int _targetRate = 32000;
const int _fftSize = 2048;

/// A chirp plus noise: broadband enough that every rendered bin carries
/// signal, so a regression shows up rather than hiding in silence.
DecodedAudio _signal({
  required int sampleCount,
  required int sampleRate,
  int seed = 11,
}) {
  final samples = Int16List(sampleCount);
  var state = seed;
  for (var i = 0; i < sampleCount; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    final noise = (state / 0x7FFFFFFF) * 2 - 1;
    final t = i / sampleRate;
    final sweep = math.sin(2 * math.pi * (500 + 3000 * (t % 1.0)) * t);
    samples[i] = ((0.5 * sweep + 0.2 * noise) * 20000).round().clamp(
      -32768,
      32767,
    );
  }
  return DecodedAudio(samples: samples, sampleRate: sampleRate);
}

/// The previous implementation: resample the whole tile, then transform.
/// Kept here as the reference the optimized path must reproduce.
SpectrogramPixels? _referenceRender(
  DecodedAudio audio, {
  required int targetSampleRate,
  required int fftSize,
  required int hop,
  required int maxDisplayBins,
  required String colorMapName,
}) {
  final resampled = audio.resampleTo(targetSampleRate);
  if (resampled.totalSamples < fftSize) return null;
  final numCols = (resampled.totalSamples - fftSize) ~/ hop + 1;
  if (numCols <= 0) return null;

  final nyquist = resampled.sampleRate / 2;
  final binCount = fftSize ~/ 2 + 1;
  final visibleBins = (kSpectrogramMaxFreqHz / nyquist * binCount)
      .round()
      .clamp(1, binCount);
  final binStride = math.max(1, (visibleBins / maxDisplayBins).ceil());
  final displayBins = (visibleBins / binStride).ceil();
  final lut = SpectrogramColorMap.lut(colorMapName);
  final pixels = Uint8List(numCols * displayBins * 4);

  final hann = Float64List(fftSize);
  final hannFactor = 2.0 * math.pi / fftSize;
  for (var i = 0; i < fftSize; i++) {
    hann[i] = 0.5 * (1.0 - math.cos(hannFactor * i));
  }

  for (var c = 0; c < numCols; c++) {
    final chunk = resampled.readFloat32(c * hop, fftSize);
    final input = Float64List(fftSize);
    for (var i = 0; i < fftSize; i++) {
      input[i] = chunk[i] * hann[i];
    }
    final spectrum = _referenceFft(input);
    for (var row = 0; row < displayBins; row++) {
      final binStart = row * binStride;
      final binEnd = math.min(binStart + binStride, visibleBins);
      var power = 0.0;
      for (var bin = binStart; bin < binEnd; bin++) {
        final re = spectrum[bin * 2];
        final im = spectrum[bin * 2 + 1];
        power += re * re + im * im;
      }
      power /= (binEnd - binStart);
      final db = 10 * math.log(power + 1e-10) / math.ln10;
      final norm = ((db - kSpectrogramDbFloor) /
              (kSpectrogramDbCeiling - kSpectrogramDbFloor))
          .clamp(0.0, 1.0);
      final y = displayBins - 1 - row;
      final offset = (y * numCols + c) * 4;
      final color = lut[(norm * 255).round().clamp(0, 255)];
      pixels[offset] = (color >> 16) & 0xFF;
      pixels[offset + 1] = (color >> 8) & 0xFF;
      pixels[offset + 2] = color & 0xFF;
      pixels[offset + 3] = (color >> 24) & 0xFF;
    }
  }
  return SpectrogramPixels(pixels: pixels, width: numCols, height: displayBins);
}

/// Textbook radix-2 DFT, independent of the production FFT package, so the
/// reference does not share a possible bug with the code under test.
Float64List _referenceFft(Float64List reals) {
  final n = reals.length;
  final out = Float64List(n * 2);
  for (var i = 0; i < n; i++) {
    out[i * 2] = reals[i];
  }
  // Iterative Cooley-Tukey.
  var j = 0;
  for (var i = 1; i < n; i++) {
    var bit = n >> 1;
    while (j & bit != 0) {
      j ^= bit;
      bit >>= 1;
    }
    j ^= bit;
    if (i < j) {
      for (var k = 0; k < 2; k++) {
        final tmp = out[i * 2 + k];
        out[i * 2 + k] = out[j * 2 + k];
        out[j * 2 + k] = tmp;
      }
    }
  }
  for (var len = 2; len <= n; len <<= 1) {
    final ang = -2 * math.pi / len;
    for (var i = 0; i < n; i += len) {
      for (var k = 0; k < len ~/ 2; k++) {
        final wr = math.cos(ang * k);
        final wi = math.sin(ang * k);
        final ur = out[(i + k) * 2];
        final ui = out[(i + k) * 2 + 1];
        final vr0 = out[(i + k + len ~/ 2) * 2];
        final vi0 = out[(i + k + len ~/ 2) * 2 + 1];
        final vr = vr0 * wr - vi0 * wi;
        final vi = vr0 * wi + vi0 * wr;
        out[(i + k) * 2] = ur + vr;
        out[(i + k) * 2 + 1] = ui + vi;
        out[(i + k + len ~/ 2) * 2] = ur - vr;
        out[(i + k + len ~/ 2) * 2 + 1] = ui - vi;
      }
    }
  }
  return out;
}

void main() {
  group('renderSpectrogram', () {
    test('matches the resample-first reference at the model rate', () {
      final audio = _signal(
        sampleCount: _targetRate * 8,
        sampleRate: _targetRate,
      );

      final actual =
          renderSpectrogram(
            audio,
            targetSampleRate: _targetRate,
            fftSize: _fftSize,
            hop: 1024,
            maxDisplayBins: 512,
            colorMapName: 'viridis',
          )!;
      final expected =
          _referenceRender(
            audio,
            targetSampleRate: _targetRate,
            fftSize: _fftSize,
            hop: 1024,
            maxDisplayBins: 512,
            colorMapName: 'viridis',
          )!;

      expect(actual.width, expected.width);
      expect(actual.height, expected.height);
      _expectPixelsClose(actual, expected, tolerance: 1);
    });

    // The case the optimization exists for: a hop far wider than the window,
    // where resampling up front would touch eight times more audio than the
    // transform reads.
    test('matches the reference at the widest zoom', () {
      final audio = _signal(
        sampleCount: _targetRate * 120,
        sampleRate: _targetRate,
      );

      final actual =
          renderSpectrogram(
            audio,
            targetSampleRate: _targetRate,
            fftSize: _fftSize,
            hop: 16384,
            maxDisplayBins: 128,
            colorMapName: 'viridis',
          )!;
      final expected =
          _referenceRender(
            audio,
            targetSampleRate: _targetRate,
            fftSize: _fftSize,
            hop: 16384,
            maxDisplayBins: 128,
            colorMapName: 'viridis',
          )!;

      expect(actual.width, expected.width);
      expect(actual.height, expected.height);
      _expectPixelsClose(actual, expected, tolerance: 1);
    });

    test('matches the reference when the source needs resampling', () {
      // An imported 44.1 kHz file — where skipping the up-front resample
      // could most easily shift the time axis.
      final audio = _signal(sampleCount: 44100 * 10, sampleRate: 44100);

      final actual =
          renderSpectrogram(
            audio,
            targetSampleRate: _targetRate,
            fftSize: _fftSize,
            hop: 4096,
            maxDisplayBins: 256,
            colorMapName: 'viridis',
          )!;
      final expected =
          _referenceRender(
            audio,
            targetSampleRate: _targetRate,
            fftSize: _fftSize,
            hop: 4096,
            maxDisplayBins: 256,
            colorMapName: 'viridis',
          )!;

      expect(actual.width, expected.width);
      expect(actual.height, expected.height);
      // Interpolating in float instead of round-tripping through Int16 moves
      // a few levels; a whole color step would be a real regression.
      _expectPixelsClose(actual, expected, tolerance: 8, meanTolerance: 0.5);
    });

    test('column count follows the target grid, not the source rate', () {
      // Same duration at two source rates must yield the same tile width, or
      // tiles from a resampled source would not line up on the timeline.
      final at32k =
          renderSpectrogram(
            _signal(sampleCount: _targetRate * 20, sampleRate: _targetRate),
            targetSampleRate: _targetRate,
            fftSize: _fftSize,
            hop: 1024,
            maxDisplayBins: 256,
            colorMapName: 'viridis',
          )!;
      final at44k =
          renderSpectrogram(
            _signal(sampleCount: 44100 * 20, sampleRate: 44100),
            targetSampleRate: _targetRate,
            fftSize: _fftSize,
            hop: 1024,
            maxDisplayBins: 256,
            colorMapName: 'viridis',
          )!;

      expect(at44k.width, at32k.width);
      expect(at44k.height, at32k.height);
    });

    test('frequency axis is capped at the display ceiling', () {
      // 16 kHz of a 16 kHz nyquist is every bin; at 32 kHz nyquist it is half.
      final full =
          renderSpectrogram(
            _signal(sampleCount: _targetRate * 4, sampleRate: _targetRate),
            targetSampleRate: _targetRate,
            fftSize: _fftSize,
            hop: 1024,
            maxDisplayBins: 4096,
            colorMapName: 'viridis',
          )!;
      final halved =
          renderSpectrogram(
            _signal(sampleCount: 64000 * 4, sampleRate: 64000),
            targetSampleRate: 64000,
            fftSize: _fftSize,
            hop: 1024,
            maxDisplayBins: 4096,
            colorMapName: 'viridis',
          )!;

      expect(full.height, _fftSize ~/ 2 + 1);
      expect(halved.height, closeTo((_fftSize ~/ 2 + 1) / 2, 1));
    });

    test('audio shorter than one window renders nothing', () {
      expect(
        renderSpectrogram(
          _signal(sampleCount: _fftSize - 1, sampleRate: _targetRate),
          targetSampleRate: _targetRate,
          fftSize: _fftSize,
          hop: 1024,
          maxDisplayBins: 256,
          colorMapName: 'viridis',
        ),
        isNull,
      );
    });

    test('degenerate parameters return null instead of throwing', () {
      final audio = _signal(sampleCount: _targetRate, sampleRate: _targetRate);
      for (final args in [
        (fft: 0, hop: 1024, rate: _targetRate),
        (fft: _fftSize, hop: 0, rate: _targetRate),
        (fft: _fftSize, hop: 1024, rate: 0),
      ]) {
        expect(
          renderSpectrogram(
            audio,
            targetSampleRate: args.rate,
            fftSize: args.fft,
            hop: args.hop,
            maxDisplayBins: 256,
            colorMapName: 'viridis',
          ),
          isNull,
        );
      }
    });

    test('the buffer is fully written — no uninitialized pixels', () {
      // The renderer reuses one complex buffer across columns; a missed reset
      // would leave the previous column's tail smeared into the next.
      final result =
          renderSpectrogram(
            _signal(sampleCount: _targetRate * 6, sampleRate: _targetRate),
            targetSampleRate: _targetRate,
            fftSize: _fftSize,
            hop: 2048,
            maxDisplayBins: 128,
            colorMapName: 'viridis',
          )!;

      expect(result.pixels.length, result.width * result.height * 4);
      // Every pixel must be opaque: alpha comes from the color map, so a
      // zero alpha means a byte was never written.
      for (var i = 3; i < result.pixels.length; i += 4) {
        expect(result.pixels[i], 255, reason: 'transparent pixel at byte $i');
      }
    });
  });
}

void _expectPixelsClose(
  SpectrogramPixels actual,
  SpectrogramPixels expected, {
  required int tolerance,
  double meanTolerance = 0.05,
}) {
  expect(actual.pixels.length, expected.pixels.length);
  var maxDiff = 0;
  var sumDiff = 0;
  for (var i = 0; i < actual.pixels.length; i++) {
    final d = (actual.pixels[i] - expected.pixels[i]).abs();
    if (d > maxDiff) maxDiff = d;
    sumDiff += d;
  }
  final mean = sumDiff / actual.pixels.length;
  expect(
    maxDiff,
    lessThanOrEqualTo(tolerance),
    reason: 'max channel difference $maxDiff (mean $mean)',
  );
  expect(mean, lessThanOrEqualTo(meanTolerance), reason: 'mean difference');
}
