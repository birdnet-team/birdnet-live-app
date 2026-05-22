// =============================================================================
// App Launch Target Service
// =============================================================================
//
// Provides a platform-neutral wrapper around launcher intents / shortcuts.
// Android can hand us a pending target such as "open Live mode now" via a
// platform channel, while other platforms simply return no target.
// =============================================================================

import 'dart:async';

import 'package:flutter/services.dart';

/// App destination requested by an external launcher surface.
enum AppLaunchTarget { live }

/// Parse a platform payload into a known [AppLaunchTarget].
AppLaunchTarget? parseAppLaunchTarget(String? raw) {
  return switch (raw) {
    'live' => AppLaunchTarget.live,
    _ => null,
  };
}

/// Platform-channel bridge for external launch targets.
class AppLaunchTargetService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.birdnet/launch_target',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.birdnet/launch_target_events',
  );

  const AppLaunchTargetService();

  /// Consume the initial target that launched the app, if any.
  Future<AppLaunchTarget?> takeInitialTarget() async {
    try {
      final raw = await _methodChannel.invokeMethod<String>('takeInitialTarget');
      return parseAppLaunchTarget(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Stream launch targets that arrive while the app is already running.
  Stream<AppLaunchTarget> watchTargets() {
    return _eventChannel
        .receiveBroadcastStream()
        .transform<dynamic>(
          StreamTransformer<dynamic, dynamic>.fromHandlers(
            handleData: (event, sink) => sink.add(event),
            handleError: (Object error, StackTrace stackTrace, sink) {
              if (error is MissingPluginException) {
                return;
              }
              sink.addError(error, stackTrace);
            },
          ),
        )
        .map((dynamic event) => parseAppLaunchTarget(event?.toString()))
        .transform<AppLaunchTarget>(
          StreamTransformer<AppLaunchTarget?, AppLaunchTarget>.fromHandlers(
            handleData: (target, sink) {
              if (target != null) sink.add(target);
            },
          ),
        );
  }
}