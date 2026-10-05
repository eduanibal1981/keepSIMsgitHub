package com.keep_sims

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlertAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val scheduler = AlertAlarmScheduler(context)
        if (intent.action != AlertAlarmScheduler.ACTION_FIRE) { scheduler.reconcile(); return }
        val row = scheduler.takeDue(intent.getStringExtra("key")) ?: return
        val service = Intent(context, AlertAlarmService::class.java).putExtra("simLineId", row.getString("simLineId")).putExtra("alarmKey", intent.getStringExtra("key"))
        try {
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service) else context.startService(service)
        } catch (_: RuntimeException) {
            // The OS may refuse playback; keep the warning visible, without replaying the logical alarm.
            AlertAlarmService.showWarning(context, row.getString("simLineId"))
        }
    }
}
