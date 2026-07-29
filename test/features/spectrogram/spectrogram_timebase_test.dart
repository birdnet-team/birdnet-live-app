import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/spectrogram/spectrogram_widget.dart';

// =============================================================================
// SpectrogramTimebase — Unit tests
// =============================================================================
//
// Regression coverage for the bug where changing the FFT size changed the
// visible duration of the live spectrogram.  The column rate used to be
// derived from the FFT hop (sampleRate / (fftSize / 2)), which at fftSize
// 512 demands 125 columns/s.  A Ticker can only emit one column per vsync
// (~60/s), so columns were dropped and a "15 second" window really showed
// ~31 seconds and scrolled at half speed.
//
// The invariant asserted here is the fix:
//
//     columnCount * columnDuration == displaySeconds   (for every fftSize)
// =============================================================================

void main() {
  group('SpectrogramTimebase', () {
    // Every FFT size the settings screen offers.
    const fftSizes = [512, 1024, 2048, 4096];
    // Every duration the settings screen offers.
    const durations = [5.0, 10.0, 15.0, 20.0, 30.0];
    const qualities = ['low', 'medium', 'high'];

    // ─── The core invariant ────────────────────────────────────────────────

    test('visible window equals displaySeconds for every fftSize', () {
      for (final fftSize in fftSizes) {
        for (final seconds in durations) {
          for (final quality in qualities) {
            final tb = SpectrogramTimebase(
              displaySeconds: seconds,
              fftSize: fftSize,
              quality: quality,
            );

            final windowSeconds =
                tb.columnCount * tb.columnDuration.inMicroseconds / 1000000.0;

            expect(
              windowSeconds,
              closeTo(seconds, 0.05),
              reason: 'fftSize $fftSize, quality $quality, ${seconds}s window',
            );
          }
        }
      }
    });

    test('fftSize does not change the column grid', () {
      final grids =
          fftSizes
              .map((f) => SpectrogramTimebase(displaySeconds: 15, fftSize: f))
              .toList();

      for (final tb in grids.skip(1)) {
        expect(tb.columnCount, grids.first.columnCount);
        expect(tb.columnDuration, grids.first.columnDuration);
        expect(tb.columnHopSamples, grids.first.columnHopSamples);
      }
    });

    // ─── Sustainability: the Ticker caps us at one column per vsync ────────

    test('column rate stays below the 60 Hz vsync ceiling', () {
      for (final quality in qualities) {
        final tb = SpectrogramTimebase(
          displaySeconds: 15,
          fftSize: 512,
          quality: quality,
        );
        expect(
          tb.columnsPerSecond,
          lessThan(55),
          reason: 'quality $quality would drop columns at 60 fps',
        );
      }
    });

    test('column hop matches the column duration in samples', () {
      for (final quality in qualities) {
        final tb = SpectrogramTimebase(
          displaySeconds: 15,
          fftSize: 2048,
          quality: quality,
        );
        final hopSeconds = tb.columnHopSamples / tb.sampleRate;
        expect(
          hopSeconds,
          closeTo(tb.columnDuration.inMicroseconds / 1000000.0, 1e-4),
          reason: 'quality $quality',
        );
      }
    });

    // ─── Degenerate inputs ────────────────────────────────────────────────

    test('always keeps at least two columns', () {
      final tb = SpectrogramTimebase(displaySeconds: 0, fftSize: 2048);
      expect(tb.columnCount, greaterThanOrEqualTo(2));
    });

    test('higher quality yields a finer column grid', () {
      int columnsFor(String quality) =>
          SpectrogramTimebase(
            displaySeconds: 15,
            fftSize: 2048,
            quality: quality,
          ).columnCount;

      expect(columnsFor('low'), lessThan(columnsFor('medium')));
      expect(columnsFor('medium'), lessThan(columnsFor('high')));
    });

    test('unknown quality falls back to the medium grid', () {
      final unknown = SpectrogramTimebase(
        displaySeconds: 15,
        fftSize: 2048,
        quality: 'ultra',
      );
      final medium = SpectrogramTimebase(displaySeconds: 15, fftSize: 2048);
      expect(unknown.columnCount, medium.columnCount);
    });
  });
}
