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
/// * [maxColumns] — number of FFT columns visible (scrolling width).
/// * [hopSize] — samples between successive FFT frames.  Smaller = smoother
///   but more CPU.  Default is `fftSize ~/ 2` (50 % overlap).
class SpectrogramWidget extends StatefulWidget {
  const SpectrogramWidget({
    super.key,
    required this.ringBuffer,
    required this.isActive,
    this.fftSize = 2048,
    this.colorMapName = 'viridis',
    this.dbFloor = -80.0,
    this.dbCeiling = 0.0,
    this.maxColumns = 600,
    this.hopSize,
    this.showFrequencyAxis = true,
    this.showTimeAxis = true,
    this.maxDisplayFrequency = 0,
    this.logAmplitude = true,
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

  /// Maximum number of visible columns (determines scrolling width).
  /// More columns = longer visible duration but more memory.
  final int maxColumns;

  /// Number of new samples between successive FFT frames.
  ///
  /// Defaults to `fftSize ~/ 2` (50 % overlap) when `null`.
  final int? hopSize;

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

  @override
  State<SpectrogramWidget> createState() => _SpectrogramWidgetState();
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

  /// Effective hop size (user-supplied or default 50 % overlap).
  int get _hopSize => widget.hopSize ?? (widget.fftSize ~/ 2);

  /// Duration each column represents — used for time axis labels.
  Duration get _hopDuration =>
      Duration(microseconds: (_hopSize * 1000000 ~/ AppConstants.sampleRate));

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
        oldWidget.maxColumns != widget.maxColumns ||
        oldWidget.maxDisplayFrequency != widget.maxDisplayFrequency ||
        oldWidget.logAmplitude != widget.logAmplitude) {
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
  // Initialisation
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

    _painter = SpectrogramPainter(
      maxColumns: widget.maxColumns,
      binCount: _fft.binCount,
      colorMapName: widget.colorMapName,
      sampleRate: AppConstants.sampleRate,
      fftSize: widget.fftSize,
      showFrequencyAxis: widget.showFrequencyAxis,
      showTimeAxis: widget.showTimeAxis,
      maxDisplayFrequency: widget.maxDisplayFrequency,
      hopDuration: _hopDuration,
      repaint: _repaintNotifier,
    );

    _columnsEmitted = 0;
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

    final hopUs = _hopDuration.inMicroseconds;
    if (hopUs <= 0) return;

    // How many columns should have been emitted by this point in time?
    final targetColumns = elapsed.inMicroseconds ~/ hopUs;
    if (_columnsEmitted >= targetColumns) return; // Too early.

    // If we fell far behind (e.g. app suspended, GC pause), skip ahead
    // to avoid a burst of catch-up columns that would jar the display.
    if (targetColumns - _columnsEmitted > 3) {
      _columnsEmitted = targetColumns - 1;
    }

    // Read the most recent fftSize samples and add a single column.
    final samples = widget.ringBuffer.readLast(widget.fftSize);
    final column = _fft.process(samples);

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
      child: CustomPaint(
        painter: _painter,
        size: Size.infinite,
      ),
    );
  }
}
