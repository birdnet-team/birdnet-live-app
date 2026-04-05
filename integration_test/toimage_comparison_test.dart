// =============================================================================
// toImage (async) vs toImageSync leak comparison test
// =============================================================================
//
// Tests whether Picture.toImage (async) has the same leak as toImageSync.
//
// Run on a connected device:
//   flutter test integration_test/toimage_comparison_test.dart -d <device_id>
// =============================================================================

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:birdnet_live/core/services/memory_monitor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('toImage (async) leak test — 6000 cycles', (tester) async {
    const totalCycles = 6000;
    const imgW = 600;
    const imgH = 257;

    final lut = Int32List(256);
    for (var i = 0; i < 256; i++) {
      lut[i] = (0xFF000000 | (i << 16) | ((i ~/ 2) << 8) | (255 - i));
    }

    final cellPaint = Paint()..style = PaintingStyle.fill;
    ui.Image? spectrogramImage;

    final baseline = MemoryMonitor.logOnce(tag: 'toImage-async-start');

    for (var i = 0; i < totalCycles; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      if (spectrogramImage != null) {
        canvas.drawImageRect(
          spectrogramImage!,
          Rect.fromLTWH(1, 0, imgW - 1, imgH.toDouble()),
          Rect.fromLTWH(0, 0, imgW - 1, imgH.toDouble()),
          Paint()..filterQuality = FilterQuality.none,
        );
      }

      final x = (imgW - 1).toDouble();
      for (var y = 0; y < imgH; y++) {
        final lutIdx = ((i + y) * 7 % 256);
        cellPaint.color = Color(lut[lutIdx]);
        canvas.drawRect(Rect.fromLTWH(x, y.toDouble(), 1, 1), cellPaint);
      }

      final picture = recorder.endRecording();
      spectrogramImage?.dispose();
      // Use ASYNC toImage instead of toImageSync.
      spectrogramImage = await picture.toImage(imgW, imgH);
      picture.dispose();

      if ((i + 1) % 500 == 0) {
        final snap = MemoryMonitor.logOnce(tag: 'async-${i + 1}');
        final growthMb = snap.vmRssMb - baseline.vmRssMb;
        debugPrint('[AsyncImg] cycle ${i + 1}/$totalCycles '
            'RSS_growth=${growthMb.toStringAsFixed(1)}MB');
      }

      if ((i + 1) % 100 == 0) {
        await tester.pump(const Duration(milliseconds: 1));
      }
    }

    spectrogramImage?.dispose();
    spectrogramImage = null;

    final afterTest = MemoryMonitor.logOnce(tag: 'toImage-async-end');
    final totalGrowthMb = afterTest.vmRssMb - baseline.vmRssMb;
    debugPrint('[AsyncImg] ═══ SUMMARY ═══');
    debugPrint('[AsyncImg] Total RSS growth: '
        '${totalGrowthMb.toStringAsFixed(1)}MB over $totalCycles cycles');

    expect(
      totalGrowthMb,
      lessThan(100.0),
      reason: 'toImage(async) leaked ${totalGrowthMb.toStringAsFixed(1)}MB '
          'over $totalCycles cycles',
    );
  });

  testWidgets('decodeImageFromPixels leak test — 6000 cycles', (tester) async {
    const totalCycles = 6000;
    const imgW = 600;
    const imgH = 257;

    // Pre-allocate a pixel buffer (RGBA).
    final pixels = Uint8List(imgW * imgH * 4);

    // Fill with a gradient pattern.
    for (var y = 0; y < imgH; y++) {
      for (var x = 0; x < imgW; x++) {
        final offset = (y * imgW + x) * 4;
        pixels[offset] = x % 256; // R
        pixels[offset + 1] = y % 256; // G
        pixels[offset + 2] = 128; // B
        pixels[offset + 3] = 255; // A
      }
    }

    ui.Image? currentImage;
    final baseline = MemoryMonitor.logOnce(tag: 'decodePixels-start');

    for (var i = 0; i < totalCycles; i++) {
      // Shift pixels left by 1 column (in-place).
      for (var y = 0; y < imgH; y++) {
        final rowOffset = y * imgW * 4;
        // Copy bytes left by 4 (one pixel).
        pixels.buffer.asUint8List().setRange(
              rowOffset,
              rowOffset + (imgW - 1) * 4,
              pixels,
              rowOffset + 4,
            );
        // Write new rightmost pixel.
        final rightOffset = rowOffset + (imgW - 1) * 4;
        pixels[rightOffset] = (i + y) % 256;
        pixels[rightOffset + 1] = (i * 3 + y) % 256;
        pixels[rightOffset + 2] = 128;
        pixels[rightOffset + 3] = 255;
      }

      // Decode image from raw pixel buffer.
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        imgW,
        imgH,
        ui.PixelFormat.rgba8888,
        (ui.Image img) {
          completer.complete(img);
        },
      );
      currentImage?.dispose();
      currentImage = await completer.future;

      if ((i + 1) % 500 == 0) {
        final snap = MemoryMonitor.logOnce(tag: 'pixels-${i + 1}');
        final growthMb = snap.vmRssMb - baseline.vmRssMb;
        debugPrint('[PixelBuf] cycle ${i + 1}/$totalCycles '
            'RSS_growth=${growthMb.toStringAsFixed(1)}MB');
      }

      if ((i + 1) % 100 == 0) {
        await tester.pump(const Duration(milliseconds: 1));
      }
    }

    currentImage?.dispose();
    currentImage = null;

    final afterTest = MemoryMonitor.logOnce(tag: 'decodePixels-end');
    final totalGrowthMb = afterTest.vmRssMb - baseline.vmRssMb;
    debugPrint('[PixelBuf] ═══ SUMMARY ═══');
    debugPrint('[PixelBuf] Total RSS growth: '
        '${totalGrowthMb.toStringAsFixed(1)}MB over $totalCycles cycles');

    expect(
      totalGrowthMb,
      lessThan(100.0),
      reason: 'decodeImageFromPixels leaked '
          '${totalGrowthMb.toStringAsFixed(1)}MB over $totalCycles cycles',
    );
  });
}
