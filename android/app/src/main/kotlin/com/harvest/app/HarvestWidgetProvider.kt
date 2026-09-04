package com.harvest.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home-screen widget: the streak, today's progress, and the rank.
 *
 * It renders from whatever Dart last wrote into the shared preferences
 * store, so it is correct the moment the app writes and stays correct
 * with the app closed. Tapping anywhere opens Harvest.
 */
class HarvestWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.harvest_widget).apply {
                setTextViewText(R.id.widget_streak, widgetData.getString(KEY_STREAK, "0"))
                setTextViewText(
                    R.id.widget_streak_label,
                    widgetData.getString(KEY_STREAK_LABEL, "day streak"),
                )
                setTextViewText(R.id.widget_tasks, widgetData.getString(KEY_TASKS, "—"))
                setTextViewText(R.id.widget_rank, widgetData.getString(KEY_RANK, ""))
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private companion object {
        const val KEY_STREAK = "streak"
        const val KEY_STREAK_LABEL = "streakLabel"
        const val KEY_TASKS = "tasks"
        const val KEY_RANK = "rank"
    }
}
