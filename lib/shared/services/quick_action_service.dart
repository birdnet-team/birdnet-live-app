// =============================================================================
// Quick Action Service — Quick Listen entry points → app deep link
// =============================================================================
//
// Bridges the native "Quick Listen" entry points to Dart. On Android that is
// the home-screen widget (QuickListenWidgetProvider.kt); on iOS it is the
// "Start Listening" App Intent (Shortcuts, Siri, Action Button), the
// `birdnetlive://listen` URL, and the app icon's long-press menu
// (QuickAction.swift). Either platform queues the action natively and either
// forwards it immediately (app already running — "warm" case) or holds it for
// [takePendingNativeAction] to pick up once Dart starts listening (app was
// killed — "cold" case). Mirrors `features/aru/aru_notification.dart`'s
// native-action bridge.
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class QuickActionService {
  /// Action sent by every Quick Listen entry point.
  static const String startListeningAction = 'startListening';

  /// Prefix of an action that carries an upload-destination join link
  /// (#284): `join:<url>`. Produced by MainActivity.kt and QuickAction.swift.
  static const String joinActionPrefix = 'join:';

  static const MethodChannel _intentChannel = MethodChannel(
    'com.birdnet/quick_action_intents',
  );

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  /// Returns the action queued natively before Dart attached a listener
  /// (cold start), or `null` if there is none. Android and iOS only; no-op
  /// elsewhere.
  static Future<String?> takePendingNativeAction() async {
    if (!_supported) return null;
    return _intentChannel.invokeMethod<String>('takePendingAction');
  }

  /// Registers [handler] to be called immediately when a quick action
  /// arrives while the app is already running (warm start). Pass `null`
  /// to detach. Android and iOS only; no-op elsewhere.
  static void setNativeActionHandler(void Function(String action)? handler) {
    if (!_supported) return;
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

enum QuickListenSessionOwner { pointCount, survey, fileAnalysis }

/// Tracks recording screens that Quick Listen must not replace.
///
/// Owner tokens make registration idempotent and remain correct while routes
/// overlap during a transition.
abstract final class QuickListenSafety {
  static final Map<Object, QuickListenSessionOwner> _incompatibleSessionOwners =
      <Object, QuickListenSessionOwner>{};

  static QuickListenSessionOwner? get activeSessionOwner {
    if (_incompatibleSessionOwners.isEmpty) return null;
    return _incompatibleSessionOwners.values.last;
  }

  static void registerIncompatibleSessionOwner(
    Object owner,
    QuickListenSessionOwner mode,
  ) {
    _incompatibleSessionOwners[owner] = mode;
  }

  static void unregisterIncompatibleSessionOwner(Object owner) {
    _incompatibleSessionOwners.remove(owner);
  }

  @visibleForTesting
  static void reset() {
    _incompatibleSessionOwners.clear();
  }
}
