import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/features/appointments/appointments_provider.dart';
import 'package:client/src/features/appointments/appointments_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'support/fake_auth_repository.dart';

/// „Moji termini" i otkazivanje — task 16.
///
/// **Rok i autorizacija se ovdje ne dokazuju.** Oni su svojstva `cancel_appointment` i
/// dokazani su u `supabase/tests/004_cancel_appointment.test.sql`. Ovdje se mjeri šta
/// ekran radi: šta ide u koji tab, da li modal stvarno traži potvrdu, i šta se vidi kad
/// baza odbije.
void main() {
  group('razvrstavanje', () {
    test('zatvoren termin ide u prošle bez obzira na datum', () {
      // Otkazan termin za sljedeću sedmicu nije „predstojeći" — korisnik na njega ne
      // dolazi, a kartica sa dugmetom „otkaži" iznad otkazanog termina je besmislena.
      final podjela = splitAppointments([
        _termin(dan: 20, status: AppointmentStatus.cancelled),
        _termin(dan: 20, status: AppointmentStatus.pending),
        _termin(dan: 5, status: AppointmentStatus.completed),
      ], now: _sada);

      expect(podjela.upcoming, hasLength(1));
      expect(podjela.upcoming.single.status, AppointmentStatus.pending);
      expect(podjela.past, hasLength(2));
    });

    test('predstojeći su sortirani najbliži prvi, prošli obrnuto', () {
      // Repozitorij vraća silazno — tačno za „prošle", obrnuto za „predstojeće".
      final podjela = splitAppointments([
        _termin(dan: 22),
        _termin(dan: 18),
        _termin(dan: 20),
      ], now: _sada);

      expect(podjela.upcoming.map((a) => a.date.day), [18, 20, 22]);
    });

    test('termin koji je danas već počeo je prošao', () {
      final podjela = splitAppointments([
        _termin(dan: 15, sat: 9),
        _termin(dan: 15, sat: 18),
      ], now: DateTime(2026, 9, 15, 12));

      expect(podjela.past.single.startTime.hour, 9);
      expect(podjela.upcoming.single.startTime.hour, 18);
    });
  });

  group('canCancel', () {
    test('unutar roka da, izvan roka ne', () {
      final termin = _termin(dan: 16, sat: 10);
      final now = DateTime(2026, 9, 16, 6);

      expect(canCancel(termin, now: now, minCancelHours: 3), isTrue);
      expect(canCancel(termin, now: now, minCancelHours: 5), isFalse);
    });

    test('zatvoren termin se ne otkazuje ni u roku', () {
      expect(
        canCancel(
          _termin(dan: 20, status: AppointmentStatus.cancelled),
          now: _sada,
          minCancelHours: 0,
        ),
        isFalse,
      );
    });
  });

  group('ekran', () {
    testWidgets('Ime ostaje na terminu bez radnika u aktivnom katalogu', (
      tester,
    ) async {
      final repo = _MockAppointments();
      when(repo.forCurrentCustomer).thenAnswer(
        (_) async => [
          _termin(
            dan: 5,
            status: AppointmentStatus.completed,
          ).copyWith(employeeName: 'Bivši radnik'),
        ],
      );
      await _pump(tester, repo: repo);
      await tester.tap(find.text('Prošli'));
      await tester.pumpAndSettle();
      expect(find.text('Bivši radnik'), findsOneWidget);
    });
    testWidgets('dva taba razdvajaju predstojeće od prošlih', (tester) async {
      final repo = _MockAppointments();
      when(repo.forCurrentCustomer).thenAnswer(
        (_) async => [
          _termin(dan: 20, sat: 10),
          _termin(dan: 5, sat: 14, status: AppointmentStatus.completed),
        ],
      );

      final container = await _pump(tester, repo: repo);

      expect(find.byType(AppointmentsScreen), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('Na čekanju'), findsOneWidget);
      // Prošli termin nije u prvom tabu.
      expect(find.text('14:00'), findsNothing);

      await tester.tap(find.text('Prošli'));
      await tester.pumpAndSettle();

      expect(find.text('14:00'), findsOneWidget);
      expect(find.text('Odrađeno'), findsOneWidget);

      container.dispose();
    });

    testWidgets('nakon roka je dugme onemogućeno, sa objašnjenjem', (
      tester,
    ) async {
      // Onemogućeno dugme bez objašnjenja izgleda kao kvar. Broj sati dolazi iz
      // vertikale, ne iz konstante.
      final repo = _MockAppointments();
      when(repo.forCurrentCustomer)
          .thenAnswer((_) async => [_termin(dan: 15, sat: 14)]);

      final container = await _pump(
        tester,
        repo: repo,
        now: DateTime(2026, 9, 15, 13),
      );

      final dugme = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Otkaži termin'),
      );
      expect(dugme.onPressed, isNull);
      expect(
        find.text('Otkazivanje je moguće najkasnije 3 sati prije termina.'),
        findsOneWidget,
      );

      container.dispose();
    });

    testWidgets('otkazivanje traži potvrdu — „Zadrži termin" ne zove bazu', (
      tester,
    ) async {
      final repo = _MockAppointments();
      when(repo.forCurrentCustomer)
          .thenAnswer((_) async => [_termin(dan: 20, sat: 10)]);

      final container = await _pump(tester, repo: repo);

      await tester.tap(find.widgetWithText(AppButton, 'Otkaži termin'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Otkazati termin?'), findsOneWidget);

      await tester.tap(find.text('Zadrži termin'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      verifyNever(
        () => repo.cancel(
          salonId: any(named: 'salonId'),
          appointmentId: any(named: 'appointmentId'),
          reason: any(named: 'reason'),
        ),
      );

      container.dispose();
    });

    testWidgets('potvrda zove cancel i osvježi listu', (tester) async {
      final repo = _MockAppointments();
      var otkazan = false;
      when(repo.forCurrentCustomer).thenAnswer(
        (_) async => [
          _termin(
            dan: 20,
            sat: 10,
            status: otkazan
                ? AppointmentStatus.cancelled
                : AppointmentStatus.pending,
          ),
        ],
      );
      when(
        () => repo.cancel(
          salonId: any(named: 'salonId'),
          appointmentId: any(named: 'appointmentId'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {
        otkazan = true;
        return _termin(dan: 20, sat: 10, status: AppointmentStatus.cancelled);
      });

      final container = await _pump(tester, repo: repo);

      await tester.tap(find.widgetWithText(AppButton, 'Otkaži termin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Da, otkaži'));
      await tester.pumpAndSettle();

      expect(find.text('Termin je otkazan.'), findsOneWidget);
      // Lista se ne „ažurira" nego se baca — otkazan termin je prešao u drugi tab.
      expect(find.widgetWithText(AppButton, 'Otkaži termin'), findsNothing);

      container.dispose();
    });

    testWidgets('povlačenje nadolje ponovo čita listu iz baze', (tester) async {
      // Realtime veza može biti suspendovana dok je app u pozadini, pa povlačenje
      // mora stvarno pogoditi bazu, a ne samo animirati indikator.
      final repo = _MockAppointments();
      var citanja = 0;
      when(repo.forCurrentCustomer).thenAnswer((_) async {
        citanja++;
        return [_termin(dan: 20, sat: 10)];
      });

      final container = await _pump(tester, repo: repo);
      final prije = citanja;

      await tester.fling(find.text('10:00'), const Offset(0, 900), 2000);
      await tester.pumpAndSettle();

      expect(citanja, prije + 1);

      container.dispose();
    });

    testWidgets('povratak u prvi plan ponovo čita listu', (tester) async {
      // FCM ili Realtime događaj se može propustiti dok je app u pozadini. Povratak
      // na ekran zato ne smije vjerovati keširanom stanju.
      final repo = _MockAppointments();
      var citanja = 0;
      when(repo.forCurrentCustomer).thenAnswer((_) async {
        citanja++;
        return [_termin(dan: 20, sat: 10)];
      });

      final container = await _pump(tester, repo: repo);
      final prije = citanja;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(citanja, prije + 1);

      container.dispose();
    });

    testWidgets('prazna lista se takođe može povući nadolje', (tester) async {
      // Prazno stanje nije scrollable samo po sebi — bez omotača u ListView-u
      // korisnik kojem je lista prazna nema kako da je osvježi.
      final repo = _MockAppointments();
      var citanja = 0;
      when(repo.forCurrentCustomer).thenAnswer((_) async {
        citanja++;
        return const <Appointment>[];
      });

      final container = await _pump(tester, repo: repo);
      final prije = citanja;

      await tester.fling(
        find.byType(RefreshIndicator).first,
        const Offset(0, 900),
        2000,
      );
      await tester.pumpAndSettle();

      expect(citanja, prije + 1);

      container.dispose();
    });

    testWidgets('odbijenica zbog roka kaže šta uraditi', (tester) async {
      // `PT403` iz baze stiže kao `NotFoundError` — `mapError` namjerno ne razlikuje
      // „zabranjeno" od „ne postoji". Na ovom ekranu termin sigurno postoji, pa je
      // jedini preostali razlog rok.
      final repo = _MockAppointments();
      when(repo.forCurrentCustomer)
          .thenAnswer((_) async => [_termin(dan: 20, sat: 10)]);
      when(
        () => repo.cancel(
          salonId: any(named: 'salonId'),
          appointmentId: any(named: 'appointmentId'),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(const NotFoundError('Rok za otkazivanje je prosao'));

      final container = await _pump(tester, repo: repo);

      await tester.tap(find.widgetWithText(AppButton, 'Otkaži termin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Da, otkaži'));
      await tester.pumpAndSettle();

      expect(
        find.text('Rok za otkazivanje je prošao. Nazovite salon.'),
        findsOneWidget,
      );

      container.dispose();
    });

    testWidgets('prazno stanje vodi na booking, ne ostavlja prazan ekran', (
      tester,
    ) async {
      final repo = _MockAppointments();
      when(repo.forCurrentCustomer).thenAnswer((_) async => const []);

      final container = await _pump(tester, repo: repo);

      expect(find.text('Nemate zakazanih termina.'), findsOneWidget);
      expect(find.text('Zakažite termin'), findsOneWidget);

      container.dispose();
    });

    testWidgets('bez prijave ekran nudi prijavu, ne praznu listu', (
      tester,
    ) async {
      final repo = _MockAppointments();
      when(repo.forCurrentCustomer).thenAnswer((_) async => const []);

      final container = await _pump(tester, repo: repo, prijavljen: false);

      expect(
        find.text('Prijavite se da vidite svoje termine.'),
        findsOneWidget,
      );
      verifyNever(repo.forCurrentCustomer);

      container.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Podaci i podizanje app-e
// ---------------------------------------------------------------------------

const _salonId = '550e8400-e29b-41d4-a716-446655440000';
final _sada = DateTime(2026, 9, 15, 12);

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

/// Vertikala sa `minCancelHours: 3` — isto što demo salon ima u `seed.sql`.
const _vertical = Vertical(
  key: 'barber',
  displayName: 'Frizer',
  terms: VerticalTerms.fallback,
  rules: BookingRules(
    mode: BookingMode.manual,
    granularity: BookingGranularity.exactSlot,
    slotStepMinutes: 15,
    bufferMinutes: 5,
    minAdvanceBookingHours: 2,
    maxAdvanceBookingDays: 30,
    minCancelHours: 3,
    pendingExpiryHours: 12,
    requireStaffChoice: false,
    showPricesInApp: true,
    allowGuestBooking: false,
  ),
  features: VerticalFeatures.fallback,
  defaultTheme: 'modern_barber',
);

Appointment _termin({
  required int dan,
  int sat = 10,
  AppointmentStatus status = AppointmentStatus.pending,
}) => Appointment(
  id: 'a-$dan-$sat-${status.wireName}',
  salonId: _salonId,
  serviceId: _usluga.id,
  customerId: '30000000-0000-4000-8000-000000000001',
  customerName: 'Amina',
  date: LocalDate(2026, 9, dan),
  startTime: LocalTime(sat, 0),
  endTime: LocalTime(sat, 30),
  status: status,
);

class _MockAppointments extends Mock implements AppointmentRepository {}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _MockAppointments repo,
  DateTime? now,
  bool prijavljen = true,
}) async {
  tester.binding.platformDispatcher.defaultRouteNameTestValue =
      ClientRoute.appointments.path;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

  tester.view
    ..physicalSize = const Size(1200, 2400)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository(
    pocetnaSesija: prijavljen ? FakeAuthRepository.sesijaNakonPrijave : null,
  );
  addTearDown(auth.dispose);

  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(_env),
      currentSalonIdProvider.overrideWithValue(_salonId),
      salonProvider.overrideWith((ref) async => _salon),
      servicesProvider.overrideWith((ref) async => const [_usluga]),
      employeesProvider.overrideWith((ref) async => const <Employee>[]),
      workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
      verticalProvider.overrideWith((ref) async => _vertical),
      authRepositoryProvider.overrideWithValue(auth),
      appointmentRepositoryProvider.overrideWithValue(repo),
      appointmentsNowProvider.overrideWithValue(now ?? _sada),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SalonClientApp(),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}
