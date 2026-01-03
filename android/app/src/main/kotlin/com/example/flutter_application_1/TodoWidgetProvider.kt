package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class TodoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                
                // 1. Title Click -> Open App
                val titlePendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_title, titlePendingIntent)
                
                // 2. Add Button Click -> Open App
                setOnClickPendingIntent(R.id.widget_add_button, titlePendingIntent)

                // 3. List Adapter
                val intent = Intent(context, TodoWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = android.net.Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                setRemoteAdapter(R.id.widget_list, intent)

                // 4. List Item Click Template -> Open App
                val templateIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setPendingIntentTemplate(R.id.widget_list, templateIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
