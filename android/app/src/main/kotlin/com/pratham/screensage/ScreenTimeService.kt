// android/app/src/main/kotlin/com/screensage/ScreenTimeService.kt
package com.screensage

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class ScreenTimeService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private val checkInterval = 1000L // check every second
    private var blockedPackages: Set<String> = emptySet()
    private var sessionActive = false

    private val checker = object : Runnable {
        override fun run() {
            if (sessionActive) {
                checkForegroundApp()
                handler.postDelayed(this, checkInterval)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()

        val notification = NotificationCompat.Builder(this, "screensage_channel")
            .setContentTitle("ScreenSage Focus Active")
            .setContentText("Stay focused. You're doing great.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(1, notification)

        // Receive blocked packages list from Flutter
        blockedPackages = intent?.getStringArrayExtra("blockedPackages")
            ?.toSet() ?: emptySet()
        sessionActive = true
        handler.post(checker)

        return START_STICKY
    }

    private fun checkForegroundApp() {
        val usageManager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val stats = usageManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY, now - 5000, now
        )
        val foreground = stats?.maxByOrNull { it.lastTimeUsed }?.packageName ?: return

        if (foreground in blockedPackages && foreground != packageName) {
            // Launch overlay / bring app to front
            val overlayIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra("showOverride", true)
                putExtra("blockedPackage", foreground)
            }
            startActivity(overlayIntent)
        }
    }

    override fun onDestroy() {
        sessionActive = false
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            "screensage_channel",
            "ScreenSage Focus Session",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
