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
import org.json.JSONArray
import org.json.JSONException

/**
 * The home-screen widget: the streak, and whatever else is switched on
 * in Settings — today's money, today's field as full-width cards you
 * swipe through, and the two quick actions.
 *
 * It renders from whatever Dart last wrote into the shared preferences
 * store, so it is correct the moment the app writes and stays correct
 * with the app closed. Tapping the card opens Harvest; the action pills
 * open it on the sheet they name.
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
        val taskCount = taskCount(widgetData.getString(KEY_TASKS, "[]"))

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

                // An empty field still needs its own line: a strip that
                // simply vanishes reads as a broken widget, not as a
                // day with nothing left in it.
                setViewVisibility(R.id.widget_tasks, visibility(showTasks && taskCount > 0))
                setViewVisibility(
                    R.id.widget_tasks_empty,
                    visibility(showTasks && taskCount == 0),
                )
                setTextViewText(
                    R.id.widget_tasks_empty,
                    widgetData.getString(KEY_TASKS_EMPTY, ""),
                )

                val cards = Intent(context, HarvestWidgetTaskService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    // A distinct data URI per widget, so Android does not
                    // hand two instances the same cached factory.
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                setRemoteAdapter(R.id.widget_tasks, cards)
                setPendingIntentTemplate(R.id.widget_tasks, launch(context))

                setViewVisibility(R.id.widget_actions, visibility(showActions))
                setTextViewText(
                    R.id.widget_action_expense_label,
                    widgetData.getString(KEY_ACTION_EXPENSE, ""),
                )
                setTextViewText(
                    R.id.widget_action_task_label,
                    widgetData.getString(KEY_ACTION_TASK, ""),
                )

                setOnClickPendingIntent(R.id.widget_card, launch(context))
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
        // The adapter caches its cards; without this the stack keeps
        // showing yesterday's field until the host feels like asking.
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_tasks)
    }

    /** A half-written blob is an empty field, never a crash. */
    private fun taskCount(raw: String?): Int = try {
        JSONArray(raw ?: "[]").length()
    } catch (error: JSONException) {
        0
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

