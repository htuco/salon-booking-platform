import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/env/app_env.dart';
import 'src/core/env/bootstrap.dart';
import 'src/core/router/admin_router.dart';
import 'src/features/appointments/appointments_providers.dart';

final adminMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
    final env = ref.watch(adminEnvProvider);

    // Foreground promjene stižu direktno kroz Supabase Realtime; FCM ostaje put za
    // pozadinu/ugašenu aplikaciju. RLS na streamu ograničava admina na njegov salon.
    if (env.hasSupabase) {
      final salonId = ref.watch(adminSalonIdProvider);
      if (salonId != null) {
        ref.listen(appointmentChangesProvider(salonId), (_, next) {
          if (next.hasValue) {
            refreshAdminAppointments(ref);
            return;
          }
          if (next.hasError) {
            adminMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text(
                  'Osvježavanje termina nije dostupno. Ručno osvježite ekran.',
                ),
              ),
            );
          }
        });
      }
    }
    ref.watch(pushInitializationProvider);

    ref.listen(pushReceivedProvider, (_, next) {
      final message = next.valueOrNull;
      if (message == null) return;
      if (message.salonId != ref.read(adminSalonIdProvider)) return;
      refreshAdminAppointments(ref);
    });
    ref.listen(pushOpenedProvider, (_, next) {
      if (!next.hasValue ||
          next.valueOrNull != ref.read(adminSalonIdProvider)) {
        return;
      }
      refreshAdminAppointments(ref);
      ref.read(adminRouterProvider).go(AdminRoute.appointments.path);
    });
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: adminMessengerKey,
      title: 'Salon Admin',
      routerConfig: ref.watch(adminRouterProvider),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF171717)),
      ),
    );
  }
}

void refreshAdminAppointments(WidgetRef ref) {
  ref
    ..invalidate(filtriraniTerminiProvider)
    ..invalidate(pendingCountProvider)
    ..invalidate(danasnjiTerminiProvider);
}
