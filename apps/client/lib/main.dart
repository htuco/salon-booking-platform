import 'package:flutter/material.dart';

import 'src/generated/tenants.g.dart';

void main() => runApp(const TenantPreviewApp());

/// Sprint 0 dokazuje da isti entrypoint prihvata svaki generisani tenant build.
///
/// `SALON_ID` dolazi iz `--dart-define`, a ostatak konfiguracije se traži u
/// generisanom registru — build ne prosljeđuje ime, boju i vertikalu ručno.
/// Runtime izvor istine je backend; ovo su fallback vrijednosti dostupne
/// prije prvog odgovora.
class TenantPreviewApp extends StatelessWidget {
  const TenantPreviewApp({super.key});

  static const salonId = String.fromEnvironment('SALON_ID');

  @override
  Widget build(BuildContext context) {
    final tenant = kTenants[salonId];
    final isDark = tenant?.vertical == 'barber';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: tenant?.displayName ?? 'Salon',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: isDark ? const Color(0xFFC6A667) : const Color(0xFFB76E79),
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      // Tijelo je zaseban widget, ne inline Scaffold: `Theme.of` mora vidjeti
      // temu koju ovaj MaterialApp postavlja. Pozvan iz `build` metode iznad,
      // vratio bi Flutterov default (svijetlu) i tekst bi na tamnoj tenant
      // temi bio nevidljiv.
      home: TenantHome(tenant: tenant, salonId: salonId),
    );
  }
}

/// Placeholder ekran — Sprint 1 ga zamjenjuje pravim UI-jem.
class TenantHome extends StatelessWidget {
  const TenantHome({required this.tenant, required this.salonId, super.key});

  final TenantConfig? tenant;
  final String salonId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = tenant?.displayName ?? 'Salon';
    final isDark = tenant?.vertical == 'barber';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isDark ? Icons.content_cut : Icons.spa_outlined, size: 72),
              const SizedBox(height: 24),
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(switch (tenant) {
                null when salonId.isEmpty =>
                  'Nedostaje SALON_ID konfiguracija.',
                null => 'Nepoznat SALON_ID: $salonId',
                final t => 'Hello, ${t.salonId}',
              }, textAlign: TextAlign.center),
              if (tenant case final t?) ...[
                const SizedBox(height: 8),
                Text(
                  '${t.flavor} · ${t.vertical}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
