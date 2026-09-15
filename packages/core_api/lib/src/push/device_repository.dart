import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../errors/errors.dart';

class DeviceRepository {
  DeviceRepository(this._client, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final SupabaseClient _client;
  final FlutterSecureStorage _storage;
  Future<({String id, String secret})>? _installation;

  Future<({String id, String secret})> _credentials() =>
      _installation ??= _loadCredentials();

  Future<({String id, String secret})> _loadCredentials() async {
    const key = 'push.installation.v1';
    final saved = await _storage.read(key: key);
    if (saved != null) {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      return (id: json['id'] as String, secret: json['secret'] as String);
    }
    final random = Random.secure();
    final secret = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final id = const Uuid().v4();
    // Jedan zapis: prekid izmedju ID-a i tajne ne smije napraviti neupotrebljiv par.
    await _storage.write(
      key: key,
      value: jsonEncode({'id': id, 'secret': secret}),
    );
    return (id: id, secret: secret);
  }

  Future<String> register({
    required String salonId,
    required String platform,
    required String? token,
    required bool staff,
  }) => guard(() async {
    final installation = await _credentials();
    final result = await _client.rpc(
      'register_device',
      params: {
        'p_salon_id': salonId,
        'p_installation_id': installation.id,
        'p_secret': installation.secret,
        'p_platform': platform,
        'p_fcm_token': token,
        'p_staff': staff,
      },
    );
    return result as String;
  });

  Future<void> unregister(String salonId) => guard(() async {
    final installation = await _credentials();
    await _client.rpc(
      'unregister_device',
      params: {
        'p_salon_id': salonId,
        'p_installation_id': installation.id,
        'p_secret': installation.secret,
      },
    );
  });
}
