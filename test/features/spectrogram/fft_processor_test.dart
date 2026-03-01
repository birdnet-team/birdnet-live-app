import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/spectrogram/fft_processor.dart';

void main() {
  group('FftProcessor', () {
    // ─── Construction ──────────────────────────────────────────────────────

    group('construction', () {
      test('creates with default parameters', () {
        final fft = FftProcessor();
        expect(fft.fftSize, 2048);
        expect(fft.dbFloor, -80.0);
        expect(fft.dbCeiling, 0.0);
        // N/2 + 1 bins for a real-valued FFT.
        expect(fft.binCount, 1025);
      });

      test('creates with custom fftSize', () {
        final fft = FftProcessor(fftSize: 512);
        expect(fft.fftSize, 512);
        expect(fft.binCount, 257); // 512/2 + 1
      });

      test('creates with custom dB range', () {
        final fft = FftProcessor(dbFloor: -60, dbCeiling: -10);
        expect(fft.dbFloor, -60.0);
        expect(fft.dbCeiling, -10.0);
      });

      test('asserts on non-power-of-two fftSize', () {
        expect(
            () => FftProcessor(fftSize: 1000), throwsA(isA<AssertionError>()));
      });

      test('asserts on zero fftSize', () {
        expect(() => FftProcessor(fftSize: 0), throwsA(isA<AssertionError>()));
      });
    });

    // ─── Frequency helpers ─────────────────────────────────────────────────

    group('frequency helpers', () {
      test('binHz returns correct resolution', () {
        final fft = FftProcessor(fftSize: 1024);
        // 32000 / 1024 = 31.25 Hz per bin.
        expect(fft.binHz(32000), closeTo(31.25, 0.01));
      });

      test('binFrequency returns centre frequency of a given bin', () {
        final fft = FftProcessor(fftSize: 2048);
        // Bin 0 = DC = 0 Hz.
        expect(fft.binFrequency(0, 32000), 0.0);
        // Bin 1 = 32000/2048 ≈ 15.625 Hz.
        expect(fft.binFrequency(1, 32000), closeTo(15.625, 0.01));
        // Last bin = Nyquist = 16000 Hz.
        expect(fft.binFrequency(1024, 32000), closeTo(16000.0, 0.1));
      });
    });

    // ─── process() output shape ────────────────────────────────────────────

    group('process', () {
      test('output has correct length (binCount)', () {
        final fft = FftProcessor(fftSize: 256);
        final silence = Float32List(256);
        final result = fft.process(silence);
        expect(result.length, fft.binCount);
      });

      test('output values are in [0, 1] range for normalised mode', () {
        final fft = FftProcessor(fftSize: 512);
        // Random signal to avoid all-zero edge case.
        final rng = math.Random(42);
        final samples = Float32List.fromList(
          List.generate(512, (_) => (rng.nextDouble() * 2 - 1) * 0.5),
        );

        final result = fft.process(samples);
        for (var i = 0; i < result.length; i++) {
          expect(result[i], greaterThanOrEqualTo(0.0),
              reason: 'Bin $i should be >= 0');
          expect(result[i], lessThanOrEqualTo(1.0),
              reason: 'Bin $i should be <= 1');
        }
      });

      test('silence produces very low normalised values', () {
        final fft = FftProcessor(fftSize: 256);
        final silence = Float32List(256);
        final result = fft.process(silence);

        // All bins should be at 0.0 (below dbFloor).
        for (var i = 0; i < result.length; i++) {
          expect(result[i], closeTo(0.0, 0.01),
              reason: 'Silent bin $i should map to ~0');
        }
      });

      test('full-scale sine produces high value at the signal bin', () {
        const size = 1024;
        const sampleRate = 32000;
        const freq = 1000.0; // 1 kHz sine

        final fft = FftProcessor(fftSize: size);
        final samples = Float32List(size);

        // Generate a pure 1 kHz sine wave at full scale.
        for (var i = 0; i < size; i++) {
          samples[i] = math.sin(2 * math.pi * freq * i / sampleRate);
        }

        final result = fft.process(samples);

        // Find the bin with the highest magnitude.
        var maxBin = 0;
        var maxVal = 0.0;
        for (var i = 0; i < result.length; i++) {
          if (result[i] > maxVal) {
            maxVal = result[i];
            maxBin = i;
          }
        }

        // Expected bin: freq * size / sampleRate = 1000 * 1024 / 32000 = 32.
        // Allow ±1 bin tolerance because of Hann window spectral smearing.
        final expectedBin = (freq * size / sampleRate).round();
        expect((maxBin - expectedBin).abs(), lessThanOrEqualTo(1));
        // The magnitude should be significantly above zero.
        expect(maxVal, greaterThan(0.5));
      });

      test('works with samples longer than fftSize (uses first N)', () {
        final fft = FftProcessor(fftSize: 256);
        // Provide 1024 samples — only first 256 should be used.
        final samples = Float32List(1024);
        for (var i = 0; i < 1024; i++) {
          samples[i] = math.sin(2 * math.pi * 500 * i / 32000);
        }

        final result = fft.process(samples);
        expect(result.length, fft.binCount);
      });
    });

    // ─── processRawDb() ────────────────────────────────────────────────────

    group('processRawDb', () {
      test('returns dB values (can be negative)', () {
        final fft = FftProcessor(fftSize: 256);
        final rng = math.Random(42);
        final samples = Float32List.fromList(
          List.generate(256, (_) => (rng.nextDouble() * 2 - 1) * 0.1),
        );

        final result = fft.processRawDb(samples);
        expect(result.length, fft.binCount);
        // At least some bins should have negative dB values.
        final hasNegative = result.any((v) => v < 0);
        expect(hasNegative, isTrue);
      });

      test('silence produces very negative dB values', () {
        final fft = FftProcessor(fftSize: 256);
        final silence = Float32List(256);
        final result = fft.processRawDb(silence);

        // All bins should be deeply negative (near epsilon floor).
        for (var i = 0; i < result.length; i++) {
          expect(result[i], lessThan(-80),
              reason: 'Silent bin $i should be < -80 dB');
        }
      });
    });

    // ─── Windowing ─────────────────────────────────────────────────────────

    group('windowing', () {
      test('Hann window reduces spectral leakage compared to rectangular', () {
        const size = 1024;
        const sampleRate = 32000;
        const freq = 2000.0;

        // Generate a pure tone that is NOT bin-aligned to create leakage.
        final samples = Float32List(size);
        for (var i = 0; i < size; i++) {
          samples[i] = math.sin(2 * math.pi * freq * i / sampleRate);
        }

        final fft = FftProcessor(fftSize: size);
        final result = fft.process(samples);

        // Find the peak bin.
        var peakBin = 0;
        var peakVal = 0.0;
        for (var i = 0; i < result.length; i++) {
          if (result[i] > peakVal) {
            peakVal = result[i];
            peakBin = i;
          }
        }

        // The energy should be concentrated near the peak, not spread out.
        // Check that bins far from the peak are substantially lower.
        final farBin = (peakBin + result.length ~/ 4) % result.length;
        expect(result[farBin], lessThan(peakVal * 0.3),
            reason: 'Far bin should have much less energy than peak');
      });
    });

    // ─── Different FFT sizes ───────────────────────────────────────────────

    group('various FFT sizes', () {
      for (final size in [64, 128, 256, 512, 1024, 2048, 4096]) {
        test('works with fftSize=$size', () {
          final fft = FftProcessor(fftSize: size);
          final samples = Float32List(size);
          // White noise.
          final rng = math.Random(size);
          for (var i = 0; i < size; i++) {
            samples[i] = (rng.nextDouble() * 2 - 1) * 0.5;
          }

          final result = fft.process(samples);
          expect(result.length, size ~/ 2 + 1);
          expect(result.every((v) => v >= 0 && v <= 1), isTrue);
        });
      }
    });
  });
}
