// =============================================================================
// export_metadata_helper.dart
//
// Builds the provenance-rich metadata block embedded in JSON exports
// and dropped as `<prefix>.metadata.json` inside ZIP bundles.
//
// Captures:
//   * App name + version + build number + package name (PackageInfo).
//   * Readable device model and OS version, without a device ID.
//   * Both ONNX model blocks from `assets/models/model_config.json`.
//   * A curated snapshot of relevant SharedPreferences key/value pairs.
//   * Session-level provenance (id, type, timestamps, observer, weather…)
//     via `buildExportMetadata` in `session_export.dart`.
//
// Used by both the session review screen (its in-place export menu) and
// the session library screen (the per-row Share action) so both code
// paths produce identical, weather-bearing bundles.
//
// Failures are non-fatal: any block that can't be read (missing platform
// plugin in tests, model asset moved, prefs unavailable) is simply
// omitted from the result map and the export proceeds.
// =============================================================================

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../live/live_session.dart';
import 'export_device_info.dart';
import 'session_export.dart';

/// Builds the standard export metadata map for [session].
///
/// [speciesLocale] is the user's effective species locale at export time
/// (e.g. `en`, `de`) and is recorded in the metadata so consumers know
/// which language the `commonName` fields use.
Future<Map<String, dynamic>> buildSessionExportMetadata(
  LiveSession session, {
  required String speciesLocale,
}) async {
  String? appVersion;
  String? appBuildNumber;
  String? appPackageName;
  try {
    final info = await PackageInfo.fromPlatform();
    appVersion = info.version;
    appBuildNumber = info.buildNumber;
    appPackageName = info.packageName;
  } catch (_) {
    /* non-fatal */
  }

  Map<String, dynamic>? audioModel;
  Map<String, dynamic>? geoModel;
  try {
    final raw = await rootBundle.loadString(AppConstants.modelConfigAssetPath);
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final am = decoded['audioModel'];
    if (am is Map) audioModel = Map<String, dynamic>.from(am);
    final gm = decoded['geoModel'];
    if (gm is Map) geoModel = Map<String, dynamic>.from(gm);
  } catch (_) {
    /* non-fatal */
  }

  Map<String, dynamic>? prefsMap;
  try {
    final prefs = await SharedPreferences.getInstance();
    prefsMap = _relevantExportPreferences(prefs);
  } catch (_) {
    /* non-fatal */
  }

  final deviceInfo = await exportDeviceInfo();
  return buildExportMetadata(
    device: deviceInfo.device,
    os: deviceInfo.os,
    appVersion: appVersion,
    appBuildNumber: appBuildNumber,
    appPackageName: appPackageName,
    audioModel: audioModel,
    geoModel: geoModel,
    prefs: prefsMap,
    speciesLocale: speciesLocale,
    session: session,
  );
}

Map<String, dynamic> _relevantExportPreferences(SharedPreferences prefs) {
  final keys = _relevantPrefKeys.toList()..sort();
  return {
    for (final key in keys)
      if (prefs.containsKey(key)) key: prefs.get(key),
  };
}

const Set<String> _relevantPrefKeys = {
  // Export and review settings that affect artifact content or interpretation.
  // Runtime session settings are persisted on LiveSession.settings instead.
  PrefKeys.exportSelection,
  PrefKeys.includeAudio,
  PrefKeys.exportHtmlReport,
  PrefKeys.timestampDisplayMode,
  PrefKeys.timestampShowSeconds,
};
