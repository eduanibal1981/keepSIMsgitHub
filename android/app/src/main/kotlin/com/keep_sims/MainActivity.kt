package com.keep_sims

import android.os.Build
import android.telephony.euicc.EuiccManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.keep_sims/esim"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "isEsimSupported") {
                    result.success(isEsimSupported())
                } else {
                    result.notImplemented()
                }
            }
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
