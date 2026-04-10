// =============================================================================
// Unit tests for FileAnalysisController data classes
// =============================================================================
//
// Tests the pure logic in AnalysisProgress and AudioFileInfo — helper getters,
// boundary conditions, and formatting.  The controller's async methods
// (loadModel, analyze) require ONNX runtime and are tested via integration
// tests on a real device.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/file_analysis/file_analysis_controller.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // AnalysisProgress
  // ═══════════════════════════════════════════════════════════════════════

  group('AnalysisProgress', () {
    test('fraction returns 0 when totalWindows is 0', () {
      const p = AnalysisProgress(
        currentWindow: 0,
        totalWindows: 0,
        detectionsFound: 0,
        speciesFound: 0,
      );
      expect(p.fraction, 0.0);
    });

    test('fraction returns correct ratio', () {
      const p = AnalysisProgress(
        currentWindow: 3,
        totalWindows: 10,
        detectionsFound: 5,
        speciesFound: 2,
      );
      expect(p.fraction, closeTo(0.3, 1e-9));
    });

    test('fraction returns 1.0 when complete', () {
      const p = AnalysisProgress(
        currentWindow: 100,
        totalWindows: 100,
        detectionsFound: 42,
        speciesFound: 8,
      );
      expect(p.fraction, 1.0);
    });

    test('percentText formats correctly', () {
      const p = AnalysisProgress(
        currentWindow: 1,
        totalWindows: 3,
        detectionsFound: 0,
        speciesFound: 0,
      );
      expect(p.percentText, '33%');
    });

    test('percentText is 0% for zero progress', () {
      expect(AnalysisProgress.zero.percentText, '0%');
    });

    test('zero constant has all fields at 0', () {
      const z = AnalysisProgress.zero;
      expect(z.currentWindow, 0);
      expect(z.totalWindows, 0);
      expect(z.detectionsFound, 0);
      expect(z.speciesFound, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // AudioFileInfo
  // ═══════════════════════════════════════════════════════════════════════

  group('AudioFileInfo', () {
    test('fileSizeText returns bytes for small files', () {
      const info = AudioFileInfo(
        path: '/tmp/tiny.wav',
        fileName: 'tiny.wav',
        fileSizeBytes: 512,
        duration: Duration(seconds: 1),
        sampleRate: 48000,
        totalSamples: 48000,
        format: 'WAV',
      );
      expect(info.fileSizeText, '512 B');
    });

    test('fileSizeText returns KB for medium files', () {
      const info = AudioFileInfo(
        path: '/tmp/small.wav',
        fileName: 'small.wav',
        fileSizeBytes: 500 * 1024,
        duration: Duration(seconds: 5),
        sampleRate: 48000,
        totalSamples: 240000,
        format: 'WAV',
      );
      expect(info.fileSizeText, '500.0 KB');
    });

    test('fileSizeText returns MB for large files', () {
      const info = AudioFileInfo(
        path: '/tmp/big.flac',
        fileName: 'big.flac',
        fileSizeBytes: 15 * 1024 * 1024,
        duration: Duration(minutes: 5),
        sampleRate: 48000,
        totalSamples: 14400000,
        format: 'FLAC',
      );
      expect(info.fileSizeText, '15.0 MB');
    });

    test('durationText formats minutes and seconds', () {
      const info = AudioFileInfo(
        path: '/tmp/test.wav',
        fileName: 'test.wav',
        fileSizeBytes: 1000,
        duration: Duration(minutes: 3, seconds: 42),
        sampleRate: 48000,
        totalSamples: 10656000,
        format: 'WAV',
      );
      expect(info.durationText, '3m 42s');
    });

    test('durationText handles zero duration', () {
      const info = AudioFileInfo(
        path: '/tmp/empty.wav',
        fileName: 'empty.wav',
        fileSizeBytes: 44,
        duration: Duration.zero,
        sampleRate: 48000,
        totalSamples: 0,
        format: 'WAV',
      );
      expect(info.durationText, '0m 0s');
    });

    test('durationText handles long recordings', () {
      const info = AudioFileInfo(
        path: '/tmp/long.flac',
        fileName: 'long.flac',
        fileSizeBytes: 100 * 1024 * 1024,
        duration: Duration(hours: 1, minutes: 23, seconds: 45),
        sampleRate: 48000,
        totalSamples: 240480000,
        format: 'FLAC',
      );
      expect(info.durationText, '83m 45s');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // FileAnalysisState enum
  // ═══════════════════════════════════════════════════════════════════════

  group('FileAnalysisState', () {
    test('has expected values', () {
      expect(FileAnalysisState.values, hasLength(6));
      expect(
        FileAnalysisState.values.map((e) => e.name),
        containsAll([
          'idle',
          'loading',
          'ready',
          'analyzing',
          'complete',
          'error',
        ]),
      );
    });
  });
}
