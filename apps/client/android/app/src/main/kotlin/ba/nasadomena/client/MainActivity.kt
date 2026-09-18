package ba.nasadomena.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "ba.nasadomena.client/foreground_notifications"
        private const val NOTIFICATION_CHANNEL = "appointment_updates"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "show") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                showNotification(
                    call.argument<String>("id").orEmpty(),
                    call.argument<String>("title") ?: getString(R.string.app_name),
                    call.argument<String>("body").orEmpty(),
                )
                result.success(null)
            }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL,
                "Obavijesti o terminima",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Potvrde, odbijanja i otkazivanja termina"
                enableVibration(true)
            },
        )
    }

    @Suppress("DEPRECATION")
    private fun showNotification(id: String, title: String, body: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(Notification.CATEGORY_EVENT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(id.ifEmpty { System.currentTimeMillis().toString() }, 0, notification)
    }
}
