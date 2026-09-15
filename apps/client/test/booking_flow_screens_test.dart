import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/features/booking/booking_flow_provider.dart';
import 'package:client/src/features/booking/booking_identity.dart';
import 'package:client/src/features/booking/details_step_screen.dart';
import 'package:client/src/features/booking/employee_step_screen.dart';
import 'package:client/src/features/booking/service_step_screen.dart';
import 'package:client/src/features/booking/slot_step_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mocktail/mocktail.dart';

import 'support/fake_auth_repository.dart';

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
        // `docs/01 §18`: termin nastaje kao `pending`. Lažno "potvrđeno" bi značilo da
        // korisnik dođe u salon koji ga ne očekuje.
        expect(find.text('Na čekanju'), findsOneWidget);
        await tester.pump(AppDuration.slow);

        container.dispose();
      },
    );
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
    allowGuestBooking: false,
  ),
  features: VerticalFeatures.fallback,
  defaultTheme: 'clinical_calm',
);

class _MockBooking extends Mock implements BookingRepository {
  void stubUspjesan() {
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
    ).thenAnswer((_) async => _termin);
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
      servicesProvider.overrideWith((ref) async => const [_usluga]),
      employeesProvider.overrideWith((ref) async => const [_radnik]),
      employeeServiceLinksProvider.overrideWith(
        (ref) async => const <EmployeeService>[],
      ),
      workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
      verticalProvider.overrideWith((ref) async => vertical),
      bookingRepositoryProvider.overrideWithValue(repo),
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
