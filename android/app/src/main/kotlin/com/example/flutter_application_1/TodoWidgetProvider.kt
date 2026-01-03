package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
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

                
                // 3. Switch Space Button -> Background Intent
                val switchIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("homeWidget://switchspace")
                )
                setOnClickPendingIntent(R.id.widget_switch_space, switchIntent)

                // 4. List Adapter
                val intent = Intent(context, TodoWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = android.net.Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                setRemoteAdapter(R.id.widget_list, intent)

                // 5. List Item Click Template -> Background Intent
                val templateIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("homeWidget://updateitem")
                )
                setPendingIntentTemplate(R.id.widget_list, templateIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
