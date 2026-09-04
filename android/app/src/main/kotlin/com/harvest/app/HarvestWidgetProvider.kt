package com.harvest.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home-screen widget: the streak, and whatever else is switched on
 * in Settings — today's money, the scrollable list of what is still
 * due, and the two quick actions.
 *
 * It renders from whatever Dart last wrote into the shared preferences
 * store, so it is correct the moment the app writes and stays correct
 * with the app closed. Tapping the background opens Harvest; the action
 * pills open it on the sheet they name.
 */
class HarvestWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val showMoney = widgetData.getBoolean(KEY_SHOW_MONEY, true)
        val showTasks = widgetData.getBoolean(KEY_SHOW_TASKS, true)
        val showActions = widgetData.getBoolean(KEY_SHOW_ACTIONS, true)
        // An empty list still needs its own line: a blank strip where
        // the tasks were reads as a broken widget, not as a free day.
        val hasTasks = widgetData.getString(KEY_TASKS, "[]").orEmpty().length > 2

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.harvest_widget).apply {
                setTextViewText(R.id.widget_streak, widgetData.getString(KEY_STREAK, "0"))
                setTextViewText(
                    R.id.widget_streak_label,
                    widgetData.getString(KEY_STREAK_LABEL, "day streak"),
                )
                setTextViewText(R.id.widget_progress, widgetData.getString(KEY_PROGRESS, ""))

                setViewVisibility(R.id.widget_money, visibility(showMoney))
                setTextViewText(R.id.widget_spent, widgetData.getString(KEY_SPENT, ""))
                setTextViewText(R.id.widget_wallet, widgetData.getString(KEY_WALLET, ""))

                setViewVisibility(R.id.widget_tasks, visibility(showTasks && hasTasks))
                setViewVisibility(R.id.widget_tasks_empty, visibility(showTasks && !hasTasks))
                setTextViewText(
                    R.id.widget_tasks_empty,
                    widgetData.getString(KEY_TASKS_EMPTY, ""),
                )

                setViewVisibility(R.id.widget_actions, visibility(showActions))
                setTextViewText(
                    R.id.widget_action_expense_label,
                    widgetData.getString(KEY_ACTION_EXPENSE, ""),
                )
                setTextViewText(
                    R.id.widget_action_task_label,
                    widgetData.getString(KEY_ACTION_TASK, ""),
                )

                // The list is served by HarvestWidgetTaskService, which
                // reads the same preferences this method does.
                val listIntent = Intent(context, HarvestWidgetTaskService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    // A distinct data URI per widget id, so Android does
                    // not hand two instances the same cached factory.
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                setRemoteAdapter(R.id.widget_tasks, listIntent)
                setPendingIntentTemplate(R.id.widget_tasks, launch(context))

                setOnClickPendingIntent(R.id.widget_root, launch(context))
                setOnClickPendingIntent(
                    R.id.widget_action_expense,
                    launch(context, ACTION_EXPENSE),
                )
                setOnClickPendingIntent(
                    R.id.widget_action_task,
                    launch(context, ACTION_TASK),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
        // The adapter caches its rows; without this the list keeps
        // showing yesterday's field until the host feels like asking.
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_tasks)
    }

    private fun visibility(shown: Boolean) = if (shown) View.VISIBLE else View.GONE

    /**
     * Opens the app, optionally carrying the quick action Dart should
     * carry out. A home-screen button has no other channel in.
     */
    private fun launch(context: Context, action: String? = null): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            action?.let { Uri.parse(it) },
        )

    private companion object {
        const val KEY_STREAK = "streak"
        const val KEY_STREAK_LABEL = "streakLabel"
        const val KEY_PROGRESS = "progress"
        const val KEY_SPENT = "spent"
        const val KEY_WALLET = "wallet"
        const val KEY_TASKS = "tasks"
        const val KEY_TASKS_EMPTY = "emptyTasks"
        const val KEY_ACTION_EXPENSE = "actionExpense"
        const val KEY_ACTION_TASK = "actionTask"
        const val KEY_SHOW_MONEY = "showMoney"
        const val KEY_SHOW_TASKS = "showTasks"
        const val KEY_SHOW_ACTIONS = "showActions"

        const val ACTION_EXPENSE = "harvest://expense"
        const val ACTION_TASK = "harvest://task"
    }
}
