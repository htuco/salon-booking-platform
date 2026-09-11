import 'package:client/main.dart';
import 'package:client/src/generated/tenants.g.dart';
import 'package:flutter/material.dart';
import 'package:client/src/core/vertical_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // SALON_ID je compile-time konstanta, pa test bez --dart-define može pokriti
  // samo prazan slučaj. Sadržaj po tenantu se provjerava kroz registar.
  testWidgets('Build bez tenanta prijavljuje da konfiguracija nedostaje', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TenantPreviewApp()));
    expect(find.text('Nedostaje SALON_ID konfiguracija.'), findsOneWidget);
  });

  group('Generisani registar tenanata', () {
    test('sadrži oba demo salona iz seed.sql', () {
      expect(
        kTenants.keys,
        containsAll(<String>[
          '550e8400-e29b-41d4-a716-446655440000',
          '550e8400-e29b-41d4-a716-446655440001',
        ]),
      );
    });

    test('ključ je salonId svakog tenanta', () {
      for (final entry in kTenants.entries) {
        expect(entry.key, entry.value.salonId);
      }
    });

    test('applicationId je jedinstven po tenantu', () {
      final flavors = kTenants.values.map((t) => t.flavor).toSet();
      expect(flavors.length, kTenants.length);
    });

    test('flavor je validan gradle identifikator', () {
      for (final tenant in kTenants.values) {
        expect(
          RegExp(r'^[a-z][a-z0-9]*$').hasMatch(tenant.flavor),
          isTrue,
          reason: '${tenant.flavor} nije validan gradle flavor',
        );
      }
    });
  });

  group('TenantHome', () {
    const barber = TenantConfig(
      flavor: 'barberstudiovitez',
      salonId: '550e8400-e29b-41d4-a716-446655440000',
      slug: 'barberstudiovitez',
      vertical: 'barber',
      displayName: 'Barber Studio Vitez',
    );

    // Tenant se ubacuje kroz override provider-a, ne kao konstruktorski argument:
    // popunjeni slucaj tako i dalje ne zavisi od --dart-define i pokriva se u
    // obicnom `flutter test`.
    testWidgets('prikazuje ime, flavor i vertikalu tenanta', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tenantProvider.overrideWithValue(barber)],
          child: const MaterialApp(home: TenantHome()),
        ),
      );
      expect(
        find.text('Barber Studio Vitez'),
        findsNWidgets(2),
      ); // AppBar + tijelo
      expect(find.text('Hello, ${barber.salonId}'), findsOneWidget);
      expect(find.text('barberstudiovitez · barber'), findsOneWidget);
    });

    // Regresija: `Theme.of` pozvan iznad MaterialApp-a vraca Flutterov default,
    // pa se tekst iscrta tamno na tamnoj tenant temi. V. TenantPreviewApp.build.
    testWidgets('tekst koristi temu koju MaterialApp primjenjuje', (
      tester,
    ) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC6A667),
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tenantProvider.overrideWithValue(barber)],
          child: MaterialApp(theme: theme, home: const TenantHome()),
        ),
      );

      final applied = Theme.of(tester.element(find.byType(Scaffold)));
      for (final finder in <Finder>[
        find.text('barberstudiovitez · barber'),
        find.descendant(
          of: find.byType(Column),
          matching: find.text('Barber Studio Vitez'),
        ),
      ]) {
        final style = tester.widget<Text>(finder).style!;
        final bg = applied.colorScheme.surface;
        final a = style.color!.computeLuminance();
        final b = bg.computeLuminance();
        final ratio =
            (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
        expect(
          ratio,
          greaterThan(4.5),
          reason: 'kontrast ${ratio.toStringAsFixed(2)}:1 je ispod WCAG AA',
        );
      }
    });
  });
}
