import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/env/app_env.dart';
import 'src/core/env/bootstrap.dart';
import 'src/core/router/app_router.dart';
import 'src/core/vertical_provider.dart';
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
    final isDark = tenant?.vertical == 'barber';

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: tenant?.displayName ?? 'Salon',
      routerConfig: ref.watch(appRouterProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: isDark ? const Color(0xFFC6A667) : const Color(0xFFB76E79),
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
    );
  }
}
