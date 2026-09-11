import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/vertical_provider.dart';

void main() => runApp(const ProviderScope(child: TenantPreviewApp()));

/// Sprint 0 dokazuje da isti entrypoint prihvata svaki generisani tenant build.
///
/// `SALON_ID` dolazi iz `--dart-define`, a ostatak konfiguracije se traži u
/// generisanom registru — build ne prosljeđuje ime, boju i vertikalu ručno.
/// Runtime izvor istine je backend; ovo su fallback vrijednosti dostupne
/// prije prvog odgovora.
class TenantPreviewApp extends ConsumerWidget {
  const TenantPreviewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantProvider);
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
      home: const TenantHome(),
    );
  }
}

/// Placeholder ekran — Sprint 1 ga zamjenjuje pravim UI-jem.
///
/// Postoji da dokaže lanac **baza → repozitorij → provider → widget**: svaki tekst koji
/// se razlikuje po vertikali dolazi iz `vertical.terms`, nijedan nije literal ovdje.
/// Zato "Zakaži termin" na frizerskom buildu i "Rezerviši termin" na beauty buildu izlaze
/// iz istog `Text`-a, bez `if`-a po vertikali.
class TenantHome extends ConsumerWidget {
  const TenantHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tenant = ref.watch(tenantProvider);
    final vertical = verticalOf(ref);
    final title = tenant?.displayName ?? vertical.terms.businessSingular;
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
                null when kSalonId.isEmpty =>
                  'Nedostaje SALON_ID konfiguracija.',
                null => 'Nepoznat SALON_ID: $kSalonId',
                final t => 'Hello, ${t.salonId}',
              }, textAlign: TextAlign.center),
              if (tenant case final t?) ...[
                const SizedBox(height: 8),
                Text(
                  '${t.flavor} · ${t.vertical}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              // Terminologija iz vertikale — ovo je dokaz da mehanizam radi.
              // Na `barber` buildu: "Zakaži termin" / "Barber" / "Moji termini".
              // Na `beauty` buildu: "Rezerviši termin" / "Stilistica" / "Moji termini".
              FilledButton(
                onPressed: null,
                child: Text(vertical.terms.bookCta),
              ),
              const SizedBox(height: 8),
              Text(
                '${vertical.terms.staffPlural} · ${vertical.terms.servicePlural}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
