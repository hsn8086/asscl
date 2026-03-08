package com.hsn8086.asscl

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.util.Calendar

class TodayScheduleWidgetProvider : AppWidgetProvider() {
    companion object {
        private val DAY_CONTAINER_IDS = intArrayOf(
            R.id.widget_day_1,
            R.id.widget_day_2,
            R.id.widget_day_3,
            R.id.widget_day_4,
            R.id.widget_day_5,
            R.id.widget_day_6,
            R.id.widget_day_7,
        )
        private val HEADER_IDS = intArrayOf(
            R.id.widget_header_1,
            R.id.widget_header_2,
            R.id.widget_header_3,
            R.id.widget_header_4,
            R.id.widget_header_5,
            R.id.widget_header_6,
            R.id.widget_header_7,
        )
        // Material 500-level — vivid enough for small cells with white text
        private val COURSE_COLORS = intArrayOf(
            0xFF42A5F5.toInt(), // blue
            0xFF66BB6A.toInt(), // green
            0xFFFFA726.toInt(), // orange
            0xFFAB47BC.toInt(), // purple
            0xFF26C6DA.toInt(), // cyan
            0xFFEC407A.toInt(), // pink
            0xFFFFCA28.toInt(), // amber
            0xFF5C6BC0.toInt(), // indigo
            0xFF8D6E63.toInt(), // brown
            0xFF26A69A.toInt(), // teal
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val pkg = context.packageName

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(pkg, R.layout.widget_today_schedule)

            val json = prefs.getString("weekly_courses_json", "") ?: ""
            val currentWeek = prefs.getInt("current_week", 1)
            val totalPeriods = prefs.getInt("total_periods", 12)
            val semesterName = prefs.getString("semester_name", "") ?: ""

            views.setTextViewText(R.id.widget_week_title, "第${currentWeek}周")
            views.setTextViewText(R.id.widget_semester_name, semesterName)

            // Highlight today's weekday header
            val todayDow = todayDayOfWeek() // 1=Mon..7=Sun
            val isDark = isDarkMode(context)
            val normalHeaderColor = if (isDark) 0x99FFFFFF.toInt() else 0x99000000.toInt()
            for (i in 0..6) {
                if (i + 1 == todayDow) {
                    views.setTextColor(HEADER_IDS[i], 0xFF1976D2.toInt())
                    views.setInt(HEADER_IDS[i], "setBackgroundColor", 0x1A1976D2)
                } else {
                    views.setTextColor(HEADER_IDS[i], normalHeaderColor)
                    views.setInt(HEADER_IDS[i], "setBackgroundColor", 0x00000000)
                }
            }

            // Clear all day containers
            for (containerId in DAY_CONTAINER_IDS) {
                views.removeAllViews(containerId)
            }

            if (json.isNotEmpty()) {
                try {
                    val weekly = JSONObject(json)
                    var totalCourses = 0
                    var colorIndex = 0

                    for (day in 1..7) {
                        val containerId = DAY_CONTAINER_IDS[day - 1]
                        val dayCourses = weekly.optJSONArray(day.toString())

                        var currentPeriod = 1

                        if (dayCourses != null && dayCourses.length() > 0) {
                            for (i in 0 until dayCourses.length()) {
                                val course = dayCourses.getJSONObject(i)
                                val start = course.optInt("startPeriod", 0)
                                val end = course.optInt("endPeriod", 0)
                                if (start <= 0 || end <= 0 || start > end) continue

                                // Add empty spacers for gap before this course
                                for (p in currentPeriod until start) {
                                    views.addView(
                                        containerId,
                                        RemoteViews(pkg, R.layout.widget_period_empty)
                                    )
                                }

                                // Determine background color
                                val colorStr = course.optString("color", "")
                                val bgColor = if (colorStr.isNotEmpty()) {
                                    try {
                                        Color.parseColor(colorStr)
                                    } catch (_: Exception) {
                                        COURSE_COLORS[colorIndex % COURSE_COLORS.size]
                                    }
                                } else {
                                    COURSE_COLORS[colorIndex % COURSE_COLORS.size]
                                }
                                colorIndex++

                                // First cell: show course name + location
                                val startCell = RemoteViews(pkg, R.layout.widget_period_course)
                                startCell.setTextViewText(
                                    R.id.period_course_name,
                                    course.optString("name", "")
                                )
                                val location = course.optString("location", "")
                                if (location.isNotEmpty()) {
                                    startCell.setTextViewText(
                                        R.id.period_course_location,
                                        location
                                    )
                                } else {
                                    startCell.setViewVisibility(
                                        R.id.period_course_location,
                                        View.GONE
                                    )
                                }
                                startCell.setInt(
                                    R.id.period_course_root,
                                    "setBackgroundColor",
                                    bgColor
                                )
                                views.addView(containerId, startCell)

                                // Continuation cells: seamless colored background (no margin gap)
                                for (p in (start + 1)..end) {
                                    val contCell = RemoteViews(pkg, R.layout.widget_period_course_cont)
                                    contCell.setInt(
                                        R.id.period_course_cont_root,
                                        "setBackgroundColor",
                                        bgColor
                                    )
                                    views.addView(containerId, contCell)
                                }

                                currentPeriod = end + 1
                                totalCourses++
                            }
                        }

                        // Fill remaining periods with empty spacers
                        for (p in currentPeriod..totalPeriods) {
                            views.addView(
                                containerId,
                                RemoteViews(pkg, R.layout.widget_period_empty)
                            )
                        }
                    }

                    if (totalCourses > 0) {
                        views.setViewVisibility(R.id.widget_week_grid, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_schedule_empty, View.GONE)
                    } else {
                        showEmpty(views)
                    }
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
        views.setViewVisibility(R.id.widget_week_grid, View.GONE)
        views.setViewVisibility(R.id.widget_schedule_empty, View.VISIBLE)
    }

    /** Returns 1=Monday .. 7=Sunday */
    private fun todayDayOfWeek(): Int {
        val cal = Calendar.getInstance()
        val dow = cal.get(Calendar.DAY_OF_WEEK) // Sun=1 .. Sat=7
        return if (dow == Calendar.SUNDAY) 7 else dow - 1
    }

    private fun isDarkMode(context: Context): Boolean {
        val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return nightMode == Configuration.UI_MODE_NIGHT_YES
    }
}
