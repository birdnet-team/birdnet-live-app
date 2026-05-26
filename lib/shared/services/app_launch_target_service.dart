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

/// Complete launch request emitted by a widget or other external surface.
class AppLaunchRequest {
  const AppLaunchRequest({required this.target, this.autoStartLive = false});

  final AppLaunchTarget target;
  final bool autoStartLive;
}

/// Parse a platform payload into a known [AppLaunchRequest].
AppLaunchRequest? parseAppLaunchRequest(dynamic raw) {
  if (raw is String?) {
    return _requestForTarget(_parseTarget(raw));
  }

  if (raw is Map<Object?, Object?>) {
    final target = _parseTarget(raw['target']?.toString());
    if (target == null) return null;
    return AppLaunchRequest(
      target: target,
      autoStartLive: raw['liveAutoStart'] == true,
    );
  }

  return null;
}

AppLaunchRequest? _requestForTarget(AppLaunchTarget? target) {
  if (target == null) return null;
  return AppLaunchRequest(target: target);
}

AppLaunchTarget? _parseTarget(String? raw) {
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
  Future<AppLaunchRequest?> takeInitialTarget() async {
    try {
      final raw = await _methodChannel.invokeMethod<dynamic>('takeInitialTarget');
      return parseAppLaunchRequest(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Stream launch targets that arrive while the app is already running.
  Stream<AppLaunchRequest> watchTargets() {
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
        .map(parseAppLaunchRequest)
        .transform<AppLaunchRequest>(
          StreamTransformer<AppLaunchRequest?, AppLaunchRequest>.fromHandlers(
            handleData: (request, sink) {
              if (request != null) sink.add(request);
            },
          ),
        );
  }
}
