package com.keep_sims

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import android.telephony.euicc.EuiccManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.keep_sims/esim"
    private var pushChannel: MethodChannel? = null
    private var pushListenerReady = false
    private val pushPayloadExtra = "keepsims_foreground_push"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createNotificationChannels()

        pushChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.keep_sims/notifications")
        pushChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "showForeground" -> {
                    try {
                        showForegroundNotification(call.arguments as Map<*, *>)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("notification_display", error.message, null)
                    }
                }
                "getInitialTap" -> {
                    pushListenerReady = true
                    result.success(takePushPayload(intent))
                }
                "trimBacklog" -> {
                    // Keep room below Android's per-app cap when legacy
                    // OneSignal retries and FCM cards have accumulated together.
                    // Notification history remains available in the app inbox.
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val old = manager.activeNotifications.sortedByDescending { it.postTime }.drop(20)
                    old.forEach { manager.cancel(it.tag, it.id) }
                    // OneSignal must also mark its old cards dismissed so it
                    // does not restore them on the next launch.
                    result.success(old.filter { it.tag == null }.map { it.id })
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.keep_sims/timezone")
            .setMethodCallHandler { call, result ->
                if (call.method == "getTimeZoneId") {
                    result.success(java.util.TimeZone.getDefault().id)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "isEsimSupported") {
                    result.success(isEsimSupported())
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (pushListenerReady) {
            takePushPayload(intent)?.let { pushChannel?.invokeMethod("notificationTap", it) }
        }
    }

    private fun takePushPayload(source: Intent?): String? {
        val payload = source?.getStringExtra(pushPayloadExtra) ?: return null
        source.removeExtra(pushPayloadExtra)
        return payload
    }

    private fun showForegroundNotification(arguments: Map<*, *>) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !manager.areNotificationsEnabled()) return
        val key = arguments["id"] as String
        val data = arguments["data"] as Map<*, *>
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(pushPayloadExtra, JSONObject(data).toString())
            // Distinct intents preserve the destination of every visible card.
            action = "com.keep_sims.PUSH.$key"
        }
        val pending = PendingIntent.getActivity(this, key.hashCode(), tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val channelId = arguments["channel_id"] as String
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_keepsims)
            .setContentTitle(arguments["title"] as? String)
            .setContentText(arguments["body"] as? String)
            .setStyle(Notification.BigTextStyle().bigText(arguments["body"] as? String))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .build()
        manager.notify(key, 0, notification)
    }

    /**
     * Pre-registers the three KeepSIMs notification channels with appropriate
     * Android importance levels and localized names/descriptions from strings.xml.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        // Channel 1: Setup confirmations (LOW importance, quiet, no vibration)
        val confirmationsChannel = NotificationChannel(
            "ks_confirmations_v1",
            getString(R.string.channel_confirmations_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = getString(R.string.channel_confirmations_description)
            setShowBadge(true)
        }

        // Channel 2: Recharge updates (DEFAULT importance, normal sound, no forced pop-up)
        val updatesChannel = NotificationChannel(
            "ks_updates_v1",
            getString(R.string.channel_updates_name),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = getString(R.string.channel_updates_description)
            setShowBadge(true)
        }

        // Channel 3: Urgent recharge alerts (HIGH importance, heads-up eligible, vibration)
        val urgentChannel = NotificationChannel(
            "ks_urgent_v1",
            getString(R.string.channel_urgent_name),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = getString(R.string.channel_urgent_description)
            setShowBadge(true)
            enableVibration(true)
        }

        notificationManager.createNotificationChannels(
            listOf(confirmationsChannel, updatesChannel, urgentChannel)
        )
    }

    /**
     * Checks whether the device supports eSIM provisioning.
     *
     * Requires Android 9 (API 28) or higher for EuiccManager access.
     * Returns false on older API levels or when eUICC is not enabled.
     */
    private fun isEsimSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return false
        }
        val euiccManager = getSystemService(EuiccManager::class.java)
        return euiccManager?.isEnabled == true
    }
}
