import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:birdnet_live/features/history/services/share_export_config.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/upload/connectivity.dart';
import 'package:birdnet_live/features/upload/secret_store.dart';
import 'package:birdnet_live/features/upload/upload_destination.dart';
import 'package:birdnet_live/features/upload/upload_job.dart';
import 'package:birdnet_live/features/upload/upload_queue_store.dart';
import 'package:birdnet_live/features/upload/upload_service.dart';
import 'package:birdnet_live/features/upload/webdav_client.dart';

/// Stands in for the OS transfer (iOS): records hand-offs, answers `recover`
/// with [recovery], and lets a test report an outcome through [report].
class _FakeTransfer implements UploadTransfer {
  @override
  void Function(String transferId, int status)? onFinished;

  final List<Map<String, Object?>> puts = [];
  final List<String> acked = [];
  final List<String> cancelled = [];
  final List<bool> running = [];
  Object? putError;

  /// What `recover` answers; by default every hand-off not yet reported or
  /// cancelled is still running, as the OS would say.
  TransferRecovery? recovery;

  @override
  Future<void> put({
    required String transferId,
    required Uri uri,
    required Map<String, String> headers,
    required String username,
    required String secret,
    required File file,
    required bool wifiOnly,
  }) async {
    if (putError != null) throw putError!;
    puts.add({
      'transferId': transferId,
      'uri': uri,
      'headers': headers,
      'path': file.path,
      'wifiOnly': wifiOnly,
    });
  }

  @override
  Future<TransferRecovery> recover() async =>
      recovery ??
      TransferRecovery(
        running: {
          for (final p in puts)
            if (!acked.contains(p['transferId']) &&
                !cancelled.contains(p['transferId']))
              p['transferId'] as String,
        },
        finished: const {},
      );

  @override
  Future<void> ack(String transferId) async => acked.add(transferId);

  @override
  Future<void> cancel(String transferId) async => cancelled.add(transferId);

  @override
  Future<void> setRunning(bool isRunning) async => running.add(isRunning);

  /// Reports an outcome the way the OS would and waits until the service has
  /// recorded it; the acknowledgement is the last thing it does.
  Future<void> report(String transferId, int status) async {
    final before = acked.length;
    onFinished!(transferId, status);
    while (acked.length == before) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }
}

/// Records every request; answers PUT/MKCOL with [putStatus] (or a per-path
/// override) and stores PUT bodies by path.
class _FakeDav {
  int putStatus = 201;
  final Map<String, int> overrides = {};
  final List<http.BaseRequest> requests = [];
  final Map<String, List<int>> bodies = {};
  int failuresLeft = 0;

  http.Client get client => MockClient.streaming((request, bodyStream) async {
    requests.add(request);
    if (failuresLeft > 0) {
      failuresLeft--;
      throw const SocketException('connection reset');
    }
    final body = await bodyStream.toBytes();
    if (request.method == 'PUT') bodies[request.url.path] = body;
    final status =
        overrides[request.url.path] ??
        (request.method == 'MKCOL' ? 201 : putStatus);
    return http.StreamedResponse(const Stream.empty(), status);
  });

  List<String> paths(String method) => [
    for (final r in requests)
      if (r.method == method) r.url.path,
  ];
}

void main() {
  late Directory tempDir;
  late _FakeDav dav;
  late FixedConnectivity connectivity;
  late UploadDestination destination;
  late LiveSession session;
  late UploadService service;
  late String? exportPath;
  final exportConfigs = <ShareExportConfig>[];
  var now = DateTime.utc(2026, 10, 28, 12);
  Future<String?> Function(UploadDestination) secretFor = (_) async => 'pw';

  final config = ShareExportConfig(formats: const {'csv'}, includeAudio: false);

  UploadService build({
    UploadDestination? dest,
    List<UploadDestination> others = const [],
    UploadTransfer? transfer,
    DestinationUploaded? onDestinationUploaded,
  }) {
    return UploadService(
      transfer: transfer,
      onDestinationUploaded: onDestinationUploaded,
      store: UploadQueueStore(documentsDirectory: () async => tempDir),
      client: WebDavClient(client: dav.client),
      connectivity: connectivity,
      deviceCode: () => '4ee91c8f',
      loadSession: (id) async => id == session.id ? session : null,
      findDestination: (id) async {
        for (final d in [dest ?? destination, ...others]) {
          if (d.id == id) return d;
        }
        return null;
      },
      secretFor: (d) => secretFor(d),
      buildExport: (_, config) async {
        exportConfigs.add(config);
        final path = exportPath;
        if (path == null) return null;
        // The service deletes the staged export after each upload; a real
        // builder produces a fresh file every time.
        await File(path).writeAsBytes(List<int>.generate(1000, (i) => i % 251));
        return path;
      },
      now: () => now,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('upload_service_');
    dav = _FakeDav();
    exportConfigs.clear();
    connectivity = FixedConnectivity(NetworkType.wifi);
    destination = UploadDestination(
      id: 'dest-1',
      name: 'Project',
      url: 'https://cloud.example.org/public.php/webdav/',
      username: 'token',
      createdAt: now,
    );
    session = LiveSession(
      id: '2026-10-28T10-00-00.000',
      startTime: DateTime(2026, 10, 28, 10),
      endTime: DateTime(2026, 10, 28, 10, 30),
      settings: const SessionSettings(
        windowDuration: 3,
        confidenceThreshold: 25,
        inferenceRate: 1.0,
        speciesFilterMode: 'off',
      ),
    );
    final export = File('${tempDir.path}/BirdNET_Live_export_#13.zip');
    await export.writeAsBytes(List<int>.generate(1000, (i) => i % 251));
    exportPath = export.path;
    service = build();
  });

  tearDown(() async {
    // A run kicked off by the last enqueue may still be writing.
    await service.processQueue();
    service.dispose();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('uploads one ZIP into the device folder', () async {
    final job = await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();

    expect(dav.paths('MKCOL'), ['/public.php/webdav/4ee91c8f/']);
    expect(dav.paths('PUT'), [
      '/public.php/webdav/4ee91c8f/BirdNET_Live_export_%2313.zip',
    ]);
    // The `#` travels percent-encoded, never as a fragment.
    final put = dav.requests[1];
    expect(
      put.url.toString(),
      'https://cloud.example.org/public.php/webdav/4ee91c8f/'
      'BirdNET_Live_export_%2313.zip',
    );
    expect(put.headers['Authorization'], startsWith('Basic '));
    expect(put.headers['Content-Type'], 'application/zip');
    expect(dav.bodies[put.url.path]!.length, 1000);
    // The JSON record always rides inside the bundle.
    expect(exportConfigs.single.formats, {'csv', 'json'});
    expect(exportConfigs.single.includeAudio, isFalse);

    final done = service.jobsForSession(session.id).single;
    expect(done.id, job.id);
    expect(done.state, UploadJobState.uploaded);
    expect(done.finishedAt, now);
    expect(done.remotePath, '4ee91c8f/BirdNET_Live_export_#13.zip');
    // The staged export is cleaned up; it was not a session asset.
    expect(await File(exportPath!).exists(), isFalse);
  });

  test('flat layout folds the folder path into file names', () async {
    final flat = destination.copyWith(flatLayout: true);
    service.dispose();
    service = build(dest: flat);
    await service.enqueue(session: session, destination: flat, config: config);
    await service.processQueue();

    expect(dav.paths('MKCOL'), isEmpty);
    expect(dav.paths('PUT'), [
      '/public.php/webdav/4ee91c8f__BirdNET_Live_export_%2313.zip',
    ]);
  });

  test(
    'a configuration the pipeline yields nothing for fails the job',
    () async {
      exportPath = null;
      await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
      await service.processQueue();

      expect(dav.paths('PUT'), isEmpty);
      final job = service.jobsForSession(session.id).single;
      expect(job.state, UploadJobState.failed);
      expect(job.lastError, UploadErrorCode.exportFailed);
      // Nothing about a refused export changes between attempts.
      expect(job.gaveUp, isTrue);
    },
  );

  test('a hard MKCOL failure is reported before the export is built', () async {
    dav.overrides['/public.php/webdav/4ee91c8f/'] = 507;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();

    expect(exportConfigs, isEmpty);
    expect(dav.paths('PUT'), isEmpty);
    expect(
      service.jobsForSession(session.id).single.lastError,
      UploadErrorCode.quota,
    );
  });

  test('a network failure backs off and a later run succeeds', () async {
    dav.failuresLeft = 1;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();

    var job = service.jobsForSession(session.id).single;
    expect(job.state, UploadJobState.failed);
    expect(job.attempts, 1);
    expect(job.lastError, UploadErrorCode.network);
    expect(job.nextAttemptAt, now.add(const Duration(minutes: 1)));

    // Not due yet: nothing happens.
    final before = dav.requests.length;
    await service.processQueue();
    expect(dav.requests.length, before);

    now = now.add(const Duration(minutes: 2));
    await service.processQueue();
    job = service.jobsForSession(session.id).single;
    expect(job.state, UploadJobState.uploaded);
  });

  test('a 401 is reported as unauthorized', () async {
    dav.putStatus = 401;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    expect(
      service.jobsForSession(session.id).single.lastError,
      UploadErrorCode.unauthorized,
    );
  });

  test('a 412 on an existing path counts as written', () async {
    dav.overrides['/public.php/webdav/4ee91c8f/BirdNET_Live_export_%2313.zip'] =
        412;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    expect(
      service.jobsForSession(session.id).single.state,
      UploadJobState.uploaded,
    );
  });

  test(
    'Wi-Fi-only destinations wait on cellular, offline stops the run',
    () async {
      connectivity.type = NetworkType.cellular;
      await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
      await service.processQueue();
      var job = service.jobsForSession(session.id).single;
      expect(job.state, UploadJobState.queued);
      expect(job.lastError, UploadErrorCode.waitingForWifi);
      expect(dav.requests, isEmpty);

      connectivity.type = NetworkType.none;
      await service.processQueue();
      job = service.jobsForSession(session.id).single;
      expect(job.lastError, UploadErrorCode.offline);
      expect(dav.requests, isEmpty);

      connectivity.type = NetworkType.wifi;
      await service.processQueue();
      expect(
        service.jobsForSession(session.id).single.state,
        UploadJobState.uploaded,
      );
    },
  );

  test('enqueue refuses a paused destination', () async {
    await expectLater(
      service.enqueue(
        session: session,
        destination: destination.copyWith(paused: true),
        config: config,
      ),
      throwsStateError,
    );
    expect(service.jobsForSession(session.id), isEmpty);
  });

  test('a paused destination holds its jobs until it is resumed', () async {
    // Queued offline, so the job is still waiting when the pause comes.
    connectivity.type = NetworkType.none;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    expect(dav.requests, isEmpty);

    connectivity.type = NetworkType.wifi;
    service.dispose();
    service = build(dest: destination.copyWith(paused: true));
    await service.processQueue();

    var job = service.jobsForSession(session.id).single;
    expect(job.state, UploadJobState.queued);
    expect(job.lastError, UploadErrorCode.destinationPaused);
    expect(dav.requests, isEmpty);
    // Nothing for the background scheduler to book.
    expect(await service.actionablePending(), isEmpty);

    // Resuming is a destination change; the next run finds the same queue.
    service.dispose();
    service = build();
    await service.processQueue();
    job = service.jobsForSession(session.id).single;
    expect(job.state, UploadJobState.uploaded);
    expect(job.lastError, isNull);
  });

  test('pausing also holds a job in retry backoff', () async {
    dav.failuresLeft = 1;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    var job = service.jobsForSession(session.id).single;
    expect(job.state, UploadJobState.failed);
    expect(job.nextAttemptAt, isNotNull);

    // Paused before the retry is due: the job reads "Destination paused"
    // rather than "failed", and loses its backoff so resuming sends it.
    service.dispose();
    service = build(dest: destination.copyWith(paused: true));
    await service.processQueue();
    job = service.jobsForSession(session.id).single;
    expect(job.state, UploadJobState.queued);
    expect(job.lastError, UploadErrorCode.destinationPaused);
    expect(job.nextAttemptAt, isNull);
    expect(await service.actionablePending(), isEmpty);
  });

  test('pausing holds a job the run never reaches', () async {
    final other = UploadDestination(
      id: 'dest-2',
      name: 'Other',
      url: 'https://cloud.example.org/other/',
      username: 'token',
      createdAt: now,
    );
    service.dispose();
    service = build(others: [other]);
    connectivity.type = NetworkType.none;
    await service.enqueue(session: session, destination: other, config: config);
    // Strictly older, so the run reaches the other destination's job first.
    now = now.add(const Duration(minutes: 1));
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();

    // Still offline, the older job (the live destination's) stops the run
    // before the paused destination's job would have its turn.
    service.dispose();
    service = build(dest: destination.copyWith(paused: true), others: [other]);
    await service.processQueue();

    final jobs = {
      for (final j in service.jobsForSession(session.id)) j.destinationId: j,
    };
    expect(jobs[other.id]!.lastError, UploadErrorCode.offline);
    expect(jobs[destination.id]!.lastError, UploadErrorCode.destinationPaused);
    expect(await service.actionablePending(), hasLength(1));
  });

  test('resuming clears the mark of a job the run never reaches', () async {
    final other = UploadDestination(
      id: 'dest-2',
      name: 'Other',
      url: 'https://cloud.example.org/other/',
      username: 'token',
      createdAt: now,
    );
    Map<String, UploadJob> byDestination() => {
      for (final j in service.jobsForSession(session.id)) j.destinationId: j,
    };
    service.dispose();
    service = build(others: [other]);
    connectivity.type = NetworkType.none;
    await service.enqueue(session: session, destination: other, config: config);
    // Strictly older, so the run reaches the other destination's job first.
    now = now.add(const Duration(minutes: 1));
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    service.dispose();
    service = build(dest: destination.copyWith(paused: true), others: [other]);
    await service.processQueue();
    expect(
      byDestination()[destination.id]!.lastError,
      UploadErrorCode.destinationPaused,
    );

    // Resumed, still offline: the other destination's older job stops the
    // run first, yet this one no longer claims to be paused.
    service.dispose();
    service = build(others: [other]);
    await service.processQueue();
    final job = byDestination()[destination.id]!;
    expect(job.state, UploadJobState.queued);
    expect(job.lastError, isNull);
    expect(await service.actionablePending(), hasLength(2));
  });

  test('enqueue is idempotent while pending and re-uploads to the same path '
      'afterwards', () async {
    connectivity.type = NetworkType.none;
    final a = await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    final b = await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    expect(b.id, a.id);

    connectivity.type = NetworkType.wifi;
    await service.processQueue();
    final c = await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    expect(c.version, 2);
    await service.processQueue();
    expect(dav.paths('PUT'), [
      '/public.php/webdav/4ee91c8f/BirdNET_Live_export_%2313.zip',
      '/public.php/webdav/4ee91c8f/BirdNET_Live_export_%2313.zip',
    ]);
  });

  test('jobs survive a restart and an interrupted upload is retried', () async {
    connectivity.type = NetworkType.none;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    // Simulate a kill mid-upload by persisting the job as uploading.
    final store = UploadQueueStore(documentsDirectory: () async => tempDir);
    final stored = await store.load();
    await store.save([stored.single.copyWith(state: UploadJobState.uploading)]);

    service.dispose();
    connectivity.type = NetworkType.wifi;
    service = build();
    await service.processQueue();
    expect(
      service.jobsForSession(session.id).single.state,
      UploadJobState.uploaded,
    );
  });

  test('a removed destination gives up without retrying', () async {
    service.dispose();
    service = build(dest: destination.copyWith(name: 'x'));
    await service.enqueue(
      session: session,
      destination: UploadDestination(
        id: 'gone',
        name: 'Gone',
        url: 'https://x.example.org/',
        username: '',
        createdAt: now,
      ),
      config: config,
    );
    await service.processQueue();
    final job = service.jobsForSession(session.id).single;
    expect(job.gaveUp, isTrue);
    expect(job.lastError, UploadErrorCode.destinationMissing);
  });

  test('cancelForDestination drops pending jobs and keeps the log', () async {
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    final other = LiveSession(
      id: 'other',
      startTime: DateTime(2026, 10, 28, 11),
      endTime: DateTime(2026, 10, 28, 11, 10),
      settings: session.settings,
    );
    connectivity.type = NetworkType.none;
    await service.enqueue(
      session: other,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    expect(service.pendingCount, 1);

    await service.cancelForDestination(destination.id);

    expect(service.pendingCount, 0);
    expect(
      service.jobsForSession(session.id).single.state,
      UploadJobState.uploaded,
    );
    expect(service.jobsForSession(other.id), isEmpty);
  });

  test('enqueue keys on the stored UUID, not the copy handed in', () async {
    // A library listing of a legacy session carries a fresh, unsaved UUID.
    final listed = LiveSession(
      id: session.id,
      startTime: session.startTime,
      endTime: session.endTime,
      settings: session.settings,
    );
    expect(listed.uuid, isNot(session.uuid));

    final job = await service.enqueue(
      session: listed,
      destination: destination,
      config: config,
    );
    expect(job.sessionUuid, session.uuid);
    await service.processQueue();

    final again = await service.enqueue(
      session: listed,
      destination: destination,
      config: config,
    );
    expect(again.version, 2);
    // Let the run the second enqueue started finish before the temp
    // directory is deleted.
    await service.processQueue();
  });

  test('a keychain failure fails the job and the run continues', () async {
    secretFor = (_) async => throw const SecretStoreException('locked');
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();

    final job = service.jobsForSession(session.id).single;
    expect(job.state, UploadJobState.failed);
    expect(job.lastError, UploadErrorCode.secretMissing);
    expect(job.nextAttemptAt, isNotNull);

    secretFor = (_) async => 'pw';
    now = now.add(const Duration(minutes: 2));
    await service.processQueue();
    expect(
      service.jobsForSession(session.id).single.state,
      UploadJobState.uploaded,
    );
  });

  test('an export the pipeline refuses fails the job instead of uploading '
      'without audio', () async {
    exportPath = null;
    final withAudio = LiveSession(
      id: 'audio',
      startTime: session.startTime,
      endTime: session.endTime,
      settings: session.settings,
      recordingPath: '${tempDir.path}/full.flac',
    );
    await File(withAudio.recordingPath!).writeAsBytes([1, 2, 3]);
    final previous = session;
    session = withAudio;
    addTearDown(() => session = previous);
    final audioConfig = ShareExportConfig(
      formats: const {'csv'},
      includeAudio: true,
    );

    await service.enqueue(
      session: withAudio,
      destination: destination,
      config: audioConfig,
    );
    await service.processQueue();

    final job = service.jobsForSession(withAudio.id).single;
    expect(job.state, UploadJobState.failed);
    expect(job.lastError, UploadErrorCode.exportFailed);
    expect(dav.paths('PUT'), isEmpty);
  });

  test('the export is moved into staging before upload and the original '
      'path is left alone afterwards', () async {
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();

    expect(await File(exportPath!).exists(), isFalse);
    final staging = Directory('${tempDir.path}/upload_staging');
    expect(
      await staging.exists() ? await staging.list().toList() : const [],
      isEmpty,
    );
    expect(
      service.jobsForSession(session.id).single.state,
      UploadJobState.uploaded,
    );
  });

  test(
    'a second service on the same file sees what the first one did',
    () async {
      // The foreground app enqueues while offline.
      connectivity.type = NetworkType.none;
      await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
      await service.processQueue();

      // The background worker (another isolate) uploads it.
      final worker = build();
      connectivity.type = NetworkType.wifi;
      await worker.processQueue();
      expect(
        worker.jobsForSession(session.id).single.state,
        UploadJobState.uploaded,
      );
      worker.dispose();

      // The app's next run must not re-upload, and a later write by the app
      // must keep the worker's result.
      final puts = dav.paths('PUT').length;
      await service.processQueue();
      expect(dav.paths('PUT').length, puts);
      expect(
        service.jobsForSession(session.id).single.state,
        UploadJobState.uploaded,
      );
      final other = LiveSession(
        id: 'other',
        startTime: session.startTime,
        endTime: session.endTime,
        settings: session.settings,
      );
      await service.enqueue(
        session: other,
        destination: destination,
        config: config,
      );
      await service.processQueue();
      final reloaded = await UploadQueueStore(
        documentsDirectory: () async => tempDir,
      ).load();
      // The app knows nothing about 'other' on disk, so that job fails; the
      // point is that the worker's finished job survives the app's write.
      expect(reloaded.length, 2);
      expect(
        reloaded.singleWhere((j) => j.sessionId == session.id).state,
        UploadJobState.uploaded,
      );
    },
  );

  group('with an OS transfer', () {
    late _FakeTransfer transfer;
    final uploadedAt = <DateTime>[];

    UploadService buildWith(
      _FakeTransfer transfer, {
      List<UploadDestination> others = const [],
    }) => build(
      transfer: transfer,
      others: others,
      onDestinationUploaded: (_, at) async => uploadedAt.add(at),
    );

    UploadDestination dest(String id) => UploadDestination(
      id: id,
      name: id,
      url: 'https://$id.example.org/dav/',
      username: 'u',
      createdAt: now,
    );

    setUp(() {
      transfer = _FakeTransfer();
      uploadedAt.clear();
      service.dispose();
      service = buildWith(transfer);
    });

    test(
      'hands the staged export to the OS and leaves the job uploading',
      () async {
        final job = await service.enqueue(
          session: session,
          destination: destination,
          config: config,
        );
        await service.processQueue();

        expect(dav.paths('MKCOL'), ['/public.php/webdav/4ee91c8f/']);
        expect(dav.paths('PUT'), isEmpty);
        final put = transfer.puts.single;
        final current = service.jobs.single;
        expect(current.state, UploadJobState.uploading);
        expect(current.transferId, startsWith('${job.id}.'));
        expect(put['transferId'], current.transferId);
        expect(
          (put['uri'] as Uri).path,
          '/public.php/webdav/4ee91c8f/BirdNET_Live_export_%2313.zip',
        );
        final headers = put['headers'] as Map<String, String>;
        expect(headers['Authorization'], startsWith('Basic '));
        expect(headers['Content-Type'], 'application/zip');
        expect(put['wifiOnly'], destination.wifiOnly);
        // The staged file must outlive the run; the OS reads it later.
        expect(File(put['path'] as String).existsSync(), isTrue);
        expect(current.remotePath, '4ee91c8f/BirdNET_Live_export_#13.zip');
        expect(transfer.running, [true, false]);
      },
    );

    test('a reported 2xx finishes the job and drops the staged file', () async {
      await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
      await service.processQueue();
      final staged = File(transfer.puts.single['path'] as String);
      final transferId = service.jobs.single.transferId!;

      await transfer.report(transferId, 201);

      final current = service.jobs.single;
      expect(current.state, UploadJobState.uploaded);
      expect(current.finishedAt, now);
      expect(staged.existsSync(), isFalse);
      expect(transfer.acked, [transferId]);
      expect(uploadedAt, [now]);
    });

    test('a reported 401 fails the job for a retry; no answer is a network '
        'failure', () async {
      await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
      await service.processQueue();

      await transfer.report(service.jobs.single.transferId!, 401);
      // The outcome kicks a run that read the clock before it moves; join
      // it here so the next processQueue starts a fresh one.
      await service.processQueue();
      var current = service.jobs.single;
      expect(current.state, UploadJobState.failed);
      expect(current.lastError, UploadErrorCode.unauthorized);
      expect(current.nextAttemptAt, now.add(const Duration(minutes: 1)));

      now = now.add(const Duration(minutes: 2));
      await service.processQueue();
      expect(transfer.puts, hasLength(2));
      await transfer.report(service.jobs.single.transferId!, 0);
      current = service.jobs.single;
      expect(current.state, UploadJobState.failed);
      expect(current.lastError, UploadErrorCode.network);
      expect(current.attempts, 2);
    });

    test('an outcome of an earlier hand-off is ignored once the job was '
        'handed off again', () async {
      await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
      await service.processQueue();
      final first = service.jobs.single.transferId!;
      service.dispose();

      // The OS lost the first hand-off; the next run sends it again.
      final second = _FakeTransfer();
      service = buildWith(second);
      await service.processQueue();
      final again = service.jobs.single.transferId!;
      expect(again, isNot(first));
      expect(second.puts.single['transferId'], again);
      final staged = File(second.puts.single['path'] as String);

      // A late report for the first hand-off changes nothing and leaves
      // the staged file of the second alone.
      await second.report(first, 0);
      expect(service.jobs.single.state, UploadJobState.uploading);
      expect(staged.existsSync(), isTrue);
      expect(second.acked, [first]);

      await second.report(again, 204);
      expect(service.jobs.single.state, UploadJobState.uploaded);
      expect(staged.existsSync(), isFalse);
    });

    test('an outcome reported while the app was gone is settled on the next '
        'run', () async {
      await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
      await service.processQueue();
      final staged = File(transfer.puts.single['path'] as String);
      final transferId = service.jobs.single.transferId!;
      service.dispose();

      final second = _FakeTransfer()
        ..recovery = TransferRecovery(
          running: const {},
          finished: {transferId: 204},
        );
      service = buildWith(second);
      await service.ensureLoaded();
      // Not reset to queued at load: the OS may still carry it.
      expect(service.jobs.single.state, UploadJobState.uploading);

      await service.processQueue();
      expect(service.jobs.single.state, UploadJobState.uploaded);
      expect(second.acked, [transferId]);
      expect(second.puts, isEmpty);
      expect(staged.existsSync(), isFalse);
      expect(uploadedAt, [now]);
    });

    test(
      'a job the OS still carries waits; one it lost is sent again',
      () async {
        final other = dest('dest-2');
        service.dispose();
        service = buildWith(transfer, others: [other]);
        final a = await service.enqueue(
          session: session,
          destination: destination,
          config: config,
        );
        final b = await service.enqueue(
          session: session,
          destination: other,
          config: config,
        );
        await service.processQueue();
        final ids = {for (final j in service.jobs) j.id: j.transferId!};
        expect(transfer.puts.map((p) => p['transferId']), [
          ids[b.id],
          ids[a.id],
        ]);
        service.dispose();

        final second = _FakeTransfer()
          ..recovery = TransferRecovery(
            running: {ids[a.id]!},
            finished: const {},
          );
        service = buildWith(second, others: [other]);
        await service.processQueue();

        final byId = {for (final j in service.jobs) j.id: j};
        expect(byId[a.id]!.state, UploadJobState.uploading);
        expect(byId[a.id]!.transferId, ids[a.id]);
        expect(byId[b.id]!.state, UploadJobState.uploading);
        expect(byId[b.id]!.transferId, isNot(ids[b.id]));
        expect(second.puts.single['transferId'], byId[b.id]!.transferId);
      },
    );

    test('removing a job or its destination stops the hand-off and the late '
        'outcome only cleans up', () async {
      final other = dest('dest-2');
      service.dispose();
      service = buildWith(transfer, others: [other]);
      final a = await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
      final b = await service.enqueue(
        session: session,
        destination: other,
        config: config,
      );
      await service.processQueue();
      final ids = {for (final j in service.jobs) j.id: j.transferId!};
      final stagedA = Directory('${tempDir.path}/upload_staging/${a.id}');
      expect(stagedA.existsSync(), isTrue);

      await service.cancel(a.id);
      await service.cancelForDestination(other.id);
      expect(transfer.cancelled, [ids[a.id], ids[b.id]]);
      expect(service.jobs, isEmpty);

      await transfer.report(ids[a.id]!, 0);
      expect(stagedA.existsSync(), isFalse);
      expect(transfer.acked, [ids[a.id]]);
    });

    test('an outcome for a job removed while the app was gone is cleared '
        'even when nothing is pending', () async {
      final job = await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
      await service.processQueue();
      final transferId = service.jobs.single.transferId!;
      final staged = Directory('${tempDir.path}/upload_staging/${job.id}');
      service.dispose();

      // Removed, then the OS finished it while no app was running.
      service = buildWith(_FakeTransfer());
      await service.cancel(job.id);
      service.dispose();
      final second = _FakeTransfer()
        ..recovery = TransferRecovery(
          running: const {},
          finished: {transferId: 201},
        );
      service = buildWith(second);
      await service.processQueue();

      expect(second.acked, [transferId]);
      expect(staged.existsSync(), isFalse);
    });

    test('at most three hand-offs are in flight; an outcome lets the next one '
        'go', () async {
      final others = [dest('dest-2'), dest('dest-3'), dest('dest-4')];
      service.dispose();
      service = buildWith(transfer, others: others);
      for (final d in [destination, ...others]) {
        await service.enqueue(session: session, destination: d, config: config);
      }
      await service.processQueue();

      expect(transfer.puts, hasLength(UploadService.maxInFlight));
      expect(
        service.jobs.where((j) => j.state == UploadJobState.queued),
        hasLength(1),
      );

      await transfer.report(transfer.puts.first['transferId'] as String, 201);
      await service.processQueue();
      expect(transfer.puts, hasLength(4));
      expect(
        service.jobs.where((j) => j.state == UploadJobState.queued),
        isEmpty,
      );
    });

    test(
      'a hand-off the OS refuses fails the job and drops the staged file',
      () async {
        transfer.putError = PlatformException(code: 'INVALID_ARG');
        final job = await service.enqueue(
          session: session,
          destination: destination,
          config: config,
        );
        await service.processQueue();

        final current = service.jobs.single;
        expect(current.state, UploadJobState.failed);
        expect(current.lastError, UploadErrorCode.network);
        expect(
          Directory('${tempDir.path}/upload_staging/${job.id}').existsSync(),
          isFalse,
        );
      },
    );

    test('a plain-http destination keeps the in-app PUT', () async {
      final lan = UploadDestination(
        id: 'dest-lan',
        name: 'NAS',
        url: 'http://nas.local/dav/',
        username: 'u',
        createdAt: now,
      );
      service.dispose();
      service = buildWith(transfer, others: [lan]);
      await service.enqueue(session: session, destination: lan, config: config);
      await service.processQueue();

      expect(transfer.puts, isEmpty);
      expect(dav.paths('PUT'), ['/dav/4ee91c8f/BirdNET_Live_export_%2313.zip']);
      final current = service.jobs.single;
      expect(current.state, UploadJobState.uploaded);
      expect(current.transferId, isNull);
    });

    test('dispose detaches from the transfer', () {
      expect(transfer.onFinished, isNotNull);
      service.dispose();
      expect(transfer.onFinished, isNull);
      service = buildWith(_FakeTransfer());
    });
  });

  test('backoff doubles from one minute and caps at six hours', () {
    expect(UploadService.backoff(1), const Duration(minutes: 1));
    expect(UploadService.backoff(2), const Duration(minutes: 2));
    expect(UploadService.backoff(5), const Duration(minutes: 16));
    expect(UploadService.backoff(10), const Duration(hours: 6));
    expect(UploadService.backoff(25), const Duration(hours: 6));
  });
}
