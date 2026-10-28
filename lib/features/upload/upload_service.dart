// =============================================================================
// Upload Service — the queue engine
// =============================================================================
//
// Owns the job list (see upload_job.dart) and pushes due jobs to their
// destinations one at a time. For every job it writes, in this order:
//
//   <deviceId>/<sessionUuid>/v<version>/session.json    the JSON export,
//                                                       always, so the lead
//                                                       gets structured data
//                                                       whatever the user's
//                                                       share preferences
//   <deviceId>/<sessionUuid>/v<version>/<export file>   what the Share dialog
//                                                       would have produced
//                                                       (ZIP or single file),
//                                                       if the config yields
//                                                       one
//   <deviceId>/<sessionUuid>/v<version>/_complete.json  sizes and SHA-256 of
//                                                       the files above;
//                                                       written last, so the
//                                                       collect script knows
//                                                       the upload finished
//
// Destinations that refused MKCOL during the probe get the same three files
// with the folder path folded into the file name (`a__b__v1__session.json`).
//
// A failed job backs off exponentially (1 min, 2, 4, … capped at 6 h) and
// gives up after [UploadJob.maxAttempts]. Jobs whose destination is on
// Wi-Fi only wait while the device is on cellular; with no network at all the
// run stops early. Every state change is persisted, so a kill mid-upload
// simply retries that job on the next run.
//
// Triggers (see app.dart and upload_providers.dart): enqueue, app start,
// return to foreground. True OS background transfer is a later stage.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../shared/utils/uuid.dart';
import '../history/services/share_export_config.dart';
import '../live/live_session.dart';
import 'connectivity.dart';
import 'secret_store.dart';
import 'upload_destination.dart';
import 'upload_job.dart';
import 'upload_queue_store.dart';
import 'webdav_client.dart';
import 'webdav_probe.dart';

/// Builds the user-facing export (ZIP or single file) for [session]; null
/// when the configuration yields no file. Paths in [keep] must not be
/// deleted afterwards (the session's own recording can be returned as-is).
typedef ExportBuilder = Future<String?> Function(
  LiveSession session,
  ShareExportConfig config,
);

/// Builds the always-on structured record (the JSON export).
typedef JsonBuilder = Future<String> Function(LiveSession session);

typedef SessionLoader = Future<LiveSession?> Function(String sessionId);
typedef DestinationLookup = Future<UploadDestination?> Function(String id);
typedef SecretLookup = Future<String?> Function(UploadDestination destination);
typedef DestinationUploaded = Future<void> Function(
  UploadDestination destination,
  DateTime at,
);

/// Called after every run with the jobs still pending, so a platform
/// scheduler can arrange a background run or cancel one. [wifiOnly] is true
/// when every pending job waits for Wi-Fi.
typedef PendingChanged = Future<void> Function({
  required int pending,
  required bool wifiOnly,
});

/// Machine codes stored in [UploadJob.lastError]; the UI maps them to text.
abstract final class UploadErrorCode {
  static const String offline = 'offline';
  static const String waitingForWifi = 'waitingForWifi';
  static const String unauthorized = 'unauthorized';
  static const String forbidden = 'forbidden';
  static const String quota = 'quota';
  static const String server = 'server';
  static const String network = 'network';
  static const String exportFailed = 'exportFailed';
  static const String destinationMissing = 'destinationMissing';
  static const String secretMissing = 'secretMissing';
  static const String sessionMissing = 'sessionMissing';
}

class UploadService extends ChangeNotifier {
  UploadService({
    required UploadQueueStore store,
    required WebDavClient client,
    required Connectivity connectivity,
    required String Function() deviceId,
    required Future<String> Function() appVersion,
    required SessionLoader loadSession,
    required DestinationLookup findDestination,
    required SecretLookup secretFor,
    required ExportBuilder buildExport,
    required JsonBuilder buildJson,
    DestinationUploaded? onDestinationUploaded,
    PendingChanged? onPendingChanged,
    DateTime Function()? now,
  }) : _store = store,
       _client = client,
       _connectivity = connectivity,
       _deviceId = deviceId,
       _appVersion = appVersion,
       _loadSession = loadSession,
       _findDestination = findDestination,
       _secretFor = secretFor,
       _buildExport = buildExport,
       _buildJson = buildJson,
       _onDestinationUploaded = onDestinationUploaded,
       _onPendingChanged = onPendingChanged,
       _now = now ?? DateTime.now;

  final UploadQueueStore _store;
  final WebDavClient _client;
  final Connectivity _connectivity;
  final String Function() _deviceId;
  final Future<String> Function() _appVersion;
  final SessionLoader _loadSession;
  final DestinationLookup _findDestination;
  final SecretLookup _secretFor;
  final ExportBuilder _buildExport;
  final JsonBuilder _buildJson;
  final DestinationUploaded? _onDestinationUploaded;
  final PendingChanged? _onPendingChanged;
  final DateTime Function() _now;

  List<UploadJob> _jobs = const [];
  Future<void>? _loaded;
  Future<void>? _running;

  /// Jobs this isolate changed since the last write, and jobs it removed.
  /// The foreground app and the background worker share one file; on every
  /// write the file is re-read and merged so neither side overwrites what
  /// the other did while it held the lock (see [_mergeAndSave]).
  final Set<String> _dirty = {};
  final Set<String> _removed = {};

  /// Every job, pending and finished, newest first.
  List<UploadJob> get jobs => List.unmodifiable(_jobs);

  /// Jobs for [sessionId], newest first.
  List<UploadJob> jobsForSession(String sessionId) => [
    for (final j in _jobs)
      if (j.sessionId == sessionId) j,
  ];

  int get pendingCount => _jobs.where((j) => j.isPending).length;

  /// Reads the job list from disk once. Safe to call from widgets: a
  /// store that cannot be read (no documents directory in a widget test)
  /// simply yields an empty list.
  Future<void> ensureLoaded() => _ensureLoaded();

  Future<void> _ensureLoaded() {
    return _loaded ??= () async {
      List<UploadJob> jobs;
      try {
        jobs = await _store.load();
      } catch (_) {
        jobs = const [];
      }
      // A kill mid-upload leaves a job "uploading"; it is simply due again.
      _jobs = [
        for (final j in jobs)
          if (j.state == UploadJobState.uploading)
            j.copyWith(state: UploadJobState.queued)
          else
            j,
      ];
      _sort();
      notifyListeners();
    }();
  }

  void _sort() {
    _jobs = [..._jobs]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _persistChain = Future<void>.value();

  /// Writes go out one at a time; overlapping renames of the same file
  /// fail on Windows.
  Future<void> _persist() async {
    final write = _persistChain
        .catchError((Object _) {})
        .then((_) => _mergeAndSave());
    _persistChain = write;
    await write;
    notifyListeners();
  }

  /// Re-reads the file, lets this isolate's changes win only for the jobs
  /// it touched, keeps everything the other isolate wrote, and saves.
  Future<void> _mergeAndSave() async {
    _mergeFromDisk(await _loadDisk());
    _dirty.clear();
    _removed.clear();
    await _store.save(_jobs);
  }

  Future<List<UploadJob>> _loadDisk() async {
    try {
      return await _store.load();
    } catch (_) {
      return const [];
    }
  }

  void _mergeFromDisk(List<UploadJob> disk) {
    final merged = <String, UploadJob>{for (final d in disk) d.id: d};
    for (final mine in _jobs) {
      if (_dirty.contains(mine.id) || !merged.containsKey(mine.id)) {
        merged[mine.id] = mine;
      }
    }
    for (final id in _removed) {
      merged.remove(id);
    }
    _jobs = merged.values.toList();
    _sort();
  }

  /// Runs the queue without letting an error escape an unawaited call.
  void _kick() {
    unawaited(
      processQueue().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Upload queue run failed: $error\n$stackTrace');
      }),
    );
  }

  /// Queues [session] for [destination]. An already pending job for the pair
  /// is returned instead of duplicated; after a finished upload a new
  /// version is queued.
  Future<UploadJob> enqueue({
    required LiveSession session,
    required UploadDestination destination,
    required ShareExportConfig config,
  }) async {
    await _ensureLoaded();
    // A session listed by the library may still carry an unsaved UUID (one
    // saved before UUIDs existed gets its permanent one on the first full
    // load), so the identity jobs are keyed on comes from the repository.
    final uuid = (await _loadSession(session.id))?.uuid ?? session.uuid;
    final existing = _jobs.where(
      (j) => j.sessionUuid == uuid && j.destinationId == destination.id,
    );
    for (final j in existing) {
      if (j.isPending) return j;
    }
    final version = existing.isEmpty
        ? 1
        : existing.map((j) => j.version).reduce(math.max) + 1;
    final job = UploadJob(
      id: generateUuidV4(),
      sessionId: session.id,
      sessionUuid: uuid,
      destinationId: destination.id,
      version: version,
      config: config,
      createdAt: _now(),
    );
    _jobs = [job, ..._jobs];
    _dirty.add(job.id);
    await _persist();
    _kick();
    return job;
  }

  /// Puts a failed or given-up job back at the front of the line.
  Future<void> retryNow(String jobId) async {
    await _ensureLoaded();
    _replace(
      jobId,
      (j) => j.copyWith(
        state: UploadJobState.queued,
        clearNextAttempt: true,
        clearError: true,
      ),
    );
    await _persist();
    _kick();
  }

  /// Drops a pending job. Finished jobs stay as the log.
  Future<void> cancel(String jobId) async {
    await _ensureLoaded();
    for (final j in _jobs) {
      if (j.id == jobId && j.state != UploadJobState.uploaded) {
        _removed.add(j.id);
      }
    }
    _jobs = [
      for (final j in _jobs)
        if (!_removed.contains(j.id)) j,
    ];
    await _persist();
  }

  /// Drops every pending job for [destinationId]; called when the
  /// destination is removed. Finished jobs stay as the log.
  Future<void> cancelForDestination(String destinationId) async {
    await _ensureLoaded();
    for (final j in _jobs) {
      if (j.destinationId == destinationId &&
          j.state != UploadJobState.uploaded) {
        _removed.add(j.id);
      }
    }
    _jobs = [
      for (final j in _jobs)
        if (!_removed.contains(j.id)) j,
    ];
    await _persist();
  }

  /// Runs every due job. Concurrent calls share one run.
  Future<void> processQueue() {
    return _running ??= _run().whenComplete(() => _running = null);
  }

  Future<void> _run() async {
    await _ensureLoaded();
    if (!_jobs.any((j) => j.isPending)) return;
    if (!await _store.tryLock()) return;
    // A single PUT of a long recording can outlast the stale-lock window;
    // keep the lock fresh while this run is alive.
    final keepAlive = Timer.periodic(
      UploadQueueStore.staleLock ~/ 3,
      (_) => unawaited(_store.touchLock()),
    );
    try {
      // The other isolate may have finished jobs since this one loaded the
      // file; a job it left "uploading" is one it was killed in.
      _mergeFromDisk(await _loadDisk());
      _jobs = [
        for (final j in _jobs)
          if (j.state == UploadJobState.uploading && !_dirty.contains(j.id))
            j.copyWith(state: UploadJobState.queued)
          else
            j,
      ];
      notifyListeners();
      await _runLocked();
    } finally {
      keepAlive.cancel();
      await _store.unlock();
      await _reportPending();
    }
  }

  /// Tells the scheduler what is left. A destination lookup failure counts
  /// as "any network" so nothing waits forever.
  Future<void> _reportPending() async {
    final hook = _onPendingChanged;
    if (hook == null) return;
    final pending = _jobs.where((j) => j.isPending).toList();
    var wifiOnly = pending.isNotEmpty;
    for (final job in pending) {
      final destination = await _findDestination(job.destinationId);
      if (destination == null || !destination.wifiOnly) {
        wifiOnly = false;
        break;
      }
    }
    try {
      await hook(pending: pending.length, wifiOnly: wifiOnly);
    } catch (error) {
      debugPrint('Upload scheduler hook failed: $error');
    }
  }

  Future<void> _runLocked() async {
    final skipped = <String>{};
    while (true) {
      final now = _now();
      UploadJob? next;
      for (final j in _jobs.reversed) {
        if (j.isDue(now) && !skipped.contains(j.id)) {
          next = j;
          break;
        }
      }
      if (next == null) return;
      final outcome = await _runJob(next);
      switch (outcome) {
        case _Outcome.stop:
          return;
        case _Outcome.skip:
          skipped.add(next.id);
        case _Outcome.done:
          break;
      }
    }
  }

  Future<_Outcome> _runJob(UploadJob job) async {
    try {
      return await _runJobUnguarded(job);
    } on SecretStoreException {
      await _fail(job, UploadErrorCode.secretMissing);
    } catch (error, stackTrace) {
      debugPrint(
        'Upload of ${job.sessionId} could not start: $error\n$stackTrace',
      );
      await _fail(job, UploadErrorCode.network);
    }
    return _Outcome.done;
  }

  Future<_Outcome> _runJobUnguarded(UploadJob job) async {
    final destination = await _findDestination(job.destinationId);
    if (destination == null) {
      await _giveUp(job, UploadErrorCode.destinationMissing);
      return _Outcome.done;
    }
    final network = await _connectivity.currentType();
    if (network.isOffline) {
      _replace(job.id, (j) => j.copyWith(lastError: UploadErrorCode.offline));
      await _persist();
      return _Outcome.stop;
    }
    if (destination.wifiOnly && !network.allowsWifiOnlyUpload) {
      _replace(
        job.id,
        (j) => j.copyWith(lastError: UploadErrorCode.waitingForWifi),
      );
      await _persist();
      return _Outcome.skip;
    }
    final secret = await _secretFor(destination);
    if (secret == null) {
      await _giveUp(job, UploadErrorCode.secretMissing);
      return _Outcome.done;
    }
    final session = await _loadSession(job.sessionId);
    if (session == null) {
      await _giveUp(job, UploadErrorCode.sessionMissing);
      return _Outcome.done;
    }

    _replace(job.id, (j) => j.copyWith(state: UploadJobState.uploading));
    await _persist();

    try {
      final remotePath = await _upload(job, destination, secret, session);
      final at = _now();
      _replace(
        job.id,
        (j) => j.copyWith(
          state: UploadJobState.uploaded,
          finishedAt: at,
          clearError: true,
          clearNextAttempt: true,
          remotePath: remotePath,
        ),
      );
      await _persist();
      await _onDestinationUploaded?.call(destination, at);
    } on _UploadFailure catch (failure) {
      await _fail(job, failure.code);
    } on TimeoutException {
      await _fail(job, UploadErrorCode.network);
    } on IOException {
      await _fail(job, UploadErrorCode.network);
    } catch (error, stackTrace) {
      debugPrint('Upload of ${job.sessionId} failed: $error\n$stackTrace');
      await _fail(job, UploadErrorCode.exportFailed);
    }
    return _Outcome.done;
  }

  Future<String> _upload(
    UploadJob job,
    UploadDestination destination,
    String secret,
    LiveSession session,
  ) async {
    final auth = WebDavClient.basicAuth(destination.username, secret);
    final base = Uri.parse(destination.url);
    final deviceId = _deviceId();
    final segments = [deviceId, session.uuid, 'v${job.version}'];
    final String prefix;
    if (destination.flatLayout) {
      prefix =
          segments.join(WebDavProbe.flatSeparator) + WebDavProbe.flatSeparator;
    } else {
      var folder = base;
      for (final segment in segments) {
        folder = folder.resolve('$segment/');
        final status = await _client.mkcol(folder, auth);
        if (status != 201 && status != 405) _throwForStatus(status);
      }
      prefix = '${segments.join('/')}/';
    }
    // Export names carry the session number (`…_#13.zip`); a raw `#` would
    // start a URL fragment, so every file name is percent-encoded.
    Uri target(String name) =>
        base.resolve('$prefix${Uri.encodeComponent(name)}');

    final manifest = <String, Map<String, Object>>{};

    // 1. Structured record.
    final jsonBytes = utf8.encode(await _buildJson(session));
    await _put(target('session.json'), auth, bytes: jsonBytes);
    manifest['session.json'] = {
      'size': jsonBytes.length,
      'sha256': sha256.convert(jsonBytes).toString(),
    };

    // 2. The share bundle, if the configuration yields one. A null with
    //    audio requested on a session that has audio is the export pipeline
    //    refusing (a trim it cannot cut), not an empty configuration.
    final exportPath = await _buildExport(session, job.config);
    if (exportPath == null &&
        job.config.includeAudio &&
        sessionMayHaveAudio(session)) {
      throw const _UploadFailure(UploadErrorCode.exportFailed);
    }
    if (exportPath != null) {
      final name = File(exportPath).uri.pathSegments.last;
      // The export lands next to the recording under a deterministic name,
      // which a foreground share of the same session would also write and
      // read. Move it into a private staging folder first so neither side
      // deletes or truncates the other's file.
      final staged = await _stage(job, exportPath, session);
      final file = File(staged ?? exportPath);
      try {
        await _put(target(name), auth, file: file);
        manifest[name] = {
          'size': await file.length(),
          'sha256': (await sha256.bind(file.openRead()).first).toString(),
        };
      } finally {
        if (staged != null) {
          try {
            await file.parent.delete(recursive: true);
          } catch (_) {
            // Best-effort cleanup of the staged export.
          }
        }
      }
    }

    // 3. Completion marker.
    final complete = utf8.encode(
      const JsonEncoder.withIndent('  ').convert({
        'sessionUuid': session.uuid,
        'sessionId': session.id,
        'version': job.version,
        'deviceId': deviceId,
        'app': 'BirdNET Live',
        'appVersion': await _appVersion(),
        'uploadedAt': _now().toUtc().toIso8601String(),
        'files': manifest,
      }),
    );
    await _put(target('_complete.json'), auth, bytes: complete);
    return prefix;
  }

  Future<void> _put(
    Uri uri,
    Map<String, String> auth, {
    List<int>? bytes,
    File? file,
  }) async {
    final isJson = uri.path.endsWith('.json');
    final status = file != null
        ? await _client.putFile(uri, auth, file)
        : await _client.putBytes(
            uri,
            auth,
            bytes!,
            contentType: isJson
                ? 'application/json'
                : 'application/octet-stream',
          );
    // 412: an immutable server already holds this exact path (a retry after
    // a kill between PUT and bookkeeping). The bytes are the same; move on.
    if (status == 200 || status == 201 || status == 204 || status == 412) {
      return;
    }
    _throwForStatus(status);
  }

  Never _throwForStatus(int status) {
    switch (status) {
      case 401:
        throw const _UploadFailure(UploadErrorCode.unauthorized);
      case 403:
        throw const _UploadFailure(UploadErrorCode.forbidden);
      case 507:
        throw const _UploadFailure(UploadErrorCode.quota);
      default:
        throw _UploadFailure(
          status >= 500 ? UploadErrorCode.server : UploadErrorCode.network,
        );
    }
  }

  /// The export can hand back the session's own recording untouched; that
  /// file belongs to the session and must survive the upload.
  bool _isSessionAsset(String path, LiveSession session) {
    if (path == session.recordingPath) return true;
    for (final d in session.detections) {
      if (path == d.audioClipPath) return true;
    }
    return false;
  }

  /// Moves a freshly built export into `upload_staging/<job id>/` and
  /// returns the new path, or null when the file is one of the session's
  /// own assets (an audio-only share can hand back the recording itself).
  Future<String?> _stage(
    UploadJob job,
    String exportPath,
    LiveSession session,
  ) async {
    if (_isSessionAsset(exportPath, session)) return null;
    final dir = Directory('${(await _store.stagingDir()).path}/${job.id}');
    await dir.create(recursive: true);
    final target = '${dir.path}/${File(exportPath).uri.pathSegments.last}';
    final source = File(exportPath);
    try {
      await source.rename(target);
    } on FileSystemException {
      await source.copy(target);
      try {
        await source.delete();
      } catch (_) {
        // The copy is what gets uploaded; the original is best-effort.
      }
    }
    return target;
  }

  Future<void> _fail(UploadJob job, String code) async {
    final attempts = job.attempts + 1;
    final gaveUp = attempts >= UploadJob.maxAttempts;
    _replace(
      job.id,
      (j) => j.copyWith(
        state: UploadJobState.failed,
        attempts: attempts,
        lastError: code,
        nextAttemptAt: gaveUp ? null : _now().add(backoff(attempts)),
        clearNextAttempt: gaveUp,
      ),
    );
    await _persist();
  }

  Future<void> _giveUp(UploadJob job, String code) async {
    _replace(
      job.id,
      (j) => j.copyWith(
        state: UploadJobState.failed,
        lastError: code,
        clearNextAttempt: true,
      ),
    );
    await _persist();
  }

  /// 1 min, 2, 4, … capped at 6 h.
  static Duration backoff(int attempts) {
    final minutes = math.min(360, 1 << math.min(attempts - 1, 9));
    return Duration(minutes: minutes);
  }

  void _replace(String jobId, UploadJob Function(UploadJob) change) {
    _dirty.add(jobId);
    _jobs = [
      for (final j in _jobs)
        if (j.id == jobId) change(j) else j,
    ];
  }
}

enum _Outcome { done, skip, stop }

class _UploadFailure implements Exception {
  const _UploadFailure(this.code);
  final String code;
}
