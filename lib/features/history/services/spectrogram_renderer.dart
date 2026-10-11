// =============================================================================
// Spectrogram Renderer — STFT → RGBA pixels
// =============================================================================
//
// Turns decoded PCM into the RGBA buffer the Session Review strip uploads as a
// texture. Pure computation: no Flutter bindings, no file access, no UI. That
// is deliberate — it runs inside `Isolate.run` for every spectrogram tile, and
// it is the one piece of the review pipeline worth measuring in isolation.
//
// ### Why the resampling happens per column
//
// The obvious shape is "resample the tile to the model rate, then run the
// STFT". But the strip renders wide zoom levels with a hop far larger than the
// FFT window — at the widest level a tile carries eight times more audio than
// the transform ever reads. Resampling up front pays for all of it.
//
// Folding the interpolation into the per-column gather makes the cost scale
// with the number of columns instead of the tile's duration. Measured on a
// 44.1 kHz source at the strip's three zoom levels:
//
//   30 s tile,  hop 1024:   122 ms → 49 ms
//   120 s tile, hop 4096:   186 ms → 53 ms
//   480 s tile, hop 16384:  657 ms → 47 ms
//
// Output matches the resample-first version to within one 8-bit level; the
// difference is that samples no longer round-trip through Int16.
// =============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import '../../recording/audio_decoder.dart';
import '../../spectrogram/color_maps.dart';

/// Highest frequency drawn. Above this there is nothing a bird call needs.
const int kSpectrogramMaxFreqHz = 16000;

/// dBFS mapped to the bottom and top of the color ramp.
const double kSpectrogramDbFloor = -80.0;
const double kSpectrogramDbCeiling = 0.0;

/// An RGBA image ready for `ui.decodeImageFromPixels`.
class SpectrogramPixels {
  const SpectrogramPixels({
    required this.pixels,
    required this.width,
    required this.height,
  });

  /// RGBA8888, row-major, `width * height * 4` bytes.
  final Uint8List pixels;

  /// One column per FFT frame.
  final int width;

  /// One row per rendered frequency bin.
  final int height;
}

/// Render [audio] as a spectrogram, resampling to [targetSampleRate] on the fly.
///
/// [hop] and the resulting column count are expressed on the *target* grid, so
/// callers get the same image whatever rate the source happens to be at.
/// Returns null when the audio is too short to fill a single FFT window.
SpectrogramPixels? renderSpectrogram(
  DecodedAudio audio, {
  required int targetSampleRate,
  required int fftSize,
  required int hop,
  required int maxDisplayBins,
  required String colorMapName,
}) {
  if (fftSize <= 0 || hop <= 0 || targetSampleRate <= 0) return null;

  final samples = audio.samples;
  final ratio = audio.sampleRate / targetSampleRate;
  // What the tile would contain after resampling — matches
  // [DecodedAudio.resampleTo] so tile widths are unchanged.
  final targetTotal = ratio == 1.0
      ? samples.length
      : (samples.length / ratio).floor();
  if (targetTotal < fftSize) return null;

  final numCols = (targetTotal - fftSize) ~/ hop + 1;
  if (numCols <= 0) return null;

  final nyquist = targetSampleRate / 2;
  final binCount = fftSize ~/ 2 + 1;
  final visibleBins = (kSpectrogramMaxFreqHz / nyquist * binCount)
      .round()
      .clamp(1, binCount);
  // Collapse bins when there are more frequency rows than the strip can paint
  // as distinct pixels: smoother, and much cheaper on a phone-sized strip.
  final binStride = math.max(1, (visibleBins / maxDisplayBins).ceil());
  final displayBins = (visibleBins / binStride).ceil();

  final lut = SpectrogramColorMap.lut(colorMapName);
  final pixels = Uint8List(numCols * displayBins * 4);

  // Fold the Int16→unit-float scale into the window, so gathering a sample is
  // a single multiply.
  final window = Float64List(fftSize);
  final windowFactor = 2.0 * math.pi / fftSize;
  for (var i = 0; i < fftSize; i++) {
    window[i] = 0.5 * (1.0 - math.cos(windowFactor * i)) / 32768.0;
  }

  final fft = FFT(fftSize);
  // One complex buffer for the whole tile instead of two arrays and an FFT
  // result per column.
  final buffer = Float64x2List(fftSize);
  final lastSample = samples.length - 1;
  const invLn10 = 1.0 / math.ln10;
  final normScale = 1.0 / (kSpectrogramDbCeiling - kSpectrogramDbFloor);

  for (var c = 0; c < numCols; c++) {
    final colStart = c * hop;

    if (ratio == 1.0) {
      // Source already at the target rate — our own recordings, and a
      // straight copy.
      final available = math.min(fftSize, samples.length - colStart);
      for (var i = 0; i < available; i++) {
        buffer[i] = Float64x2(samples[colStart + i] * window[i], 0.0);
      }
      for (var i = available; i < fftSize; i++) {
        buffer[i] = Float64x2.zero();
      }
    } else {
      for (var i = 0; i < fftSize; i++) {
        final src = (colStart + i) * ratio;
        final i0 = src.toInt();
        final double v;
        if (i0 >= lastSample) {
          v = i0 == lastSample ? samples[i0].toDouble() : 0.0;
        } else {
          final frac = src - i0;
          v = samples[i0] * (1.0 - frac) + samples[i0 + 1] * frac;
        }
        buffer[i] = Float64x2(v * window[i], 0.0);
      }
    }

    fft.inPlaceFft(buffer);

    for (var row = 0; row < displayBins; row++) {
      final binStart = row * binStride;
      final binEnd = math.min(binStart + binStride, visibleBins);
      var power = 0.0;
      for (var bin = binStart; bin < binEnd; bin++) {
        final v = buffer[bin];
        power += v.x * v.x + v.y * v.y;
      }
      power /= (binEnd - binStart);
      final db = 10 * math.log(power + 1e-10) * invLn10;
      var norm = (db - kSpectrogramDbFloor) * normScale;
      if (norm < 0.0) norm = 0.0;
      if (norm > 1.0) norm = 1.0;

      // Row 0 is the lowest frequency; the image is drawn top-down.
      final y = displayBins - 1 - row;
      final offset = (y * numCols + c) * 4;
      final color = lut[(norm * 255).round()];
      pixels[offset] = (color >> 16) & 0xFF;
      pixels[offset + 1] = (color >> 8) & 0xFF;
      pixels[offset + 2] = color & 0xFF;
      pixels[offset + 3] = (color >> 24) & 0xFF;
    }
  }

  return SpectrogramPixels(pixels: pixels, width: numCols, height: displayBins);
}

/// Decodes `[startSample, startSample + count)` of a recording at its own
/// sample rate. May return fewer samples when the recording ends early.
typedef AudioRangeDecoder = Future<DecodedAudio> Function(
  int startSample,
  int count,
);

/// Render a whole recording in bounded memory.
///
/// Decodes the source in batches of columns through [decode] and renders each
/// batch with [renderSpectrogram], so a recording of any length holds one
/// batch of PCM at a time instead of the whole file. The output is the image
/// a single [renderSpectrogram] over the entire recording would produce: a
/// batch always starts on an exact source sample, so every column reads the
/// same window it would in one pass, and the interpolation's right-hand
/// neighbour is included at the end of each batch.
///
/// [sourceTotalSamples] comes from the container header; if the audio ends
/// earlier the image is cropped to the columns that could be rendered.
/// Returns null when the recording is shorter than one FFT window.
Future<SpectrogramPixels?> renderSpectrogramInBatches({
  required int sourceSampleRate,
  required int sourceTotalSamples,
  required AudioRangeDecoder decode,
  required int targetSampleRate,
  required int fftSize,
  required int hop,
  required int maxDisplayBins,
  required String colorMapName,
  int batchSeconds = 60,
}) async {
  if (fftSize <= 0 ||
      hop <= 0 ||
      targetSampleRate <= 0 ||
      sourceSampleRate <= 0 ||
      batchSeconds <= 0) {
    return null;
  }
  final ratio = sourceSampleRate / targetSampleRate;
  final targetTotal = ratio == 1.0
      ? sourceTotalSamples
      : (sourceTotalSamples / ratio).floor();
  if (targetTotal < fftSize) return null;
  final numCols = (targetTotal - fftSize) ~/ hop + 1;
  if (numCols <= 0) return null;

  // Columns per batch, as a multiple of `k`: the smallest column count whose
  // start maps onto a whole source sample, since k * hop * sourceRate is a
  // multiple of targetRate by construction.
  final k = targetSampleRate ~/ _gcd(hop * sourceSampleRate, targetSampleRate);
  final wanted = math.max(1, (batchSeconds * targetSampleRate) ~/ hop);
  final batchCols = math.max(k, (wanted ~/ k) * k);

  Uint8List? pixels;
  var height = 0;
  var renderedCols = 0;
  for (var c0 = 0; c0 < numCols; c0 += batchCols) {
    final cols = math.min(batchCols, numCols - c0);
    final targetStart = c0 * hop;
    final targetSpan = (cols - 1) * hop + fftSize;
    final sourceStart = (targetStart * sourceSampleRate) ~/ targetSampleRate;
    // One extra sample for the interpolation's right-hand neighbour, as the
    // single-pass render would see it.
    final sourceCount = math.min(
      sourceTotalSamples - sourceStart,
      (targetSpan * ratio).ceil() + 2,
    );
    if (sourceCount <= 0) break;

    final chunk = await decode(sourceStart, sourceCount);
    final part = renderSpectrogram(
      chunk,
      targetSampleRate: targetSampleRate,
      fftSize: fftSize,
      hop: hop,
      maxDisplayBins: maxDisplayBins,
      colorMapName: colorMapName,
    );
    if (part == null) break;

    pixels ??= Uint8List(numCols * part.height * 4);
    height = part.height;
    final copyCols = math.min(cols, part.width);
    for (var row = 0; row < height; row++) {
      final src = row * part.width * 4;
      final dst = (row * numCols + c0) * 4;
      pixels.setRange(dst, dst + copyCols * 4, part.pixels, src);
    }
    renderedCols = c0 + copyCols;
    // The audio ended before the header said it would.
    if (copyCols < cols) break;
  }

  if (pixels == null || renderedCols <= 0) return null;
  if (renderedCols == numCols) {
    return SpectrogramPixels(pixels: pixels, width: numCols, height: height);
  }
  // Crop to the columns that exist.
  final cropped = Uint8List(renderedCols * height * 4);
  for (var row = 0; row < height; row++) {
    final src = row * numCols * 4;
    cropped.setRange(
      row * renderedCols * 4,
      (row + 1) * renderedCols * 4,
      pixels,
      src,
    );
  }
  return SpectrogramPixels(
    pixels: cropped,
    width: renderedCols,
    height: height,
  );
}

int _gcd(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final t = x % y;
    x = y;
    y = t;
  }
  return x == 0 ? 1 : x;
}
