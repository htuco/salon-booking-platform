import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/features/booking/booking_flow_provider.dart';
import 'package:client/src/features/booking/booking_identity.dart';
import 'package:client/src/features/booking/booking_submit_provider.dart';
import 'package:client/src/features/booking/details_step_screen.dart';
import 'package:client/src/features/booking/employee_step_screen.dart';
import 'package:client/src/features/booking/service_step_screen.dart';
import 'package:client/src/features/booking/slot_step_screen.dart';
import 'package:client/src/features/auth/login_screen.dart';
import 'package:client/src/features/waitlist/waitlist_day_panel.dart';
import 'package:client/src/features/waitlist/waitlist_providers.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mocktail/mocktail.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_client_profile_repository.dart';

/// Booking flow kroz sva četiri koraka.
///
/// Nigdje `pumpAndSettle` na ekranima koji imaju skeleton: puls se ponavlja dok je
/// vidljiv, pa bi test istekao i kad je ekran ispravan (naučeno u tasku 10). Na ekranima
/// bez skeletona se koristi, jer tamo čeka stvarni prelaz.
///
/// **Repozitorij je mock, ali je to jedini mock.** Provideri, router i ekrani su pravi —
/// ono što se ovdje dokazuje je ponašanje flowa, ne to da mock vraća ono što mu se kaže.
void main() {
  setUpAll(() {
    registerFallbackValue(const LocalDate(2026, 1, 1));
    registerFallbackValue(const LocalTime(0, 0));
  });

  group('prelaz kroz korake', () {
    testWidgets('usluga → radnik → termin → sažetak, izbor se pamti', (
      tester,
    ) async {
      final repo = _MockBooking()..stubUspjesan();
      await _pumpFlow(tester, repo: repo, ruta: ClientRoute.bookService.path);

      expect(find.byType(ServiceStepScreen), findsOneWidget);

      // Tap oznaci red, ali **ne vodi dalje** — korak zakljucuje CTA na dnu
      // (`SPEC.md`, Interactions). Automatski prelaz bi znacio da poredjenje dvije
      // usluge trazi dva prolaza kroz flow.
      await tester.tap(find.text('Šišanje'));
      await tester.pump();
      expect(find.byType(ServiceStepScreen), findsOneWidget);

      await tester.tap(find.text('Dalje'));
      await tester.pumpAndSettle();

      expect(find.byType(EmployeeStepScreen), findsOneWidget);
      // "Bilo ko od nas" stoji prvi jer `requireStaffChoice` nije uključen.
      expect(find.text('Bilo ko od nas'), findsOneWidget);
      await tester.tap(find.text('Amar'));
      await tester.pump();
      await tester.tap(find.text('Dalje'));
      await tester.pumpAndSettle();

      expect(find.byType(SlotStepScreen), findsOneWidget);
      await tester.tap(find.text('14'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('09:00'));
      await tester.pump();

      await tester.tap(find.text('Dalje'));
      await tester.pumpAndSettle();

      expect(find.byType(DetailsStepScreen), findsOneWidget);
      // Kartica "Cuvamo vam" nosi ono sto je izabrano u prethodna tri koraka —
      // povratak nazad i naprijed ne smije izgubiti izbor.
      expect(find.text('Čuvamo vam'), findsOneWidget);
      expect(find.textContaining('Šišanje'), findsWidgets);
      expect(find.textContaining('Amar'), findsWidgets);
      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('CTA trećeg koraka je onemogućen dok termin nije izabran', (
      tester,
    ) async {
      final repo = _MockBooking()..stubUspjesan();
      final container = await _pumpFlow(
        tester,
        repo: repo,
        ruta: ClientRoute.bookSlot.path,
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee(),
      );

      // Labela govori šta fali, ne samo da je dugme sivo (`SPEC.md`, Interactions).
      final dugme = tester.widget<AppButton>(find.byType(AppButton));
      expect(dugme.onPressed, isNull);
      expect(dugme.label, 'Izaberite vrijeme');

      container.dispose();
    });
  });

  // Bug sa uređaja: swipe sa lijeve ivice „radi djelimično". Flow je išao kroz `go`, pa je
  // svaki korak bio sam na stacku — swipe nije imao šta vratiti, a dugme „Nazad" je
  // ponovo gradilo prethodni korak. Sada se ide sa `push`.
  group('povratak nazad', () {
    testWidgets(
      'iOS swipe sa lijeve ivice vraća na prethodni korak, izbor ostaje',
      (tester) async {
        final repo = _MockBooking()..stubUspjesan();
        await _pumpFlow(tester, repo: repo, ruta: ClientRoute.bookService.path);

        await tester.tap(find.text('Šišanje'));
        await tester.pump();
        await tester.tap(find.text('Dalje'));
        await tester.pumpAndSettle();
        expect(find.byType(EmployeeStepScreen), findsOneWidget);

        await tester.dragFrom(const Offset(5, 600), const Offset(800, 0));
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeStepScreen), findsNothing);
        expect(find.byType(ServiceStepScreen), findsOneWidget);
        // Izbor je preživio povratak: CTA je odmah aktivan i vodi dalje.
        await tester.tap(find.text('Dalje'));
        await tester.pumpAndSettle();
        expect(find.byType(EmployeeStepScreen), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('dugme „Nazad" skida korak, ne gradi prethodni ponovo', (
      tester,
    ) async {
      final repo = _MockBooking()..stubUspjesan();
      final container = await _pumpFlow(
        tester,
        repo: repo,
        ruta: ClientRoute.bookService.path,
      );

      await tester.tap(find.text('Šišanje'));
      await tester.pump();
      await tester.tap(find.text('Dalje'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amar'));
      await tester.pump();
      await tester.tap(find.text('Dalje'));
      await tester.pumpAndSettle();
      expect(find.byType(SlotStepScreen), findsOneWidget);

      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeStepScreen), findsOneWidget);
      // Korak 1 je i dalje ispod — stack je stvaran, ne izgrađen iz URL-a.
      expect(container.read(appRouterProvider).canPop(), isTrue);

      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceStepScreen), findsOneWidget);
    });

    testWidgets('korak otvoren direktnim linkom i dalje ima „Nazad"', (
      tester,
    ) async {
      final repo = _MockBooking()..stubUspjesan();
      await _pumpFlow(
        tester,
        repo: repo,
        ruta: ClientRoute.bookEmployee.path,
        pocetniFlow: (n) => n.chooseService(_usluga.id),
      );
      expect(find.byType(EmployeeStepScreen), findsOneWidget);

      // Ispod nema ničega, pa dugme ide na korak 1 kroz `go`.
      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceStepScreen), findsOneWidget);
    });
  });

  group('guard', () {
    testWidgets(
      '/book/details bez prethodnih koraka nudi izlaz, ne prazan ekran',
      (tester) async {
        final repo = _MockBooking()..stubUspjesan();
        await _pumpFlow(tester, repo: repo, ruta: ClientRoute.bookDetails.path);

        expect(
          find.text('Nedostaje izbor iz prethodnog koraka.'),
          findsOneWidget,
        );
        expect(find.text('Krenite ispočetka'), findsOneWidget);
      },
    );
  });

  group('preselekcija sa home ekrana', () {
    testWidgets('?serviceId= iz URL-a bira uslugu bez drugog tapa', (
      tester,
    ) async {
      // Regresija za zamku iz taska 10: home vodi na `/book/service?serviceId=<id>`.
      // Kad prvi korak ne pročita taj parametar, ekran izgleda ispravno, a korisnik
      // bira istu uslugu dvaput.
      final repo = _MockBooking()..stubUspjesan();
      final container = await _pumpFlow(
        tester,
        repo: repo,
        ruta: '${ClientRoute.bookService.path}?serviceId=${_usluga.id}',
      );

      expect(container.read(bookingFlowProvider).serviceId, _usluga.id);
      container.dispose();
    });
  });

  group('prazan dan', () {
    testWidgets('salon bez usluga: svoja rečenica i put na Početnu (FE-501)', (
      tester,
    ) async {
      final repo = _MockBooking()..stubUspjesan();

      final container = await _pumpFlow(
        tester,
        repo: repo,
        ruta: ClientRoute.bookService.path,
        usluge: const [],
      );

      expect(
        find.text('Salon još nije objavio usluge za rezervaciju.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Nazad na Početnu'));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceStepScreen), findsNothing);

      container.dispose();
    });

    testWidgets(
      'salon bez radnika: svoja rečenica, ne ona sa koraka 1 (FE-501)',
      (tester) async {
        final repo = _MockBooking()..stubUspjesan();

        final container = await _pumpFlow(
          tester,
          repo: repo,
          ruta: ClientRoute.bookEmployee.path,
          radnici: const [],
          traziIzborRadnika: true,
          pocetniFlow: (notifier) => notifier.chooseService(_usluga.id),
        );

        expect(
          find.text('Salon trenutno nema nikoga dostupnog za rezervaciju.'),
          findsOneWidget,
        );
        // Ne ista rečenica kao prazan korak 1 — FE-501 traži rečenicu po ekranu.
        expect(
          find.text('Salon još nije objavio usluge za rezervaciju.'),
          findsNothing,
        );

        await tester.tap(find.text('Nazad na Početnu'));
        await tester.pumpAndSettle();
        expect(find.byType(EmployeeStepScreen), findsNothing);

        container.dispose();
      },
    );

    testWidgets('dan bez slobodnih termina je prazno stanje, ne greška', (
      tester,
    ) async {
      final repo = _MockBooking()
        ..stubUspjesan()
        ..stubSlotovi(const []);

      final container = await _pumpFlow(
        tester,
        repo: repo,
        ruta: ClientRoute.bookSlot.path,
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseDate(_danas),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Ovaj dan je popunjen.'), findsOneWidget);
      expect(find.byType(TimeSlotChip), findsNothing);

      container.dispose();
    });
  });

  group('lista čekanja (task 68)', () {
    testWidgets('pun dan se bira i nudi listu; neprijavljen ide na prijavu', (
      tester,
    ) async {
      final repo = _MockBooking()
        ..stubUspjesan()
        ..stubSlotovi(const []);
      final lista = _MockWaitlist()..stubPunDan();

      final container = await _pumpFlow(
        tester,
        repo: repo,
        listaCekanja: lista,
        ruta: ClientRoute.bookSlot.path,
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseDate(_danas),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(WaitlistDayPanel), findsOneWidget);
      expect(
        find.text(
          'Ovaj dan je popunjen. Ako se mjesto oslobodi, možemo vam javiti.',
        ),
        findsOneWidget,
      );
      // Neradni-dan rečenica ne stoji uz pun dan.
      expect(find.text('Ovaj dan je popunjen.'), findsNothing);

      await tester.tap(find.text('Obavijesti me kad se oslobodi'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      verifyNever(
        () => lista.join(
          serviceId: any(named: 'serviceId'),
          date: any(named: 'date'),
          employeeId: any(named: 'employeeId'),
        ),
      );

      container.dispose();
    });

    testWidgets('prijavljen se upisuje za uslugu, dan i „Bilo ko"', (
      tester,
    ) async {
      final repo = _MockBooking()
        ..stubUspjesan()
        ..stubSlotovi(const []);
      final lista = _MockWaitlist()..stubPunDan();
      var upisan = false;
      when(lista.mine).thenAnswer(
        (_) async => upisan
            ? [
                WaitlistEntry(
                  id: 'w1',
                  serviceId: _usluga.id,
                  serviceName: _usluga.name,
                  date: _danas,
                ),
              ]
            : const [],
      );
      when(
        () => lista.join(
          serviceId: any(named: 'serviceId'),
          date: any(named: 'date'),
          employeeId: any(named: 'employeeId'),
        ),
      ).thenAnswer((_) async {
        upisan = true;
        return 'w1';
      });

      final container = await _pumpFlow(
        tester,
        repo: repo,
        listaCekanja: lista,
        customerId: _customerId,
        ruta: ClientRoute.bookSlot.path,
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseDate(_danas),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Obavijesti me kad se oslobodi'));
      await tester.pump();
      await tester.pump();

      verify(
        () => lista.join(serviceId: _usluga.id, date: _danas, employeeId: null),
      ).called(1);
      expect(find.textContaining('Na listi čekanja ste.'), findsOneWidget);
      expect(find.text('Odjavi se sa liste'), findsOneWidget);

      container.dispose();
    });

    testWidgets('bez dozvole za obavijesti panel ne obećava javljanje', (
      tester,
    ) async {
      final repo = _MockBooking()
        ..stubUspjesan()
        ..stubSlotovi(const []);
      final lista = _MockWaitlist()..stubPunDan();
      when(lista.mine).thenAnswer(
        (_) async => [
          WaitlistEntry(
            id: 'w1',
            serviceId: _usluga.id,
            serviceName: _usluga.name,
            date: _danas,
          ),
        ],
      );

      final container = await _pumpFlow(
        tester,
        repo: repo,
        listaCekanja: lista,
        customerId: _customerId,
        obavijestiDozvoljene: false,
        ruta: ClientRoute.bookSlot.path,
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseDate(_danas),
      );
      await tester.pump();
      await tester.pump();

      // Ponuda ide samo uređaju sa push tokenom (ADR-0031): „Javićemo vam" bi bilo netačno.
      expect(
        find.textContaining('obavijesti za ovu aplikaciju su isključene'),
        findsOneWidget,
      );
      expect(find.textContaining('Javićemo vam'), findsNothing);
      expect(find.text('Odjavi se sa liste'), findsOneWidget);

      container.dispose();
    });

    testWidgets('neuspjela odjava na punom danu ima svoju poruku', (
      tester,
    ) async {
      final repo = _MockBooking()
        ..stubUspjesan()
        ..stubSlotovi(const []);
      final lista = _MockWaitlist()..stubPunDan();
      when(lista.mine).thenAnswer(
        (_) async => [
          WaitlistEntry(
            id: 'w1',
            serviceId: _usluga.id,
            serviceName: _usluga.name,
            date: _danas,
          ),
        ],
      );
      when(() => lista.leave('w1')).thenThrow(const ServerError('pad'));

      final container = await _pumpFlow(
        tester,
        repo: repo,
        listaCekanja: lista,
        customerId: _customerId,
        ruta: ClientRoute.bookSlot.path,
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseDate(_danas),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Odjavi se sa liste'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Odjava sa liste čekanja nije uspjela. Pokušajte ponovo.'),
        findsOneWidget,
      );
      expect(
        find.text('Upis na listu čekanja nije uspio. Pokušajte ponovo.'),
        findsNothing,
      );

      container.dispose();
    });

    testWidgets('poslije zakazivanja sa upisa kartica upisa nestaje', (
      tester,
    ) async {
      // Auto režim: termin nastaje potvrđen, pa baza briše upis iste usluge tog dana.
      // Mock to glumi tako što drugo čitanje `my_waitlist` vraća praznu listu.
      final repo = _MockBooking()
        ..stubUspjesan(status: AppointmentStatus.confirmed);
      final lista = _MockWaitlist()..stubPunDan(puni: {});
      var citanja = 0;
      when(lista.mine).thenAnswer((_) async {
        citanja++;
        return citanja == 1
            ? [
                WaitlistEntry(
                  id: 'w1',
                  serviceId: _usluga.id,
                  serviceName: _usluga.name,
                  date: _danas,
                ),
              ]
            : const [];
      });

      final container = await _pumpFlow(
        tester,
        repo: repo,
        listaCekanja: lista,
        customerId: _customerId,
        ruta: ClientRoute.bookDetails.path,
        dodatno: [myAppointmentsProvider.overrideWith((ref) async => const [])],
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
      );
      // Korisnik je upis vidio u „Moji termini" prije nego što je tapnuo „Zakaži":
      // `myWaitlistProvider` ga drži u kešu.
      expect(await container.read(myWaitlistProvider.future), hasLength(1));

      await tester.pump();
      await tester.tap(find.text('Pošalji zahtjev'));
      await tester.pump();
      await tester.pump();
      expect(container.read(lastBookingProvider), isNotNull);

      container.read(appRouterProvider).go(ClientRoute.appointments.path);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(citanja, 2);
      expect(find.text('Lista čekanja'), findsNothing);

      // Snackbar potvrde i prelaz rute imaju svoje tajmere; test ih pušta da isteknu.
      await tester.pump(const Duration(seconds: 5));
      container.dispose();
    });

    testWidgets('prazan dan koji nije pun ostaje stara rečenica, bez dugmeta', (
      tester,
    ) async {
      final repo = _MockBooking()
        ..stubUspjesan()
        ..stubSlotovi(const []);
      final lista = _MockWaitlist()..stubPunDan(puni: {});

      final container = await _pumpFlow(
        tester,
        repo: repo,
        listaCekanja: lista,
        ruta: ClientRoute.bookSlot.path,
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseDate(_danas),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Ovaj dan je popunjen.'), findsOneWidget);
      expect(find.text('Obavijesti me kad se oslobodi'), findsNothing);

      container.dispose();
    });
  });

  group('date_only vertikala', () {
    testWidgets('klijent bira samo dan — mreže vremena nema', (tester) async {
      // `docs/05 §4.1`: ordinacija ne nudi tačno vrijeme, salon ga dodjeljuje. Ista
      // app, drugi red u `vertical_packs`.
      final repo = _MockBooking()..stubUspjesan();
      final container = await _pumpFlow(
        tester,
        repo: repo,
        ruta: ClientRoute.bookSlot.path,
        vertical: _verticalDateOnly,
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee(),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Tačno vrijeme vam dodjeljuje salon.'), findsOneWidget);
      expect(find.byType(TimeSlotChip), findsNothing);

      await tester.tap(find.text('14'));
      await tester.pump();

      // Sam datum zaključuje korak — u `exact_slot` modu bi dugme još bilo sivo.
      final dugme = tester.widget<AppButton>(find.byType(AppButton));
      expect(dugme.onPressed, isNotNull);
      expect(dugme.label, 'Dalje');

      // Nijedan poziv za slotovima: u ovom modu vremena se ni ne traže.
      verifyNever(
        () => repo.availableSlots(
          salonId: any(named: 'salonId'),
          serviceId: any(named: 'serviceId'),
          date: any(named: 'date'),
          employeeId: any(named: 'employeeId'),
        ),
      );

      container.dispose();
    });
  });

  group('profil prije slanja (pregled #136)', () {
    void nijePoslano(_MockBooking repo) => verifyNever(
      () => repo.book(
        salonId: any(named: 'salonId'),
        customerId: any(named: 'customerId'),
        serviceId: any(named: 'serviceId'),
        date: any(named: 'date'),
        startTime: any(named: 'startTime'),
        employeeId: any(named: 'employeeId'),
        note: any(named: 'note'),
        deviceId: any(named: 'deviceId'),
      ),
    );

    // Sačuvana sesija bez telefona (Apple/Google) ili sa starom verzijom uslova nikad ne
    // prođe kroz login — provjera na loginu je bila jedina, pa se mogla zaobići.
    for (final (opis, status) in [
      (
        'bez telefona',
        const ClientProfileStatus(
          hasName: true,
          hasPhone: false,
          termsCurrent: true,
        ),
      ),
      (
        'stara verzija uslova',
        const ClientProfileStatus(
          hasName: true,
          hasPhone: true,
          termsCurrent: false,
        ),
      ),
    ]) {
      testWidgets('$opis: „Dopuni profil", termin se ne šalje', (tester) async {
        final repo = _MockBooking()..stubUspjesan();
        final container = await _pumpFlow(
          tester,
          repo: repo,
          ruta: ClientRoute.bookDetails.path,
          customerId: _customerId,
          profil: FakeClientProfileRepository(trenutni: status),
          pocetniFlow: (notifier) => notifier
            ..chooseService(_usluga.id)
            ..chooseAnyEmployee()
            ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
        );

        await tester.pump();
        await tester.tap(find.text('Pošalji zahtjev'));
        await tester.pump();
        await tester.pump();

        nijePoslano(repo);
        expect(
          container.read(appRouterProvider).state.uri.path,
          ClientRoute.completeProfile.path,
        );
        // Izbor flowa ostaje — „Dopuni profil" vraća na korak 4 sa istim terminom.
        expect(
          container.read(bookingFlowProvider).startTime,
          const LocalTime(9, 0),
        );
        container.dispose();
      });
    }

    testWidgets('profil se ne može provjeriti: poruka, termin se ne šalje', (
      tester,
    ) async {
      final repo = _MockBooking()..stubUspjesan();
      final container = await _pumpFlow(
        tester,
        repo: repo,
        ruta: ClientRoute.bookDetails.path,
        customerId: _customerId,
        profil: FakeClientProfileRepository(
          statusGreska: const NetworkError('nema mreže'),
        ),
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
      );

      await tester.pump();
      await tester.tap(find.text('Pošalji zahtjev'));
      await tester.pump();
      await tester.pump();

      nijePoslano(repo);
      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.bookDetails.path,
      );
      container.dispose();
    });
  });

  group('409 — slot je otišao između prikaza i potvrde', () {
    testWidgets('poruka, osvježena lista i povratak na izbor termina', (
      tester,
    ) async {
      final repo = _MockBooking()
        ..stubUspjesan()
        ..stubKonflikt();

      final container = await _pumpFlow(
        tester,
        repo: repo,
        ruta: ClientRoute.bookDetails.path,
        customerId: _customerId,
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
      );

      await tester.pump();
      await tester.tap(find.text('Pošalji zahtjev'));
      await tester.pump();
      await tester.pump();

      // 1. Poruka kaže šta se desilo — ne "nešto je pošlo naopako".
      expect(
        find.text('Ovaj termin je upravo zauzet. Izaberite drugi.'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();

      // 2. Korisnik je na koraku sa terminima, sa zadržanim danom.
      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.bookSlot.path,
      );
      expect(container.read(bookingFlowProvider).date, _danas);
      // 3. Vrijeme je palo, jer ga više nema.
      expect(container.read(bookingFlowProvider).startTime, isNull);

      // 4. Lista je ponovo zatražena od baze, a ne prikazana iz pamćenja — to je
      // razlog zbog kojeg stanje flowa namjerno ne nosi slotove.
      verify(
        () => repo.availableSlots(
          salonId: any(named: 'salonId'),
          serviceId: any(named: 'serviceId'),
          date: any(named: 'date'),
          employeeId: any(named: 'employeeId'),
        ),
      ).called(greaterThanOrEqualTo(2));

      container.dispose();
    });

    testWidgets('pun brojač zahtjeva: poruka, a korisnik ostaje na koraku', (
      tester,
    ) async {
      final repo = _MockBooking()
        ..stubUspjesan()
        ..stubPunBrojac();

      final container = await _pumpFlow(
        tester,
        repo: repo,
        ruta: ClientRoute.bookDetails.path,
        customerId: _customerId,
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
      );

      await tester.pump();
      await tester.tap(find.text('Pošalji zahtjev'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Već imate zahtjeve koji čekaju potvrdu. Sačekajte odgovor salona '
          'ili otkažite jedan od njih.',
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();

      // Termin je slobodan — problem nije izbor, pa se ni ne briše.
      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.bookDetails.path,
      );
      expect(
        container.read(bookingFlowProvider).startTime,
        const LocalTime(9, 0),
      );

      container.dispose();
    });

    testWidgets(
      'uspjeh salje registrovani devices.id i vodi na success ekran',
      (tester) async {
        final repo = _MockBooking()..stubUspjesan();

        final container = await _pumpFlow(
          tester,
          repo: repo,
          ruta: ClientRoute.bookDetails.path,
          customerId: _customerId,
          deviceId: 'registered-device-id',
          pocetniFlow: (notifier) => notifier
            ..chooseService(_usluga.id)
            ..chooseAnyEmployee()
            ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
        );

        await tester.pump();
        await tester.tap(find.text('Pošalji zahtjev'));
        await tester.pump();
        await tester.pump();

        expect(
          container.read(appRouterProvider).state.uri.path,
          ClientRoute.bookSuccess.path,
        );
        expect(find.text('ZAHTJEV JE POSLAN'), findsOneWidget);
        verify(
          () => repo.book(
            salonId: any(named: 'salonId'),
            customerId: any(named: 'customerId'),
            serviceId: any(named: 'serviceId'),
            date: any(named: 'date'),
            startTime: any(named: 'startTime'),
            employeeId: any(named: 'employeeId'),
            note: any(named: 'note'),
            deviceId: 'registered-device-id',
          ),
        ).called(1);
        expect(find.text('Salon vas je vidio'), findsOneWidget);
        // Salon u `manual` modu: baza je vratila `pending`, pa ekran ne smije reći više
        // od toga. Lažno "potvrđeno" znači da korisnik dođe u salon koji ga ne očekuje.
        expect(find.text('Na čekanju'), findsOneWidget);
        await tester.pump(AppDuration.slow);

        container.dispose();
      },
    );

    testWidgets('potvrdjen termin ne pise da ceka potvrdu', (tester) async {
      // Salon u `auto` modu (`salon_settings.booking_mode`): `book_appointment` vraca
      // red koji je **vec** `confirmed`. Ekran tu postavku ne vidi niti je smije gledati
      // — grana iskljucivo po statusu reda koji je stvarno nastao.
      final repo = _MockBooking()
        ..stubUspjesan(status: AppointmentStatus.confirmed);

      final container = await _pumpFlow(
        tester,
        repo: repo,
        ruta: ClientRoute.bookDetails.path,
        customerId: _customerId,
        deviceId: 'registered-device-id',
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
      );

      await tester.pump();
      await tester.tap(find.text('Pošalji zahtjev'));
      await tester.pump();
      await tester.pump();

      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.bookSuccess.path,
      );

      // Ovo su tri odvojene tvrdnje jer su do taska 37 sve tri bile hardkodirane: ko
      // popravi samo badge, ostavi korisniku naslov koji i dalje kaze da salon tek treba
      // da pogleda zahtjev.
      expect(find.text('TERMIN JE POTVRĐEN'), findsOneWidget);
      expect(find.text('Termin je vaš'), findsOneWidget);
      expect(find.text('Potvrđeno'), findsOneWidget);

      // Negativan dio: stari tekst ne smije ostati nigdje na ekranu.
      expect(find.text('ZAHTJEV JE POSLAN'), findsNothing);
      expect(find.text('Na čekanju'), findsNothing);
      await tester.pump(AppDuration.slow);

      container.dispose();
    });

    testWidgets('back sa success ekrana vodi na Početnu i čisti flow', (
      tester,
    ) async {
      // Flow ide kroz `context.go`, pa ispod success ekrana nema rute. Bez `PopScope`
      // sistemski back na Androidu zatvara aplikaciju umjesto da vodi na Početnu.
      final repo = _MockBooking()..stubUspjesan();

      final container = await _pumpFlow(
        tester,
        repo: repo,
        ruta: ClientRoute.bookDetails.path,
        customerId: _customerId,
        deviceId: 'registered-device-id',
        pocetniFlow: (notifier) => notifier
          ..chooseService(_usluga.id)
          ..chooseAnyEmployee()
          ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
      );

      await tester.pump();
      await tester.tap(find.text('Pošalji zahtjev'));
      await tester.pump();
      await tester.pump();
      expect(container.read(lastBookingProvider), isNotNull);

      final obradjeno = await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(AppDuration.slow);

      expect(obradjeno, isTrue, reason: 'back ne smije izaći iz aplikacije');
      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.home.path,
      );
      // Zapamćeni termin se čisti na izlasku — sljedeći booking ne smije zateći stari.
      expect(container.read(lastBookingProvider), isNull);

      container.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Podaci i podizanje app-e
// ---------------------------------------------------------------------------

const _salonId = '550e8400-e29b-41d4-a716-446655440000';
const _customerId = '30000000-0000-4000-8000-000000000001';
const _danas = LocalDate(2026, 9, 14);

const _env = AppEnv(
  salonId: _salonId,
  supabaseUrl: '',
  supabaseAnonKey: '',
  apiUrl: '',
);

const _salon = Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  city: 'Vitez',
);

const _usluga = Service(
  id: '10000000-0000-4000-8000-000000000001',
  salonId: _salonId,
  name: 'Šišanje',
  price: 15,
  durationMinutes: 30,
);

const _radnik = Employee(
  id: '20000000-0000-4000-8000-000000000001',
  salonId: _salonId,
  name: 'Amar',
  role: 'Barber',
);

final _termin = Appointment(
  id: '40000000-0000-4000-8000-000000000001',
  salonId: _salonId,
  serviceId: _usluga.id,
  customerId: _customerId,
  customerName: 'Test',
  date: _danas,
  startTime: const LocalTime(9, 0),
  endTime: const LocalTime(9, 30),
  status: AppointmentStatus.pending,
);

/// Ista vertikala kao `fallback`, ali sa `date_only` granularnošću.
const _verticalDateOnly = Vertical(
  key: 'health',
  displayName: 'Ordinacija',
  terms: VerticalTerms.fallback,
  rules: BookingRules(
    mode: BookingMode.manual,
    granularity: BookingGranularity.dateOnly,
    slotStepMinutes: 30,
    bufferMinutes: 10,
    minAdvanceBookingHours: 4,
    maxAdvanceBookingDays: 30,
    minCancelHours: 6,
    pendingExpiryHours: 24,
    requireStaffChoice: false,
    showPricesInApp: true,
  ),
  features: VerticalFeatures.fallback,
  defaultTheme: 'clinical_calm',
);

class _MockWaitlist extends Mock implements WaitlistRepository {
  /// [puni] je ono što vrati `waitlist_full_dates`; podrazumijevano je današnji dan pun.
  void stubPunDan({Set<LocalDate>? puni}) {
    when(
      () => fullDates(
        salonId: any(named: 'salonId'),
        serviceId: any(named: 'serviceId'),
        from: any(named: 'from'),
        to: any(named: 'to'),
        employeeId: any(named: 'employeeId'),
      ),
    ).thenAnswer((_) async => puni ?? {_danas});
    when(mine).thenAnswer((_) async => const []);
  }
}

class _MockBooking extends Mock implements BookingRepository {
  /// [status] je ono sto **baza** vrati, ne postavka: od taska 37 `book_appointment` u
  /// `auto` modu pravi red koji je vec `confirmed`. Klijent postavku ne vidi, pa se ni
  /// test ne smije praviti da je vidi.
  void stubUspjesan({AppointmentStatus status = AppointmentStatus.pending}) {
    stubSlotovi([
      AvailableSlot(startTime: const LocalTime(9, 0), employeeId: _radnik.id),
      AvailableSlot(startTime: const LocalTime(9, 30), employeeId: _radnik.id),
    ]);

    when(
      () => availableDates(
        salonId: any(named: 'salonId'),
        serviceId: any(named: 'serviceId'),
        from: any(named: 'from'),
        to: any(named: 'to'),
        employeeId: any(named: 'employeeId'),
      ),
    ).thenAnswer((_) async => const [_danas]);

    when(
      () => book(
        salonId: any(named: 'salonId'),
        customerId: any(named: 'customerId'),
        serviceId: any(named: 'serviceId'),
        date: any(named: 'date'),
        startTime: any(named: 'startTime'),
        employeeId: any(named: 'employeeId'),
        note: any(named: 'note'),
        deviceId: any(named: 'deviceId'),
      ),
    ).thenAnswer((_) async => _termin.copyWith(status: status));
  }

  void stubSlotovi(List<AvailableSlot> slotovi) {
    when(
      () => availableSlots(
        salonId: any(named: 'salonId'),
        serviceId: any(named: 'serviceId'),
        date: any(named: 'date'),
        employeeId: any(named: 'employeeId'),
      ),
    ).thenAnswer((_) async => slotovi);
  }

  /// `book_appointment` diže `PT409` kad je slot u međuvremenu otišao; `core_api` to
  /// mapira u `ConflictError`, a ovaj test gleda šta ekran s tim uradi.
  void stubKonflikt() {
    when(
      () => book(
        salonId: any(named: 'salonId'),
        customerId: any(named: 'customerId'),
        serviceId: any(named: 'serviceId'),
        date: any(named: 'date'),
        startTime: any(named: 'startTime'),
        employeeId: any(named: 'employeeId'),
        note: any(named: 'note'),
        deviceId: any(named: 'deviceId'),
      ),
    ).thenThrow(const ConflictError('slot je zauzet'));
  }

  /// Task 65: `book_appointment` diže `PT429` kad klijent već ima pun brojač otvorenih
  /// zahtjeva; `core_api` to mapira u `RateLimitError`.
  void stubPunBrojac() {
    when(
      () => book(
        salonId: any(named: 'salonId'),
        customerId: any(named: 'customerId'),
        serviceId: any(named: 'serviceId'),
        date: any(named: 'date'),
        startTime: any(named: 'startTime'),
        employeeId: any(named: 'employeeId'),
        note: any(named: 'note'),
        deviceId: any(named: 'deviceId'),
      ),
    ).thenThrow(const RateLimitError('Već imate zahtjeve koji čekaju potvrdu'));
  }
}

/// Podiže pravu app-u na zadanoj ruti, sa mock repozitorijem ispod.
Future<ProviderContainer> _pumpFlow(
  WidgetTester tester, {
  required _MockBooking repo,
  required String ruta,
  Vertical vertical = Vertical.fallback,
  String? customerId,
  String? deviceId,
  AuthSession? sesija,
  List<Service> usluge = const [_usluga],
  List<Employee> radnici = const [_radnik],
  bool? traziIzborRadnika,
  FakeClientProfileRepository? profil,
  WaitlistRepository? listaCekanja,
  bool obavijestiDozvoljene = true,
  List<Override> dodatno = const [],
  void Function(BookingFlowNotifier notifier)? pocetniFlow,
}) async {
  tester.binding.platformDispatcher.defaultRouteNameTestValue = ruta;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

  // Visok viewport: korak sa terminima je kalendar **plus** dvije grupe slotova, sto je
  // duze od podrazumijevanih 600x800. `ListView` gradi lijeno, pa bi sadrzaj ispod ruba
  // bio "nije pronadjen" — greska u testu koja izgleda kao greska u ekranu.
  tester.view
    ..physicalSize = const Size(1200, 3000)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(_env),
      currentSalonIdProvider.overrideWithValue(_salonId),
      salonProvider.overrideWith((ref) async => _salon),
      servicesProvider.overrideWith((ref) async => usluge),
      if (traziIzborRadnika != null)
        bookingRequiresStaffChoiceProvider.overrideWithValue(traziIzborRadnika),
      employeesProvider.overrideWith((ref) async => radnici),
      employeeServiceLinksProvider.overrideWith(
        (ref) async => const <EmployeeService>[],
      ),
      workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
      verticalProvider.overrideWith((ref) async => vertical),
      bookingRepositoryProvider.overrideWithValue(repo),
      if (listaCekanja != null)
        waitlistRepositoryProvider.overrideWithValue(listaCekanja),
      // U testu push ne postoji (`PUSH_ENABLED`), pa bi panel liste čekanja uvijek rekao
      // da su obavijesti isključene. Podrazumijevano je telefon sa dozvolom.
      pushPermissionProvider.overrideWith((ref) async => obavijestiDozvoljene),
      ...dodatno,
      // Korak 4 provjerava profil prije slanja (pregled #136); podrazumijevano je kompletan.
      clientProfileRepositoryProvider.overrideWithValue(
        profil ?? FakeClientProfileRepository(),
      ),
      bookingTodayProvider.overrideWithValue(_danas),
      bookingCustomerIdProvider.overrideWith((ref) async => customerId),
      bookingDeviceIdProvider.overrideWithValue(() async => deviceId),
      // Prijava odlučuje koji CTA zadnji korak prikazuje (task 13), a `customerId` samo
      // da li slanje može proći. Test koji zada `customerId` zadaje i sesiju — bez nje
      // bi „prijavljen korisnik bez klijenta" bio jedino stanje koje se može testirati.
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          pocetnaSesija:
              sesija ??
              (customerId == null
                  ? null
                  : FakeAuthRepository.sesijaNakonPrijave),
        ),
      ),
    ],
  );

  // Pretplata prije prvog `read`-a. `bookingFlowProvider` je `autoDispose`, pa provider
  // bez ijednog slušaoca zakaže brisanje **tajmerom** — a test koji se završi prije nego
  // taj tajmer opali pada na "A Timer is still pending", i to na asercijama koje prolaze.
  final pretplata = container.listen(bookingFlowProvider, (_, _) {});
  addTearDown(pretplata.close);

  // Izbori prethodnih koraka se postavljaju kroz notifier, ne kroz tapove: test koji
  // gađa treći korak ne treba ponovo dokazivati prva dva.
  if (pocetniFlow != null) {
    pocetniFlow(container.read(bookingFlowProvider.notifier));
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SalonClientApp(),
    ),
  );
  await tester.pump();
  await tester.pump();

  return container;
}
