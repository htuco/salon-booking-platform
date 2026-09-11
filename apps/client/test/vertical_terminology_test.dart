import 'dart:async';

import 'package:client/main.dart';
import 'package:client/src/core/vertical_provider.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockVerticalRepository extends Mock implements VerticalRepository {}

/// Vertikala kakvu bi backend vratio za `barber` salon.
Vertical _barber({String bookCta = 'Zakaži termin'}) => Vertical.fromJson({
  'key': 'barber',
  'display_name': 'Barber',
  'terminology': {
    'businessSingular': 'Barbershop',
    'staffPlural': 'Naš tim',
    'servicePlural': 'Usluge',
    'appointmentSingular': 'Termin',
    'bookCta': bookCta,
  },
  'default_theme': 'modern_barber',
});

/// Vertikala kakvu bi backend vratio za `beauty` salon — ista polja, drugi tekst.
Vertical get _beauty => Vertical.fromJson({
  'key': 'beauty',
  'display_name': 'Beauty',
  'terminology': {
    'businessSingular': 'Salon',
    'staffPlural': 'Naš tim',
    'servicePlural': 'Usluge',
    'appointmentSingular': 'Termin',
    'bookCta': 'Rezerviši termin',
  },
  'default_theme': 'elegant_beauty',
});

Widget _app(Vertical vertical) => ProviderScope(
  overrides: [
    // Provider se override-uje, ne repozitorij ispod njega: test o terminologiji
    // ne treba ni mrežu ni Supabase inicijalizaciju.
    verticalProvider.overrideWith((ref) async => vertical),
  ],
  child: const TenantPreviewApp(),
);

void main() {
  setUpAll(() => registerFallbackValue(''));

  testWidgets('CTA tekst dolazi iz vertikale, ne iz literala u ekranu', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_barber()));
    await tester.pumpAndSettle();

    expect(find.text('Zakaži termin'), findsOneWidget);
  });

  testWidgets('druga vertikala daje drugi tekst iz istog widgeta', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_beauty));
    await tester.pumpAndSettle();

    // Isti `Text` widget, isti build — samo je config drugi. Da je string bio
    // literal u ekranu, ovo bi tražilo `if` po vertikali.
    expect(find.text('Rezerviši termin'), findsOneWidget);
    expect(find.text('Zakaži termin'), findsNothing);
  });

  testWidgets('promjena terminologije mijenja tekst bez rebuilda aplikacije', (
    tester,
  ) async {
    // Dokaz da je mehanizam zaista runtime, a ne compile-time: ista instanca
    // app-e, isti `ProviderScope`, bez `pumpWidget` ispočetka. Mijenja se samo
    // ono što repozitorij vrati — kao backend čiji se red u `vertical_packs`
    // promijenio dok app radi.
    var served = _barber();
    final repository = _MockVerticalRepository();
    when(() => repository.fetchForSalon(any())).thenAnswer((_) async => served);

    final container = ProviderContainer(
      overrides: [verticalRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TenantPreviewApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zakaži termin'), findsOneWidget);

    served = _barber(bookCta: 'Zakaži pregled');
    container.invalidate(verticalProvider);
    await tester.pumpAndSettle();

    expect(
      find.text('Zakaži pregled'),
      findsOneWidget,
      reason: 'tekst se mijenja iz konfiguracije, bez novog builda app-e',
    );
    expect(find.text('Zakaži termin'), findsNothing);
  });

  testWidgets(
    'dok podaci stižu, ekran pokazuje generic tekst umjesto praznog',
    (tester) async {
      // Provider koji nikad ne završi — simulira spor odgovor backenda.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            verticalProvider.overrideWith(
              (ref) => Completer<Vertical>().future,
            ),
          ],
          child: const TenantPreviewApp(),
        ),
      );
      await tester.pump();

      expect(find.text(VerticalTerms.fallback.bookCta), findsOneWidget);
    },
  );

  group('VerticalRepository', () {
    testWidgets('greška iz repozitorija ne ruši ekran', (tester) async {
      final repository = _MockVerticalRepository();
      when(() => repository.fetchForSalon(any()))
          .thenThrow(Exception('nema mreže'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [verticalRepositoryProvider.overrideWithValue(repository)],
          child: const TenantPreviewApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Fallback terminologija, ne crveni ekran greške.
      expect(find.text(VerticalTerms.fallback.bookCta), findsOneWidget);
    });
  });
}
