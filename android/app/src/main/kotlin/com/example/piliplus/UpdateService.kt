package com.example.piliplus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * PiliGlass: keeps the app alive while an update downloads, so it goes on
 * when the app is left or the screen is off. The download itself runs in
 * Dart (lib/utils/update_download.dart); this only holds a foreground
 * notification with its progress, and a wake lock.
 */
class UpdateService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = this
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "PiliGlass:update")
            .apply { acquire(30 * 60 * 1000L) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = progress(this, intent?.getStringExtra("title") ?: "", 0, "")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(ID, notification)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        wakeLock?.takeIf { it.isHeld }?.release()
        running = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "update"
        private const val ID = 7301
        var running: UpdateService? = null

        private fun channel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.getSystemService(NotificationManager::class.java)
                    .createNotificationChannel(
                        NotificationChannel(CHANNEL, "更新下载", NotificationManager.IMPORTANCE_LOW)
                    )
            }
        }

        private fun builder(context: Context): Notification.Builder {
            channel(context)
            return (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                Notification.Builder(context, CHANNEL)
            else
                @Suppress("DEPRECATION") Notification.Builder(context))
                .setSmallIcon(R.drawable.ic_notification_icon)
        }

        private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
            context, 0,
            context.packageManager.getLaunchIntentForPackage(context.packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        fun progress(context: Context, title: String, percent: Int, text: String): Notification =
            builder(context)
                .setContentTitle(title)
                .setContentText(text)
                .setProgress(100, percent, percent == 0)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(openApp(context))
                .build()

        fun start(context: Context, title: String) {
            val intent = Intent(context, UpdateService::class.java).putExtra("title", title)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(context: Context, title: String, percent: Int, text: String) {
            if (running == null) return
            context.getSystemService(NotificationManager::class.java)
                .notify(ID, progress(context, title, percent, text))
        }

        /** done, or failed: the progress gives way to [text], which opens [tap] */
        fun finish(context: Context, title: String, text: String, tap: PendingIntent?) {
            running?.let {
                it.stopForeground(Service.STOP_FOREGROUND_REMOVE)
                it.stopSelf()
            }
            if (text.isEmpty()) {
                context.getSystemService(NotificationManager::class.java).cancel(ID)
                return
            }
            context.getSystemService(NotificationManager::class.java).notify(
                ID,
                builder(context)
                    .setContentTitle(title)
                    .setContentText(text)
                    .setAutoCancel(true)
                    .setContentIntent(tap ?: openApp(context))
                    .build()
            )
        }
    }
}
