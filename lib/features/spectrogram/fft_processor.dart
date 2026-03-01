import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

// =============================================================================
// FFT Processor — Windowed FFT → magnitude dB spectrum
// =============================================================================
//
// Accepts a chunk of time-domain audio samples (Float32List) and returns a
// half-spectrum of magnitude values expressed in decibels (dB).
//
// ### Pipeline
//
// 1. **Window**  — Apply a Hann (raised-cosine) window to reduce spectral
//    leakage.  The window coefficients are pre-computed once and cached for
//    the lifetime of the processor.
//
// 2. **FFT**     — Compute the complex DFT of the windowed frame via
//    [fftea](https://pub.dev/packages/fftea).  Only the first N/2 + 1 bins
//    (positive frequencies) are used, exploiting the symmetry of real input.
//
// 3. **Magnitude** — Convert each complex bin `(re, im)` to power
//    `re² + im²`, then to decibels: `10 * log10(power + ε)`.  The `ε`
//    constant avoids `−∞` for zero-power bins.
//
// 4. **Clamp**   — Values are clamped to a configurable `[dbFloor, dbCeiling]`
//    range and linearly normalised to `[0.0, 1.0]` so they can feed directly
//    into a colour-map lookup.
//
// ### Thread safety
//
// This class is intended to be called on the UI isolate with small FFTs
// (≤ 4096).  For larger FFTs the caller should run it in an isolate.
// The internal state is mutable (pre-allocated scratch buffers) so it is
// **not** safe to share across isolates.
// =============================================================================

/// Performs windowed FFT and converts the result to a normalised dB magnitude
/// spectrum suitable for spectrogram rendering.
///
/// Create one instance and reuse it — the constructor pre-allocates all
/// scratch buffers for the given [fftSize].
class FftProcessor {
  /// Creates a processor for a fixed [fftSize] (must be a power of two).
  ///
  /// [dbFloor] and [dbCeiling] define the dynamic range mapped to
  /// normalised output [0.0, 1.0].  Typical values:
  ///   • `dbFloor  = -80`  (quiet background noise)
  ///   • `dbCeiling =  0`  (digital full-scale)
  FftProcessor({
    this.fftSize = 2048,
    this.dbFloor = -80.0,
    this.dbCeiling = 0.0,
  })  : assert(fftSize > 0 && (fftSize & (fftSize - 1)) == 0,
            'fftSize must be a positive power of two'),
        _fft = FFT(fftSize),
        _window = Float64List(fftSize),
        _binCount = fftSize ~/ 2 + 1 {
    _buildHannWindow();
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Number of samples per FFT frame (must be a power of two).
  final int fftSize;

  /// Lower bound in dB — values below are clamped to 0.0 in normalised output.
  final double dbFloor;

  /// Upper bound in dB — values above are clamped to 1.0 in normalised output.
  final double dbCeiling;

  // ---------------------------------------------------------------------------
  // Pre-allocated / cached state
  // ---------------------------------------------------------------------------

  /// The underlying FFT engine from the `fftea` package.
  final FFT _fft;

  /// Pre-computed Hann window coefficients (length = [fftSize]).
  final Float64List _window;

  /// Number of positive-frequency bins: `fftSize / 2 + 1`.
  final int _binCount;

  /// Number of unique frequency bins in the output spectrum.
  int get binCount => _binCount;

  /// The frequency resolution per bin in Hz, given [sampleRate].
  ///
  /// ```
  /// binHz = sampleRate / fftSize
  /// ```
  double binHz(int sampleRate) => sampleRate / fftSize;

  /// Return the centre frequency of bin [index] for the given [sampleRate].
  double binFrequency(int index, int sampleRate) =>
      index * sampleRate / fftSize;

  // ---------------------------------------------------------------------------
  // Processing
  // ---------------------------------------------------------------------------

  /// Process a time-domain frame and return **normalised** magnitudes.
  ///
  /// [samples] must have at least [fftSize] elements.  If longer, only the
  /// first [fftSize] samples are used.
  ///
  /// Returns a [Float64List] of length [binCount] with values in [0.0, 1.0]
  /// where 0.0 maps to [dbFloor] and 1.0 maps to [dbCeiling].
  Float64List process(Float32List samples) {
    assert(samples.length >= fftSize,
        'Need at least $fftSize samples, got ${samples.length}');

    // 1. Apply Hann window.
    final windowed = Float64List(fftSize);
    for (var i = 0; i < fftSize; i++) {
      windowed[i] = samples[i] * _window[i];
    }

    // 2. Run FFT — returns interleaved [re0, im0, re1, im1, …].
    final spectrum = _fft.realFft(windowed);

    // 3. Convert to normalised dB magnitudes.
    return _spectrumToNormalisedDb(spectrum);
  }

  /// Process a frame and return **raw dB** magnitudes (not normalised).
  ///
  /// Useful for axis-label rendering or custom colour scaling.
  Float64List processRawDb(Float32List samples) {
    assert(samples.length >= fftSize);

    final windowed = Float64List(fftSize);
    for (var i = 0; i < fftSize; i++) {
      windowed[i] = samples[i] * _window[i];
    }

    final spectrum = _fft.realFft(windowed);
    return _spectrumToDb(spectrum);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Build a Hann window: `w[n] = 0.5 * (1 − cos(2π n / N))`.
  void _buildHannWindow() {
    final n = fftSize;
    final factor = 2.0 * math.pi / n;
    for (var i = 0; i < n; i++) {
      _window[i] = 0.5 * (1.0 - math.cos(factor * i));
    }
  }

  /// Convert interleaved complex spectrum to raw dB Float64List.
  ///
  /// The `fftea` `realFft` returns a [Float64x2List] of complex values.
  /// We only need the first [_binCount] bins (positive frequencies).
  Float64List _spectrumToDb(Float64x2List spectrum) {
    final result = Float64List(_binCount);
    // Epsilon to avoid log10(0).
    const eps = 1e-10;

    for (var i = 0; i < _binCount; i++) {
      final complex = spectrum[i];
      final re = complex.x;
      final im = complex.y;
      final power = re * re + im * im;
      result[i] = 10.0 * _log10(power + eps);
    }

    return result;
  }

  /// Convert spectrum to normalised [0, 1] magnitudes clamped to the
  /// configured dB range.
  Float64List _spectrumToNormalisedDb(Float64x2List spectrum) {
    final db = _spectrumToDb(spectrum);
    final range = dbCeiling - dbFloor;
    if (range <= 0) return Float64List(_binCount); // safety

    for (var i = 0; i < _binCount; i++) {
      db[i] = ((db[i] - dbFloor) / range).clamp(0.0, 1.0);
    }

    return db;
  }

  /// Fast base-10 logarithm using the natural log identity:
  /// `log10(x) = ln(x) / ln(10)`.
  static double _log10(double x) => math.log(x) * _log10e;

  /// Pre-computed `1 / ln(10)`.
  static final double _log10e = 1.0 / math.ln10;
}
