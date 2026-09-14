import 'package:admin/src/features/appointments/appointment_actions_bar.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Akcije nad terminom — task 24.
///
/// Testira se **koje se akcije nude**, ne šta baza radi. Da admin salona A ne može dirati
/// termin salona B i da otkazan termin ne može nazad u `confirmed` dokazuje
/// `supabase/tests/008_admin_akcije.test.sql`; ovdje se dokazuje da vlasnik ne dobije dugme
/// koje vodi u grešku koja se mogla izbjeći.
const _salonId = '550e8400-e29b-41d4-a716-446655440000';

Appointment _termin(AppointmentStatus status) => Appointment(
  id: 'a1',
  salonId: _salonId,
  serviceId: 's1',
  customerId: 'c1',
  customerName: 'Amina',
  date: LocalDate(2026, 9, 14),
  startTime: const LocalTime(10, 0),
  endTime: const LocalTime(10, 40),
  status: status,
);

Widget _traka(AppointmentStatus status) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(body: AppointmentActionsBar(termin: _termin(status))),
  ),
);

void main() {
  group('koje akcije stoje uz koji status', () {
    testWidgets('zahtjev na čekanju nudi potvrdu i odbijanje', (tester) async {
      await tester.pumpWidget(_traka(AppointmentStatus.pending));

      expect(find.text('Potvrdi'), findsOneWidget);
      expect(find.text('Odbij'), findsOneWidget);
      // Termin koji čeka nema šta da se „završi" prije nego je potvrđen.
      expect(find.text('Završen'), findsNothing);
      expect(find.text('Nije došao'), findsNothing);
    });

    testWidgets('potvrđen termin nudi završetak, nedolazak i otkazivanje', (
      tester,
    ) async {
      await tester.pumpWidget(_traka(AppointmentStatus.confirmed));

      expect(find.text('Završen'), findsOneWidget);
      expect(find.text('Nije došao'), findsOneWidget);
      expect(find.text('Otkaži'), findsOneWidget);
      // Dvaput potvrditi nema smisla; baza bi to primila idempotentno, ali dugme koje ne
      // radi ništa je gore od dugmeta kojeg nema.
      expect(find.text('Potvrdi'), findsNothing);
    });

    // **Zatvoren termin nema nijednu akciju.** „Potvrdi" nad otkazanim terminom baza odbija
    // sa `PT409` — slot je u međuvremenu mogao biti prodat, a `appointments_no_overlap`
    // pokriva samo `pending`/`confirmed`, pa bi potvrda otkazanog mogla napraviti
    // preklapanje koje constraint nikad nije vidio.
    for (final status in [
      AppointmentStatus.cancelled,
      AppointmentStatus.completed,
      AppointmentStatus.noShow,
    ]) {
      testWidgets('$status nema nijednu akciju', (tester) async {
        await tester.pumpWidget(_traka(status));

        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      });
    }

    testWidgets('nepoznat status ne ruši ekran i ne nudi akcije', (
      tester,
    ) async {
      // App u storeu je uvijek starija od baze: `alter type ... add value` niko ne prati po
      // verzijama storea. Novi status ne smije ni pasti ni ponuditi pogrešnu akciju.
      await tester.pumpWidget(_traka(AppointmentStatus.unknown));

      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('destruktivne akcije traže potvrdu', () {
    testWidgets('odbijanje otvara dijalog sa poljem za razlog', (tester) async {
      await tester.pumpWidget(_traka(AppointmentStatus.pending));

      await tester.tap(find.text('Odbij'));
      await tester.pumpAndSettle();

      expect(find.text('Odbij zahtjev'), findsOneWidget);
      // Razlog **nije obavezan**: salon koji odbija zbog bolesti radnika u tri ujutro nema
      // šta objašnjavati, a prisilno polje bi ga natjeralo da upiše tačku.
      expect(find.text('Razlog (nije obavezno)'), findsOneWidget);
      // Ime klijenta stoji u dijalogu — vlasnik mora vidjeti koga odbija prije nego potvrdi.
      expect(find.textContaining('Amina'), findsOneWidget);
    });

    testWidgets('odustajanje ne izvršava akciju', (tester) async {
      await tester.pumpWidget(_traka(AppointmentStatus.pending));

      await tester.tap(find.text('Odbij'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      // Traka je i dalje tu sa istim akcijama: ništa se nije desilo.
      expect(find.text('Potvrdi'), findsOneWidget);
      expect(find.text('Odbij zahtjev'), findsNothing);
    });

    testWidgets('nedolazak traži potvrdu prije bilježenja', (tester) async {
      await tester.pumpWidget(_traka(AppointmentStatus.confirmed));

      await tester.tap(find.text('Nije došao'));
      await tester.pumpAndSettle();

      expect(find.text('Klijent se nije pojavio?'), findsOneWidget);
    });

    testWidgets('potvrda ne traži dijalog — nije destruktivna', (tester) async {
      // Potvrda je radnja koju vlasnik radi desetak puta dnevno i ne uništava ništa.
      // Dijalog na njoj bi bio trenje bez svrhe.
      await tester.pumpWidget(_traka(AppointmentStatus.pending));

      await tester.tap(find.text('Potvrdi'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('pristupačnost', () {
    testWidgets('svaka akcija ima tekst, ne samo ikonu', (tester) async {
      // „✓" i „✕" jedno pored drugog se razlikuju samo oblikom, a odbijanje termina nije
      // radnja koja smije zavisiti od toga je li vlasnik dobro pogledao (WCAG 1.4.1 — boja
      // i oblik nisu jedini nosioci informacije).
      await tester.pumpWidget(_traka(AppointmentStatus.pending));

      for (final labela in ['Potvrdi', 'Odbij']) {
        expect(find.text(labela), findsOneWidget);
      }
    });
  });
}
