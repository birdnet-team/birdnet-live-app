// =============================================================================
// Upload Background — run the queue while the app is closed (Android)
// =============================================================================
//
// Android's WorkManager starts UploadWorker.kt when the device is on a
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
// iOS has no equivalent yet; there the queue runs whenever the app is open.
// =============================================================================

import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/app_providers.dart';
import '../explore/explore_providers.dart';
import 'upload_providers.dart';

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
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
    pending = service.pendingCount;
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
