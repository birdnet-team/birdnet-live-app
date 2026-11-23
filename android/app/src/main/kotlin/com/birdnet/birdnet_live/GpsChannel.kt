package com.birdnet.birdnet_live

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/**
 * Satellite fixes for Survey tracks — the Android side of the
 * `com.birdnet/gps` event channel. See lib/core/services/gps_fix_stream.dart
 * for the contract.
 *
 * Listens to the platform `gps` provider directly. geolocator's
 * LocationManager client picks the `fused` provider on Android 12+, which on
 * Google devices is Play Services and mixes Wi-Fi and cell positions into a
 * track. The `gps` provider is part of AOSP, needs no Play Services, and does
 * not depend on the Google Location Accuracy switch.
 *
 * The stream answers with an `unavailable` error when precise location is not
 * granted or the provider is missing or turned off; the Dart side then falls
 * back to geolocator. Updates are requested at the Survey GPS interval, so the
 * receiver can sleep between fixes.
 */
class GpsChannel(private val context: Context, messenger: BinaryMessenger) :
    EventChannel.StreamHandler {
    companion object {
        const val CHANNEL = "com.birdnet/gps"
        private const val UNAVAILABLE = "unavailable"
    }

    private val channel = EventChannel(messenger, CHANNEL)
    private val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
    private var listener: LocationListener? = null

    init {
        channel.setStreamHandler(this)
    }

    fun dispose() {
        stop()
        channel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
        val args = arguments as? Map<*, *>
        val intervalMs = (args?.get("intervalMs") as? Number)?.toLong() ?: 10_000L
        val minDistanceMeters = (args?.get("minDistanceMeters") as? Number)?.toFloat() ?: 0f

        val manager = manager
        val reason = when {
            manager == null -> "no location manager"
            context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
                PackageManager.PERMISSION_GRANTED -> "precise location not granted"
            !manager.allProviders.contains(LocationManager.GPS_PROVIDER) -> "no gps provider"
            !manager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> "gps provider is off"
            else -> null
        }
        if (manager == null || reason != null) {
            events.error(UNAVAILABLE, reason, null)
            return
        }

        val newListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                events.success(toMap(location))
            }

            override fun onProviderDisabled(provider: String) {
                if (listener !== this) return
                stop()
                events.error(UNAVAILABLE, "gps provider turned off", null)
            }

            override fun onProviderEnabled(provider: String) {}

            // Abstract before API 30; never called from API 29 on.
            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }
        try {
            manager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                intervalMs,
                minDistanceMeters,
                newListener,
                Looper.getMainLooper(),
            )
            listener = newListener
        } catch (e: Exception) {
            // SecurityException when the permission is revoked between the
            // check and the request; IllegalArgumentException on odd devices.
            events.error(UNAVAILABLE, e.message ?: e.javaClass.simpleName, null)
        }
    }

    override fun onCancel(arguments: Any?) {
        stop()
    }

    private fun stop() {
        val current = listener ?: return
        listener = null
        try {
            manager?.removeUpdates(current)
        } catch (_: Exception) {
        }
    }

    private fun toMap(location: Location): Map<String, Any> {
        val fix = HashMap<String, Any>()
        fix["lat"] = location.latitude
        fix["lon"] = location.longitude
        fix["t"] = location.time
        if (location.hasAccuracy()) fix["acc"] = location.accuracy.toDouble()
        // The gps provider reports height above the WGS84 ellipsoid.
        if (location.hasAltitude()) fix["alt"] = location.altitude
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && location.hasVerticalAccuracy()) {
            fix["vAcc"] = location.verticalAccuracyMeters.toDouble()
        }
        return fix
    }
}
