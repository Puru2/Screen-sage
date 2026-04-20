package com.pratham.screensage

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON") return

        // Check if a session was active before reboot
        val prefs: SharedPreferences = context.getSharedPreferences(
            "ScreenSagePrefs", Context.MODE_PRIVATE
        )
        val sessionActive = prefs.getBoolean("session_active", false)
        val sessionEndTime = prefs.getLong("session_end_time", 0L)

        if (sessionActive && sessionEndTime > System.currentTimeMillis()) {
            // Session still has time remaining — restart the foreground service
            val serviceIntent = Intent(context, ScreenTimeService::class.java).apply {
                putExtra("resumeSession", true)
                putExtra("endTime", sessionEndTime)
            }
            context.startForegroundService(serviceIntent)
        }
    }
}
