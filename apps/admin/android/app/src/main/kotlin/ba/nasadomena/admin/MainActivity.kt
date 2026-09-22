package ba.nasadomena.admin

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        // Isti ID kao u klijentu i kao `default_notification_channel_id` u manifestu.
        // Kad kanal ne postoji, FCM obavijest baca na vlastiti
        // `fcm_fallback_notification_channel`, koji se korisniku zove „Miscellaneous"
        // i cija importance nije nasa — tako je admin dobijao nijeme obavijesti.
        private const val NOTIFICATION_CHANNEL = "appointment_updates"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
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
                description = "Novi zahtjevi, nove rezervacije i otkazivanja"
                enableVibration(true)
                // Na API 26+ o zvuku odlucuje kanal, ne poruka. `USAGE_NOTIFICATION` drzi
                // ton na kanalu jacine za obavijesti umjesto na medijskom.
                setSound(
                    Settings.System.DEFAULT_NOTIFICATION_URI,
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .build(),
                )
            },
        )
    }
}
