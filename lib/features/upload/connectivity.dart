// =============================================================================
// Connectivity — which kind of network the device is on right now
// =============================================================================
//
// Backs the per-destination "Upload on Wi-Fi only" switch. The
// `com.birdnet/connectivity` channel answers one method, `getType`, with one
// of `wifi`, `ethernet`, `cellular`, `none`, or `unknown` (ConnectivityChannel.kt
// and ConnectivityChannel.swift). Desktop platforms have no channel and count
// as unmetered. The answer is a snapshot; the queue asks again on every run.
// =============================================================================

import 'dart:io' show Platform;

import 'package:flutter/services.dart';

enum NetworkType { wifi, ethernet, cellular, none, unknown }

extension NetworkTypeUpload on NetworkType {
  /// Whether a Wi-Fi-only destination may upload on this network. Unknown
  /// counts as allowed so a missing channel never blocks uploads for good.
  bool get allowsWifiOnlyUpload =>
      this == NetworkType.wifi ||
      this == NetworkType.ethernet ||
      this == NetworkType.unknown;

  bool get isOffline => this == NetworkType.none;
}

abstract class Connectivity {
  Future<NetworkType> currentType();
}

class PlatformConnectivity implements Connectivity {
  PlatformConnectivity({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  static const MethodChannel defaultChannel = MethodChannel(
    'com.birdnet/connectivity',
  );

  final MethodChannel _channel;

  @override
  Future<NetworkType> currentType() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return NetworkType.unknown;
    try {
      final raw = await _channel.invokeMethod<String>('getType');
      return NetworkType.values.firstWhere(
        (t) => t.name == raw,
        orElse: () => NetworkType.unknown,
      );
    } on PlatformException {
      return NetworkType.unknown;
    } on MissingPluginException {
      return NetworkType.unknown;
    }
  }
}

/// Fixed answer for tests.
class FixedConnectivity implements Connectivity {
  FixedConnectivity(this.type);
  NetworkType type;

  @override
  Future<NetworkType> currentType() async => type;
}
