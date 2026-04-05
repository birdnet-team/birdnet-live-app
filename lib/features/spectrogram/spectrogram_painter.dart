import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'color_maps.dart';

// =============================================================================
// Spectrogram Painter — CustomPainter for scrolling FFT visualisation
// =============================================================================
//
// The painter maintains a rolling history of FFT columns.  Each column is a
// [Float64List] of normalized magnitudes (0–1) per frequency bin, newest on
// the right.  The widget that owns this painter is responsible for calling
// `addColumn()` to push new data and then requesting a repaint.
//
// ### Rendering strategy — synchronous canvas-shift
//
// Inspired by the PWA's `drawSpectrogram()` which performs a canvas self-blit
// (shift left, draw new columns on the right), this painter uses Flutter's
// [Picture.toImageSync] for fully synchronous rendering:
//
// 1. On each paint where new columns have arrived:
//    a. Create a [PictureRecorder] + offscreen [Canvas].
//    b. Draw the previous [_spectrogramImage] shifted left by N columns.
//    c. Draw the N new columns as colored rectangles on the right edge.
//    d. Call [Picture.toImageSync] to produce a new GPU-backed [ui.Image].
//
// 2. The resulting image is composited to the main canvas with a single
//    [drawImageRect] — GPU-accelerated and zero-latency.
//
// This approach eliminates the async `decodeImageFromPixels` used previously,
// which caused the spectrogram to appear frozen during active recording
// because decode callbacks could not keep up with the frame rate.
//
// ### Memory budget
//
// At most [maxColumns] columns × [binCount] doubles are stored.  With the
// default 600 columns × 1025 bins ≈ 4.7 MB — well within budget.
// One [ui.Image] of the spectrogram area size is also kept (~1–2 MB).
// =============================================================================

/// Paints a scrolling spectrogram using time-domain FFT column data.
///
/// The parent widget feeds data via [addColumn] and triggers repaint.
class SpectrogramPainter extends CustomPainter {
  /// Creates a painter that can hold up to [maxColumns] FFT snapshots.
  ///
  /// [colorMapName] selects the palette from [SpectrogramColorMap.names].
  /// [sampleRate] is needed to compute axis frequency labels.
  /// [fftSize] is needed to compute the frequency resolution.
  SpectrogramPainter({
    required this.maxColumns,
    required this.binCount,
    required this.colorMapName,
    required this.sampleRate,
    required this.fftSize,
    this.showFrequencyAxis = true,
    this.showTimeAxis = true,
    this.maxDisplayFrequency = 0,
    this.hopDuration = const Duration(milliseconds: 50),
    super.repaint,
  }) : _lut = SpectrogramColorMap.lut(colorMapName);

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Maximum number of FFT columns shown (width of the scrolling window).
  final int maxColumns;

  /// Number of frequency bins per column (fftSize / 2 + 1).
  final int binCount;

  /// Active color map name (e.g., 'viridis', 'birdnet').
  final String colorMapName;

  /// Audio sample rate in Hz — used for frequency axis labels.
  final int sampleRate;

  /// FFT size — used together with [sampleRate] for bin→Hz conversion.
  final int fftSize;

  /// Whether to render frequency axis labels (left edge).
  final bool showFrequencyAxis;

  /// Whether to render time axis labels (bottom edge).
  final bool showTimeAxis;

  /// Maximum frequency (Hz) to display.  When > 0 only bins up to this
  /// frequency are rendered and overlay labels are drawn every 2 kHz.
  /// When 0 the full Nyquist range is shown.
  final int maxDisplayFrequency;

  /// Duration represented by each column — used for time axis labels.
  final Duration hopDuration;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  /// Pre-fetched color look-up table (256 ARGB entries).
  final Int32List _lut;

  /// Rolling list of FFT columns (oldest first, newest last).
  final List<Float64List> _columns = [];

  /// Accumulated spectrogram image — shift-blitted on each paint.
  ui.Image? _spectrogramImage;

  /// Number of new columns added since the last image build.
  int _newSinceLastPaint = 0;

  /// Whether an async image build is currently in progress.
  bool _isBuilding = false;

  /// Reusable paint for drawing individual bin cells.
  final Paint _cellPaint = Paint()..style = PaintingStyle.fill;

  // ---------------------------------------------------------------------------
  // Public data API
  // ---------------------------------------------------------------------------

  /// Push a new FFT column onto the rolling buffer.
  ///
  /// [column] must have [binCount] elements, each in [0.0, 1.0].
  /// Call `markNeedsPaint()` on the owning [RenderObject] after this.
  void addColumn(Float64List column) {
    assert(column.length == binCount,
        'Column length ${column.length} != binCount $binCount');
    _columns.add(column);
    if (_columns.length > maxColumns) {
      _columns.removeAt(0);
    }
    _newSinceLastPaint++;
  }

  /// Number of columns currently held.
  int get columnCount => _columns.length;

  /// Remove all column data and reset the image cache.
  void clear() {
    _columns.clear();
    _spectrogramImage?.dispose();
    _spectrogramImage = null;
    _newSinceLastPaint = 0;
    _isBuilding = false;
  }

  // ---------------------------------------------------------------------------
  // CustomPainter overrides
  // ---------------------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    if (_columns.isEmpty) {
      _paintEmptyState(canvas, size);
      return;
    }

    // Compute layout insets for axes.
    final leftInset = showFrequencyAxis ? 48.0 : 0.0;
    final bottomInset = showTimeAxis ? 24.0 : 0.0;
    final spectrogramRect = Rect.fromLTWH(
      leftInset,
      0,
      size.width - leftInset,
      size.height - bottomInset,
    );

    final w = spectrogramRect.width.ceil();
    final h = spectrogramRect.height.ceil();
    if (w <= 0 || h <= 0) return;

    // Compute effective max frequency for axis overlay.
    final effectiveMaxFreq =
        maxDisplayFrequency > 0 ? maxDisplayFrequency : (sampleRate ~/ 2);

    // Draw the spectrogram image scaled to the display area.
    // The internal image is at 1:1 pixel resolution (maxColumns × binCount).
    // GPU bilinear filtering (FilterQuality.low) smooths the upscale.
    if (_spectrogramImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        _spectrogramImage!.width.toDouble(),
        _spectrogramImage!.height.toDouble(),
      );
      canvas.drawImageRect(
        _spectrogramImage!,
        src,
        spectrogramRect,
        Paint()..filterQuality = FilterQuality.low,
      );
    }

    // Draw axes.
    if (showFrequencyAxis) {
      _paintFrequencyAxis(canvas, size, spectrogramRect);
    }
    if (showTimeAxis) {
      _paintTimeAxis(canvas, size, spectrogramRect);
    }
    // Always draw overlay frequency labels when a max frequency is set.
    if (maxDisplayFrequency > 0) {
      _paintFrequencyOverlay(canvas, spectrogramRect, effectiveMaxFreq);
    }
  }

  @override
  bool shouldRepaint(covariant SpectrogramPainter oldDelegate) {
    // Repaint on any structural change.
    return oldDelegate.colorMapName != colorMapName ||
        oldDelegate.binCount != binCount ||
        oldDelegate.maxColumns != maxColumns ||
        oldDelegate.maxDisplayFrequency != maxDisplayFrequency;
  }

  // ---------------------------------------------------------------------------
  // Synchronous image building — canvas-shift at 1:1 pixel resolution
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Async image building — replaces synchronous toImageSync to avoid
  // a GPU memory leak in the Flutter engine (toImageSync leaks ~42 KB
  // per call, causing OOM after ~3 min of continuous spectrogram updates).
  // ---------------------------------------------------------------------------

  /// Number of frequency bins to display (constant per painter lifetime).
  int get displayBins {
    final effectiveMaxFreq =
        maxDisplayFrequency > 0 ? maxDisplayFrequency : (sampleRate ~/ 2);
    return (effectiveMaxFreq * fftSize / sampleRate).round().clamp(1, binCount);
  }

  /// Asynchronously rebuild the spectrogram image if new columns have
  /// been added since the last build.  Returns immediately if a build
  /// is already in progress.
  ///
  /// Call this from the widget's tick callback after [addColumn].
  Future<void> rebuildImageAsync() async {
    if (_isBuilding || _newSinceLastPaint == 0 || _columns.isEmpty) return;
    _isBuilding = true;
    try {
      final colsToProcess = _newSinceLastPaint;
      await _buildImageAsync(colsToProcess);
      // Only subtract the columns we actually processed — more may have
      // arrived during the async gap.
      _newSinceLastPaint -= colsToProcess;
    } finally {
      _isBuilding = false;
    }
  }

  /// Build or update the spectrogram image asynchronously.
  ///
  /// Uses [Picture.toImage] (async) instead of [Picture.toImageSync] to
  /// avoid a GPU texture leak on Android.  The async variant properly
  /// reclaims textures through the raster thread's resource lifecycle.
  Future<void> _buildImageAsync(int newCols) async {
    final cols = _columns.length;
    if (cols == 0) return;

    final imgW = maxColumns;
    final imgH = displayBins;
    newCols = newCols.clamp(0, cols);

    final recorder = ui.PictureRecorder();
    final offscreen = Canvas(recorder);

    final clearPaint = Paint()..color = Color(_lut[0]);

    if (_spectrogramImage != null &&
        _spectrogramImage!.width == imgW &&
        newCols < imgW) {
      final keepW = imgW - newCols;

      offscreen.drawImageRect(
        _spectrogramImage!,
        Rect.fromLTWH(newCols.toDouble(), 0, keepW.toDouble(), imgH.toDouble()),
        Rect.fromLTWH(0, 0, keepW.toDouble(), imgH.toDouble()),
        Paint()..filterQuality = FilterQuality.none,
      );

      offscreen.drawRect(
        Rect.fromLTWH(keepW.toDouble(), 0, newCols.toDouble(), imgH.toDouble()),
        clearPaint,
      );
    } else {
      offscreen.drawRect(
        Rect.fromLTWH(0, 0, imgW.toDouble(), imgH.toDouble()),
        clearPaint,
      );
    }

    _drawNewColumnsPixel(offscreen, imgW, imgH, newCols);

    final picture = recorder.endRecording();
    final newImage = await picture.toImage(imgW, imgH);
    picture.dispose();

    _spectrogramImage?.dispose();
    _spectrogramImage = newImage;
  }

  /// Draw [newCols] new columns at 1:1 pixel resolution.
  ///
  /// Each column is exactly 1 pixel wide and [binCount] pixels tall.
  void _drawNewColumnsPixel(Canvas canvas, int imgW, int imgH, int newCols) {
    final numCols = _columns.length;

    for (var i = 0; i < newCols; i++) {
      final colIdx = numCols - newCols + i;
      if (colIdx < 0 || colIdx >= numCols) continue;

      final column = _columns[colIdx];
      final x = (imgW - newCols + i).toDouble();

      for (var y = 0; y < imgH; y++) {
        // Flip vertically — low frequencies at the bottom.
        final srcBin = imgH - 1 - y;
        final value = srcBin < column.length ? column[srcBin] : 0.0;

        // If the value maps to the 0th index, it's already the background color.
        final lutIndex = (value * 255).round().clamp(0, 255);
        if (lutIndex == 0) continue;

        _cellPaint.color = Color(_lut[lutIndex]);
        canvas.drawRect(Rect.fromLTWH(x, y.toDouble(), 1, 1), _cellPaint);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Axis rendering
  // ---------------------------------------------------------------------------

  /// Draw frequency labels along the left edge.
  ///
  /// Shows labels at 1 kHz, 2 kHz, 4 kHz, 8 kHz, and 16 kHz when they
  /// fall within the Nyquist frequency.
  void _paintFrequencyAxis(Canvas canvas, Size size, Rect spectrogramRect) {
    final nyquist = sampleRate / 2;
    final labelFreqs = <double>[1000, 2000, 4000, 8000, 10000]
        .where((f) => f < nyquist)
        .toList();

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    final labelStyle = TextStyle(
      color: Colors.white.withAlpha(179),
      fontSize: 10,
    );

    final linePaint = Paint()
      ..color = Colors.white.withAlpha(51)
      ..strokeWidth = 0.5;

    for (final freq in labelFreqs) {
      // Normalize frequency to vertical position (0 = bottom = 0 Hz).
      final normY = freq / nyquist;
      final y = spectrogramRect.bottom - normY * spectrogramRect.height;

      if (y < spectrogramRect.top || y > spectrogramRect.bottom) continue;

      // Horizontal guide line.
      canvas.drawLine(
        Offset(spectrogramRect.left, y),
        Offset(spectrogramRect.right, y),
        linePaint,
      );

      // Label text.
      final label = freq >= 1000
          ? '${(freq / 1000).toStringAsFixed(0)}k'
          : '${freq.toInt()}';
      textPainter.text = TextSpan(text: label, style: labelStyle);
      textPainter.layout(maxWidth: 44);
      textPainter.paint(
        canvas,
        Offset(spectrogramRect.left - textPainter.width - 4,
            y - textPainter.height / 2),
      );
    }
  }

  /// Draw time labels along the bottom edge.
  ///
  /// Labels are rendered at regular intervals showing seconds of elapsed
  /// scrolling time.  The rightmost column represents "now".
  void _paintTimeAxis(Canvas canvas, Size size, Rect spectrogramRect) {
    final totalSeconds = _columns.length * hopDuration.inMilliseconds / 1000.0;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final labelStyle = TextStyle(
      color: Colors.white.withAlpha(179),
      fontSize: 10,
    );

    // Determine a good interval for labels (aim for ~5–8 labels).
    final interval = _timeInterval(totalSeconds);
    if (interval <= 0) return;

    final colWidth = spectrogramRect.width / _columns.length;

    for (var t = 0.0; t <= totalSeconds; t += interval) {
      // Column index from the left (oldest data).
      final colIndex = t / (hopDuration.inMilliseconds / 1000.0);
      final x = spectrogramRect.left + colIndex * colWidth;

      if (x < spectrogramRect.left || x > spectrogramRect.right) continue;

      final secsAgo = totalSeconds - t;
      final label = secsAgo < 0.05
          ? '0s'
          : '-${secsAgo.toStringAsFixed(secsAgo < 10 ? 1 : 0)}s';

      textPainter.text = TextSpan(text: label, style: labelStyle);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, spectrogramRect.bottom + 4),
      );
    }
  }

  /// Choose a round time interval for label spacing.
  double _timeInterval(double totalSeconds) {
    if (totalSeconds <= 0) return 0;
    const candidates = [0.5, 1, 2, 5, 10, 15, 30, 60];
    for (final c in candidates) {
      if (totalSeconds / c <= 8) return c.toDouble();
    }
    return 60;
  }

  /// Draw frequency labels as a semi-transparent overlay inside the
  /// spectrogram area every 2 kHz.
  void _paintFrequencyOverlay(
      Canvas canvas, Rect spectrogramRect, int effectiveMaxFreq) {
    // Generate labels every 2 kHz up to (but not including) the max.
    final labelFreqs = <double>[
      for (var f = 2000.0; f < effectiveMaxFreq; f += 2000) f,
    ];
    if (labelFreqs.isEmpty) return;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    final labelStyle = TextStyle(
      color: Colors.white.withAlpha(200),
      fontSize: 10,
      fontWeight: FontWeight.w500,
      shadows: const [
        Shadow(blurRadius: 3, color: Colors.black),
        Shadow(blurRadius: 6, color: Colors.black),
      ],
    );

    final linePaint = Paint()
      ..color = Colors.white.withAlpha(38)
      ..strokeWidth = 0.5;

    for (final freq in labelFreqs) {
      final normY = freq / effectiveMaxFreq;
      final y = spectrogramRect.bottom - normY * spectrogramRect.height;

      if (y < spectrogramRect.top || y > spectrogramRect.bottom) continue;

      // Horizontal guide line.
      canvas.drawLine(
        Offset(spectrogramRect.left, y),
        Offset(spectrogramRect.right, y),
        linePaint,
      );

      // Label text — drawn inside the spectrogram near the left edge.
      final label = '${(freq / 1000).toStringAsFixed(0)}k';
      textPainter.text = TextSpan(text: label, style: labelStyle);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(spectrogramRect.left + 4, y - textPainter.height - 1),
      );
    }
  }

  /// Paint the empty state shown when no data is available.
  void _paintEmptyState(Canvas canvas, Size size) {
    // Fill with the base color of the selected color map.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Color(_lut[0]),
    );
  }
}
