import 'dart:typed_data';

// =============================================================================
// Ring Buffer — Lock-free circular audio sample store
// =============================================================================
//
// This ring buffer is the heart of the audio pipeline.  All captured PCM
// samples flow through here before being consumed by:
//
//   • The **spectrogram** — reads a sliding FFT window via [readLast].
//   • The **inference engine** — reads the most recent N seconds.
//   • The **level meter** — reads a small recent window via [rmsLevel].
//
// ### Threading model
//
// Designed for single-writer (capture isolate) / single-reader (UI isolate)
// usage.  The writer only advances [_writePos]; the reader only reads it.
// No locks are needed because [_writePos] is a single int whose writes are
// atomic on all Dart VMs.
//
// ### Capacity
//
// Default capacity = 2 × 10 s × 32 000 Hz = **640 000** samples, ensuring
// that even while the model processes a 10-second window the capture can
// continue writing without overwriting unread data.
// =============================================================================

/// Lock-free ring buffer for audio samples.
///
/// Stores mono float32 audio samples in a fixed-capacity [Float32List].
/// Capacity is always 2× the maximum window size (10s × 32 kHz = 640 000
/// samples) so that full windows can be read while new data is being
/// written.
///
/// This implementation is **single-writer / single-reader safe** for use
/// across isolates when the writer only advances [_writePos] and the
/// reader only reads it.
class RingBuffer {
  /// Creates a ring buffer with [capacity] samples.
  ///
  /// Default capacity = 2 × 10 s × 32 000 Hz = 640 000 samples.
  RingBuffer({this.capacity = 640000}) : _buffer = Float32List(capacity);

  /// Maximum number of samples the buffer can hold.
  final int capacity;

  /// Internal storage.
  final Float32List _buffer;

  /// Current write position (wraps around via modulo).
  int _writePos = 0;

  /// Total number of samples written since creation / last reset.
  int _totalWritten = 0;

  /// Number of samples available for reading (capped at [capacity]).
  int get available => _totalWritten < capacity ? _totalWritten : capacity;

  /// Total samples written since creation.
  int get totalWritten => _totalWritten;

  /// Whether the buffer has been filled at least once.
  bool get isFull => _totalWritten >= capacity;

  /// Current write position (for diagnostics).
  int get writePosition => _writePos;

  // -----------------------------------------------------------------------
  // Writing
  // -----------------------------------------------------------------------

  /// Append [samples] to the buffer.
  ///
  /// If the data is larger than [capacity], only the last [capacity]
  /// samples are kept.
  void write(Float32List samples) {
    final len = samples.length;

    if (len >= capacity) {
      // Only keep the last `capacity` samples.
      _buffer.setAll(0, samples.sublist(len - capacity));
      _writePos = 0;
      _totalWritten += len;
      return;
    }

    final remaining = capacity - _writePos;

    if (len <= remaining) {
      // Fits without wrapping.
      _buffer.setRange(_writePos, _writePos + len, samples);
    } else {
      // Wraps around.
      _buffer.setRange(_writePos, capacity, samples, 0);
      _buffer.setRange(0, len - remaining, samples, remaining);
    }

    _writePos = (_writePos + len) % capacity;
    _totalWritten += len;
  }

  /// Write a single sample. Useful for format conversion loops.
  void writeSample(double sample) {
    _buffer[_writePos] = sample;
    _writePos = (_writePos + 1) % capacity;
    _totalWritten++;
  }

  // -----------------------------------------------------------------------
  // Reading
  // -----------------------------------------------------------------------

  /// Read the most recent [count] samples into a new [Float32List].
  ///
  /// If fewer than [count] samples are available the returned list is
  /// zero-padded at the beginning (suitable for feeding the model which
  /// expects a fixed-length input).
  Float32List readLast(int count) {
    final result = Float32List(count);
    final avail = available;

    if (avail == 0) return result;

    final toRead = count > avail ? avail : count;
    final offset = count - toRead; // zero-padding offset

    // Start position in the ring for the oldest of the `toRead` samples.
    final start = (_writePos - toRead + capacity) % capacity;

    if (start + toRead <= capacity) {
      // Contiguous read.
      result.setRange(offset, count, _buffer, start);
    } else {
      // Wrapped read.
      final firstChunk = capacity - start;
      result.setRange(offset, offset + firstChunk, _buffer, start);
      result.setRange(offset + firstChunk, count, _buffer, 0);
    }

    return result;
  }

  /// Read all available samples (up to [capacity]).
  Float32List readAll() => readLast(available);

  // -----------------------------------------------------------------------
  // Utilities
  // -----------------------------------------------------------------------

  /// Reset the buffer to empty state.
  void clear() {
    _writePos = 0;
    _totalWritten = 0;
    // The underlying memory is not zeroed for performance.
  }

  /// Compute the RMS (root-mean-square) level of the most recent
  /// [windowSize] samples, returned in the range [0.0, 1.0].
  ///
  /// This is efficient for a live level meter — no allocation needed.
  double rmsLevel({int windowSize = 4096}) {
    final avail = available;
    if (avail == 0) return 0;

    final n = windowSize > avail ? avail : windowSize;
    var sum = 0.0;

    var pos = (_writePos - n + capacity) % capacity;
    for (var i = 0; i < n; i++) {
      final s = _buffer[pos];
      sum += s * s;
      pos = (pos + 1) % capacity;
    }

    return _sqrt(sum / n);
  }

  /// Compute peak absolute amplitude of the most recent [windowSize]
  /// samples.
  double peakLevel({int windowSize = 4096}) {
    final avail = available;
    if (avail == 0) return 0;

    final n = windowSize > avail ? avail : windowSize;
    var peak = 0.0;

    var pos = (_writePos - n + capacity) % capacity;
    for (var i = 0; i < n; i++) {
      final abs = _buffer[pos].abs();
      if (abs > peak) peak = abs;
      pos = (pos + 1) % capacity;
    }

    return peak;
  }

  // Dart doesn't expose a simple sqrt at the top level in dart:typed_data,
  // so we use a fast Newton approximation for level metering where exact
  // precision isn't critical.  For unit tests we can compare against a
  // tolerance.
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    var guess = x;
    for (var i = 0; i < 10; i++) {
      guess = 0.5 * (guess + x / guess);
    }
    return guess;
  }
}
