// =============================================================================
// Upload Background — run the queue while the app is closed
// =============================================================================
//
// Android: WorkManager starts UploadWorker.kt when the device is on a
// suitable network; the worker spins up a headless Flutter engine on
// [uploadQueueBackgroundMain], which builds the same providers the app uses,
// runs the queue once, and reports how many jobs are left so the worker can
// ask for a retry. The foreground app and the worker never run the queue at
// the same time: UploadQueueStore.tryLock arbitrates.
//
// [UploadWorkScheduler] is the Dart side of `com.birdnet/upload_work`:
//
//   schedule({wifiOnly}) -> null   one-time work, kept if already queued
//   cancel()             -> null
//   finished({pending})  -> null   worker <- Dart, from the headless run
//
// iOS: there is no headless run. Instead the queue builds and stages each
// export while the app is open and hands the PUT itself to a background
// URLSession (UploadTransferChannel.swift), which carries it out while the
// app is suspended or gone and wakes the app when it ends. The job stays
// "uploading" until the outcome comes back, through `onFinished` while the
// app is alive or through `recover` on the next run after a relaunch.
// [BackgroundTransfer] is the Dart side of `com.birdnet/upload_transfer`:
//
//   upload({transferId, url, headers, path, username, secret, wifiOnly})
//   recover()  -> {running: [transferId], finished: [{transferId, status}]}
//   ack({transferId})     -> null   drops a finished entry once recorded
//   cancel({transferId})  -> null   stops a hand-off; reported as status 0
//   setRunning({running}) -> null   background time while a run prepares
//   onFinished({transferId, status})   native -> Dart; 0 = no answer
// =============================================================================

import 'dart:io' show File, Platform;
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/app_providers.dart';
import '../explore/explore_providers.dart';
import '../history/session_repository.dart';
import '../live/live_providers.dart';
import 'upload_providers.dart';
import 'upload_service.dart';

abstract final class UploadWorkScheduler {
  static const MethodChannel channel = MethodChannel('com.birdnet/upload_work');

  static bool get supported => Platform.isAndroid;

  /// Asks the platform for a background run once a suitable network is
  /// available. No-op where unsupported.
  static Future<void> schedule({required bool wifiOnly}) async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('schedule', {'wifiOnly': wifiOnly});
    } on PlatformException catch (e) {
      debugPrint('Upload work could not be scheduled: ${e.message}');
    } on MissingPluginException {
      // Running without the native half (tests, other platforms).
    }
  }

  static Future<void> cancel() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('cancel');
    } on PlatformException {
      // Nothing to cancel.
    } on MissingPluginException {
      // See above.
    }
  }

  /// The hook UploadService calls after every run.
  static Future<void> onPendingChanged({
    required int pending,
    required bool wifiOnly,
  }) {
    return pending > 0 ? schedule(wifiOnly: wifiOnly) : cancel();
  }
}

/// Entry point of the headless engine UploadWorker.kt starts.
@pragma('vm:entry-point')
Future<void> uploadQueueBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  var pending = -1;
  String? error;
  ProviderContainer? container;
  try {
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Never write a session file from here; the app may be editing it.
        sessionRepositoryProvider.overrideWithValue(
          SessionRepository(backfillUuid: false),
        ),
      ],
    );
    // Species names in the exported documents come from the taxonomy; wait
    // for it so a background upload matches a foreground one.
    try {
      await container.read(taxonomyServiceProvider.future);
    } catch (_) {
      // Exports fall back to the names stored with the session.
    }
    final service = container.read(uploadServiceProvider);
    await service.processQueue();
    // Jobs held by a paused destination are not worth another worker run.
    pending = (await service.actionablePending()).length;
  } catch (e, stackTrace) {
    error = '$e';
    debugPrint('Background upload run failed: $e\n$stackTrace');
  } finally {
    container?.dispose();
  }
  try {
    await UploadWorkScheduler.channel.invokeMethod<void>('finished', {
      'pending': pending,
      if (error != null) 'error': error,
    });
  } on MissingPluginException {
    // Not started by the worker.
  }
}

class BackgroundTransfer implements UploadTransfer {
  BackgroundTransfer({MethodChannel? channel})
    : _channel = channel ?? defaultChannel {
    _channel.setMethodCallHandler(_handle);
  }

  static const MethodChannel defaultChannel = MethodChannel(
    'com.birdnet/upload_transfer',
  );

  static bool get supported => Platform.isIOS;

  final MethodChannel _channel;

  @override
  void Function(String transferId, int status)? onFinished;

  Future<dynamic> _handle(MethodCall call) async {
    if (call.method != 'onFinished') throw MissingPluginException();
    final args = call.arguments as Map<Object?, Object?>;
    onFinished?.call(args['transferId'] as String, args['status'] as int? ?? 0);
  }

  @override
  Future<void> put({
    required String transferId,
    required Uri uri,
    required Map<String, String> headers,
    required String username,
    required String secret,
    required File file,
    required bool wifiOnly,
  }) {
    return _channel.invokeMethod<void>('upload', {
      'transferId': transferId,
      'url': uri.toString(),
      'headers': headers,
      'path': file.path,
      'username': username,
      'secret': secret,
      'wifiOnly': wifiOnly,
    });
  }

  @override
  Future<TransferRecovery> recover() async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>('recover');
    final running = (raw?['running'] as List<Object?>?) ?? const [];
    final finished = (raw?['finished'] as List<Object?>?) ?? const [];
    return TransferRecovery(
      running: {for (final id in running) id as String},
      finished: {
        for (final entry in finished.cast<Map<Object?, Object?>>())
          entry['transferId'] as String: entry['status'] as int? ?? 0,
      },
    );
  }

  @override
  Future<void> ack(String transferId) =>
      _channel.invokeMethod<void>('ack', {'transferId': transferId});

  @override
  Future<void> cancel(String transferId) =>
      _channel.invokeMethod<void>('cancel', {'transferId': transferId});

  @override
  Future<void> setRunning(bool running) =>
      _channel.invokeMethod<void>('setRunning', {'running': running});
}
