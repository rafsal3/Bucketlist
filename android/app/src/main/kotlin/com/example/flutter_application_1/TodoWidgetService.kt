package com.example.flutter_application_1

import android.content.Intent
import android.widget.RemoteViewsService

class TodoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TodoListFactory(this.applicationContext)
    }
}
