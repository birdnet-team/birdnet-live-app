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
            val views = RemoteViews(context.packageName, R.layout.live_mode_widget)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                buildLaunchPendingIntent(context, widgetId),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
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
