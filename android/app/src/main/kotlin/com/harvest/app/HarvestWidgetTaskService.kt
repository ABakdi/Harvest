package com.harvest.app

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

/**
 * Serves the widget's scrollable task list.
 *
 * A RemoteViews ListView cannot be handed a list of rows directly — it
 * is fed by a factory living in a service the launcher binds to. This
 * one reads the same JSON blob Dart writes into the widget's shared
 * preferences, so the list and the numbers above it can never disagree.
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
        val raw = HomeWidgetPlugin.getData(context).getString("tasks", "[]") ?: "[]"
        tasks = try {
            val array = JSONArray(raw)
            (0 until array.length()).map { i ->
                val item = array.getJSONObject(i)
                Task(item.optString("title"), item.optBoolean("done"))
            }
        } catch (error: org.json.JSONException) {
            // A half-written blob is a blank list, never a crash inside
            // the launcher's process.
            emptyList()
        }
    }

    override fun onDestroy() = Unit

    override fun getCount() = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        val task = tasks[position]
        return RemoteViews(context.packageName, R.layout.harvest_widget_task).apply {
            setTextViewText(R.id.task_title, task.title)
            setImageViewResource(
                R.id.task_mark,
                if (task.done) R.drawable.ic_widget_done else R.drawable.ic_widget_pending,
            )
            setTextColor(R.id.task_title, if (task.done) DONE_COLOR else PENDING_COLOR)
            // Every row opens the app; the template lives on the list.
            setOnClickFillInIntent(R.id.task_row, Intent())
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount() = 1

    override fun getItemId(position: Int) = position.toLong()

    override fun hasStableIds() = true

    private companion object {
        const val PENDING_COLOR = 0xFFFFFFFF.toInt()
        const val DONE_COLOR = 0x99FFFFFF.toInt()
    }
}
