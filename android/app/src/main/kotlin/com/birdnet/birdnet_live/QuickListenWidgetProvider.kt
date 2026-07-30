package com.birdnet.birdnet_live

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

/**
 * Shared logic for the "Quick Listen" home-screen widgets: a button that
 * launches the app straight into Live Mode with recording auto-started.
 *
 * The button's [PendingIntent] launches [MainActivity] with
 * [ACTION_START_LISTENING]; see `MainActivity.captureQuickAction` and
 * `lib/shared/services/quick_action_service.dart` for how that extra is
 * forwarded to Dart and turned into navigation + auto-start.
 *
 * Two [AppWidgetProvider] subclasses reuse this: [QuickListenWidgetProvider]
 * (2x1, icon + label) and [QuickListenWidgetProviderCompact] (1x1, icon
 * only) — same click behavior, different layouts/manifest entries since
 * Android widget providers are identified by component class.
 */
private object QuickListenWidgetHelper {
    const val ACTION_START_LISTENING = "startListening"
    private const val QUICK_ACTION_EXTRA = "com.birdnet.quick_action"

    fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        layoutResId: Int
    ) {
        val views = RemoteViews(context.packageName, layoutResId)

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        launchIntent.apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra(QUICK_ACTION_EXTRA, ACTION_START_LISTENING)
        }

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId,
            launchIntent,
            flags
        )

        views.setOnClickPendingIntent(R.id.quick_listen_widget_root, pendingIntent)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

/** 2x1 variant: icon + "Start Listening" label. */
class QuickListenWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            QuickListenWidgetHelper.updateWidget(
                context,
                appWidgetManager,
                appWidgetId,
                R.layout.quick_listen_widget
            )
        }
    }
}

/** 1x1 compact variant: icon only, for launchers with a tight grid. */
class QuickListenWidgetProviderCompact : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            QuickListenWidgetHelper.updateWidget(
                context,
                appWidgetManager,
                appWidgetId,
                R.layout.quick_listen_widget_1x1
            )
        }
    }
}
