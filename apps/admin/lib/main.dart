import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/env/app_env.dart';
import 'src/core/env/bootstrap.dart';
import 'src/core/router/admin_router.dart';
import 'src/features/appointments/appointments_providers.dart';

Future<void> main() async {
  final env = await bootstrapAdmin();

  runApp(
    ProviderScope(
      overrides: [
        adminEnvProvider.overrideWithValue(env),
        pushStaffProvider.overrideWithValue(true),
      ],
      child: const SalonAdminApp(),
    ),
  );
}

/// Admin aplikacija — **jedna za sve salone**, bez flavora i bez `SALON_ID`.
///
/// Vlasnik se prijavi i vidi svoj salon na osnovu clanstva u `public.users`; zato admin
/// nema brandiranje po tenantu koje klijentska app ima.
class SalonAdminApp extends ConsumerWidget {
  const SalonAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushInitializationProvider);
    void refresh() {
      ref.invalidate(filtriraniTerminiProvider);
      ref.invalidate(pendingCountProvider);
      ref.invalidate(danasnjiTerminiProvider);
    }

    ref.listen(pushReceivedProvider, (_, next) {
      if (next.valueOrNull == ref.read(adminSalonIdProvider) && next.hasValue) {
        refresh();
      }
    });
    ref.listen(pushOpenedProvider, (_, next) {
      if (!next.hasValue ||
          next.valueOrNull != ref.read(adminSalonIdProvider)) {
        return;
      }
      refresh();
      ref.read(adminRouterProvider).go(AdminRoute.appointments.path);
    });
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Salon Admin',
      routerConfig: ref.watch(adminRouterProvider),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF171717)),
      ),
    );
  }
}
