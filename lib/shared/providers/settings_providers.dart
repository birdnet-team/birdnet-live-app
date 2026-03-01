import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import 'app_providers.dart';

// ---------------------------------------------------------------------------
// Audio Settings
// ---------------------------------------------------------------------------

/// Audio gain (0.0 – 2.0, default 1.0).
final audioGainProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DoubleSettingNotifier(prefs, PrefKeys.audioGain, 1.0);
});

/// High-pass filter cutoff in Hz (0 = off, default 0).
final highPassFilterProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DoubleSettingNotifier(prefs, PrefKeys.highPassFilter, 0);
});

// ---------------------------------------------------------------------------
// Inference Settings
// ---------------------------------------------------------------------------

/// Window duration in seconds (3, 5, or 10).
final windowDurationProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IntSettingNotifier(prefs, PrefKeys.windowDuration, 3);
});

/// Confidence threshold (0 – 100, default 25).
final confidenceThresholdProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IntSettingNotifier(prefs, PrefKeys.confidenceThreshold, 25);
});

/// Inference rate in Hz (0.25, 0.5, 1.0, 2.0 — default 1.0).
final inferenceRateProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DoubleSettingNotifier(prefs, PrefKeys.inferenceRate, 1.0);
});

/// Species filter mode ('off', 'geoExclude', 'geoMerge', 'customList').
final speciesFilterModeProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StringSettingNotifier(prefs, PrefKeys.speciesFilterMode, 'off');
});

// ---------------------------------------------------------------------------
// Spectrogram Settings
// ---------------------------------------------------------------------------

/// FFT size (512, 1024, 2048, 4096 — default 2048).
final fftSizeProvider = StateNotifierProvider<IntSettingNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IntSettingNotifier(prefs, PrefKeys.fftSize, 2048);
});

/// Color map name (default 'viridis').
final colorMapProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StringSettingNotifier(prefs, PrefKeys.colorMap, 'viridis');
});

/// dB floor (default -80).
final dbFloorProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DoubleSettingNotifier(prefs, PrefKeys.dbFloor, -80);
});

/// dB ceiling (default 0).
final dbCeilingProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DoubleSettingNotifier(prefs, PrefKeys.dbCeiling, 0);
});

/// Spectrogram visible duration in seconds (5, 10, 15, 20, 30 — default 15).
final spectrogramDurationProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IntSettingNotifier(prefs, PrefKeys.spectrogramDuration, 15);
});

/// Maximum frequency displayed in the spectrogram in Hz (default 10000).
final spectrogramMaxFreqProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IntSettingNotifier(prefs, PrefKeys.spectrogramMaxFreq, 10000);
});

// ---------------------------------------------------------------------------
// Recording Settings
// ---------------------------------------------------------------------------

/// Recording format ('wav' or 'flac', default 'wav').
final recordingFormatProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StringSettingNotifier(prefs, PrefKeys.recordingFormat, 'wav');
});

/// Recording mode ('full', 'detections', 'off' — default 'off').
final recordingModeProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StringSettingNotifier(prefs, PrefKeys.recordingMode, 'off');
});

/// Pre-buffer seconds (default 5).
final preBufferProvider = StateNotifierProvider<IntSettingNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IntSettingNotifier(prefs, PrefKeys.preBuffer, 5);
});

/// Post-buffer seconds (default 5).
final postBufferProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IntSettingNotifier(prefs, PrefKeys.postBuffer, 5);
});

// ---------------------------------------------------------------------------
// Export Settings
// ---------------------------------------------------------------------------

/// Export format ('csv', 'json', 'gpx' — default 'csv').
final exportFormatProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StringSettingNotifier(prefs, PrefKeys.exportFormat, 'csv');
});

/// Include audio files in export (default false).
final includeAudioProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BoolSettingNotifier(prefs, PrefKeys.includeAudio, false);
});

// ===========================================================================
// Generic setting notifiers
// ===========================================================================

/// [StateNotifier] for a `double` setting backed by [SharedPreferences].
class DoubleSettingNotifier extends StateNotifier<double> {
  DoubleSettingNotifier(this._prefs, this._key, double defaultValue)
      : super(_prefs.getDouble(_key) ?? defaultValue);

  final SharedPreferences _prefs;
  final String _key;

  Future<void> set(double value) async {
    state = value;
    await _prefs.setDouble(_key, value);
  }
}

/// [StateNotifier] for an `int` setting backed by [SharedPreferences].
class IntSettingNotifier extends StateNotifier<int> {
  IntSettingNotifier(this._prefs, this._key, int defaultValue)
      : super(_prefs.getInt(_key) ?? defaultValue);

  final SharedPreferences _prefs;
  final String _key;

  Future<void> set(int value) async {
    state = value;
    await _prefs.setInt(_key, value);
  }
}

/// [StateNotifier] for a `String` setting backed by [SharedPreferences].
class StringSettingNotifier extends StateNotifier<String> {
  StringSettingNotifier(this._prefs, this._key, String defaultValue)
      : super(_prefs.getString(_key) ?? defaultValue);

  final SharedPreferences _prefs;
  final String _key;

  Future<void> set(String value) async {
    state = value;
    await _prefs.setString(_key, value);
  }
}

/// [StateNotifier] for a `bool` setting backed by [SharedPreferences].
class BoolSettingNotifier extends StateNotifier<bool> {
  BoolSettingNotifier(this._prefs, this._key, bool defaultValue)
      : super(_prefs.getBool(_key) ?? defaultValue);

  final SharedPreferences _prefs;
  final String _key;

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(_key, value);
  }
}
