package com.keep_sims

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.ceil
import kotlin.math.floor

/**
 * SIM Shield — Android home-screen widget (G4).
 *
 * Renders `ks_widget_payload`, a JSON blob the Flutter side writes into
 * `HomeWidgetPreferences` every time it loads SIM lines / eSIMs / forecasts.
 * Nothing here touches the network, a Flutter engine or a Supabase session:
 * the launcher reads a file the app already wrote, which is what lets the
 * widget render on a plane with the app closed.
 *
 * The payload's shape is defined by `widget_snapshot.dart`. Two rules matter:
 *
 *  - **Schema first.** An unrecognised `schema` draws the "open the app"
 *    placeholder. A widget from an old install showing a confidently wrong
 *    number is worse than one that admits it is out of date.
 *  - **Re-derive the countdown.** `depletes_at_ms` is an absolute instant, so
 *    the day count is computed here at render time rather than trusted from
 *    the payload. A phone that has not opened the app for a week still shows
 *    the right number of days. Megabytes are *not* recomputed — they cannot
 *    move without a sync, and the "updated Xd ago" line is what says so.
 */
class KeepSimsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            render(context, appWidgetManager, appWidgetId, widgetData)
        }
    }

    /** Resizing changes how many rows fit, so re-render on it. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widgetData: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.keepsims_widget)
        val payload = parsePayload(widgetData.getString(PAYLOAD_KEY, null))

        // Default click target: the app. Overwritten below with the deep link
        // of whichever subject is on top.
        var launchUri = "keepsims://widget/home"

        if (payload == null) {
            showPlaceholder(views, context.getString(R.string.ks_widget_open_app))
        } else if (!payload.optBoolean("signed_in", false)) {
            showPlaceholder(views, context.getString(R.string.ks_widget_signed_out))
        } else {
            val subjects = payload.optJSONArray("subjects") ?: JSONArray()
            if (subjects.length() == 0) {
                showPlaceholder(
                    views,
                    payload.optString("empty_message").ifBlank {
                        context.getString(R.string.ks_widget_open_app)
                    },
                )
            } else {
                val primary = subjects.optJSONObject(0)
                if (primary == null) {
                    showPlaceholder(views, context.getString(R.string.ks_widget_open_app))
                } else {
                    launchUri = primary.optString("deep_link").ifBlank { launchUri }
                    showPrimary(context, views, primary)
                    showExtraRows(context, views, subjects, appWidgetManager, appWidgetId)
                }
            }
        }

        views.setTextViewText(R.id.ks_updated, freshness(context, payload))
        views.setOnClickPendingIntent(
            R.id.ks_root,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(launchUri),
            ),
        )

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /** Returns the payload only when it parses *and* the schema is one we render. */
    private fun parsePayload(raw: String?): JSONObject? {
        if (raw.isNullOrBlank()) return null
        return try {
            val json = JSONObject(raw)
            if (json.optInt("schema", -1) != SUPPORTED_SCHEMA) null else json
        } catch (e: Exception) {
            null
        }
    }

    private fun showPlaceholder(views: RemoteViews, message: String) {
        views.setViewVisibility(R.id.ks_primary, View.GONE)
        views.setViewVisibility(R.id.ks_rows, View.GONE)
        views.setViewVisibility(R.id.ks_empty, View.VISIBLE)
        views.setTextViewText(R.id.ks_empty, message)
    }

    private fun showPrimary(context: Context, views: RemoteViews, subject: JSONObject) {
        views.setViewVisibility(R.id.ks_empty, View.GONE)
        views.setViewVisibility(R.id.ks_primary, View.VISIBLE)

        val days = daysUntil(subject.optLong("depletes_at_ms", 0L))
        val severity = effectiveSeverity(subject, days)
        val accent = accentColor(severity)

        views.setTextViewText(R.id.ks_title, subject.optString("title"))
        views.setTextViewText(R.id.ks_metric, metricOf(subject, days))
        views.setTextViewText(R.id.ks_metric_label, metricLabelOf(context, subject, days))
        views.setTextViewText(R.id.ks_subtitle, subtitleOf(context, subject, days))
        views.setTextColor(R.id.ks_metric, accent)
        views.setInt(R.id.ks_dot, "setColorFilter", accent)

        val percent = subject.optInt("percent", -1)
        if (percent in 0..100) {
            views.setViewVisibility(R.id.ks_progress, View.VISIBLE)
            views.setProgressBar(R.id.ks_progress, 100, percent, false)
        } else {
            views.setViewVisibility(R.id.ks_progress, View.GONE)
        }
    }

    /**
     * Fills the two secondary rows, but only on a widget with room for them.
     * A 2x2 tile shows the headline subject alone rather than three squashed
     * unreadable ones.
     */
    private fun showExtraRows(
        context: Context,
        views: RemoteViews,
        subjects: JSONArray,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        val hasRoom = minWidthDp >= WIDE_DP && minHeightDp >= TALL_DP

        if (!hasRoom || subjects.length() < 2) {
            views.setViewVisibility(R.id.ks_rows, View.GONE)
            return
        }

        views.setViewVisibility(R.id.ks_rows, View.VISIBLE)
        val rowIds = listOf(
            Triple(R.id.ks_row_1, R.id.ks_row_1_dot, Pair(R.id.ks_row_1_title, R.id.ks_row_1_metric)),
            Triple(R.id.ks_row_2, R.id.ks_row_2_dot, Pair(R.id.ks_row_2_title, R.id.ks_row_2_metric)),
        )

        rowIds.forEachIndexed { index, (rowId, dotId, texts) ->
            val subject = subjects.optJSONObject(index + 1)
            if (subject == null) {
                views.setViewVisibility(rowId, View.GONE)
                return@forEachIndexed
            }
            val days = daysUntil(subject.optLong("depletes_at_ms", 0L))
            views.setViewVisibility(rowId, View.VISIBLE)
            views.setInt(dotId, "setColorFilter", accentColor(effectiveSeverity(subject, days)))
            views.setTextViewText(texts.first, subject.optString("title"))
            views.setTextViewText(
                texts.second,
                "${metricOf(subject, days)} ${metricLabelOf(context, subject, days)}",
            )
        }
    }

    // ── payload → text ────────────────────────────────────────────────────

    private fun metricOf(subject: JSONObject, days: Int?): String {
        if (subject.optBoolean("metric_is_countdown", false) && days != null) {
            return if (days <= 0) "0" else days.toString()
        }
        return subject.optString("metric")
    }

    private fun metricLabelOf(context: Context, subject: JSONObject, days: Int?): String {
        if (subject.optBoolean("metric_is_countdown", false) && days != null) {
            return countdownLabel(context, days)
        }
        return subject.optString("metric_label")
    }

    private fun subtitleOf(context: Context, subject: JSONObject, days: Int?): String {
        val prefix = subject.optString("subtitle_prefix")
        if (prefix.isNotEmpty() && days != null) {
            return "$prefix · ${countdownPhrase(context, days)}"
        }
        return subject.optString("subtitle")
    }

    /** Mirrors `countdownLabel` in `widget_snapshot.dart`. */
    private fun countdownLabel(context: Context, days: Int): String = when {
        days <= 0 -> context.getString(R.string.ks_widget_expired)
        days == 1 -> context.getString(R.string.ks_widget_day_left)
        else -> context.getString(R.string.ks_widget_days_left)
    }

    /** Mirrors `countdownPhrase` in `widget_snapshot.dart`. */
    private fun countdownPhrase(context: Context, days: Int): String = when {
        days <= 0 -> context.getString(R.string.ks_widget_expired)
        else -> context.getString(
            R.string.ks_widget_phrase_left,
            days,
            context.getString(
                if (days == 1) R.string.ks_widget_day else R.string.ks_widget_days,
            ),
        )
    }

    /**
     * The published severity, downgraded to critical once the recomputed
     * countdown has run out — a red-hot "0 days left" printed in calm green is
     * the kind of mismatch that makes people distrust the whole widget.
     */
    private fun effectiveSeverity(subject: JSONObject, days: Int?): String {
        val severity = subject.optString("severity").ifBlank { "ok" }
        if (severity == "paused") return severity
        return if (days != null && days <= 0) "critical" else severity
    }

    private fun accentColor(severity: String): Int = when (severity) {
        "critical" -> Color.parseColor("#FFB4AB")
        "warning" -> Color.parseColor("#FFB95F")
        "paused" -> Color.parseColor("#BCC9CD")
        else -> Color.parseColor("#4CD7F6")
    }

    /**
     * Whole days until [epochMillis], rounded away from zero, matching
     * `daysBetween` in `widget_snapshot.dart`. Null when the payload carries no
     * absolute instant to count down to.
     */
    private fun daysUntil(epochMillis: Long): Int? {
        if (epochMillis <= 0L) return null
        val diff = epochMillis - System.currentTimeMillis()
        val days = diff.toDouble() / DAY_MILLIS
        return if (diff <= 0L) floor(days).toInt() else ceil(days).toInt()
    }

    /** "just now" / "14m ago" / "3h ago" / "2d ago" — how stale the numbers are. */
    private fun freshness(context: Context, payload: JSONObject?): String {
        val generatedAt = payload?.optLong("generated_at_ms", 0L) ?: 0L
        if (generatedAt <= 0L) return ""
        val elapsed = System.currentTimeMillis() - generatedAt
        if (elapsed < 60_000L) return context.getString(R.string.ks_widget_just_now)
        val minutes = elapsed / 60_000L
        if (minutes < 60L) return context.getString(R.string.ks_widget_updated_minutes, minutes.toInt())
        val hours = minutes / 60L
        if (hours < 24L) return context.getString(R.string.ks_widget_updated_hours, hours.toInt())
        return context.getString(R.string.ks_widget_updated_days, (hours / 24L).toInt())
    }

    private companion object {
        /** Must match `kWidgetPayloadKey` in `home_widget_publisher.dart`. */
        const val PAYLOAD_KEY = "ks_widget_payload"

        /** Must match `kWidgetSnapshotSchema` in `widget_snapshot.dart`. */
        const val SUPPORTED_SCHEMA = 1

        const val DAY_MILLIS = 86_400_000.0

        /** Roughly a 4-cell-wide, 2-cell-tall tile. */
        const val WIDE_DP = 220
        const val TALL_DP = 110
    }
}
