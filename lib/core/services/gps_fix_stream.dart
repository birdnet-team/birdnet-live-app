// =============================================================================
// GPS Fix Stream — satellite fixes from Android's `gps` provider
// =============================================================================
//
// Dart side of the `com.birdnet/gps` event channel (GpsChannel.kt). Survey
// tracking uses it on Android instead of geolocator, whose LocationManager
// client selects the `fused` provider on Android 12+. On Google devices that
// provider is Play Services and mixes Wi-Fi and cell positions into a track.
//
// The stream emits an error when the `gps` provider cannot be used (precise
// location not granted, provider missing or turned off). Callers fall back to
// geolocator in that case. Other platforms do not implement the channel.
// =============================================================================

import 'package:flutter/services.dart';

import '../../shared/models/altitude_reference.dart';
import '../../shared/models/gps_point.dart';

const _channel = EventChannel('com.birdnet/gps');

/// Fixes from the Android `gps` provider, requested every [interval].
///
/// The provider starts when the stream is listened to and stops when the
/// subscription is canceled.
///
/// No minimum distance is requested: the receiver runs on the interval
/// either way, and the track filter needs the fixes of a stationary device.
Stream<GpsPoint> androidGpsFixes({required Duration interval}) {
  return _channel
      .receiveBroadcastStream({
        'intervalMs': interval.inMilliseconds,
        'minDistanceMeters': 0,
      })
      .map((event) => gpsPointFromFix(event as Map<Object?, Object?>));
}

/// Convert one channel event into a [GpsPoint].
GpsPoint gpsPointFromFix(Map<Object?, Object?> fix) {
  final altitude = (fix['alt'] as num?)?.toDouble();
  final verticalAccuracy = (fix['vAcc'] as num?)?.toDouble();
  return GpsPoint(
    latitude: (fix['lat'] as num).toDouble(),
    longitude: (fix['lon'] as num).toDouble(),
    accuracy: (fix['acc'] as num?)?.toDouble(),
    altitude: altitude,
    altitudeAccuracy:
        altitude != null && verticalAccuracy != null && verticalAccuracy > 0
        ? verticalAccuracy
        : null,
    altitudeReference: altitude != null
        ? AltitudeReference.wgs84Ellipsoid
        : null,
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      (fix['t'] as num).toInt(),
      isUtc: true,
    ),
  );
}
