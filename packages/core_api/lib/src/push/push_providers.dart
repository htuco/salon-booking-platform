import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'push_service.dart';

final pushEnabledProvider = Provider<bool>(
  (ref) =>
      const bool.fromEnvironment('PUSH_ENABLED') &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS),
);
final pushStaffProvider = Provider<bool>((ref) => false);
final pushServiceProvider = Provider<PushService?>((ref) {
  if (!ref.watch(pushEnabledProvider)) return null;
  final staff = ref.watch(pushStaffProvider);
  final service = PushService(
    ref.watch(supabaseClientProvider),
    salonId: staff ? null : ref.watch(currentSalonIdProvider),
    staff: staff,
  );
  ref.onDispose(service.dispose);
  return service;
});

final pushInitializationProvider = FutureProvider<void>((ref) async {
  await ref.watch(pushServiceProvider)?.initialize();
});

final pushOpenedProvider = StreamProvider<String>((ref) async* {
  final service = ref.watch(pushServiceProvider);
  if (service == null) return;
  // Pretplata prije initialize: hladni start i tap ne smiju se izgubiti tokom registracije.
  final messages = StreamController<String>();
  final subscription = service.opened.listen(messages.add);
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(messages.close());
  });
  await ref.watch(pushInitializationProvider.future);
  final initial = service.takeInitialSalon();
  if (initial != null) yield initial;
  yield* messages.stream;
});

final pushReceivedProvider = StreamProvider<String>(
  (ref) => ref.watch(pushServiceProvider)?.received ?? const Stream.empty(),
);

final bookingDeviceIdProvider = Provider<Future<String?> Function()>(
  (ref) =>
      () async => ref.read(pushServiceProvider)?.deviceForBooking(),
);
