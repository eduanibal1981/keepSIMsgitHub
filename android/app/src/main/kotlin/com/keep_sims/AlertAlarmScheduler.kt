package com.keep_sims

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/** Local device opt-in, independent of push providers. Never changes server alert policy. */
class AlertAlarmScheduler(private val context: Context) {
    companion object {
        const val CHANNEL = "ks_alarm_clock_v1"
        const val ACTION_FIRE = "com.keep_sims.ALERT_ALARM"
        const val ACTION_STOP = "com.keep_sims.STOP_ALERT_ALARM"
        const val PREFS = "keepsims_alert_alarms"
        const val LEAD_MILLIS = 48L * 60 * 60 * 1000

        /** Latest local time no later than the real 48-hour threshold. DST-safe calendar arithmetic. */
        fun alarmTime(cutoffMillis: Long, zone: TimeZone = TimeZone.getDefault(), hour: Int = 18, minute: Int = 0): Long {
            val threshold = cutoffMillis - LEAD_MILLIS
            val calendar = Calendar.getInstance(zone).apply {
                timeInMillis = threshold
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (calendar.timeInMillis > threshold) calendar.add(Calendar.DATE, -1)
            return calendar.timeInMillis
        }
    }

    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private fun rows() = JSONArray(prefs.getString("schedules", "[]"))
    private fun allowed() = Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val channel = NotificationChannel(CHANNEL, "SIM protection alarm", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Opted-in final reminder before an estimated SIM deactivation"
            setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM), AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
            enableVibration(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
        }
        notifications.createNotificationChannel(channel)
    }

    fun notificationsAllowed(): Boolean {
        createChannel()
        if (Build.VERSION.SDK_INT >= 24 && !notifications.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = notifications.getNotificationChannel(CHANNEL)
            return channel != null && channel.importance >= NotificationManager.IMPORTANCE_DEFAULT && channel.sound != null
        }
        return true
    }

    fun status(userId: String?): Map<String, Any> {
        val owner = prefs.getString("owner", null)
        // A new account must never inherit another account's local alarms.
        if (userId != null && owner != null && owner != userId) clear()
        val enabled = userId != null && prefs.getString("owner", null) == userId && prefs.getBoolean("enabled", false)
        val permitted = allowed() && notificationsAllowed()
        val now = System.currentTimeMillis()
        val pending = rows().let { array -> (0 until array.length()).count {
            val row = array.getJSONObject(it)
            row.getLong("cutoffMillis") > now && !wasFired(row)
        } }
        val hour = prefs.getInt("alarm_hour", 18)
        val minute = prefs.getInt("alarm_minute", 0)
        return mapOf("supported" to true, "enabled" to enabled, "exactAlarmAllowed" to allowed(),
            "notificationsAllowed" to notificationsAllowed(), "scheduledCount" to if (enabled && permitted) pending else 0,
            "timeZone" to TimeZone.getDefault().id, "alarmHour" to hour, "alarmMinute" to minute)
    }

    fun setAlarmTime(userId: String, hour: Int, minute: Int) {
        require(userId.isNotBlank())
        require(hour in 0..23) { "Hour must be between 0 and 23" }
        require(minute in 0..59) { "Minute must be between 0 and 59" }
        val currentOwner = prefs.getString("owner", null)
        if (currentOwner != null && currentOwner != userId) clear()
        prefs.edit().putString("owner", userId).putInt("alarm_hour", hour).putInt("alarm_minute", minute).commit()
        reconcile()
    }

    fun setEnabled(userId: String, enabled: Boolean) {
        require(userId.isNotBlank())
        val currentOwner = prefs.getString("owner", null)
        if (currentOwner != null && currentOwner != userId) clear()
        prefs.edit().putString("owner", userId).putBoolean("enabled", enabled).commit()
        if (!enabled) { cancelAll(); context.stopService(Intent(context, AlertAlarmService::class.java)) }
        else reconcile()
    }

    fun synchronize(userId: String, schedules: List<Map<*, *>>) {
        // Ignore obsolete in-flight work following a logout/account change.
        if (prefs.getString("owner", null) != userId || !prefs.getBoolean("enabled", false)) return
        val incoming = JSONArray()
        schedules.forEach { raw ->
            val line = raw["simLineId"] as? String ?: return@forEach
            val cycle = raw["cycleToken"] as? String ?: return@forEach
            val cutoff = (raw["cutoffMillis"] as? Number)?.toLong() ?: return@forEach
            if (line.isNotBlank() && cycle.isNotBlank() && cutoff > System.currentTimeMillis()) {
                incoming.put(JSONObject().put("simLineId", line).put("cycleToken", cycle).put("cutoffMillis", cutoff))
            }
        }
        cancelAll()
        prefs.edit().putString("schedules", incoming.toString()).commit()
        // Cancel a ringing alarm if the risk resolved while the app refreshed.
        val ringing = prefs.getString("ringing", null)
        if (ringing != null && (0 until incoming.length()).none { key(incoming.getJSONObject(it)) == ringing }) {
            context.stopService(Intent(context, AlertAlarmService::class.java))
        }
        reconcile()
    }

    fun clear() {
        cancelAll()
        prefs.edit().clear().commit()
        context.stopService(Intent(context, AlertAlarmService::class.java))
        notifications.cancel(760048)
    }

    private fun key(row: JSONObject) = "${row.getString("simLineId")}:${row.getString("cycleToken")}" 
    private fun wasFired(row: JSONObject) = prefs.getStringSet("fired", emptySet())!!.contains(key(row))
    private fun intent(row: JSONObject) = Intent(context, AlertAlarmReceiver::class.java).apply {
        action = ACTION_FIRE
        data = Uri.parse("keepsims-alarm://${Uri.encode(row.getString("simLineId"))}/${Uri.encode(row.getString("cycleToken"))}")
        putExtra("key", key(row))
    }
    private fun pending(row: JSONObject) = PendingIntent.getBroadcast(context, 0, intent(row), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun cancelAll() { val array = rows(); for (i in 0 until array.length()) manager.cancel(pending(array.getJSONObject(i))) }

    fun reconcile() {
        val array = rows()
        cancelAll()
        if (!prefs.getBoolean("enabled", false) || !allowed() || !notificationsAllowed()) return
        val now = System.currentTimeMillis()
        val hour = prefs.getInt("alarm_hour", 18)
        val minute = prefs.getInt("alarm_minute", 0)
        for (i in 0 until array.length()) {
            val row = array.getJSONObject(i)
            if (row.getLong("cutoffMillis") <= now || wasFired(row)) continue
            val whenMillis = maxOf(alarmTime(row.getLong("cutoffMillis"), hour = hour, minute = minute), now + 60_000)
            val displayIntent = Intent(context, MainActivity::class.java)
            val display = PendingIntent.getActivity(context, 0, displayIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            try { manager.setAlarmClock(AlarmManager.AlarmClockInfo(whenMillis, display), pending(row)) }
            catch (_: SecurityException) { /* Permission can be revoked between checking and scheduling. */ }
        }
    }

    @Synchronized
    fun takeDue(dueKey: String?): JSONObject? {
        if (dueKey == null || !prefs.getBoolean("enabled", false) || !allowed() || !notificationsAllowed()) return null
        val array = rows()
        for (i in 0 until array.length()) {
            val row = array.getJSONObject(i)
            if (key(row) != dueKey || wasFired(row) || row.getLong("cutoffMillis") <= System.currentTimeMillis()) continue
            if (alarmTime(row.getLong("cutoffMillis")) > System.currentTimeMillis() + 1000) return null
            val fired = prefs.getStringSet("fired", emptySet())!!.toMutableSet()
            fired.add(dueKey)
            // Persist before starting playback, so duplicate broadcasts cannot ring twice.
            prefs.edit().putStringSet("fired", fired).putString("ringing", dueKey).commit()
            return row
        }
        return null
    }

    fun openPermissionSettings() {
        val intent = if (!allowed() && Build.VERSION.SDK_INT >= 31) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}"))
        else if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName).putExtra(Settings.EXTRA_CHANNEL_ID, CHANNEL)
        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
