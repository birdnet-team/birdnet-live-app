import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/spectrogram/spectrogram_painter.dart';

void main() {
  group('SpectrogramPainter', () {
    late SpectrogramPainter painter;

    setUp(() {
      painter = SpectrogramPainter(
        maxColumns: 100,
        binCount: 129, // fftSize=256 → 128+1
        colorMapName: 'viridis',
        sampleRate: 32000,
        fftSize: 256,
      );
    });

    // ─── Column management ─────────────────────────────────────────────────

    group('addColumn', () {
      test('starts with zero columns', () {
        expect(painter.columnCount, 0);
      });

      test('addColumn increases columnCount', () {
        final col = Float64List(129);
        painter.addColumn(col);
        expect(painter.columnCount, 1);
      });

      test('respects maxColumns limit', () {
        final col = Float64List(129);
        for (var i = 0; i < 150; i++) {
          painter.addColumn(col);
        }
        expect(painter.columnCount, 100);
      });

      test('asserts on wrong column length', () {
        expect(
          () => painter.addColumn(Float64List(64)),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    // ─── Clear ─────────────────────────────────────────────────────────────

    group('clear', () {
      test('resets columnCount to zero', () {
        painter.addColumn(Float64List(129));
        painter.addColumn(Float64List(129));
        expect(painter.columnCount, 2);

        painter.clear();
        expect(painter.columnCount, 0);
      });
    });

    // ─── shouldRepaint ─────────────────────────────────────────────────────

    group('shouldRepaint', () {
      test('returns true when colorMapName changes', () {
        final other = SpectrogramPainter(
          maxColumns: 100,
          binCount: 129,
          colorMapName: 'magma', // different
          sampleRate: 32000,
          fftSize: 256,
        );

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when binCount changes', () {
        final other = SpectrogramPainter(
          maxColumns: 100,
          binCount: 65, // different
          colorMapName: 'viridis',
          sampleRate: 32000,
          fftSize: 128,
        );

        expect(painter.shouldRepaint(other), isTrue);
      });
    });

    // ─── Various colour maps ───────────────────────────────────────────────

    group('works with all colour maps', () {
      for (final name in [
        'viridis',
        'magma',
        'inferno',
        'grayscale',
        'birdnet'
      ]) {
        test('creates painter with $name colour map', () {
          final p = SpectrogramPainter(
            maxColumns: 50,
            binCount: 129,
            colorMapName: name,
            sampleRate: 32000,
            fftSize: 256,
          );

          // Should accept columns without error.
          p.addColumn(Float64List(129));
          expect(p.columnCount, 1);
        });
      }
    });
  });
}
