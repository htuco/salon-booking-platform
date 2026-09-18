import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/staff_repository.dart';
import '../errors/errors.dart';
import 'device_repository.dart';

/// Nema licnih podataka u poruci; ekran ih ponovo ucitava pod trenutnim JWT-om.
class PushService with WidgetsBindingObserver {
  PushService(this._client, {required this.salonId, required this.staff})
    : _devices = DeviceRepository(_client);

  final SupabaseClient _client;
  final DeviceRepository _devices;
  final String? salonId;
  final bool staff;
  final _opened = StreamController<String>.broadcast();
  final _received = StreamController<PushMessage>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> _queue = Future.value();
  Future<void>? _initializing;
  String? _registeredSalon;
  String? _deviceId;
  String? _pendingSalon;
  bool _disposed = false;
  bool _signingOut = false;

  Stream<String> get opened => _opened.stream;
  Stream<PushMessage> get received => _received.stream;

  String? takeInitialSalon() {
    final value = _pendingSalon;
    _pendingSalon = null;
    return value;
  }

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    const options = FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
    );
    if (options.apiKey.isEmpty ||
        options.appId.isEmpty ||
        options.messagingSenderId.isEmpty ||
        options.projectId.isEmpty) {
      throw const ServerError('Nedostaje Firebase konfiguracija');
    }
    await Firebase.initializeApp(options: options);
    if (_disposed) return;
    WidgetsBinding.instance.addObserver(this);
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    _subscriptions.add(messaging.onTokenRefresh.listen((_) => _refresh()));
    _subscriptions.add(
      _client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedOut ||
            state.event == AuthChangeEvent.signedIn) {
          _signingOut = false;
        }
        _refresh();
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final salon = _messageSalon(message);
        if (salon != null) _opened.add(salon);
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((message) {
        final push = _pushMessage(message);
        if (push != null) _received.add(push);
      }),
    );
    await _serialize(_sync).catchError((Object _) => null);
    final initial = await messaging.getInitialMessage();
    if (initial != null) _pendingSalon = _messageSalon(initial);
  }

  String? _messageSalon(RemoteMessage message) {
    final salon = message.data['salon_id'];
    if (message.data['route'] != '/appointments' || salon is! String) {
      return null;
    }
    if (salon != _registeredSalon && salon != salonId) return null;
    return salon;
  }

  PushMessage? _pushMessage(RemoteMessage message) {
    final salon = _messageSalon(message);
    if (salon == null) return null;
    return PushMessage(
      salonId: salon,
      notificationId:
          message.data['notification_id'] as String? ?? message.messageId ?? '',
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }

  Future<T> _serialize<T>(Future<T> Function() work) {
    final result = _queue.then((_) => work());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _refresh() {
    if (_disposed) return;
    unawaited(
      _serialize(_sync).catchError((Object _) {
        // Bez tokena/tajne u logu. Sljedeci resume ili booking ponavlja registraciju.
        debugPrint('Push registracija nije uspjela; ceka ponovni pokusaj.');
        return null;
      }),
    );
  }

  Future<String?> _sync() async {
    if (_disposed || _signingOut) return null;
    final userId = _client.auth.currentUser?.id;
    final salon = staff
        ? (await StaffRepository(_client).membership())?.salonId
        : salonId;
    if (salon == null) {
      if (_registeredSalon != null) {
        await _devices.unregister(_registeredSalon!);
      }
      _registeredSalon = null;
      _deviceId = null;
      return null;
    }
    if (_registeredSalon != null && _registeredSalon != salon) {
      await _devices.unregister(_registeredSalon!);
    }
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.getNotificationSettings();
    String? token;
    if (permission.authorizationStatus == AuthorizationStatus.authorized ||
        permission.authorizationStatus == AuthorizationStatus.provisional) {
      // Apple ne dozvoljava getToken prije nego sto stigne APNs token.
      if (defaultTargetPlatform != TargetPlatform.iOS ||
          await messaging.getAPNSToken() != null) {
        token = await messaging.getToken();
      }
    }
    if (_client.auth.currentUser?.id != userId) return _sync();
    _deviceId = await _devices.register(
      salonId: salon,
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      token: token,
      staff: staff,
    );
    _registeredSalon = salon;
    if (_client.auth.currentUser?.id != userId) return _sync();
    return _deviceId;
  }

  Future<String?> deviceForBooking() => guard(() async {
    await initialize();
    return _serialize(_sync);
  });

  /// Poziva se prije uklanjanja sesije; neuspjeh se prikazuje kao greska odjave.
  Future<void> beforeSignOut() async {
    // Poslije restarta memorija jos ne zna uredjaj. Ne smijemo obrisati sesiju dok
    // stara registracija na serveru moze nastaviti primati poruke.
    await initialize();
    await _serialize(_sync);
    _signingOut = true;
    try {
      await _serialize(() async {
        if (_registeredSalon != null) {
          await _devices.unregister(_registeredSalon!);
        }
        _deviceId = null;
        _registeredSalon = null;
      });
    } catch (_) {
      _signingOut = false;
      rethrow;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_opened.close());
    unawaited(_received.close());
  }
}

/// Sigurni dio FCM poruke potreban UI-ju za foreground prikaz.
///
/// Backend namjerno ne šalje lične podatke u push payloadu. Detalji termina se uvijek
/// ponovo čitaju pod trenutnim JWT-om.
///
/// `title` i `body` su ono što je backend poslao — ovdje nema fallback teksta, jer bi
/// svaki takav tekst nosio terminologiju jedne vertikale u zajednički paket. Poruka bez
/// njih i dalje osvježava listu, samo se ne prikazuje kao sistemska obavijest.
@immutable
class PushMessage {
  const PushMessage({
    required this.salonId,
    required this.notificationId,
    this.title,
    this.body,
  });

  final String salonId;
  final String notificationId;
  final String? title;
  final String? body;
}
