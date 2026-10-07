import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/env/app_env.dart';
import 'src/core/env/bootstrap.dart';
import 'src/core/router/admin_router.dart';
import 'src/core/theme/theme.dart';
import 'src/core/widgets/admin_toast.dart';
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
            final overlay = adminToastOverlayKey.currentState;
            if (overlay == null) return;
            AdminToast.prikazi(
              overlay,
              AdminToastVrsta.upozorenje,
              'Osvježavanje termina nije dostupno',
              opis: 'Ručno osvježite ekran.',
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
      // „Novi zahtjev" otvara granu Zahtjevi i detalj u njoj, sa „nazad" na listu.
      final termin = ref.read(pushServiceProvider)?.takeOpenedAppointment();
      ref
          .read(adminRouterProvider)
          .go(
            termin == null
                ? AdminRoute.requests.path
                : '${AdminRoute.requests.path}/$termin',
          );
    });
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      // Toastovi stoje iznad navigatora, pa ih dijalog ne prekriva (v. `AdminToast`).
      builder: (context, child) => AdminToastSloj(child: child!),
      title: 'Melura',
      routerConfig: ref.watch(adminRouterProvider),
      theme: buildAdminTheme(),
      darkTheme: buildAdminTheme(Brightness.dark),
      // **Svijetla, ne sistemska** (ADR-0020). `adminv2/export/` crta samo svijetlu
      // radnu površinu uz tamni sidebar; sa `system` je svaki vlasnik u dark modu OS-a
      // vidio ekran koji nije nacrtan nigdje. Tamna tema ostaje izgrađena i testirana —
      // vraća se promjenom ovog reda kad handoff dobije tamnu varijantu.
      themeMode: ThemeMode.light,
    );
  }
}

void refreshAdminAppointments(WidgetRef ref) {
  ref
    ..invalidate(filtriraniTerminiProvider)
    ..invalidate(pendingCountProvider)
    ..invalidate(danasnjiTerminiProvider);
}
