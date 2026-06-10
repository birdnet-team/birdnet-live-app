import 'package:flutter/services.dart';

/// Lightweight wakelock via platform channel — keeps the screen on.
///
/// Uses Android's `FLAG_KEEP_SCREEN_ON` window flag under the hood.
/// No third-party dependency required.
class WakelockService {
  static const _channel = MethodChannel('com.birdnet/wakelock');

  /// Keep the screen awake.
  static Future<void> enable() => _invokeSafely('enable');

  /// Allow the screen to turn off normally.
  static Future<void> disable() => _invokeSafely('disable');

  static Future<void> _invokeSafely(String method) async {
    try {
      await _channel.invokeMethod(method);
    } on MissingPluginException {
      // Wakelock channel is only implemented on some platforms.
      // Unsupported platforms should continue without crashing.
    }
  }
}
