import 'dart:convert';

import 'package:core_api/core_api.dart';
import 'package:core_api/src/push/device_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../tool/firebase_defines.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'Registracija cuva tajnu instalacije i vraca FK, ne instalacioni ID',
    () async {
      final payloads = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'http://localhost',
        'anon',
        httpClient: MockClient((request) async {
          payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            '"database-device-id"',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = DeviceRepository(client);
      final id = await repo.register(
        salonId: 'salon',
        platform: 'ios',
        token: null,
        staff: false,
      );
      await DeviceRepository(client).register(
        salonId: 'salon',
        platform: 'ios',
        token: 'refreshed',
        staff: false,
      );
      expect(id, 'database-device-id');
      expect(payloads[0]['p_installation_id'], isNot(id));
      expect(payloads[0]['p_secret'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(payloads[1]['p_secret'], payloads[0]['p_secret']);
      expect(
        payloads[1]['p_installation_id'],
        payloads[0]['p_installation_id'],
      );
      expect(payloads[1]['p_fcm_token'], 'refreshed');
      expect(payloads[1].containsKey('p_auth_identity_id'), isFalse);
    },
  );

  test('Odjava koristi istu tajnu; PostgREST greska ostaje ApiError', () async {
    final payloads = <Map<String, dynamic>>[];
    final client = SupabaseClient(
      'http://localhost',
      'anon',
      httpClient: MockClient((request) async {
        payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (request.url.path.endsWith('unregister_device')) {
          return http.Response(
            '{"code":"42501","message":"Nije dozvoljeno"}',
            403,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '"database-device-id"',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = DeviceRepository(client);
    await repo.register(
      salonId: 'salon',
      platform: 'android',
      token: 'token',
      staff: true,
    );
    await expectLater(repo.unregister('salon'), throwsA(isA<ApiError>()));
    expect(payloads[1]['p_secret'], payloads[0]['p_secret']);
    expect(payloads[1]['p_salon_id'], 'salon');
  });

  test('Iskljucen push ne trazi Supabase niti native plugin', () async {
    final container = ProviderContainer(
      overrides: [pushEnabledProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);
    expect(container.read(pushServiceProvider), isNull);
    expect(await container.read(bookingDeviceIdProvider)(), isNull);
    await container.read(pushInitializationProvider.future);
  });

  test('Greska odjave uredjaja zaustavlja uklanjanje sesije', () async {
    var authCalls = 0;
    final client = SupabaseClient(
      'http://localhost',
      'anon',
      httpClient: MockClient((_) async {
        authCalls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.dispose);
    Future<void> fail() async => throw const NetworkError('offline');
    await expectLater(
      SupabaseAuthRepository(client, beforeSignOut: fail).signOut(),
      throwsA(isA<NetworkError>()),
    );
    await expectLater(
      StaffRepository(client, beforeSignOut: fail).signOut(),
      throwsA(isA<NetworkError>()),
    );
    expect(authCalls, 0);
  });

  test(
    'Firebase konfiguracija bira pravi Android paket i odbija drugi flavor',
    () {
      final Map<String, dynamic> config = {
        'project_info': {'project_id': 'project', 'project_number': '123'},
        'client': [
          {
            'client_info': {
              'mobilesdk_app_id': 'app-id',
              'android_client_info': {'package_name': 'ba.salon'},
            },
            'api_key': [
              {'current_key': 'test-key'},
            ],
          },
        ],
      };
      expect(firebaseDefines(config, 'ba.salon')['FIREBASE_APP_ID'], 'app-id');
      expect(() => firebaseDefines(config, 'ba.drugi'), throwsFormatException);
      config['project_info']!['project_id'] = 'placeholder';
      expect(() => firebaseDefines(config, 'ba.salon'), throwsFormatException);
    },
  );

  test('iOS config mora odgovarati bundle ID-u', () {
    final config = {
      'BUNDLE_ID': 'ba.salon',
      'API_KEY': 'key',
      'GOOGLE_APP_ID': 'app',
      'PROJECT_ID': 'project',
      'GCM_SENDER_ID': '123',
    };
    expect(firebaseDefines(config, 'ba.salon')['PUSH_ENABLED'], 'true');
    expect(() => firebaseDefines(config, 'ba.drugi'), throwsFormatException);
  });
}
