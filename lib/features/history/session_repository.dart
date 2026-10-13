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
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';

import '../live/live_session.dart';
import 'session_path_codec.dart';

/// Persists [LiveSession] objects as JSON files.
class SessionRepository {
  /// Creates a repository that stores sessions in the app documents directory.
  SessionRepository();

  String? _basePath;
  final Map<String, Future<void>> _writeTails = {};
  Future<void>? _deleteAllOperation;
  int _activeWrites = 0;
  Completer<void>? _writesDrained;

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
    await _queueSave(session);
  }

  /// Save a recoverable, finished snapshot without ending the live session.
  /// A process kill leaves this partial session visible in the library.
  Future<void> saveCheckpoint(LiveSession session) async {
    await _queueSave(session, checkpoint: true);
  }

  Future<void> _queueSave(
    LiveSession session, {
    bool checkpoint = false,
  }) async {
    while (_deleteAllOperation != null) {
      final operation = _deleteAllOperation!;
      await operation;
    }
    _activeWrites++;
    try {
      final basePath = await _getBasePath();
      final id = _sanitiseId(session.id);
      final previous = _writeTails[id] ?? Future<void>.value();
      final write = previous
          .catchError((Object _) {})
          .then((_) => _writeSession(basePath, id, session, checkpoint));
      _writeTails[id] = write;
      try {
        await write;
      } finally {
        if (identical(_writeTails[id], write)) _writeTails.remove(id);
      }
    } finally {
      _activeWrites--;
      if (_activeWrites == 0) {
        _writesDrained?.complete();
        _writesDrained = null;
      }
    }
  }

  Future<void> _writeSession(
    String basePath,
    String id,
    LiveSession session,
    bool checkpoint,
  ) async {
    final file = File('$basePath/$id.json');
    final pending = File('$basePath/$id.pending');
    final recovery = File('$basePath/$id.recovery.json');
    final documentsPath = Directory(basePath).parent.path;
    // Large Surveys can contain thousands of detections and GPS points.
    // Building and encoding that object graph on the main isolate freezes all
    // navigation while the session is being saved.
    final jsonString = await Isolate.run(() {
      final data = sessionJsonForStorage(session, documentsPath: documentsPath);
      if (checkpoint) {
        final snapshotAt = DateTime.now().toUtc().toIso8601String();
        data['endTime'] = snapshotAt;
        data['recordedDurationSeconds'] = session.duration.inSeconds;
        final segments = data['segments'];
        if (segments is List && segments.isNotEmpty) {
          final last = segments.last;
          if (last is Map<String, dynamic> && last['endTime'] == null) {
            last['endTime'] = snapshotAt;
          }
        }
        final aru = data['aru'];
        final cycles = aru is Map<String, dynamic> ? aru['cycles'] : null;
        if (cycles is List) {
          for (final cycle in cycles) {
            if (cycle is Map<String, dynamic> &&
                cycle['status'] == 'recording') {
              cycle['status'] = 'partial';
              cycle['actualEnd'] = snapshotAt;
            }
          }
        }
      }
      return const JsonEncoder.withIndent('  ').convert(data);
    });
    await pending.writeAsString(jsonString, flush: true);
    // Keep the last good file available through a crash between renames.
    if (await file.exists()) {
      if (await recovery.exists()) {
        // A previous interrupted write may have left the only valid copy in
        // recovery. Keep it until the new primary is safely in place.
        await file.delete();
      } else {
        await file.rename(recovery.path);
      }
    }
    await pending.rename(file.path);
    if (await recovery.exists()) await recovery.delete();
  }

  /// IDs with at least one snapshot file (primary, pending, or recovery).
  Future<Set<String>> _sessionIds(Directory dir) async {
    final suffix = RegExp(r'(\.recovery)?\.json$|\.pending$');
    final ids = <String>{};
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (suffix.hasMatch(name)) ids.add(name.replaceFirst(suffix, ''));
    }
    return ids;
  }

  /// Load a session by ID.
  ///
  /// Returns `null` if the session does not exist.
  Future<LiveSession?> load(String id) async {
    final basePath = await _getBasePath();
    final safeId = _sanitiseId(id);
    for (final path in [
      '$basePath/$safeId.pending',
      '$basePath/$safeId.json',
      '$basePath/$safeId.recovery.json',
    ]) {
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        return sessionFromStorageJson(
          json,
          documentsPath: Directory(basePath).parent.path,
        );
      } catch (_) {
        // A partially written file can leave another valid snapshot behind.
      }
    }
    return null;
  }

  /// List all saved sessions, sorted by start time (newest first).
  ///
  /// File reading and JSON parsing run in a background isolate so large
  /// sessions (e.g. 1 000-detection ARU deployments) do not block the UI.
  Future<List<LiveSession>> listAll() async {
    final basePath = await _getBasePath();
    final dir = Directory(basePath);
    if (!await dir.exists()) return const [];

    final ids = await _sessionIds(dir);
    if (ids.isEmpty) return const [];

    final documentsPath = Directory(basePath).parent.path;
    return Isolate.run(() async {
      final sessions = <LiveSession>[];
      for (final id in ids) {
        for (final path in [
          '$basePath/$id.pending',
          '$basePath/$id.json',
          '$basePath/$id.recovery.json',
        ]) {
          try {
            final jsonString = await File(path).readAsString();
            final json = jsonDecode(jsonString) as Map<String, dynamic>;
            sessions.add(
              sessionFromStorageJson(json, documentsPath: documentsPath),
            );
            break;
          } catch (_) {
            // Try the next snapshot if this one is missing or corrupt.
          }
        }
      }
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      return sessions;
    });
  }

  /// Delete a session by ID.
  ///
  /// Also deletes any associated recording directory.
  Future<void> delete(String id) async {
    await deleteMetadataOnly(id);

    // Also try to delete associated recordings.
    // Derive recordings dir as a sibling of the sessions dir.
    final basePath = await _getBasePath();
    final sessionsDir = Directory(basePath);
    final parentDir = sessionsDir.parent.path;
    final recordingsDir = Directory('$parentDir/recordings/${_sanitiseId(id)}');
    if (await recordingsDir.exists()) {
      await recordingsDir.delete(recursive: true);
    }
  }

  /// Delete only the saved session JSON by ID.
  ///
  /// Leaves associated recording files in place. ARU per-cycle sessions use
  /// this to discard a completed deployment aggregate without deleting cycle
  /// clip directories that are still referenced by the cycle sessions.
  Future<void> deleteMetadataOnly(String id) async {
    final basePath = await _getBasePath();
    final safeId = _sanitiseId(id);
    await _writeTails[safeId]?.catchError((Object _) {});
    for (final suffix in ['.json', '.recovery.json', '.pending']) {
      final file = File('$basePath/$safeId$suffix');
      if (await file.exists()) await file.delete();
    }
  }

  /// Delete all saved sessions.
  Future<void> deleteAll() async {
    while (_deleteAllOperation != null) {
      final operation = _deleteAllOperation!;
      await operation;
    }
    final deletion = Completer<void>();
    _deleteAllOperation = deletion.future;
    try {
      if (_activeWrites > 0) {
        _writesDrained ??= Completer<void>();
        await _writesDrained!.future;
      }
      final basePath = await _getBasePath();
      final dir = Directory(basePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } finally {
      _deleteAllOperation = null;
      deletion.complete();
    }
  }

  /// Count of saved sessions.
  Future<int> count() async {
    final basePath = await _getBasePath();
    final dir = Directory(basePath);
    if (!await dir.exists()) return 0;

    final ids = await _sessionIds(dir);
    return ids.length;
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
      final sessionNum = numMatch != null
          ? int.tryParse(numMatch.group(1)!)
          : null;

      return {'type': typeStr, 'sessionNumber': sessionNum};
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
    final ids = await _sessionIds(dir);
    for (final id in ids) {
      for (final path in [
        '$basePath/$id.pending',
        '$basePath/$id.json',
        '$basePath/$id.recovery.json',
      ]) {
        final header = await _parseSessionHeader(File(path));
        final number = header?['sessionNumber'] as int?;
        if (number != null) {
          if (header!['type'] == type.name && number > maxNum) {
            maxNum = number;
          }
          break;
        }
      }
    }
    return maxNum + 1;
  }

  /// Sanitise a session ID for use as a filename.
  static String _sanitiseId(String id) =>
      id.replaceAll(RegExp(r'[<>:"/\\|?*]'), '-');
}
