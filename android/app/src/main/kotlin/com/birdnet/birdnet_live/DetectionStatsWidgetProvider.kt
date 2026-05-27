package com.birdnet.birdnet_live

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.util.TypedValue
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DetectionStatsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        appWidgetIds.forEach { appWidgetId ->
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        appWidgetIds.forEach { id ->
            DetectionStatsWidgetStore.clearSettings(context, id)
        }
    }

    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, DetectionStatsWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            ids.forEach { id -> updateWidget(context, manager, id) }
        }

        fun updateWidget(context: Context, appWidgetId: Int) {
            val manager = AppWidgetManager.getInstance(context)
            updateWidget(context, manager, appWidgetId)
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val sizeClass = classifySize(minWidth, minHeight)
            val settings = DetectionStatsWidgetStore.loadSettings(context, appWidgetId)

            val all = DetectionStatsWidgetStore.readDetections(context)
            val now = System.currentTimeMillis()
            val cutoff = DetectionStatsWidgetStore.timeframeCutoffMillis(settings.timeframe, now)
            val filtered = all.filter { it.timestampMs >= cutoff }.sortedByDescending { it.timestampMs }

            val views = when (sizeClass) {
                SizeClass.SMALL -> buildSmallViews(context, appWidgetId, settings, filtered)
                SizeClass.EXPANDED -> buildExpandedViews(context, appWidgetId, settings, filtered)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun buildSmallViews(
            context: Context,
            appWidgetId: Int,
            settings: DetectionStatsWidgetSettings,
            detections: List<StatsDetection>,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.detection_stats_widget_small)
            styleCommon(views, R.id.stats_widget_root_small, settings)
            applyOpenAppIntent(context, views, R.id.stats_widget_root_small, appWidgetId)

            val latest = detections.firstOrNull()
            if (latest == null) {
                views.setImageViewResource(R.id.stats_small_image, R.mipmap.ic_launcher)
            } else {
                applyImage(views, R.id.stats_small_image, latest.imagePath)
            }
            return views
        }

        private fun buildExpandedViews(
            context: Context,
            appWidgetId: Int,
            settings: DetectionStatsWidgetSettings,
            detections: List<StatsDetection>,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.detection_stats_widget_large)
            styleCommon(views, R.id.stats_widget_root_large, settings)
            applyOpenAppIntent(context, views, R.id.stats_widget_root_large, appWidgetId)
            applyConfigIntent(context, views, R.id.stats_large_settings, appWidgetId)

            views.setTextViewText(
                R.id.stats_large_title,
                context.getString(R.string.stats_widget_large_title, timeframeLabel(context, settings.timeframe)),
            )

            val latest = detections.take(3)
            views.setTextViewText(
                R.id.stats_large_latest_1,
                latest.getOrNull(0)?.commonName ?: context.getString(R.string.stats_widget_no_recent_species),
            )
            views.setTextViewText(
                R.id.stats_large_latest_2,
                latest.getOrNull(1)?.commonName ?: "",
            )
            views.setTextViewText(
                R.id.stats_large_latest_3,
                latest.getOrNull(2)?.commonName ?: "",
            )

            val speciesCount = detections.map { it.scientificName }.toSet().size
            views.setTextViewText(
                R.id.stats_large_total_detections,
                context.getString(R.string.stats_widget_total_detections, detections.size),
            )
            views.setTextViewText(
                R.id.stats_large_total_species,
                context.getString(R.string.stats_widget_total_species, speciesCount),
            )

            val hero = latest.firstOrNull()
            if (hero != null) {
                applyImage(views, R.id.stats_large_image, hero.imagePath)
            } else {
                views.setImageViewResource(R.id.stats_large_image, R.mipmap.ic_launcher)
            }

            val textIds = listOf(
                R.id.stats_large_title,
                R.id.stats_large_latest_label,
                R.id.stats_large_latest_1,
                R.id.stats_large_latest_2,
                R.id.stats_large_latest_3,
                R.id.stats_large_total_detections,
                R.id.stats_large_total_species,
            )
            textIds.forEach { setFontSize(views, it, settings.fontSizeSp) }
            setFontSize(views, R.id.stats_large_title, settings.fontSizeSp + 1)

            return views
        }

        private fun styleCommon(
            views: RemoteViews,
            rootId: Int,
            settings: DetectionStatsWidgetSettings,
        ) {
            val alpha = ((100 - settings.transparencyPercent).coerceIn(10, 100) * 255 / 100)
            val color = Color.argb(alpha, 18, 30, 40)
            views.setInt(rootId, "setBackgroundColor", color)
        }

        private fun applyImage(views: RemoteViews, imageViewId: Int, imagePath: String?) {
            if (imagePath.isNullOrBlank()) {
                views.setImageViewResource(imageViewId, R.mipmap.ic_launcher)
                return
            }
            val bitmap = BitmapFactory.decodeFile(imagePath)
            if (bitmap != null) {
                views.setImageViewBitmap(imageViewId, bitmap)
            } else {
                views.setImageViewResource(imageViewId, R.mipmap.ic_launcher)
            }
        }

        private fun applyOpenAppIntent(
            context: Context,
            views: RemoteViews,
            viewId: Int,
            appWidgetId: Int,
        ) {
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 10000,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(viewId, pendingIntent)
        }

        private fun applyConfigIntent(
            context: Context,
            views: RemoteViews,
            viewId: Int,
            appWidgetId: Int,
        ) {
            val intent = Intent(context, DetectionStatsWidgetConfigActivity::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_CONFIGURE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 20000,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(viewId, pendingIntent)
        }

        private fun setFontSize(views: RemoteViews, viewId: Int, sizeSp: Int) {
            views.setTextViewTextSize(viewId, TypedValue.COMPLEX_UNIT_SP, sizeSp.toFloat())
        }

        private fun formatTimestamp(timestampMs: Long): String {
            if (timestampMs <= 0L) return ""
            val formatter = SimpleDateFormat("MMM d, HH:mm", Locale.getDefault())
            return formatter.format(Date(timestampMs))
        }

        private fun timeframeLabel(context: Context, timeframe: String): String {
            return when (timeframe) {
                DetectionStatsWidgetContract.timeframe7d ->
                    context.getString(R.string.stats_widget_timeframe_7d)
                DetectionStatsWidgetContract.timeframe30d ->
                    context.getString(R.string.stats_widget_timeframe_30d)
                else -> context.getString(R.string.stats_widget_timeframe_24h)
            }
        }

        private fun classifySize(minWidthDp: Int, minHeightDp: Int): SizeClass {
            return when {
                minWidthDp >= 130 || minHeightDp >= 100 -> SizeClass.EXPANDED
                else -> SizeClass.SMALL
            }
        }
    }
}

private enum class SizeClass {
    SMALL,
    EXPANDED,
}
