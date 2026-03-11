package com.hsn8086.asscl

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.util.Calendar

class NextClassWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_next_class)

            val course = findNextCourse(context)

            if (course != null) {
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
            } else {
                showEmpty(views)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    /**
     * Find next course from weekly_courses_json based on current time.
     * Returns the first course whose startMinutes > now, or null.
     */
    private fun findNextCourse(context: Context): JSONObject? {
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            val json = prefs.getString("weekly_courses_json", "") ?: ""
            if (json.isEmpty()) return null

            val weekly = JSONObject(json)
            val todayDow = todayDayOfWeek() // 1=Mon..7=Sun
            val dayCourses = weekly.optJSONArray(todayDow.toString()) ?: return null

            val cal = Calendar.getInstance()
            val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

            for (i in 0 until dayCourses.length()) {
                val course = dayCourses.getJSONObject(i)
                val startMinutes = course.optInt("startMinutes", -1)
                if (startMinutes < 0) continue
                if (startMinutes > nowMinutes) return course
            }
        } catch (_: Exception) {
            // Fall through
        }
        return null
    }

    private fun showEmpty(views: RemoteViews) {
        views.setViewVisibility(R.id.widget_next_class_content, View.GONE)
        views.setViewVisibility(R.id.widget_accent_bar, View.GONE)
        views.setViewVisibility(R.id.widget_no_class, View.VISIBLE)
    }

    /** Returns 1=Monday .. 7=Sunday */
    private fun todayDayOfWeek(): Int {
        val cal = Calendar.getInstance()
        val dow = cal.get(Calendar.DAY_OF_WEEK) // Sun=1 .. Sat=7
        return if (dow == Calendar.SUNDAY) 7 else dow - 1
    }
}
