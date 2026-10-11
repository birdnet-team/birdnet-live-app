// =============================================================================
// ARU Notification Service - Foreground notification for scheduled deployments
// =============================================================================

import 'dart:io';
import 'dart:ui';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/shared/services/foreground_service_guard.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void aruTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_AruTaskHandler());
}

class _AruTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[AruTaskHandler] onStart');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[AruTaskHandler] onDestroy');
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == AruNotificationService.stopActionId) {
      FlutterForegroundTask.wakeUpScreen();
      FlutterForegroundTask.launchApp(AruNotificationService.stopRoute);
      FlutterForegroundTask.sendDataToMain({'action': 'aruStop'});
    } else if (id == AruNotificationService.openActionId) {
      FlutterForegroundTask.wakeUpScreen();
      FlutterForegroundTask.launchApp(AruNotificationService.openRoute);
      FlutterForegroundTask.sendDataToMain({'action': 'aruOpen'});
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.sendDataToMain({'action': 'aruOpen'});
  }

  @override
  void onNotificationDismissed() {}
}

class AruNotificationService {
  static const String stopActionId = 'aruStop';
  static const String openActionId = 'aruOpen';
  static const String openRoute = '/aru-active';
  static const String stopRoute = '/aru-stop';
  static const int serviceId = 512;
  static const MethodChannel _notificationChannel = MethodChannel(
    'com.birdnet/aru_notification',
  );
  static const MethodChannel _intentChannel = MethodChannel(
    'com.birdnet/aru_notification_intents',
  );

  static String _notificationTitle = '';
  static String _stopButtonText = '';
  static String _openButtonText = '';
  static const Duration _startRetryDelay = Duration(minutes: 1);
  bool _running = false;
  bool _starting = false;
  DateTime? _nextStartAttempt;
  String? _lastTitle;
  String? _lastText;

  bool get isRunning => _running;
  static String get notificationTitle => _notificationTitle;

  static Future<void> init() async {
    final l10n = await _loadAppLocalizations();
    _applyLocalizedStrings(l10n);

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'birdnet_aru_fg',
        channelName: l10n.aruNotificationChannelName,
        channelDescription: l10n.aruNotificationChannelDescription,
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
  }

  static Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return true;
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission == NotificationPermission.granted) return true;
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  Future<void> start({required String title, required String text}) async {
    if (!Platform.isAndroid) return;
    if (_running || _starting) return;
    if (!ForegroundServiceGuard.tryClaim(ForegroundServiceOwner.aru)) {
      debugPrint(
        '[AruNotification] foreground service already owned by '
        '${ForegroundServiceGuard.owner}; not starting',
      );
      return;
    }

    final now = DateTime.now();
    final nextAttempt = _nextStartAttempt;
    if (nextAttempt != null && now.isBefore(nextAttempt)) {
      return;
    }

    _starting = true;
    try {
      await init();

      final granted = await ensurePermission();
      if (!granted) {
        debugPrint(
          '[AruNotification] permission not granted - attempting startService',
        );
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: serviceId,
        // Explicit rather than the manifest's `microphone|location`: an ARU
        // deployment records at a fixed position and never tracks GPS, and on
        // Android 14+ declaring `location` without a granted location
        // permission makes the service fail to start.
        serviceTypes: const [ForegroundServiceTypes.microphone],
        notificationTitle: title,
        notificationText: text,
        notificationInitialRoute: openRoute,
        notificationIcon: const NotificationIcon(
          metaDataName: 'com.birdnet.live.notification_icon',
        ),
        callback: aruTaskCallback,
      );
      if (result is ServiceRequestSuccess) {
        _running = true;
        _lastTitle = title;
        _lastText = text;
        _nextStartAttempt = null;
        await _updateNativeNotificationActions(title: title, text: text);
        debugPrint('[AruNotification] started');
      } else {
        _running = false;
        ForegroundServiceGuard.release(ForegroundServiceOwner.aru);
        _nextStartAttempt = now.add(_startRetryDelay);
        debugPrint(
          '[AruNotification] startService failed: $result. '
          'Retrying in ${_startRetryDelay.inSeconds}s.',
        );
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> update({required String title, required String text}) async {
    if (!_running) return;
    if (_lastTitle == title && _lastText == text) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
      notificationInitialRoute: openRoute,
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.birdnet.live.notification_icon',
      ),
    );
    await _updateNativeNotificationActions(title: title, text: text);
    _lastTitle = title;
    _lastText = text;
  }

  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    _running = false;
    _lastTitle = null;
    _lastText = null;
    _nextStartAttempt = null;
    ForegroundServiceGuard.release(ForegroundServiceOwner.aru);
    debugPrint('[AruNotification] stopped');
  }

  static void updateLocalizedStrings(AppLocalizations l10n) {
    _applyLocalizedStrings(l10n);
  }

  static Future<String?> takePendingNativeAction() async {
    if (!Platform.isAndroid) return null;
    final action = await _intentChannel.invokeMethod<String>(
      'takePendingAction',
    );
    return action;
  }

  static void setNativeActionHandler(void Function(String action)? handler) {
    if (!Platform.isAndroid) return;
    _intentChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationAction' && call.arguments is String) {
        final action = call.arguments as String;
        handler?.call(action);
        await _intentChannel.invokeMethod<void>('clearPendingAction', action);
      }
    });
  }

  static Future<void> _updateNativeNotificationActions({
    required String title,
    required String text,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _notificationChannel.invokeMethod<void>('update', {
        'serviceId': serviceId,
        'channelId': 'birdnet_aru_fg',
        'title': title,
        'text': text,
        'stopText': _stopButtonText,
        'openText': _openButtonText,
        'openAction': openActionId,
        'stopAction': stopActionId,
        'openRoute': openRoute,
        'stopRoute': stopRoute,
      });
    } catch (error, stackTrace) {
      debugPrint('[AruNotification] native update failed: $error\n$stackTrace');
    }
  }
}

void _applyLocalizedStrings(AppLocalizations l10n) {
  AruNotificationService._notificationTitle = l10n.aruNotificationTitle;
  AruNotificationService._stopButtonText = l10n.notificationStop;
  AruNotificationService._openButtonText = l10n.notificationOpen;
}

Future<AppLocalizations> _loadAppLocalizations() async {
  final prefs = await SharedPreferences.getInstance();
  final savedLocaleCode = prefs.getString(PrefKeys.locale);
  final deviceLocale = PlatformDispatcher.instance.locale;
  final supportedLocale = AppLocalizations.supportedLocales.firstWhere(
    (locale) =>
        locale.languageCode == (savedLocaleCode ?? deviceLocale.languageCode),
    orElse: () => const Locale('en'),
  );
  return AppLocalizations.delegate.load(supportedLocale);
}
