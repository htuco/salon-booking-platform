import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Istorija obavijesti klijenta (task 70).
///
/// Klijent nema politiku nad `notification_logs` — jedina putanja su dva RPC-a koja same
/// izvode salon iz `x-salon-id` i vlasnika iz tokena. Ovdje se zato ne šalje ni salon ni
/// klijent: argument koji se ne šalje ne može se ni podmetnuti.
class NotificationRepository {
  const NotificationRepository(this._client);

  final SupabaseClient _client;

  /// Najnovije prve, jedna stavka po (termin, tip).
  Future<List<ClientNotification>> mine({int limit = 50}) => guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'my_notifications',
      params: {'p_limit': limit},
    );
    return rows
        .cast<Map<String, dynamic>>()
        .map(ClientNotification.fromJson)
        .toList(growable: false);
  });

  /// Označava sve obavijesti klijenta u ovom salonu pročitanim.
  Future<void> markAllRead() => guard(() async {
    await _client.rpc<dynamic>('mark_notifications_read');
  });
}
