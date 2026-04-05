// =============================================================================
// Memory Monitor — Periodic process memory tracking
// =============================================================================
//
// Reads VmRSS (resident set size) from /proc/self/status on Android/Linux
// to track total process memory usage including native allocations (ONNX
// Runtime, GPU textures, etc.) that the Dart VM's own metrics don't cover.
//
// On platforms where /proc/self/status is unavailable, falls back to
// reporting -1 for all values.
//
// ### Usage
//
// ```dart
// MemoryMonitor.logOnce(tag: 'after model load');
// MemoryMonitor.startPeriodic(intervalSeconds: 5);
// // … later …
// MemoryMonitor.stop();
// ```
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Snapshot of process memory at a point in time.
class MemorySnapshot {
  const MemorySnapshot({
    required this.timestampMs,
    required this.vmRssKb,
    required this.vmSizeKb,
    required this.vmDataKb,
  });

  /// Milliseconds since epoch.
  final int timestampMs;

  /// Resident set size in KB (physical memory actually used).
  /// -1 if unavailable.
  final int vmRssKb;

  /// Virtual memory size in KB (total address space).
  /// -1 if unavailable.
  final int vmSizeKb;

  /// Data + stack segment size in KB (heap + stack).
  /// -1 if unavailable.
  final int vmDataKb;

  /// RSS in megabytes for convenient logging.
  double get vmRssMb => vmRssKb / 1024.0;

  /// VmSize in megabytes.
  double get vmSizeMb => vmSizeKb / 1024.0;

  @override
  String toString() => 'RSS=${vmRssMb.toStringAsFixed(1)}MB '
      'VmSize=${vmSizeMb.toStringAsFixed(1)}MB '
      'VmData=${(vmDataKb / 1024.0).toStringAsFixed(1)}MB';
}

/// Lightweight process memory monitor.
///
/// Reads /proc/self/status (Android/Linux) to track RSS and virtual memory.
/// All methods are safe to call on any platform — they return -1 values
/// when /proc is unavailable.
class MemoryMonitor {
  MemoryMonitor._();

  static Timer? _timer;
  static final List<MemorySnapshot> _history = [];
  static int _startMs = 0;

  /// All snapshots collected since [startPeriodic] was called.
  static List<MemorySnapshot> get history => List.unmodifiable(_history);

  /// Take a single memory snapshot and log it.
  static MemorySnapshot logOnce({String tag = ''}) {
    final snap = _readMemory();
    final prefix = tag.isNotEmpty ? '[$tag] ' : '';
    debugPrint('[MemoryMonitor] ${prefix}$snap');
    return snap;
  }

  /// Start periodic memory logging.
  ///
  /// Logs a snapshot every [intervalSeconds] seconds and accumulates
  /// them in [history] for later analysis.
  static void startPeriodic({int intervalSeconds = 5}) {
    stop(); // Cancel any existing timer.
    _history.clear();
    _startMs = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[MemoryMonitor] started (interval=${intervalSeconds}s)');

    // Immediate first reading.
    _tick();

    _timer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _tick(),
    );
  }

  /// Stop periodic monitoring.
  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Print a summary of memory growth over the monitoring period.
  static void printSummary() {
    if (_history.isEmpty) {
      debugPrint('[MemoryMonitor] no data collected');
      return;
    }

    final first = _history.first;
    final last = _history.last;
    final durationSec = (last.timestampMs - first.timestampMs) / 1000.0;
    final rssGrowthMb = last.vmRssMb - first.vmRssMb;
    final ratePerMin =
        durationSec > 0 ? rssGrowthMb / (durationSec / 60.0) : 0.0;

    debugPrint('[MemoryMonitor] ═══ SUMMARY ═══');
    debugPrint('[MemoryMonitor] Duration: ${durationSec.toStringAsFixed(1)}s');
    debugPrint(
        '[MemoryMonitor] RSS start: ${first.vmRssMb.toStringAsFixed(1)}MB');
    debugPrint(
        '[MemoryMonitor] RSS end:   ${last.vmRssMb.toStringAsFixed(1)}MB');
    debugPrint(
        '[MemoryMonitor] RSS growth: ${rssGrowthMb.toStringAsFixed(1)}MB '
        '(${ratePerMin.toStringAsFixed(1)}MB/min)');
    debugPrint('[MemoryMonitor] Snapshots: ${_history.length}');

    // Find peak.
    var peakRss = first.vmRssKb;
    for (final s in _history) {
      if (s.vmRssKb > peakRss) peakRss = s.vmRssKb;
    }
    debugPrint(
        '[MemoryMonitor] RSS peak:  ${(peakRss / 1024.0).toStringAsFixed(1)}MB');
    debugPrint('[MemoryMonitor] ═══════════════');
  }

  static void _tick() {
    final snap = _readMemory();
    _history.add(snap);
    final elapsedSec = (snap.timestampMs - _startMs) / 1000.0;
    debugPrint('[MemoryMonitor] t=${elapsedSec.toStringAsFixed(0)}s $snap');
  }

  /// Read memory stats from /proc/self/status.
  static MemorySnapshot _readMemory() {
    int vmRss = -1;
    int vmSize = -1;
    int vmData = -1;

    try {
      final status = File('/proc/self/status').readAsStringSync();
      for (final line in status.split('\n')) {
        if (line.startsWith('VmRSS:')) {
          vmRss = _parseKb(line);
        } else if (line.startsWith('VmSize:')) {
          vmSize = _parseKb(line);
        } else if (line.startsWith('VmData:')) {
          vmData = _parseKb(line);
        }
      }
    } catch (_) {
      // /proc not available (iOS, Windows, etc.)
    }

    return MemorySnapshot(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      vmRssKb: vmRss,
      vmSizeKb: vmSize,
      vmDataKb: vmData,
    );
  }

  /// Parse "VmRSS:    123456 kB" → 123456.
  static int _parseKb(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return int.tryParse(parts[1]) ?? -1;
    }
    return -1;
  }
}
