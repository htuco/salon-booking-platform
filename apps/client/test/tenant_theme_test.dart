import 'dart:async';

import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/generated/tenants.g.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresija za neusklađenost teme: `Theme.of` pozvan u `build` metodi koja
/// tek gradi `MaterialApp` vraća Flutterov default (svijetlu) temu, pa se
/// tekst iscrta tamno na tamnoj tenant pozadini i postane nevidljiv.
///
/// Ranije je ovaj fajl tražio `--dart-define=SALON_ID=<uuid>` i bez njega se **skipovao**,
/// jer je `SALON_ID` bio compile-time konstanta. Otkad env ulazi kroz `appEnvProvider`,
/// test bira tenanta sam i uvijek se izvršava — uključujući tamnu temu, gdje se
/// neusklađenost jedino i vidi.
///
/// Od taska 09 provjerava i **fallback lanac**: boje dolaze sa backenda, pa iz
/// `tenant.yaml`, pa tek onda iz podrazumijevane palete.
void main() {
  for (final tenant in kTenants.values) {
    testWidgets('svaki tekst ima WCAG AA kontrast — ${tenant.flavor}', (
      tester,
    ) async {
      await tester.pumpWidget(_app(tenant));
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      final background = theme.colorScheme.surface;
      final fallback = theme.textTheme.bodyMedium!.color!;

      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final color = text.style?.color ?? fallback;
        final ratio = contrastRatio(color, background);
        expect(
          ratio,
          greaterThan(4.5),
          reason:
              'Tekst "${text.data}" ima kontrast ${ratio.toStringAsFixed(2)}:1 '
              'prema pozadini — ispod WCAG AA. Vjerovatno `Theme.of` iz '
              'konteksta iznad MaterialApp-a.',
        );
      }
    });

    testWidgets('tema dolazi iz tenant.yaml prije bilo kakvog odgovora — '
        '${tenant.flavor}', (tester) async {
      // Prvi frame, bez `pumpAndSettle`: ovo je tacno trenutak u kojem bi se vidio
      // bijeli flash da tema ceka `salonProvider`. `salonProvider` ovdje nikad ne
      // odgovori (Completer bez `complete`), pa je jedini izvor boje `tenant.yaml`.
      await tester.pumpWidget(_app(tenant, salon: _nikadNeStigne));
      await tester.pump();

      final theme = _temaEkrana(tester);
      expect(
        theme.colorScheme.primary.toARGB32(),
        tenant.primaryColor,
        reason:
            '${tenant.flavor}: prvi frame nema boju iz tenant.yaml — '
            'tema ceka mrezu, sto je bijeli flash na startu.',
      );
      expect(
        theme.brightness,
        AppTheme.fromName(tenant.themeName).brightness,
        reason: '${tenant.flavor}: pogresna svjetlina prije odgovora backenda',
      );
      expect(
        theme.scaffoldBackgroundColor,
        isNot(const Color(0xFFFFFFFF)),
        reason:
            'bijela pozadina na prvom frameu je upravo flash koji izbjegavamo',
      );
    });

    testWidgets('boja sa backenda pretekne tenant.yaml — ${tenant.flavor}', (
      tester,
    ) async {
      // Vlasnik je promijenio boju u admin app-i. Promjena mora stici do app-e **bez
      // novog builda** — to je cijela poenta runtime brandinga.
      const novaPrimarna = '#0B6E4F';
      await tester.pumpWidget(
        _app(
          tenant,
          salon: Future.value(
            _salon(tenant, primary: novaPrimarna, theme: tenant.themeName),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final theme = _temaEkrana(tester);
      expect(theme.colorScheme.primary.toARGB32(), 0xFF0B6E4F);
      expect(
        contrastRatio(theme.colorScheme.onPrimary, theme.colorScheme.primary),
        greaterThanOrEqualTo(kWcagAa),
        reason: 'boja koju vlasnik izabere mora ostati citljiva bez rucnog dotjerivanja',
      );
    });
  }

  testWidgets('neispravan heks iz baze pada na tenant.yaml, ne ruši app', (
    tester,
  ) async {
    // Boju uredjuje vlasnik kroz admin app; neispravna vrijednost tamo ne smije biti
    // izuzetak pri startu klijentske aplikacije.
    final tenant = kTenants.values.first;
    await tester.pumpWidget(
      _app(tenant, salon: Future.value(_salon(tenant, primary: 'nije-boja'))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final theme = _temaEkrana(tester);
    expect(theme.colorScheme.primary.toARGB32(), tenant.primaryColor);
  });

  testWidgets('build bez tenanta u registru dobije podrazumijevanu temu', (
    tester,
  ) async {
    // `SALON_ID` koji nije u `tenants.g.dart` (zaboravljen generator). App se mora
    // otvoriti u nekoj temi umjesto da pukne na `null`-u.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvProvider.overrideWithValue(
            const AppEnv(
              salonId: '00000000-0000-0000-0000-000000000000',
              supabaseUrl: '',
              supabaseAnonKey: '',
              apiUrl: '',
            ),
          ),
          currentSalonIdProvider.overrideWithValue(
            '00000000-0000-0000-0000-000000000000',
          ),
          salonProvider.overrideWith((ref) => _nikadNeStigne),
        ],
        child: const SalonClientApp(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

/// Tema onakva kakvu **ekran** vidi.
///
/// Namjerno ne `Theme.of(tester.element(find.byType(MaterialApp)))`: taj element je
/// iznad `MaterialApp`-a, pa `Theme.of` tamo vraća Flutterov default i test bi mjerio
/// boje koje korisnik nikad ne vidi. To je ista zamka zbog koje ovaj fajl i postoji
/// (`a53a429`) — samo prebačena iz aplikacije u test.
///
/// Čita se `MaterialApp.theme` sa samog widgeta, a ne kroz `Theme.of` nekog potomka:
/// na prvom frameu router još nije iscrtao rutu, pa ispod `MaterialApp`-a nema nijednog
/// elementa koji je već ispod `Theme`-a. Ovo je ista tema koju app proslijedi dalje.
ThemeData _temaEkrana(WidgetTester tester) {
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  return app.theme!;
}

/// `salonProvider` koji nikad ne odgovori — stanje u kojem app provede prvi frame na
/// svakom hladnom startu, i jedino u kojem se flash vidi.
Future<Salon> get _nikadNeStigne => Completer<Salon>().future;

Salon _salon(TenantConfig tenant, {String? primary, String? theme}) => Salon(
  id: tenant.salonId,
  name: tenant.displayName,
  slug: tenant.slug,
  city: 'Vitez',
  primaryColor: primary ?? '#C6A667',
  secondaryColor: '#171717',
  theme: theme ?? tenant.themeName,
);

Widget _app(TenantConfig tenant, {Future<Salon>? salon}) => ProviderScope(
  overrides: [
    appEnvProvider.overrideWithValue(
      AppEnv(
        salonId: tenant.salonId,
        supabaseUrl: '',
        supabaseAnonKey: '',
        apiUrl: '',
      ),
    ),
    // `currentSalonIdProvider` se override-uje direktno umjesto kroz `coreApiOverrides`:
    // ovdje nema `Supabase.instance`, pa repozitorij ne smije ni nastati.
    currentSalonIdProvider.overrideWithValue(tenant.salonId),
    salonProvider.overrideWith((ref) => salon ?? _nikadNeStigne),
  ],
  child: const SalonClientApp(),
);
