import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/constants/app_constants.dart';
import '../audio/ring_buffer.dart';
import 'fft_processor.dart';
import 'spectrogram_painter.dart';

// =============================================================================
// Spectrogram Widget — Real-time scrolling FFT display
// =============================================================================
//
// Bridges the audio ring buffer, FFT processor, and CustomPainter into a
// single composable Flutter widget.
//
// ### Frame loop
//
// A [Ticker] drives the animation at up to 60 fps.  On each tick the widget:
//
//   1. Reads the most recent [fftSize] samples from the [RingBuffer].
//   2. Passes them through [FftProcessor.process] to get normalized dB bins.
//   3. Pushes the resulting column into [SpectrogramPainter.addColumn].
//   4. Calls `setState` which triggers `CustomPaint.markNeedsPaint`.
//
// The Ticker is started / stopped together with the [isActive] flag so no
// CPU is wasted when capture is paused.
//
// ### Time base — columns are paced by duration, not by FFT size
//
// The visible window always spans [displaySeconds], whatever [fftSize] is
// selected.  The column rate is a fixed function of the quality preset
// (see [SpectrogramTimebase]) so that it always stays well below the ~60 Hz
// vsync ceiling — a Ticker can emit at most one column per frame, so a rate
// above that silently drops columns and stretches the visible window.
//
// [fftSize] therefore controls *frequency* resolution only.  The column
// buffer is rendered at 1:1 into an image [SpectrogramTimebase.columnCount]
// wide and GPU-interpolated up to the widget's pixel width, so a coarse
// column grid still fills the display smoothly.
//
// This is a **display path only**.  Each column samples one FFT window at
// the moment it is emitted; audio falling between two columns is simply not
// drawn.  Detection is unaffected — the inference scheduler reads the same
// [RingBuffer] independently and sees every sample.
//
// ### Widget tree
//
// ```
// RepaintBoundary            ← isolates repaint from ancestors
//   └─ CustomPaint           ← full-bleed spectrogram (no rounded corners)
//       └─ CustomPaint       ← delegates to SpectrogramPainter
// ```
//
// [RepaintBoundary] is critical: without it, every spectrogram repaint would
// dirty the entire widget tree above it.
// =============================================================================

/// Displays a live scrolling spectrogram derived from audio data in a
/// [RingBuffer].
///
/// ### Required parameters
///
/// * [ringBuffer] — the audio ring buffer to read samples from.
/// * [isActive] — whether the spectrogram should animate (tied to capture
///   state).
///
/// ### Configurable parameters
///
/// * [fftSize] — FFT window size (power of two, default 2048).
/// * [colorMapName] — color palette (see [SpectrogramColorMap.names]).
/// * [dbFloor] / [dbCeiling] — dynamic range in dB.
/// * [displaySeconds] — length of the visible time window in seconds.
/// * [quality] — column rate / bin count / GPU filter preset.
class SpectrogramWidget extends StatefulWidget {
  const SpectrogramWidget({
    super.key,
    required this.ringBuffer,
    required this.isActive,
    this.fftSize = 2048,
    this.colorMapName = 'viridis',
    this.dbFloor = -80.0,
    this.dbCeiling = 0.0,
    this.displaySeconds = 20.0,
    this.showFrequencyAxis = true,
    this.showTimeAxis = true,
    this.maxDisplayFrequency = 0,
    this.logAmplitude = true,
    this.filterQuality,
    this.quality = 'medium',
  });

  /// The audio ring buffer to read samples from.
  final RingBuffer ringBuffer;

  /// Whether the spectrogram is actively processing and scrolling.
  ///
  /// When `false` the animation ticker is paused and no FFT work is done.
  final bool isActive;

  /// FFT window size (must be a power of two).
  final int fftSize;

  /// Color map name — must be one of [SpectrogramColorMap.names].
  final String colorMapName;

  /// Lower dB bound (maps to the darkest color).
  final double dbFloor;

  /// Upper dB bound (maps to the brightest color).
  final double dbCeiling;

  /// Length of the visible time window, in seconds.
  ///
  /// The spectrogram always scrolls so that exactly this much audio is on
  /// screen, independently of [fftSize] and [quality].
  final double displaySeconds;

  /// Whether to draw frequency axis labels on the left edge.
  final bool showFrequencyAxis;

  /// Whether to draw time axis labels on the bottom edge.
  final bool showTimeAxis;

  /// Maximum frequency (Hz) to display.  When > 0 only bins up to this
  /// frequency are rendered and overlay labels are drawn every 2 kHz.
  /// When 0 the full Nyquist range is shown.
  final int maxDisplayFrequency;

  /// Whether to apply logarithmic amplitude scaling.
  ///
  /// When true, normalized magnitudes are passed through a log curve that
  /// compresses the dynamic range, making quieter sounds more visible.
  final bool logAmplitude;

  /// GPU [FilterQuality] used to upscale the internal spectrogram image
  /// to the display rect. If null, mapped dynamically from [quality].
  final FilterQuality? filterQuality;

  /// Spectrogram rendering quality: 'low' | 'medium' | 'high'.
  final String quality;

  @override
  State<SpectrogramWidget> createState() => _SpectrogramWidgetState();
}

/// Maps the string value of `spectrogramQualityProvider` to a [FilterQuality].
///
/// Accepts `'low'`, `'medium'`, `'high'` (case-insensitive); any other
/// value falls back to [FilterQuality.medium].
FilterQuality spectrogramFilterQualityFromString(String value) {
  switch (value.toLowerCase()) {
    case 'low':
      return FilterQuality.low;
    case 'medium':
      return FilterQuality.medium;
    case 'high':
      return FilterQuality.high;
    default:
      return FilterQuality.medium;
  }
}

/// Maps the user's duration + quality settings onto the spectrogram's
/// column grid.
///
/// The single invariant this type exists to guarantee:
///
/// ```
/// columnCount * columnDuration == displaySeconds
/// ```
///
/// for **every** FFT size.  The FFT size only sets frequency resolution;
/// it must not influence how fast the display scrolls.
@immutable
class SpectrogramTimebase {
  const SpectrogramTimebase({
    required this.displaySeconds,
    required this.fftSize,
    this.quality = 'medium',
    this.sampleRate = AppConstants.sampleRate,
  });

  /// Length of the visible time window in seconds.
  final double displaySeconds;

  /// FFT window size in samples (frequency resolution only).
  final int fftSize;

  /// Quality preset: `'low'` | `'medium'` | `'high'`.
  final String quality;

  /// Audio sample rate in Hz.
  final int sampleRate;

  /// Number of spectrogram columns produced per second of audio.
  ///
  /// Deliberately **independent of [fftSize]**.  A [Ticker] emits at most
  /// one column per vsync (~60/s), so a rate derived from the FFT hop
  /// (`sampleRate / (fftSize / 2)` — 125/s at fftSize 512) cannot be
  /// sustained: columns are dropped and the visible window silently
  /// stretches to two or three times [displaySeconds].  A fixed rate per
  /// quality preset keeps the scroll speed matched to the setting.
  double get columnsPerSecond {
    switch (quality.toLowerCase()) {
      case 'low':
        return 20.0;
      case 'high':
        return 45.0;
      default:
        return 30.0;
    }
  }

  /// Column buffer size covering the full [displaySeconds] window.
  ///
  /// This is also the pixel width of the internal spectrogram image, which
  /// the painter interpolates up to the on-screen width — so a coarse grid
  /// still fills the display.
  int get columnCount =>
      math.max(2, (displaySeconds * columnsPerSecond).round());

  /// Wall-clock duration one column represents.
  Duration get columnDuration =>
      Duration(microseconds: (1000000 / columnsPerSecond).round());

  /// Audio advanced between two consecutive columns, in samples.
  ///
  /// When this exceeds [fftSize] the audio between two columns is only
  /// partly drawn.  That is fine — the spectrogram is a display, not an
  /// analysis path; the detector reads the ring buffer on its own schedule
  /// and never skips a sample.
  int get columnHopSamples =>
      math.max(1, (sampleRate / columnsPerSecond).round());
}

class _SpectrogramWidgetState extends State<SpectrogramWidget>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The FFT engine — recreated when [fftSize] or dB range changes.
  late FftProcessor _fft;

  /// The CustomPainter holding the scrolling column buffer.
  late SpectrogramPainter _painter;

  /// True after [_initProcessor] has run at least once.
  bool _painterInitialized = false;

  /// Ticker driving the 60 fps animation loop.
  late Ticker _ticker;

  /// Notifier used as the painter's [repaint] listenable.
  ///
  /// Incrementing this triggers `markNeedsPaint` on the render object.
  /// This is required because `setState` alone does NOT repaint a
  /// `CustomPaint` when the painter object reference is unchanged.
  final _repaintNotifier = ValueNotifier<int>(0);

  /// Number of FFT columns emitted since the ticker started.
  ///
  /// Used for time-based pacing: the target column count is derived from
  /// elapsed ticker time so that exactly one column is added per hop
  /// period, regardless of when audio chunks arrive.  This eliminates
  /// the bursty column generation that caused visible jumping.
  int _columnsEmitted = 0;

  /// Pre-allocated buffer for reading samples from the ring buffer.
  ///
  /// Avoids ~31 allocations/s of `Float32List(fftSize)` on the hot path.
  /// Recreated lazily when [fftSize] changes.
  late Float32List _readBuffer = Float32List(widget.fftSize);

  /// Column grid derived from the current duration / quality settings.
  SpectrogramTimebase get _timebase => SpectrogramTimebase(
    displaySeconds: widget.displaySeconds,
    fftSize: widget.fftSize,
    quality: widget.quality,
  );

  /// Resolves the GPU scaling quality filter.
  FilterQuality get _effectiveFilterQuality =>
      widget.filterQuality ??
      spectrogramFilterQualityFromString(widget.quality);

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initProcessor();
    _ticker = createTicker(_onTick);
    if (widget.isActive) _ticker.start();
  }

  @override
  void didUpdateWidget(SpectrogramWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Rebuild processor if FFT configuration changed.
    if (oldWidget.fftSize != widget.fftSize ||
        oldWidget.dbFloor != widget.dbFloor ||
        oldWidget.dbCeiling != widget.dbCeiling ||
        oldWidget.colorMapName != widget.colorMapName ||
        oldWidget.displaySeconds != widget.displaySeconds ||
        oldWidget.maxDisplayFrequency != widget.maxDisplayFrequency ||
        oldWidget.logAmplitude != widget.logAmplitude ||
        oldWidget.filterQuality != widget.filterQuality ||
        oldWidget.quality != widget.quality) {
      _initProcessor();
    }

    // Start / stop ticker based on active state.
    if (widget.isActive && !_ticker.isActive) {
      _columnsEmitted = 0; // Reset — elapsed restarts from zero.
      _ticker.start();
    } else if (!widget.isActive && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _painter.clear();
    _repaintNotifier.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// (Re)create the FFT processor and painter with current widget config.
  void _initProcessor() {
    // Dispose the previous painter's GPU image before replacing it to prevent
    // a ui.Image texture leak when settings change while the widget is live.
    // Guard against the first call from initState before _painter is assigned.
    if (_painterInitialized) _painter.clear();
    _painterInitialized = true;

    _fft = FftProcessor(
      fftSize: widget.fftSize,
      dbFloor: widget.dbFloor,
      dbCeiling: widget.dbCeiling,
    );

    final timebase = _timebase;

    _painter = SpectrogramPainter(
      maxColumns: timebase.columnCount,
      binCount: _fft.binCount,
      colorMapName: widget.colorMapName,
      sampleRate: AppConstants.sampleRate,
      fftSize: widget.fftSize,
      showFrequencyAxis: widget.showFrequencyAxis,
      showTimeAxis: widget.showTimeAxis,
      maxDisplayFrequency: widget.maxDisplayFrequency,
      hopDuration: timebase.columnDuration,
      filterQuality: _effectiveFilterQuality,
      repaint: _repaintNotifier,
      quality: widget.quality,
    );

    _columnsEmitted = 0;

    // Resize pre-allocated read buffer if FFT size changed.
    if (_readBuffer.length != widget.fftSize) {
      _readBuffer = Float32List(widget.fftSize);
    }
  }

  // ---------------------------------------------------------------------------
  // Animation loop
  // ---------------------------------------------------------------------------

  /// Called on every vsync (~60 fps).  Uses **time-based pacing** to add
  /// exactly one FFT column per hop period, regardless of when audio
  /// chunks arrive from the record package.
  ///
  /// This approach matches the PWA reference: column count is derived
  /// from elapsed wall-clock time so scrolling is perfectly smooth.
  void _onTick(Duration elapsed) {
    // Don't process until we have at least one FFT window of audio.
    if (widget.ringBuffer.totalWritten < widget.fftSize) return;

    final hopUs = _timebase.columnDuration.inMicroseconds;
    if (hopUs <= 0) return;

    // How many columns should have been emitted by this point in time?
    final targetColumns = elapsed.inMicroseconds ~/ hopUs;
    if (_columnsEmitted >= targetColumns) return; // Too early.

    // If we fell far behind (e.g. app suspended, GC pause), skip ahead
    // to avoid a burst of catch-up columns that would jar the display.
    if (targetColumns - _columnsEmitted > 3) {
      _columnsEmitted = targetColumns - 1;
    }

    // Read the most recent fftSize samples into pre-allocated buffer.
    widget.ringBuffer.readLastInto(_readBuffer, widget.fftSize);
    final column = _fft.process(_readBuffer);

    // The FFT processor already outputs Decibels (a logarithmic scale).
    // An additional log curve here compresses dynamic range too aggressively
    // and elevates the noise floor, so we use an exponential curve if
    // the user disabled log amplitude, to increase contrast.
    if (!widget.logAmplitude) {
      _applyExponentialContrast(column);
    }

    _painter.addColumn(column);
    _columnsEmitted++;

    // Build the spectrogram image asynchronously (uses toImage instead of
    // toImageSync to avoid a GPU memory leak).  Fire-and-forget: the
    // painter's _isBuilding guard prevents concurrent builds.
    _painter.rebuildImageAsync().then((_) {
      if (mounted) _repaintNotifier.value++;
    });
  }

  // ---------------------------------------------------------------------------
  // Linear / Contrast amplitude scaling
  // ---------------------------------------------------------------------------

  /// Applies an exponential curve to normalized [0, 1] dB values in [column].
  ///
  /// This expands the dynamic range (squashing quieter sounds towards 0),
  /// effectively pushing down the noise floor. Used when true 'logAmplitude' is off.
  static void _applyExponentialContrast(Float64List column) {
    const power = 2.0;
    for (var i = 0; i < column.length; i++) {
      column[i] = math.pow(column[i], power).toDouble();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _painter, size: Size.infinite),
    );
  }
}
