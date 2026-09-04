package com.harvest.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
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
 * in Settings — today's money, today's field as a row of boxes, and the
 * two quick actions.
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
        val tasks = readTasks(widgetData.getString(KEY_TASKS, "[]"))

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
                setViewVisibility(R.id.widget_tasks, visibility(showTasks && tasks.isNotEmpty()))
                setViewVisibility(
                    R.id.widget_tasks_empty,
                    visibility(showTasks && tasks.isEmpty()),
                )
                setTextViewText(
                    R.id.widget_tasks_empty,
                    widgetData.getString(KEY_TASKS_EMPTY, ""),
                )
                fillTasks(context, tasks)

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
    }

    private data class Task(val title: String, val done: Boolean)

    /** A half-written blob is an empty field, never a crash in the launcher. */
    private fun readTasks(raw: String?): List<Task> = try {
        val array = JSONArray(raw ?: "[]")
        (0 until array.length()).map { i ->
            val item = array.getJSONObject(i)
            Task(item.optString("title"), item.optBoolean("done"))
        }
    } catch (error: JSONException) {
        emptyList()
    }

    /**
     * Pours the tasks into the strip's slots, and counts what is left
     * over onto the last chip.
     *
     * The slots are declared in the layout rather than built by an
     * adapter because there is nothing to adapt into: RemoteViews
     * refuses to inflate a HorizontalScrollView, and its two scrolling
     * collections only go up and down. Three boxes sharing the width,
     * plus "+N more", is what the platform actually allows.
     */
    private fun RemoteViews.fillTasks(context: Context, tasks: List<Task>) {
        // Resolved here rather than left to the layout: the chip's text
        // flips to the on-accent colour once the task is done, and a
        // RemoteViews colour has to arrive as an ARGB int. The provider
        // runs in our process, so the night-mode variant resolves
        // correctly on the way out.
        val pendingColor = context.getColor(R.color.widget_text)
        val doneColor = context.getColor(R.color.widget_on_accent)
        // With more than the strip holds, the last slot gives up its
        // task so the count has somewhere to live.
        val overflow = (tasks.size - SLOTS.size).coerceAtLeast(0)
        val shown = if (overflow > 0) SLOTS.size else tasks.size

        SLOTS.forEachIndexed { index, slot ->
            val task = if (index < shown) tasks.getOrNull(index) else null
            if (task == null) {
                setViewVisibility(slot.root, View.GONE)
                return@forEachIndexed
            }
            setViewVisibility(slot.root, View.VISIBLE)
            setTextViewText(slot.title, task.title)
            setInt(
                slot.root,
                "setBackgroundResource",
                if (task.done) R.drawable.widget_chip_done else R.drawable.widget_chip,
            )
            setImageViewResource(
                slot.mark,
                if (task.done) R.drawable.ic_widget_done else R.drawable.ic_widget_pending,
            )
            setTextColor(slot.title, if (task.done) doneColor else pendingColor)
        }

        setViewVisibility(R.id.task_more, visibility(overflow > 0))
        if (overflow > 0) {
            setTextViewText(R.id.task_more, "+$overflow")
        }
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

        /** As many boxes as stay legible across a four-cell widget. */
        val SLOTS = listOf(
            Slot(R.id.task_1, R.id.task_1_mark, R.id.task_1_title),
            Slot(R.id.task_2, R.id.task_2_mark, R.id.task_2_title),
            Slot(R.id.task_3, R.id.task_3_mark, R.id.task_3_title),
        )
    }

    private data class Slot(val root: Int, val mark: Int, val title: Int)
}
