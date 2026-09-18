import 'package:core_api/core_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Prikazuje Android sistemsku obavijest kada FCM stigne dok je aplikacija otvorena.
///
/// Android tada, za razliku od background/terminated stanja, ne crta notification
/// payload automatski. Native kanal koristi isti ID kao FCM default kanal, pa korisnik
/// ima jednu postavku za sve obavijesti o terminima.
///
/// iOS ovo ne treba: `setForegroundNotificationPresentationOptions` u `PushService`
/// već pušta sistem da sam nacrta obavijest u prvom planu. Zato ovdje izlazimo odmah —
/// bez toga bi se ista obavijest pojavila dvaput.
abstract final class ForegroundNotifications {
  static const _channel = MethodChannel(
    'ba.nasadomena.client/foreground_notifications',
  );

  static Future<void> show(PushMessage message) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final title = message.title;
    final body = message.body;
    // Poruka bez notification payloada osvježava listu, ali nema šta prikazati.
    if (title == null || body == null) return;
    await _channel.invokeMethod<void>('show', {
      'id': message.notificationId,
      'title': title,
      'body': body,
    });
  }
}
