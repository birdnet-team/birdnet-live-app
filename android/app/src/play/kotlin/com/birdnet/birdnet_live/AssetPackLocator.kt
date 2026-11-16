package com.birdnet.birdnet_live

import android.content.Context
import com.google.android.play.core.assetpacks.AssetPackManagerFactory

/**
 * Resolves the on-device path of an install-time Play Asset Delivery pack.
 * Play flavor only; the F-Droid source set ships a stub that returns null.
 */
object AssetPackLocator {
    fun packAssetsPath(context: Context, packName: String): String? =
        AssetPackManagerFactory.getInstance(context).getPackLocation(packName)?.assetsPath()
}
