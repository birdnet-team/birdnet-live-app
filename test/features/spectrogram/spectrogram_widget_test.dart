import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/audio/ring_buffer.dart';
import 'package:birdnet_live/features/spectrogram/spectrogram_widget.dart';

// =============================================================================
// SpectrogramWidget — Widget tests
// =============================================================================
//
// Covers the lifecycle behaviour of [SpectrogramWidget], specifically the
// regression where calling _painter.clear() before _painter was initialised
// caused a LateInitializationError on the first _initProcessor() call from
// initState.
// =============================================================================

void main() {
  group('SpectrogramWidget', () {
    late RingBuffer ringBuffer;

    setUp(() {
      ringBuffer = RingBuffer(capacity: 4096);
    });

    Widget buildWidget({
      String colorMapName = 'viridis',
      int fftSize = 256,
      double dbFloor = -80.0,
      double dbCeiling = 0.0,
      int maxColumns = 50,
      bool isActive = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 150,
            child: SpectrogramWidget(
              ringBuffer: ringBuffer,
              isActive: isActive,
              fftSize: fftSize,
              colorMapName: colorMapName,
              dbFloor: dbFloor,
              dbCeiling: dbCeiling,
              maxColumns: maxColumns,
            ),
          ),
        ),
      );
    }

    // ─── Smoke / creation ──────────────────────────────────────────────────

    testWidgets('creates without error', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(SpectrogramWidget), findsOneWidget);
    });

    // ─── Regression: LateInitializationError on _painter ──────────────────
    //
    // Before the fix, _initProcessor() called _painter.clear() unconditionally.
    // On the first call from initState _painter was not yet assigned, causing:
    //   LateInitializationError: Field '_painter@...' has not been initialized.

    testWidgets(
        'first build does not throw LateInitializationError (regression)',
        (tester) async {
      // This single pump exercises initState → _initProcessor with an
      // uninitialized _painter.  Without the _painterInitialized guard it
      // would throw immediately.
      await tester.pumpWidget(buildWidget());
      // No exception = regression does not reoccur.
      expect(find.byType(SpectrogramWidget), findsOneWidget);
    });

    // ─── Settings changes (didUpdateWidget → _initProcessor) ──────────────

    testWidgets('changing colorMapName does not throw', (tester) async {
      await tester.pumpWidget(buildWidget(colorMapName: 'viridis'));
      await tester.pumpWidget(buildWidget(colorMapName: 'grayscale'));
      await tester.pumpWidget(buildWidget(colorMapName: 'birdnet'));
      expect(find.byType(SpectrogramWidget), findsOneWidget);
    });

    testWidgets('changing fftSize does not throw', (tester) async {
      await tester.pumpWidget(buildWidget(fftSize: 256));
      await tester.pumpWidget(buildWidget(fftSize: 512));
      await tester.pumpWidget(buildWidget(fftSize: 1024));
      expect(find.byType(SpectrogramWidget), findsOneWidget);
    });

    testWidgets('changing dB range does not throw', (tester) async {
      await tester.pumpWidget(buildWidget(dbFloor: -80, dbCeiling: 0));
      await tester.pumpWidget(buildWidget(dbFloor: -60, dbCeiling: -10));
      expect(find.byType(SpectrogramWidget), findsOneWidget);
    });

    testWidgets('multiple consecutive settings changes do not throw',
        (tester) async {
      await tester.pumpWidget(
          buildWidget(colorMapName: 'viridis', fftSize: 256, maxColumns: 50));
      await tester.pumpWidget(
          buildWidget(colorMapName: 'grayscale', fftSize: 256, maxColumns: 50));
      await tester.pumpWidget(
          buildWidget(colorMapName: 'birdnet', fftSize: 512, maxColumns: 100));
      await tester.pumpWidget(
          buildWidget(colorMapName: 'viridis', fftSize: 256, maxColumns: 50));
      expect(find.byType(SpectrogramWidget), findsOneWidget);
    });

    // ─── Dispose ───────────────────────────────────────────────────────────

    testWidgets('dispose does not throw', (tester) async {
      await tester.pumpWidget(buildWidget());
      // Replace widget tree to trigger dispose().
      await tester.pumpWidget(const SizedBox.shrink());
      // No exception = pass.
    });

    testWidgets('dispose after settings change does not throw', (tester) async {
      await tester.pumpWidget(buildWidget(colorMapName: 'viridis'));
      await tester.pumpWidget(buildWidget(colorMapName: 'birdnet'));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
