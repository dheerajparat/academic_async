package com.parat.academicasync

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.util.Calendar

class RoutineTodayWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val KEY_ROUTINE_JSON = "routine_json"
        private val dayKeys = listOf(
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday",
            "sunday",
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            updateWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            AppWidgetManager.ACTION_APPWIDGET_UPDATE,
            -> updateAll(context)
        }
    }

    private fun updateAll(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, RoutineTodayWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
        if (appWidgetIds.isEmpty()) {
            return
        }

        val widgetData = HomeWidgetPlugin.getData(context)
        appWidgetIds.forEach { widgetId ->
            updateWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.routine_today_widget)
        val todayKey = getTodayKey()
        val todayLabel = todayKey.replaceFirstChar { it.uppercase() }
        val items = getTodayItems(widgetData, todayKey)

        views.setTextViewText(R.id.widgetTitle, "Today's Routine - $todayLabel")

        if (items.isEmpty()) {
            views.setViewVisibility(R.id.widgetEmpty, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widgetContent, android.view.View.GONE)
            views.setTextViewText(R.id.widgetEmpty, "No routine planned for today.")
        } else {
            views.setViewVisibility(R.id.widgetEmpty, android.view.View.GONE)
            views.setViewVisibility(R.id.widgetContent, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widgetContent, items.joinToString("\n"))
        }

        getLaunchPendingIntent(context, widgetId)?.let { pendingIntent ->
            views.setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun getTodayItems(
        widgetData: SharedPreferences,
        todayKey: String,
    ): List<String> {
        val routineJson = widgetData.getString(KEY_ROUTINE_JSON, null)?.trim().orEmpty()
        if (routineJson.isEmpty()) {
            return emptyList()
        }

        return runCatching {
            val root = JSONObject(routineJson)
            val periodKeys = root.keys().asSequence().toList().sorted()
            val items = mutableListOf<String>()

            for (periodKey in periodKeys) {
                val periodObject = root.optJSONObject(periodKey) ?: continue
                val subject = periodObject.optString(todayKey, "").trim()
                if (subject.isNotEmpty() && subject != "-") {
                    items += "${periodKey.uppercase()} • $subject"
                }
            }

            items
        }.getOrElse { emptyList() }
    }

    private fun getLaunchPendingIntent(context: Context, widgetId: Int): PendingIntent? {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return null
        launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP

        return PendingIntent.getActivity(
            context,
            widgetId,
            launchIntent,
            pendingIntentFlags(),
        )
    }

    private fun pendingIntentFlags(): Int {
        val immutableFlag =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag
    }

    private fun getTodayKey(): String {
        val dayOfWeek = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
        val index = when (dayOfWeek) {
            Calendar.MONDAY -> 0
            Calendar.TUESDAY -> 1
            Calendar.WEDNESDAY -> 2
            Calendar.THURSDAY -> 3
            Calendar.FRIDAY -> 4
            Calendar.SATURDAY -> 5
            Calendar.SUNDAY -> 6
            else -> 0
        }
        return dayKeys[index]
    }
}
