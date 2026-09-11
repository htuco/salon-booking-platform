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
      // Salon mora stici, inace ekran ostane na kosturu i test ne izmjeri nijedan tekst.
      await tester.pumpWidget(
        _app(tenant, salon: Future.value(_salon(tenant))),
      );
      // `pump`, ne `pumpAndSettle`: od taska 10 `/` je home ekran, a njegov skeleton
      // pulsira u nedogled — `pumpAndSettle` bi istekao i kad je sve ispravno.
      await tester.pump();
      await tester.pump();
      // Prelaz preko trajanja Material animacije: CTA krene kao onemogucen (salon jos
      // nije stigao) i **animira** boju teksta u enabled stanje. Mjereno na pola te
      // animacije, tekst ima 0.38 alpha i test prijavi 2.13:1 na dugmetu koje je
      // zapravo 8:1. To je mjerenje u pogresnom trenutku, ne greska u temi.
      await tester.pump(const Duration(milliseconds: 400));

      final theme = Theme.of(tester.element(find.byType(Scaffold)));

      for (final element in find.byType(Text).evaluate()) {
        final text = element.widget as Text;
        // Boja teksta bez `style.color` dolazi iz `DefaultTextStyle`-a nad njim, ne iz
        // `textTheme.bodyMedium`. Razlika je vidljiva baš na CTA dugmetu: `FilledButton`
        // boju daje kroz `foregroundColor`, pa bi fallback na temu mjerio `onSurface`
        // na `primary` pozadini i prijavio čitljivo dugme kao neispravno.
        final color =
            text.style?.color ?? DefaultTextStyle.of(element).style.color!;
        // Pozadina se traži **iza konkretnog teksta**, ne uzima kao `surface` za cijeli
        // ekran. Home ekran ima tekst na obojenim površinama — inicijali salona na
        // `primaryContainer`, živi status na `status.info` — i mjerenje svega prema
        // `surface`-u bi ih oborilo iako su čitljivi. Ovo je ista greška kao mjerenje
        // brand teksta na `surface`-u dok kartica stoji na `surfaceContainer` (task 09).
        final background = _pozadinaIza(element) ?? theme.colorScheme.surface;
        final ratio = contrastRatio(color, background);
        expect(
          ratio,
          greaterThan(4.5),
          reason:
              'Tekst "${text.data}" ima kontrast ${ratio.toStringAsFixed(2)}:1 '
              'prema svojoj pozadini — ispod WCAG AA.',
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
      await tester.pump();
      await tester.pump();

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
    await tester.pump();
    await tester.pump();

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
          servicesProvider.overrideWith((ref) async => const <Service>[]),
          employeesProvider.overrideWith((ref) async => const <Employee>[]),
          workingHoursProvider.overrideWith(
            (ref) async => const <WorkingHour>[],
          ),
          verticalProvider.overrideWith((ref) async => Vertical.fallback),
        ],
        child: const SalonClientApp(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

/// Neprozirna pozadina najbliža datom tekstu, tražena penjanjem uz stablo.
///
/// Postoji jer home ekran ima tekst na obojenim površinama: inicijali salona u logo
/// krugu (`primaryContainer`), živi status u `StatusBadge`-u (`status.info`), cijena na
/// kartici (`surfaceContainerHighest`). Test koji bi sve mjerio prema `surface`-u bi ih
/// prijavio kao neispravne, a test koji bi ih nabrajao kao izuzetke bi prestao da štiti
/// čim neko doda četvrtu obojenu površinu.
///
/// `null` znači da iznad teksta nema obojenog pretka — pozivalac tada uzima `surface`.
Color? _pozadinaIza(Element element) {
  Color? nadjena;

  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;

    final boja = switch (widget) {
      Material(:final color) => color,
      ColoredBox(:final color) => color,
      Container(:final color) => color,
      DecoratedBox(decoration: final BoxDecoration d) => d.color,
      _ => null,
    };

    // Prozirna pozadina ne skriva ono ispod nje, pa se traženje nastavlja dalje.
    if (boja != null && boja.a > 0) {
      nadjena = boja;
      return false;
    }
    return true;
  });

  return nadjena;
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
    // ovdje nema `Supabase.instance`, pa repozitorij ne smije ni nastati. Isto vrijedi
    // za ostale podatkovne providere otkad je `/` pravi ekran (task 10) — svaki od njih
    // bi inace napravio repozitorij i posegnuo za `Supabase.instance`.
    currentSalonIdProvider.overrideWithValue(tenant.salonId),
    salonProvider.overrideWith((ref) => salon ?? _nikadNeStigne),
    servicesProvider.overrideWith((ref) async => const <Service>[]),
    employeesProvider.overrideWith((ref) async => const <Employee>[]),
    workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
    verticalProvider.overrideWith((ref) async => Vertical.fallback),
  ],
  child: const SalonClientApp(),
);
