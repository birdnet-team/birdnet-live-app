import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/audio/ring_buffer.dart';
import 'package:birdnet_live/features/spectrogram/spectrogram_painter.dart';
import 'package:birdnet_live/features/spectrogram/spectrogram_widget.dart';

// =============================================================================
// SpectrogramWidget — Widget tests
// =============================================================================
//
// Covers the lifecycle behaviour of [SpectrogramWidget], specifically the
// regression where calling _painter.clear() before _painter was initialised
// caused a LateInitializationError on the first _initProcessor() call from
// initState, and the regression where the live screens' portrait/landscape
// layout switch disposed the widget and cleared the spectrogram (#276).
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
      double displaySeconds = 2.0,
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
              displaySeconds: displaySeconds,
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
      },
    );

    // ─── Settings changes (didUpdateWidget → _initProcessor) ──────────────

    testWidgets('changing colorMapName does not throw', (tester) async {
      await tester.pumpWidget(buildWidget(colorMapName: 'viridis'));
      await tester.pumpWidget(buildWidget(colorMapName: 'grayscale'));
      await tester.pumpWidget(buildWidget(colorMapName: 'turbo'));
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

    testWidgets('multiple consecutive settings changes do not throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(colorMapName: 'viridis', fftSize: 256, displaySeconds: 2),
      );
      await tester.pumpWidget(
        buildWidget(colorMapName: 'grayscale', fftSize: 256, displaySeconds: 2),
      );
      await tester.pumpWidget(
        buildWidget(colorMapName: 'birdnet', fftSize: 512, displaySeconds: 5),
      );
      await tester.pumpWidget(
        buildWidget(colorMapName: 'viridis', fftSize: 256, displaySeconds: 2),
      );
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

  // ─── Layout reparenting on rotation (#276) ───────────────────────────────
  //
  // The live screens place the spectrogram at a different depth of the tree
  // in landscape (inside a Row → Column) than in portrait (direct child of
  // the body Column). Without a GlobalKey, Flutter disposes the State on
  // every rotation and the painter's column buffer is lost with it.

  group('SpectrogramWidget layout reparenting', () {
    late RingBuffer ringBuffer;

    setUp(() {
      ringBuffer = RingBuffer(capacity: 4096);
    });

    /// Mirrors the body layouts of the live screens: a vertical stack in
    /// portrait, spectrogram and detection list side by side in landscape.
    Widget buildLayout({required bool landscape, Key? key}) {
      final spectrogram = SpectrogramWidget(
        key: key,
        ringBuffer: ringBuffer,
        isActive: false,
        fftSize: 256,
        displaySeconds: 2.0,
        showFrequencyAxis: false,
        showTimeAxis: false,
      );
      final body = landscape
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: spectrogram),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                const Expanded(child: SizedBox.expand()),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 2, child: spectrogram),
                const SizedBox(height: 24),
                const Expanded(flex: 3, child: SizedBox.expand()),
              ],
            );
      return MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 48),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    SpectrogramPainter painterOf(WidgetTester tester) {
      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(SpectrogramWidget),
          matching: find.byType(CustomPaint),
        ),
      );
      return customPaint.painter! as SpectrogramPainter;
    }

    testWidgets(
      'keeps its State and columns across a layout switch when keyed',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(buildLayout(landscape: false, key: key));

        final state = tester.state(find.byType(SpectrogramWidget));
        final painter = painterOf(tester);
        painter.addColumn(Float64List(painter.binCount));
        painter.addColumn(Float64List(painter.binCount));
        expect(painter.columnCount, 2);

        await tester.pumpWidget(buildLayout(landscape: true, key: key));
        expect(tester.state(find.byType(SpectrogramWidget)), same(state));
        expect(painterOf(tester), same(painter));
        expect(painter.columnCount, 2);

        await tester.pumpWidget(buildLayout(landscape: false, key: key));
        expect(tester.state(find.byType(SpectrogramWidget)), same(state));
        expect(painterOf(tester), same(painter));
        expect(painter.columnCount, 2);
      },
    );

    testWidgets('is recreated across a layout switch without a key (control)', (
      tester,
    ) async {
      await tester.pumpWidget(buildLayout(landscape: false));

      final state = tester.state(find.byType(SpectrogramWidget));
      final painter = painterOf(tester);
      painter.addColumn(Float64List(painter.binCount));
      expect(painter.columnCount, 1);

      await tester.pumpWidget(buildLayout(landscape: true));
      expect(tester.state(find.byType(SpectrogramWidget)), isNot(same(state)));
      expect(painterOf(tester).columnCount, 0);
    });
  });
}
