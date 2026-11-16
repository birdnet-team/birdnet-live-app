package com.birdnet.birdnet_live

import android.content.Context

/**
 * F-Droid build: no Play Asset Delivery. Always reports no pack so the Dart
 * side extracts the models bundled in `flutter_assets`.
 */
object AssetPackLocator {
    @Suppress("UNUSED_PARAMETER")
    fun packAssetsPath(context: Context, packName: String): String? = null
}
