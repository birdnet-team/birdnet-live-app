// =============================================================================
// Session Repository — JSON-based persistence for live sessions
// =============================================================================
//
// Stores completed [LiveSession] objects as JSON files in the app's
// documents directory.  Each session is saved as a separate file named
// `<sessionId>.json`.
//
// ### File layout
//
// ```
// <appDir>/sessions/
//   2026-02-28T14-30-00.000.json
//   2026-02-28T15-00-00.000.json
// ```
//
// ### Why JSON files instead of Isar?
//
// For the initial implementation, JSON files are simpler and require no
// code generation or native binaries.  Sessions are small (typically
// <100 detections) and infrequently queried, so file-based storage is
// adequate.  Migration to Isar is straightforward if querying needs grow.
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../live/live_session.dart';

/// Persists [LiveSession] objects as JSON files.
class SessionRepository {
  /// Creates a repository that stores sessions in the app documents directory.
  SessionRepository();

  String? _basePath;

  /// Get or create the sessions directory.
  Future<String> _getBasePath() async {
    if (_basePath != null) return _basePath!;
    final appDir = await getApplicationDocumentsDirectory();
    _basePath = '${appDir.path}/sessions';
    await Directory(_basePath!).create(recursive: true);
    return _basePath!;
  }

  /// For testing: override the base path.
  set basePath(String path) => _basePath = path;

  /// Save a completed session.
  ///
  /// Overwrites any existing session with the same ID.
  Future<void> save(LiveSession session) async {
    final basePath = await _getBasePath();
    final file = File('$basePath/${_sanitiseId(session.id)}.json');
    final jsonString = const JsonEncoder.withIndent('  ').convert(
      session.toJson(),
    );
    await file.writeAsString(jsonString, flush: true);
  }

  /// Load a session by ID.
  ///
  /// Returns `null` if the session does not exist.
  Future<LiveSession?> load(String id) async {
    final basePath = await _getBasePath();
    final file = File('$basePath/${_sanitiseId(id)}.json');
    if (!await file.exists()) return null;

    final jsonString = await file.readAsString();
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return LiveSession.fromJson(json);
  }

  /// List all saved sessions, sorted by start time (newest first).
  Future<List<LiveSession>> listAll() async {
    final basePath = await _getBasePath();
    final dir = Directory(basePath);
    if (!await dir.exists()) return const [];

    final sessions = <LiveSession>[];

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final jsonString = await entity.readAsString();
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          sessions.add(LiveSession.fromJson(json));
        } catch (_) {
          // Skip corrupt files.
        }
      }
    }

    // Sort newest first.
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  /// Delete a session by ID.
  ///
  /// Also deletes any associated recording directory.
  Future<void> delete(String id) async {
    final basePath = await _getBasePath();
    final file = File('$basePath/${_sanitiseId(id)}.json');
    if (await file.exists()) {
      await file.delete();
    }

    // Also try to delete associated recordings.
    // Derive recordings dir as a sibling of the sessions dir.
    final sessionsDir = Directory(basePath);
    final parentDir = sessionsDir.parent.path;
    final recordingsDir = Directory(
      '$parentDir/recordings/${_sanitiseId(id)}',
    );
    if (await recordingsDir.exists()) {
      await recordingsDir.delete(recursive: true);
    }
  }

  /// Delete all saved sessions.
  Future<void> deleteAll() async {
    final basePath = await _getBasePath();
    final dir = Directory(basePath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
  }

  /// Count of saved sessions.
  Future<int> count() async {
    final basePath = await _getBasePath();
    final dir = Directory(basePath);
    if (!await dir.exists()) return 0;

    var count = 0;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        count++;
      }
    }
    return count;
  }

  /// Parse only the header (first 1024 bytes) of a session JSON file to extract
  /// the session type and number. This avoids decoding potentially massive
  /// JSON files with large detection arrays, which blocks the UI thread.
  Future<Map<String, dynamic>?> _parseSessionHeader(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final length = await file.length();
      final bytesToRead = length < 1024 ? length : 1024;
      final buffer = await raf.read(bytesToRead);
      final text = utf8.decode(buffer, allowMalformed: true);

      // JSON properties are written at the top of the map.
      // E.g., "type": "pointCount" (or omitted if it's "live", the default)
      final typeMatch = RegExp(r'"type"\s*:\s*"([^"]+)"').firstMatch(text);
      final typeStr = typeMatch?.group(1) ?? 'live';

      // E.g., "sessionNumber": 42
      final numMatch = RegExp(r'"sessionNumber"\s*:\s*(\d+)').firstMatch(text);
      final sessionNum = numMatch != null ? int.tryParse(numMatch.group(1)!) : null;

      return {
        'type': typeStr,
        'sessionNumber': sessionNum,
      };
    } catch (_) {
      return null;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  /// Return the next sequential session number for [type].
  ///
  /// Scans all saved sessions of the same type and returns
  /// `max(sessionNumber) + 1`, or `1` if none exist yet.
  Future<int> nextSessionNumber(SessionType type) async {
    final basePath = await _getBasePath();
    final dir = Directory(basePath);
    if (!await dir.exists()) return 1;

    var maxNum = 0;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final header = await _parseSessionHeader(entity);
        if (header != null) {
          final hTypeStr = header['type'] as String;
          final hSessionNumber = header['sessionNumber'] as int?;
          if (hTypeStr == type.name && hSessionNumber != null) {
            if (hSessionNumber > maxNum) maxNum = hSessionNumber;
          }
        }
      }
    }
    return maxNum + 1;
  }

  /// Sanitise a session ID for use as a filename.
  static String _sanitiseId(String id) =>
      id.replaceAll(RegExp(r'[<>:"/\\|?*]'), '-');
}
