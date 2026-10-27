// =============================================================================
// Session Path Codec
// =============================================================================
//
// Session JSON must not persist absolute paths into the app sandbox. iOS can
// move the data container during app updates, making paths such as
// `/var/mobile/Containers/Data/Application/<uuid>/Documents/...` stale even
// though the files are still present in the new Documents directory.
// =============================================================================

import 'package:path/path.dart' as p;

import '../live/live_session.dart';

/// Builds session JSON with app-owned file paths made portable.
Map<String, dynamic> sessionJsonForStorage(
  LiveSession session, {
  required String documentsPath,
}) {
  final json = session.toJson();
  rewriteSessionFilePaths(
    json,
    (path) => toPortableAppFilePath(path, documentsPath: documentsPath),
  );
  return json;
}

/// Builds a session from JSON, resolving portable and legacy iOS file paths.
LiveSession sessionFromStorageJson(
  Map<String, dynamic> json, {
  required String documentsPath,
}) {
  final copy = _deepCopyMap(json);
  rewriteSessionFilePaths(
    copy,
    (path) => resolveAppFilePath(path, documentsPath: documentsPath),
  );
  return LiveSession.fromJson(copy);
}

/// Converts an app-owned absolute Documents path to a portable relative path.
///
/// Non-app-owned paths are returned unchanged.
String toPortableAppFilePath(String path, {required String documentsPath}) {
  final normalized = _normalizePath(path);
  if (_isAppOwnedRelativePath(normalized)) return normalized;

  final currentRelative = _relativeToDocuments(normalized, documentsPath);
  if (currentRelative != null && _isAppOwnedRelativePath(currentRelative)) {
    return currentRelative;
  }

  final legacyRelative = _legacyIosDocumentsRelative(normalized);
  if (legacyRelative != null && _isAppOwnedRelativePath(legacyRelative)) {
    return legacyRelative;
  }

  return path;
}

/// Resolves a portable app-owned path, or a stale iOS Documents path, to now.
///
/// Paths outside the app-owned recordings tree are returned unchanged.
String resolveAppFilePath(String path, {required String documentsPath}) {
  final normalized = _normalizePath(path);

  final legacyRelative = _legacyIosDocumentsRelative(normalized);
  if (legacyRelative != null && _isAppOwnedRelativePath(legacyRelative)) {
    return _joinDocuments(documentsPath, legacyRelative);
  }

  if (_isAppOwnedRelativePath(normalized)) {
    return _joinDocuments(documentsPath, normalized);
  }

  return path;
}

/// Rewrites all file path fields currently persisted inside a session JSON map.
void rewriteSessionFilePaths(
  Map<String, dynamic> json,
  String Function(String path) rewrite,
) {
  _rewriteStringKey(json, 'recordingPath', rewrite);

  final detections = json['detections'];
  if (detections is List) {
    for (final item in detections) {
      if (item is Map<String, dynamic>) {
        _rewriteStringKey(item, 'audioClipPath', rewrite);
        _rewriteStringKey(item, 'voiceMemoPath', rewrite);
      }
    }
  }

  final annotations = json['annotations'];
  if (annotations is List) {
    for (final item in annotations) {
      if (item is Map<String, dynamic>) {
        _rewriteStringKey(item, 'voiceMemoPath', rewrite);
      }
    }
  }

  final aru = json['aru'];
  final cycles = aru is Map<String, dynamic> ? aru['cycles'] : null;
  if (cycles is List) {
    for (final item in cycles) {
      if (item is Map<String, dynamic>) {
        _rewriteStringKey(item, 'recordingPath', rewrite);
      }
    }
  }
}

void _rewriteStringKey(
  Map<String, dynamic> json,
  String key,
  String Function(String path) rewrite,
) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    json[key] = rewrite(value);
  }
}

Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
  return source.map((key, value) => MapEntry(key, _deepCopyValue(value)));
}

Object? _deepCopyValue(Object? value) {
  if (value is Map<String, dynamic>) return _deepCopyMap(value);
  if (value is List) return value.map(_deepCopyValue).toList();
  return value;
}

String _normalizePath(String path) {
  return path.replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/');
}

String? _relativeToDocuments(String normalizedPath, String documentsPath) {
  final docs = _normalizePath(documentsPath).replaceFirst(RegExp(r'/+$'), '');
  if (normalizedPath == docs) return '';
  final prefix = '$docs/';
  if (normalizedPath.startsWith(prefix)) {
    return normalizedPath.substring(prefix.length);
  }
  return null;
}

String? _legacyIosDocumentsRelative(String normalizedPath) {
  final match = RegExp(r'/Containers/Data/Application/[^/]+/Documents/(.+)$')
      .firstMatch(normalizedPath);
  return match?.group(1);
}

bool _isAppOwnedRelativePath(String normalizedPath) {
  if (normalizedPath.isEmpty) return false;
  if (normalizedPath.startsWith('/') ||
      RegExp(r'^[A-Za-z]:/').hasMatch(normalizedPath) ||
      normalizedPath.contains('/../') ||
      normalizedPath.startsWith('../') ||
      normalizedPath.endsWith('/..')) {
    return false;
  }
  return normalizedPath == 'recordings' ||
      normalizedPath.startsWith('recordings/');
}

String _joinDocuments(String documentsPath, String relativePath) {
  final parts = _normalizePath(relativePath)
      .split('/')
      .where((part) => part.isNotEmpty);
  return p.joinAll([documentsPath, ...parts]);
}
