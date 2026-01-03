package com.example.flutter_application_1

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONException

class TodoListFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var items = JSONArray()

    override fun onCreate() {
        // Init
    }

    override fun onDataSetChanged() {
        // Reload data from SharedPreferences
        val widgetData = HomeWidgetPlugin.getData(context)
        val jsonString = widgetData.getString("widget_data", "[]")
        try {
            items = JSONArray(jsonString)
        } catch (e: JSONException) {
            items = JSONArray()
        }
    }

    override fun onDestroy() {
        items = JSONArray()
    }

    override fun getCount(): Int {
        return items.length()
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_item)
        try {
            val item = items.getJSONObject(position)
            val title = item.getString("title")
            val isCompleted = item.getBoolean("isCompleted")

            views.setTextViewText(R.id.widget_item_text, title)

            if (isCompleted) {
                views.setImageViewResource(R.id.widget_item_check, android.R.drawable.checkbox_on_background)
            } else {
                views.setImageViewResource(R.id.widget_item_check, android.R.drawable.checkbox_off_background)
            }
            
            // FillInIntent for click handling by the list view's pending intent template
             val fillInIntent = Intent()
            views.setOnClickFillInIntent(R.id.widget_item_container, fillInIntent)

        } catch (e: Exception) {
            e.printStackTrace()
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return false
    }
}
