package com.parat.academicasync

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class UpcomingEventsWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val KEY_TITLE = "upcoming_title"
        private const val KEY_SUBTITLE = "upcoming_subtitle"
        private const val KEY_CONTENT = "upcoming_content"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            runCatching {
                val views = RemoteViews(context.packageName, R.layout.upcoming_events_widget)
                val title = widgetData.getString(KEY_TITLE, "Upcoming Events") ?: "Upcoming Events"
                val subtitle = widgetData.getString(KEY_SUBTITLE, "Tap to open app") ?: "Tap to open app"
                val content = widgetData.getString(KEY_CONTENT, "No upcoming events") ?: "No upcoming events"

                views.setTextViewText(R.id.widgetTitle, title)
                views.setTextViewText(R.id.widgetSubtitle, subtitle)
                views.setTextViewText(R.id.widgetContent, content)

                getLaunchPendingIntent(context, widgetId)?.let { pendingIntent ->
                    views.setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)
                    views.setOnClickPendingIntent(R.id.widgetHeaderTapTarget, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
            }.onFailure {
                val fallback = RemoteViews(context.packageName, R.layout.upcoming_events_widget)
                fallback.setTextViewText(R.id.widgetTitle, "Upcoming Events")
                fallback.setTextViewText(R.id.widgetSubtitle, "Open app to refresh")
                fallback.setTextViewText(R.id.widgetContent, "Unable to load widget data")
                appWidgetManager.updateAppWidget(widgetId, fallback)
            }
        }
    }

    private fun getLaunchPendingIntent(context: Context, widgetId: Int): PendingIntent? {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return null
        launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP

        return PendingIntent.getActivity(
            context,
            widgetId,
            launchIntent,
            pendingIntentFlags()
        )
    }

    private fun pendingIntentFlags(): Int {
        val immutableFlag =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag
    }
}
