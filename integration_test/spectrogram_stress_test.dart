// =============================================================================
// Spectrogram GPU Image Stress Test
// =============================================================================
//
// Tests that the SpectrogramPainter's async image rebuild (using toImage
// instead of toImageSync) does not leak GPU memory over sustained use.
//
// Run on a connected device:
//   flutter test integration_test/spectrogram_stress_test.dart -d <device_id>
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:birdnet_live/core/services/memory_monitor.dart';
import 'package:birdnet_live/features/spectrogram/spectrogram_painter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'SpectrogramPainter.rebuildImageAsync does not leak over 6000 cycles',
      (tester) async {
    const totalCycles = 6000;
    const maxColumns = 600;
    const binCount = 257;

    final painter = SpectrogramPainter(
      maxColumns: maxColumns,
      binCount: binCount,
      colorMapName: 'viridis',
      sampleRate: 32000,
      fftSize: 512,
    );

    final baseline = MemoryMonitor.logOnce(tag: 'painter-start');

    for (var i = 0; i < totalCycles; i++) {
      // Generate a fake FFT column.
      final column = Float64List(binCount);
      for (var b = 0; b < binCount; b++) {
        column[b] = ((i + b) * 7 % 1000) / 1000.0;
      }

      painter.addColumn(column);
      await painter.rebuildImageAsync();

      if ((i + 1) % 500 == 0) {
        final snap = MemoryMonitor.logOnce(tag: 'paint-${i + 1}');
        final growthMb = snap.vmRssMb - baseline.vmRssMb;
        debugPrint('[PainterStress] cycle ${i + 1}/$totalCycles '
            'RSS_growth=${growthMb.toStringAsFixed(1)}MB');
      }

      if ((i + 1) % 100 == 0) {
        await tester.pump(const Duration(milliseconds: 1));
      }
    }

    painter.clear();

    final afterTest = MemoryMonitor.logOnce(tag: 'painter-end');
    final totalGrowthMb = afterTest.vmRssMb - baseline.vmRssMb;
    debugPrint('[PainterStress] ═══ SUMMARY ═══');
    debugPrint('[PainterStress] Total RSS growth: '
        '${totalGrowthMb.toStringAsFixed(1)}MB over $totalCycles cycles');

    expect(
      totalGrowthMb,
      lessThan(50.0),
      reason: 'SpectrogramPainter leaked ${totalGrowthMb.toStringAsFixed(1)}MB '
          'over $totalCycles cycles',
    );
  });
}
