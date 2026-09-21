import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/env/app_env.dart';
import 'src/core/env/bootstrap.dart';
import 'src/core/foreground_notifications.dart';
import 'src/core/router/app_router.dart';
import 'src/core/theme_provider.dart';
import 'src/core/vertical_provider.dart';
import 'src/features/booking/booking_flow_provider.dart';
import 'src/l10n/generated/app_localizations.dart';

Future<void> main() async {
  final env = await bootstrapClient();

  runApp(
    ProviderScope(
      // Env se ubacuje kroz override umjesto da ga app cita iz globalne varijable:
      // test tako podize app sa svojim okruzenjem, bez `--dart-define`-a i bez mreze.
      // `coreApiOverrides` vezuje `core_api` na ovaj build (SALON_ID); bez njega
      // repozitoriji bacaju UnimplementedError na prvom pozivu.
      overrides: [appEnvProvider.overrideWithValue(env), ...coreApiOverrides],
      child: const SalonClientApp(),
    ),
  );
}

/// Klijentska aplikacija — jedan codebase, N brandiranih buildova.
///
/// `SALON_ID` dolazi iz `--dart-define`, ostatak konfiguracije iz generisanog registra
/// (`tenants.g.dart`) i, u runtime-u, sa backenda.
class SalonClientApp extends ConsumerWidget {
  const SalonClientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantProvider);
    final env = ref.watch(appEnvProvider);

    // Realtime prati samo redove koje trenutni JWT smije vidjeti. Događaj nije nova
    // kopija termina: invalidira se tipizirani upit i availability RPC se ponovo poziva.
    if (env.hasSupabase) {
      // Availability signal je javan i ne sadrži podatke o terminima. Mora raditi i prije
      // prijave, inače anonimni korisnik ne vidi da je neko drugi upravo zauzeo slot.
      //
      // **Signal nosi i promjenu kataloga, ne samo zauzeće slota.** Trigger u
      // `availability_realtime.sql` rotira reviziju i na `services`, `employees` i
      // `employee_services`. Do taska 32 se invalidirao samo `availableSlotsProvider`, i to
      // se nije vidjelo jer se cjenovnik nije mogao mijenjati u radu — `servicesProvider`
      // nema `autoDispose`, pa je katalog živio koliko i proces. Čim je salon dobio ekran za
      // izmjenu cijena, ista rupa znači da klijent staru cijenu vidi do hladnog starta, a
      // deaktiviranu uslugu može otvoriti i pasti tek na `book_appointment`.
      ref.listen(availabilityChangesProvider(env.salonId), (_, next) {
        if (!next.hasValue) return;
        ref
          ..invalidate(availableSlotsProvider)
          ..invalidate(servicesProvider)
          ..invalidate(employeesProvider)
          ..invalidate(employeeServiceLinksProvider);
      });

      final sesija = ref.watch(currentAuthSessionProvider);
      if (sesija != null) {
        ref.listen(appointmentChangesProvider(env.salonId), (_, next) {
          if (!next.hasValue) return;
          ref.invalidate(myAppointmentsProvider);
        });
      }
    }
    ref.watch(pushInitializationProvider);
    ref.listen(pushReceivedProvider, (_, next) {
      final message = next.valueOrNull;
      if (message == null) return;
      ref.invalidate(myAppointmentsProvider);
      unawaited(ForegroundNotifications.show(message));
    });
    ref.listen(pushOpenedProvider, (_, next) {
      if (!next.hasValue) return;
      ref.invalidate(myAppointmentsProvider);
      ref.read(appRouterProvider).go(ClientRoute.appointments.path);
    });

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: tenant?.displayName ?? 'Salon',
      routerConfig: ref.watch(appRouterProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Boje vise nisu ovdje. Tema se gradi iz backend vrijednosti sa fallbackom na
      // `tenant.yaml` — v. `theme_provider.dart`. Hardkodirani heks u ovom fajlu bi
      // znacio da treci tenant dobije boje prva dva.
      theme: ref.watch(appThemeProvider),
    );
  }
}
