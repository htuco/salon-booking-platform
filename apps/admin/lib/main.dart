import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/env/app_env.dart';
import 'src/core/env/bootstrap.dart';
import 'src/core/router/admin_router.dart';

Future<void> main() async {
  final env = await bootstrapAdmin();

  runApp(
    ProviderScope(
      overrides: [adminEnvProvider.overrideWithValue(env)],
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
