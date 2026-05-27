package com.birdnet.birdnet_live

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class LiveModeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)

        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
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

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)

        // 1x1 stays icon-only; once widened to ~2 cells show icon + 2-line label.
        val expanded = minWidth >= 110
        val layout = if (expanded) {
            R.layout.live_mode_widget
        } else {
            R.layout.live_mode_widget_icon
        }
        val rootId = if (expanded) R.id.widget_root else R.id.widget_root_icon

        val views = RemoteViews(context.packageName, layout)
        views.setOnClickPendingIntent(rootId, buildLaunchPendingIntent(context, widgetId))
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun buildLaunchPendingIntent(
        context: Context,
        widgetId: Int,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = AppLaunchTargetContract.actionOpenLiveMode
            putExtra(
                AppLaunchTargetContract.extraTarget,
                AppLaunchTargetContract.targetLive,
            )
            putExtra(AppLaunchTargetContract.extraLiveAutoStart, true)
            // Always relaunch through a clean task entry so repeated widget
            // taps cannot revive a stale route stack from a previous app run.
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }

        return PendingIntent.getActivity(
            context,
            widgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
