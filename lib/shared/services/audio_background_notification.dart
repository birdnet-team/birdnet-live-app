import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import 'foreground_service_guard.dart';

enum AudioBackgroundMode { live, pointCount }

@pragma('vm:entry-point')
void audioBackgroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_AudioBackgroundTaskHandler());
}

class _AudioBackgroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'liveStop' || id == 'pointCountStop') {
      unawaited(() async {
        // The main isolate may be suspended. Keep the command until the
        // screen handles it on resume; the port message is the fast path.
        try {
          await FlutterForegroundTask.saveData(
            key:
                id == 'liveStop'
                    ? AudioBackgroundNotificationService.livePendingStopKey
                    : AudioBackgroundNotificationService
                        .pointCountPendingStopKey,
            value: id,
          ).timeout(const Duration(seconds: 2));
        } catch (error) {
          debugPrint('[AudioBackground] pending stop save: $error');
        }
        FlutterForegroundTask.sendDataToMain({'action': id});
        FlutterForegroundTask.launchApp();
      }());
    } else if (id == 'audioOpen') {
      FlutterForegroundTask.launchApp();
    }
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  void onNotificationDismissed() {}
}

/// Android microphone foreground service for Live Mode and Point Count.
/// Audio capture and inference remain in the app's main isolate.
class AudioBackgroundNotificationService {
  AudioBackgroundNotificationService(this.mode);

  static const livePendingStopKey = 'audioBackgroundLivePendingStop';
  static const pointCountPendingStopKey =
      'audioBackgroundPointCountPendingStop';

  final AudioBackgroundMode mode;
  bool _running = false;
  bool _starting = false;
  int _generation = 0;
  ForegroundServiceLease? _lease;

  bool get isRunning => _running;

  String get _pendingStopKey =>
      mode == AudioBackgroundMode.live
          ? livePendingStopKey
          : pointCountPendingStopKey;

  Future<bool> hasPendingStop() async {
    if (!Platform.isAndroid) return false;
    try {
      final action = await FlutterForegroundTask.getData<String>(
        key: _pendingStopKey,
      );
      return action ==
          (mode == AudioBackgroundMode.live ? 'liveStop' : 'pointCountStop');
    } catch (error) {
      debugPrint('[AudioBackground] pending stop read: $error');
      return false;
    }
  }

  Future<void> _clearPendingStop() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterForegroundTask.removeData(key: _pendingStopKey);
    } catch (error) {
      debugPrint('[AudioBackground] pending stop clear: $error');
    }
  }

  static bool _notificationPermissionRequested = false;

  /// Ask while the setup or settings screen is visible, before starting a
  /// microphone foreground service. A denied permission does not block it.
  /// Asks at most once per app run so a denial is not followed by a second
  /// prompt when the service starts (Android treats that as permanent).
  static Future<void> ensureNotificationPermission() async {
    if (!Platform.isAndroid || _notificationPermissionRequested) return;
    try {
      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        _notificationPermissionRequested = true;
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (error) {
      debugPrint('[AudioBackground] notification permission: $error');
    }
  }

  ForegroundServiceOwner get _owner => switch (mode) {
    AudioBackgroundMode.live => ForegroundServiceOwner.live,
    AudioBackgroundMode.pointCount => ForegroundServiceOwner.pointCount,
  };

  String _title(AppLocalizations l10n) => switch (mode) {
    AudioBackgroundMode.live => l10n.liveBackgroundNotificationTitle,
    AudioBackgroundMode.pointCount =>
      l10n.pointCountBackgroundNotificationTitle,
  };

  String _text(AppLocalizations l10n, int minutes) => switch (mode) {
    AudioBackgroundMode.live => l10n.liveBackgroundNotificationText(minutes),
    AudioBackgroundMode.pointCount => l10n.pointCountBackgroundNotificationText(
      minutes,
    ),
  };

  Future<bool> start(AppLocalizations l10n, int maxMinutes) async {
    if (!Platform.isAndroid) return true;
    if (_running) return true;
    if (_starting) return false;
    await _clearPendingStop();
    final generation = ++_generation;
    final lease = ForegroundServiceGuard.tryAcquire(_owner);
    if (lease == null) {
      return false;
    }
    _lease = lease;
    _starting = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'birdnet_audio_fg',
        channelName: l10n.backgroundAudioNotificationChannelName,
        channelDescription: l10n.backgroundAudioNotificationChannelDescription,
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    // A foreground service is allowed to run even when notification display
    // permission is denied. The OS may show its own fallback notification.
    await ensureNotificationPermission();
    if (generation != _generation) {
      _starting = false;
      lease.release();
      if (identical(_lease, lease)) _lease = null;
      return false;
    }

    final request = FlutterForegroundTask.startService(
      serviceId: 384,
      serviceTypes: const [ForegroundServiceTypes.microphone],
      notificationTitle: _title(l10n),
      notificationText: _text(l10n, maxMinutes),
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.birdnet.live.notification_icon',
      ),
      notificationButtons: [
        NotificationButton(
          id: mode == AudioBackgroundMode.live ? 'liveStop' : 'pointCountStop',
          text: l10n.notificationStop,
        ),
        NotificationButton(id: 'audioOpen', text: l10n.notificationOpen),
      ],
      callback: audioBackgroundTaskCallback,
    );

    try {
      final result = await request.timeout(const Duration(seconds: 5));
      if (generation != _generation) {
        if (result is ServiceRequestSuccess && lease.isCurrent) {
          await FlutterForegroundTask.stopService();
        }
        _starting = false;
        lease.release();
        if (identical(_lease, lease)) _lease = null;
        return false;
      }
      _starting = false;
      _running = result is ServiceRequestSuccess;
      if (!_running) {
        lease.release();
        if (identical(_lease, lease)) _lease = null;
      }
      return _running;
    } on TimeoutException {
      // The platform request cannot be canceled. Clean up if it completes
      // after the caller has already fallen back to foreground-only capture.
      unawaited(() async {
        try {
          final result = await request;
          if (result is ServiceRequestSuccess && lease.isCurrent) {
            await FlutterForegroundTask.stopService();
          }
        } catch (error) {
          debugPrint('[AudioBackground] late service start: $error');
        } finally {
          _starting = false;
          lease.release();
          if (identical(_lease, lease)) _lease = null;
        }
      }());
      return false;
    } catch (error) {
      _starting = false;
      lease.release();
      if (identical(_lease, lease)) _lease = null;
      debugPrint('[AudioBackground] service start: $error');
      return false;
    }
  }

  Future<void> update(AppLocalizations l10n, int maxMinutes) async {
    if (!_running) return;
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: _title(l10n),
        notificationText: _text(l10n, maxMinutes),
        notificationIcon: const NotificationIcon(
          metaDataName: 'com.birdnet.live.notification_icon',
        ),
      );
    } catch (error) {
      debugPrint('[AudioBackground] service update: $error');
    }
  }

  Future<void> stop() async {
    ++_generation;
    if (!_running) {
      if (!_starting) {
        _lease?.release();
        _lease = null;
      }
      await _clearPendingStop();
      return;
    }
    try {
      await FlutterForegroundTask.stopService().timeout(
        const Duration(seconds: 3),
      );
    } catch (error) {
      debugPrint('[AudioBackground] service stop: $error');
    } finally {
      _running = false;
      _lease?.release();
      _lease = null;
      await _clearPendingStop();
    }
  }
}
