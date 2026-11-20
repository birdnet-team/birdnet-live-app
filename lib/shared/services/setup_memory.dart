// =============================================================================
// Setup Memory — what a setup wizard was last started with
// =============================================================================
//
// Each setup wizard (Point Count, Survey, ARU, File Analysis) keeps one JSON
// object in SharedPreferences with the choices of the last session it
// started, so the next one opens the way the previous one was launched.
//
// Only choices that live in the wizard's own state belong here. Choices that
// already have a preference of their own (Point Count duration, the Survey
// parameters, …) are remembered by that preference, and anything that
// describes a single session — its name, its coordinates, a recording date —
// is not remembered at all.
//
// Reads never fail: a missing, corrupt, or out-of-range entry is the same as
// nothing remembered, and the caller falls back to its default.
// =============================================================================

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The remembered choices of one setup wizard.
class SetupMemory {
  const SetupMemory._(this._values);

  /// Reads what was stored under [key]; empty when nothing usable is there.
  factory SetupMemory.load(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.getString(key);
      if (raw != null) {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) return SetupMemory._(decoded);
      }
    } catch (_) {
      // Unreadable memory is no memory.
    }
    return const SetupMemory._({});
  }

  /// Replaces what is stored under [key] with [values]. Null values are
  /// left out, so that choice is not remembered.
  static Future<void> save(
    SharedPreferences prefs,
    String key,
    Map<String, Object?> values,
  ) {
    return prefs.setString(
      key,
      json.encode({
        for (final entry in values.entries)
          if (entry.value != null) entry.key: entry.value,
      }),
    );
  }

  final Map<String, dynamic> _values;

  bool? boolValue(String name) => switch (_values[name]) {
    final bool value => value,
    _ => null,
  };

  /// The remembered integer, or null when it is missing or outside
  /// [min]..[max].
  int? intValue(String name, {int? min, int? max}) {
    final value = _values[name];
    if (value is! int) return null;
    if (min != null && value < min) return null;
    if (max != null && value > max) return null;
    return value;
  }

  /// The remembered number, or null when it is missing or outside
  /// [min]..[max].
  double? doubleValue(String name, {double? min, double? max}) {
    final value = _values[name];
    if (value is! num) return null;
    final number = value.toDouble();
    if (!number.isFinite) return null;
    if (min != null && number < min) return null;
    if (max != null && number > max) return null;
    return number;
  }

  /// The remembered string, or null when it is missing or not one of
  /// [allowed].
  String? stringValue(String name, {Iterable<String>? allowed}) {
    final value = _values[name];
    if (value is! String) return null;
    if (allowed != null && !allowed.contains(value)) return null;
    return value;
  }

  /// The remembered member of [values], stored by name.
  T? enumValue<T extends Enum>(String name, List<T> values) {
    final value = _values[name];
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }
}
