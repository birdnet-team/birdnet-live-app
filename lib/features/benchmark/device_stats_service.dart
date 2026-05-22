import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Snapshot of device power and thermal metrics at a point in time.
class DeviceStatsSnapshot {
  const DeviceStatsSnapshot({
    this.currentUa,
    this.voltageMv,
    this.batteryLevel,
    this.thermalStatus,
    this.cpuTotalTicks,
    this.cpuIdleTicks,
    this.socModel,
  });

  /// Instantaneous battery current in µA (negative = discharging).
  final int? currentUa;

  /// Battery voltage in mV.
  final int? voltageMv;

  /// Battery level 0–100.
  final int? batteryLevel;

  /// Android thermal status 0–6, or -1 if unavailable (pre-API-29).
  final int? thermalStatus;

  /// Total CPU ticks (from /proc/stat) for delta calculation.
  final int? cpuTotalTicks;

  /// Idle CPU ticks (from /proc/stat) for delta calculation.
  final int? cpuIdleTicks;

  /// SoC model string (e.g. "GS301", "Tensor G4").
  final String? socModel;

  /// Approximate power draw in mW (|current µA| × voltage mV / 1 000 000).
  double? get powerMw {
    final c = currentUa;
    final v = voltageMv;
    if (c == null || v == null || v <= 0) return null;
    return (c.abs() * v) / 1000000.0;
  }
}

/// Computed stats from a pair of [DeviceStatsSnapshot]s.
class DeviceStatsDelta {
  const DeviceStatsDelta({
    this.avgCurrentUa,
    this.avgVoltageMv,
    this.avgPowerMw,
    this.cpuUsagePercent,
    this.thermalStatus,
    this.batteryLevel,
    this.socModel,
  });

  final int? avgCurrentUa;
  final int? avgVoltageMv;
  final double? avgPowerMw;
  final double? cpuUsagePercent;
  final int? thermalStatus;
  final int? batteryLevel;
  final String? socModel;

  String get thermalLabel {
    switch (thermalStatus) {
      case 0: return 'None';
      case 1: return 'Light';
      case 2: return 'Moderate';
      case 3: return 'Severe';
      case 4: return 'Critical';
      case 5: return 'Emergency';
      case 6: return 'Shutdown';
      default: return 'N/A';
    }
  }
}

class DeviceStatsService {
  static const _channel = MethodChannel('com.birdnet/device_stats');

  /// Take a snapshot of current device stats.
  static Future<DeviceStatsSnapshot> snapshot() async {
    int? currentUa, voltageMv, batteryLevel, thermalStatus;
    String? socModel;

    // Native stats (Android only).
    if (Platform.isAndroid) {
      try {
        final raw = await _channel.invokeMapMethod<String, dynamic>('getStats');
        if (raw != null) {
          currentUa = raw['currentUa'] as int?;
          voltageMv = raw['voltageMv'] as int?;
          batteryLevel = raw['batteryLevel'] as int?;
          thermalStatus = raw['thermalStatus'] as int?;
          socModel = raw['socModel'] as String?;
        }
      } catch (e) {
        debugPrint('[DeviceStats] channel error: $e');
      }
    }

    // CPU ticks from /proc/stat (Android + Linux).
    final (total, idle) = await _readCpuTicks();

    return DeviceStatsSnapshot(
      currentUa: currentUa,
      voltageMv: voltageMv,
      batteryLevel: batteryLevel,
      thermalStatus: thermalStatus,
      cpuTotalTicks: total,
      cpuIdleTicks: idle,
      socModel: socModel,
    );
  }

  /// Compute delta between two snapshots.
  static DeviceStatsDelta delta(
    DeviceStatsSnapshot before,
    DeviceStatsSnapshot after,
  ) {
    // Average power across the interval (start + end / 2).
    int? avgCurrent;
    int? avgVoltage;
    double? avgPower;

    final c1 = before.currentUa;
    final c2 = after.currentUa;
    final v1 = before.voltageMv;
    final v2 = after.voltageMv;

    if (c1 != null && c2 != null) {
      avgCurrent = ((c1.abs() + c2.abs()) / 2).round();
    }
    if (v1 != null && v2 != null) {
      avgVoltage = ((v1 + v2) / 2).round();
    }
    if (avgCurrent != null && avgVoltage != null && avgVoltage > 0) {
      avgPower = (avgCurrent * avgVoltage) / 1000000.0;
    }

    // CPU usage between snapshots.
    double? cpuPercent;
    final t1 = before.cpuTotalTicks;
    final t2 = after.cpuTotalTicks;
    final i1 = before.cpuIdleTicks;
    final i2 = after.cpuIdleTicks;
    if (t1 != null && t2 != null && i1 != null && i2 != null) {
      final deltaTot = t2 - t1;
      final deltaIdle = i2 - i1;
      if (deltaTot > 0) {
        cpuPercent = (1.0 - deltaIdle / deltaTot) * 100.0;
      }
    }

    return DeviceStatsDelta(
      avgCurrentUa: avgCurrent,
      avgVoltageMv: avgVoltage,
      avgPowerMw: avgPower,
      cpuUsagePercent: cpuPercent,
      thermalStatus: after.thermalStatus,
      batteryLevel: after.batteryLevel,
      socModel: after.socModel,
    );
  }

  /// Read total and idle CPU ticks from /proc/stat.
  ///
  /// Returns (total, idle) or (null, null) on unsupported platforms.
  static Future<(int?, int?)> _readCpuTicks() async {
    if (!Platform.isAndroid && !Platform.isLinux) return (null, null);
    try {
      final lines = await File('/proc/stat').readAsLines();
      final cpuLine = lines.firstWhere(
        (l) => l.startsWith('cpu '),
        orElse: () => '',
      );
      if (cpuLine.isEmpty) return (null, null);

      // Fields: user nice system idle iowait irq softirq [steal guest ...]
      final parts = cpuLine.split(RegExp(r'\s+')).skip(1).toList();
      if (parts.length < 4) return (null, null);

      final values = parts.map((s) => int.tryParse(s) ?? 0).toList();
      final idle = values[3] + (values.length > 4 ? values[4] : 0); // idle + iowait
      final total = values.fold(0, (a, b) => a + b);
      return (total, idle);
    } catch (_) {
      return (null, null);
    }
  }
}
