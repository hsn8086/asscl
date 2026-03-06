package com.asscl.asscl

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

class NextClassWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_next_class)

            val json = HomeWidgetPlugin.getData(context)
                .getString("next_course_json", "") ?: ""

            if (json.isNotEmpty()) {
                try {
                    val course = JSONObject(json)
                    views.setTextViewText(R.id.widget_course_name, course.optString("name", ""))
                    views.setTextViewText(R.id.widget_course_time, course.optString("timeRange", ""))
                    val location = course.optString("location", "")
                    if (location.isNotEmpty()) {
                        views.setTextViewText(R.id.widget_course_location, location)
                        views.setViewVisibility(R.id.widget_course_separator, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_course_location, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.widget_course_separator, View.GONE)
                        views.setViewVisibility(R.id.widget_course_location, View.GONE)
                    }

                    // Set accent bar color from course color
                    val colorStr = course.optString("color", "")
                    val accentColor = if (colorStr.isNotEmpty()) {
                        try {
                            Color.parseColor(colorStr)
                        } catch (_: Exception) {
                            0xFF42A5F5.toInt()
                        }
                    } else {
                        0xFF42A5F5.toInt()
                    }
                    views.setInt(R.id.widget_accent_bar, "setBackgroundColor", accentColor)

                    views.setViewVisibility(R.id.widget_next_class_content, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_accent_bar, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_no_class, View.GONE)
                } catch (e: Exception) {
                    showEmpty(views)
                }
            } else {
                showEmpty(views)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun showEmpty(views: RemoteViews) {
        views.setViewVisibility(R.id.widget_next_class_content, View.GONE)
        views.setViewVisibility(R.id.widget_accent_bar, View.GONE)
        views.setViewVisibility(R.id.widget_no_class, View.VISIBLE)
    }
}
