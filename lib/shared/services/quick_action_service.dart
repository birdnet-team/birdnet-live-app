// =============================================================================
// Quick Action Service — Home-screen widget → app deep link
// =============================================================================
//
// Bridges the "Quick Listen" home-screen widget (Android:
// QuickListenWidgetProvider.kt) to Dart. Tapping the widget launches
// MainActivity with a native intent extra; MainActivity captures it and
// either forwards it immediately (app already running — "warm" case) or
// queues it for [takePendingNativeAction] to pick up once Dart starts
// listening (app was killed — "cold" case). Mirrors
// `features/aru/aru_notification.dart`'s native-action bridge.
// =============================================================================

import 'dart:io';

import 'package:flutter/services.dart';

abstract final class QuickActionService {
  /// Action sent when the Quick Listen widget is tapped.
  static const String startListeningAction = 'startListening';

  static const MethodChannel _intentChannel = MethodChannel(
    'com.birdnet/quick_action_intents',
  );

  /// Returns the action queued natively before Dart attached a listener
  /// (cold start), or `null` if there is none. Android-only; no-op
  /// elsewhere.
  static Future<String?> takePendingNativeAction() async {
    if (!Platform.isAndroid) return null;
    return _intentChannel.invokeMethod<String>('takePendingAction');
  }

  /// Registers [handler] to be called immediately when a quick action
  /// arrives while the app is already running (warm start). Pass `null`
  /// to detach. Android-only; no-op elsewhere.
  static void setNativeActionHandler(void Function(String action)? handler) {
    if (!Platform.isAndroid) return;
    if (handler == null) {
      _intentChannel.setMethodCallHandler(null);
      return;
    }
    _intentChannel.setMethodCallHandler((call) async {
      if (call.method == 'onQuickAction' && call.arguments is String) {
        final action = call.arguments as String;
        handler(action);
        await _intentChannel.invokeMethod<void>('clearPendingAction', action);
      }
    });
  }
}
