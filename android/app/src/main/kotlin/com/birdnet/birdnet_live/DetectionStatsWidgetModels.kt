package com.birdnet.birdnet_live

import android.content.Context
import org.json.JSONObject

internal object DetectionStatsWidgetContract {
    const val flutterPrefsName = "FlutterSharedPreferences"
    const val flutterSnapshotKey = "flutter.widget_stats_snapshot_v1"

    const val widgetPrefsName = "detection_stats_widget"
    const val keyTimeframePrefix = "timeframe_"
    const val keyTransparencyPrefix = "transparency_"
    const val keyFontSizePrefix = "font_size_"

    const val timeframe24h = "24h"
    const val timeframe7d = "7d"
    const val timeframe30d = "30d"
}

internal data class StatsDetection(
    val scientificName: String,
    val commonName: String,
    val confidence: Double,
    val timestampMs: Long,
    val imagePath: String?,
)

internal data class DetectionStatsWidgetSettings(
    val timeframe: String = DetectionStatsWidgetContract.timeframe24h,
    val transparencyPercent: Int = 24,
    val fontSizeSp: Int = 14,
)

internal object DetectionStatsWidgetStore {
    fun loadSettings(context: Context, appWidgetId: Int): DetectionStatsWidgetSettings {
        val prefs = context.getSharedPreferences(
            DetectionStatsWidgetContract.widgetPrefsName,
            Context.MODE_PRIVATE,
        )
        return DetectionStatsWidgetSettings(
            timeframe = prefs.getString(
                "${DetectionStatsWidgetContract.keyTimeframePrefix}$appWidgetId",
                DetectionStatsWidgetContract.timeframe24h,
            ) ?: DetectionStatsWidgetContract.timeframe24h,
            transparencyPercent = prefs.getInt(
                "${DetectionStatsWidgetContract.keyTransparencyPrefix}$appWidgetId",
                24,
            ).coerceIn(0, 90),
            fontSizeSp = prefs.getInt(
                "${DetectionStatsWidgetContract.keyFontSizePrefix}$appWidgetId",
                14,
            ).coerceIn(11, 24),
        )
    }

    fun saveSettings(
        context: Context,
        appWidgetId: Int,
        settings: DetectionStatsWidgetSettings,
    ) {
        context.getSharedPreferences(
            DetectionStatsWidgetContract.widgetPrefsName,
            Context.MODE_PRIVATE,
        )
            .edit()
            .putString(
                "${DetectionStatsWidgetContract.keyTimeframePrefix}$appWidgetId",
                settings.timeframe,
            )
            .putInt(
                "${DetectionStatsWidgetContract.keyTransparencyPrefix}$appWidgetId",
                settings.transparencyPercent.coerceIn(0, 90),
            )
            .putInt(
                "${DetectionStatsWidgetContract.keyFontSizePrefix}$appWidgetId",
                settings.fontSizeSp.coerceIn(11, 24),
            )
            .apply()
    }

    fun clearSettings(context: Context, appWidgetId: Int) {
        context.getSharedPreferences(
            DetectionStatsWidgetContract.widgetPrefsName,
            Context.MODE_PRIVATE,
        )
            .edit()
            .remove("${DetectionStatsWidgetContract.keyTimeframePrefix}$appWidgetId")
            .remove("${DetectionStatsWidgetContract.keyTransparencyPrefix}$appWidgetId")
            .remove("${DetectionStatsWidgetContract.keyFontSizePrefix}$appWidgetId")
            .apply()
    }

    fun readDetections(context: Context): List<StatsDetection> {
        val prefs = context.getSharedPreferences(
            DetectionStatsWidgetContract.flutterPrefsName,
            Context.MODE_PRIVATE,
        )
        val raw = prefs.getString(DetectionStatsWidgetContract.flutterSnapshotKey, null)
            ?: return emptyList()

        return try {
            val payload = JSONObject(raw)
            val detections = payload.optJSONArray("detections") ?: return emptyList()
            buildList(detections.length()) {
                for (i in 0 until detections.length()) {
                    val item = detections.optJSONObject(i) ?: continue
                    add(
                        StatsDetection(
                            scientificName = item.optString("scientificName", ""),
                            commonName = item.optString("commonName", "Unknown"),
                            confidence = item.optDouble("confidence", 0.0),
                            timestampMs = item.optLong("timestampMs", 0L),
                            imagePath = item.optString("imagePath", "").ifBlank { null },
                        ),
                    )
                }
            }
        } catch (_: Throwable) {
            emptyList()
        }
    }

    fun timeframeCutoffMillis(timeframe: String, nowMs: Long): Long {
        val days = when (timeframe) {
            DetectionStatsWidgetContract.timeframe7d -> 7L
            DetectionStatsWidgetContract.timeframe30d -> 30L
            else -> 1L
        }
        return nowMs - days * 24L * 60L * 60L * 1000L
    }
}
