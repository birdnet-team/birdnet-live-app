package com.birdnet.birdnet_live

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Network type snapshot — the Android half of the `com.birdnet/connectivity`
 * channel. See lib/features/upload/connectivity.dart for the contract and
 * ConnectivityChannel.swift for the iOS half.
 *
 * `getType` answers `wifi`, `ethernet`, `cellular`, `none`, or `unknown` from
 * the capabilities of the active network. Used only to honor "Upload on
 * Wi-Fi only"; nothing is cached, the queue asks again on every run.
 */
class ConnectivityChannel(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL = "com.birdnet/connectivity"
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(::handle)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "getType") {
            result.notImplemented()
            return
        }
        try {
            result.success(currentType())
        } catch (e: Exception) {
            result.error("connectivity", e.message ?: e.javaClass.simpleName, null)
        }
    }

    private fun currentType(): String {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return "unknown"
        val network = manager.activeNetwork ?: return "none"
        val capabilities = manager.getNetworkCapabilities(network) ?: return "none"
        if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) return "none"
        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            // VPN over an unknown carrier: treat as metered unless it is clearly not.
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) -> "wifi"
            else -> "unknown"
        }
    }
}
