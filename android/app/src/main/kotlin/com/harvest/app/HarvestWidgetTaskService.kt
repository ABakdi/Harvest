package com.harvest.app

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONException

/**
 * Serves the widget's swipeable task cards.
 *
 * A RemoteViews collection cannot be handed a list of rows directly —
 * it is fed by a factory living in a service the launcher binds to.
 * This one reads the same JSON blob Dart writes into the widget's
 * shared preferences, so the cards and the numbers above them can never
 * disagree.
 */
class HarvestWidgetTaskService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TaskFactory(applicationContext)
}

private class TaskFactory(private val context: Context) :
    RemoteViewsService.RemoteViewsFactory {

    private var tasks: List<Task> = emptyList()

    private data class Task(val title: String, val done: Boolean)

    override fun onCreate() = Unit

    /** Called on every notifyAppWidgetViewDataChanged. */
    override fun onDataSetChanged() {
        val raw = HomeWidgetPlugin.getData(context).getString(KEY_TASKS, "[]") ?: "[]"
        tasks = try {
            val array = JSONArray(raw)
            (0 until array.length()).map { i ->
                val item = array.getJSONObject(i)
                Task(item.optString("title"), item.optBoolean("done"))
            }
        } catch (error: JSONException) {
            // A half-written blob is an empty field, never a crash
            // inside the launcher's own process.
            emptyList()
        }
    }

    override fun onDestroy() = Unit

    override fun getCount() = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        val task = tasks[position]
        return RemoteViews(context.packageName, R.layout.harvest_widget_task).apply {
            setTextViewText(R.id.task_title, task.title)
            // Which of how many, so swiping has somewhere to end.
            setTextViewText(R.id.task_position, "${position + 1}/${tasks.size}")
            setInt(
                R.id.task_card,
                "setBackgroundResource",
                if (task.done) R.drawable.widget_chip_done else R.drawable.widget_chip,
            )
            setImageViewResource(
                R.id.task_mark,
                if (task.done) R.drawable.ic_widget_done else R.drawable.ic_widget_pending,
            )
            val title = context.getColor(
                if (task.done) R.color.widget_on_accent else R.color.widget_text,
            )
            setTextColor(R.id.task_title, title)
            setTextColor(R.id.task_position, title)
            // Every card opens the app; the template lives on the stack.
            setOnClickFillInIntent(R.id.task_card, Intent())
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount() = 1

    override fun getItemId(position: Int) = position.toLong()

    override fun hasStableIds() = true

    private companion object {
        const val KEY_TASKS = "tasks"
    }
}
