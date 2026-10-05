package com.keep_sims

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import org.json.JSONObject

/** Bounded alarm playback with an explicit stop action. No DND/volume override. */
class AlertAlarmService : Service() {
    private var ringtone: Ringtone? = null
    private val handler = Handler(Looper.getMainLooper())
    private val stop = Runnable { stopSelf() }

    companion object {
        private const val NOTIFICATION_ID = 760048
        fun warning(context: Context, lineId: String): Notification {
            val open = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                action = "com.keep_sims.OPEN_ALERT_ALARM"
                putExtra("keepsims_foreground_push", JSONObject().put("sim_line_id", lineId).toString())
            }
            val tap = PendingIntent.getActivity(context, NOTIFICATION_ID, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val stop = PendingIntent.getService(context, NOTIFICATION_ID, Intent(context, AlertAlarmService::class.java).setAction(AlertAlarmScheduler.ACTION_STOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, AlertAlarmScheduler.CHANNEL) else Notification.Builder(context)
            if (Build.VERSION.SDK_INT >= 26) builder.setGroup("ks_alarm_playback").setGroupAlertBehavior(Notification.GROUP_ALERT_SUMMARY)
            return builder.setSmallIcon(R.drawable.ic_stat_keepsims).setContentTitle("SIM protection alarm")
                .setContentText("A SIM is approaching its estimated deactivation cutoff. Open KeepSIMs to take action.")
                .setCategory(Notification.CATEGORY_ALARM).setVisibility(Notification.VISIBILITY_PRIVATE)
                .setContentIntent(tap).setOnlyAlertOnce(true).setOngoing(true)
                .addAction(Notification.Action.Builder(android.R.drawable.ic_media_pause, "Stop alarm", stop).build()).build()
        }
        fun showWarning(context: Context, lineId: String) {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIFICATION_ID, warning(context, lineId))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == AlertAlarmScheduler.ACTION_STOP) { stopSelf(); return START_NOT_STICKY }
        val lineId = intent?.getStringExtra("simLineId") ?: return START_NOT_STICKY
        val prefs = getSharedPreferences(AlertAlarmScheduler.PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false) || prefs.getString("ringing", null) != intent.getStringExtra("alarmKey")) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        startForeground(NOTIFICATION_ID, warning(this, lineId))
        if (ringtone == null) {
            try {
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val uri = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(AlertAlarmScheduler.CHANNEL)?.sound else RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                if (uri != null) ringtone = RingtoneManager.getRingtone(this, uri)?.apply {
                    audioAttributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
                    if (Build.VERSION.SDK_INT >= 28) isLooping = true
                    play()
                }
            } catch (_: RuntimeException) { /* Notification remains available if audio is blocked. */ }
            handler.postDelayed(stop, 180_000)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(stop)
        ringtone?.stop()
        getSharedPreferences(AlertAlarmScheduler.PREFS, MODE_PRIVATE).edit().remove("ringing").apply()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
