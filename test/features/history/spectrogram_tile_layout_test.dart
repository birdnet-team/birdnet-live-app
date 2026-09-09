// =============================================================================
// Spectrogram Tile Layout Tests
// =============================================================================
//
// The strip is tiled because an hour-long recording cannot be rendered in one
// go. A one-minute live session can — and paying the long-file price for it
// meant a black strip while a frame index was built and a window's worth of
// tiles were scheduled around a viewport that had not been reported yet.
//
// These pin the boundary: short files sweep, long files window.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/history/session_review_screen.dart';

/// Sample rate the strip renders against, and the finest hop it uses.
const int _sampleRate = 32000;
const int _fineHop = 512;

SpectrogramTileLayout resolve({
  required double total,
  double center = 10.0,
  double view = 10.0,
  double grid = 30.0,
  int hop = _fineHop,
}) {
  return SpectrogramTileLayout.resolve(
    totalSeconds: total,
    absoluteCenterSec: center,
    viewSeconds: view,
    gridChunkSeconds: grid,
    hop: hop,
    targetSampleRate: _sampleRate,
  );
}

/// Number of tiles a layout asks the scheduler to load.
int tileCount(SpectrogramTileLayout layout) {
  final first = (layout.startSec / layout.chunkSeconds).floor();
  final last = ((layout.endSec - 0.000001) / layout.chunkSeconds).floor();
  return (last < first ? first : last) - first + 1;
}

void main() {
  group('short recordings', () {
    test('a one-minute session is a single tile spanning the file', () {
      final layout = resolve(total: 60.0);

      expect(layout.singleSweep, isTrue);
      expect(layout.chunkSeconds, 60.0);
      expect(layout.startSec, 0.0);
      expect(layout.endSec, 60.0);
      expect(tileCount(layout), 1);
    });

    test('the sweep covers the whole file, not the visible window', () {
      // The viewport is the user's 10 s preference, parked at the head. The
      // tail still loads in the same pass, so scrolling never finds a hole.
      final layout = resolve(total: 90.0, center: 5.0, view: 10.0);

      expect(layout.startSec, 0.0);
      expect(layout.endSec, 90.0);
    });

    test('splits when one texture cannot hold the file', () {
      // 4096 columns at hop 512 is 65.5 s of audio; two minutes needs two.
      final layout = resolve(total: 120.0);

      expect(layout.singleSweep, isTrue);
      expect(layout.chunkSeconds, closeTo(65.536, 0.001));
      expect(tileCount(layout), 2);
    });

    test('a coarser hop fits the same file in one tile', () {
      // Zooming out stretches the hop, so the column budget buys more audio.
      final layout = resolve(total: 120.0, view: 45.0, grid: 120.0, hop: 2048);

      expect(layout.chunkSeconds, 120.0);
      expect(tileCount(layout), 1);
    });

    test('the two-minute boundary is inclusive', () {
      expect(resolve(total: 120.0).singleSweep, isTrue);
      expect(resolve(total: 120.5).singleSweep, isFalse);
    });
  });

  group('long recordings', () {
    test('load a padded window around the playhead, on the zoom grid', () {
      final layout = resolve(total: 3600.0, center: 1800.0, view: 10.0);

      expect(layout.singleSweep, isFalse);
      expect(layout.chunkSeconds, 30.0);
      // 10 s window, padded by the 5 s floor on either side.
      expect(layout.startSec, closeTo(1790.0, 0.001));
      expect(layout.endSec, closeTo(1810.0, 0.001));
    });

    test('padding scales with the window but never exceeds a tile', () {
      final layout = resolve(
        total: 3600.0,
        center: 1800.0,
        view: 600.0,
        grid: 480.0,
        hop: 16384,
      );

      // 25% of 600 s is 150 s, comfortably under the 480 s tile.
      expect(layout.startSec, closeTo(1350.0, 0.001));
      expect(layout.endSec, closeTo(2250.0, 0.001));
    });

    test('the window clamps to the recording at either end', () {
      final head = resolve(total: 3600.0, center: 2.0, view: 10.0);
      expect(head.startSec, 0.0);

      final tail = resolve(total: 3600.0, center: 3599.0, view: 10.0);
      expect(tail.endSec, 3600.0);
    });
  });

  group('degenerate inputs', () {
    test('an unknown duration falls back to the windowed grid', () {
      // just_audio can report a null duration and publish it later; the
      // scheduler must not treat "0 s" as a file short enough to sweep.
      final layout = resolve(total: 0.0);

      expect(layout.singleSweep, isFalse);
      expect(layout.chunkSeconds, 30.0);
    });

    test('a nonsensical hop falls back to the windowed grid', () {
      final layout = resolve(total: 60.0, hop: 0);

      expect(layout.singleSweep, isFalse);
      expect(layout.chunkSeconds, 30.0);
    });
  });
}
