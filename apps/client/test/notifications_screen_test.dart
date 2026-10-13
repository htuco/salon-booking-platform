import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/features/notifications/notifications_provider.dart';
import 'package:client/src/features/notifications/notifications_screen.dart';
import 'package:client/src/l10n/generated/app_localizations_bs.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'support/fake_auth_repository.dart';

/// „Obavijesti" — task 70.
///
/// Ko smije vidjeti koji red dokazuje `029_istorija_obavijesti.test.sql`. Ovdje se mjeri
/// ekran: lista umjesto praznog stanja, nepročitano, tap, i da otvaranje označi pročitano.
void main() {
  final l10n = AppLocalizationsBs();

  group('tekst', () {
    test('Danas i Jučer sa satom, starije samo datum', () {
      final sada = DateTime(2026, 10, 13, 15);
      expect(
        notificationWhen(l10n, DateTime(2026, 10, 13, 9, 12), sada),
        'Danas · 09:12',
      );
      expect(
        notificationWhen(l10n, DateTime(2026, 10, 12, 18, 40), sada),
        'Jučer · 18:40',
      );
      expect(notificationWhen(l10n, DateTime(2026, 4, 12, 8), sada), '12.04.');
    });

    test('nepoznat tip ima opšti naslov, ne prazan', () {
      expect(
        notificationTitle(l10n, 'expired'),
        'Salon nije odgovorio na vrijeme',
      );
      expect(notificationTitle(l10n, 'waitlist_offer'), 'Obavijest');
    });

    test('opis nosi uslugu, radnika i termin', () {
      expect(
        notificationBody(l10n, _obavijest()),
        'Fade šišanje · Emir · srijeda 21.10. u 14:30',
      );
      expect(
        notificationBody(l10n, _obavijest(radnik: null)),
        'Fade šišanje · srijeda 21.10. u 14:30',
      );
    });
  });

  group('ekran', () {
    testWidgets('lista, nepročitano i označavanje pročitanim', (tester) async {
      final repo = _MockNotifications();
      when(repo.mine).thenAnswer(
        (_) async => [
          _obavijest(),
          _obavijest(tip: 'rejected', procitano: true),
        ],
      );
      when(repo.markAllRead).thenAnswer((_) async {});

      await _pump(tester, repo: repo);

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Zahtjev je potvrđen'), findsOneWidget);
      expect(find.text('Zahtjev je odbijen'), findsOneWidget);
      expect(find.text('Danas · 09:12'), findsNWidgets(2));
      // Čitač ekrana čuje da je prva nova, druga ne.
      expect(find.bySemanticsLabel(RegExp(r'^Novo\. ')), findsOneWidget);
      verify(repo.markAllRead).called(1);
    });

    testWidgets('sve pročitano: baza se ne zove', (tester) async {
      final repo = _MockNotifications();
      when(repo.mine).thenAnswer((_) async => [_obavijest(procitano: true)]);

      await _pump(tester, repo: repo);

      verifyNever(repo.markAllRead);
    });

    testWidgets('tap vodi na Moji termini', (tester) async {
      final repo = _MockNotifications();
      when(repo.mine).thenAnswer((_) async => [_obavijest()]);
      when(repo.markAllRead).thenAnswer((_) async {});

      final container = await _pump(tester, repo: repo);
      await tester.tap(find.text('Zahtjev je potvrđen'));
      await tester.pumpAndSettle();

      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.appointments.path,
      );
    });

    testWidgets('bez obavijesti ostaje prazno stanje', (tester) async {
      final repo = _MockNotifications();
      when(repo.mine).thenAnswer((_) async => const []);

      await _pump(tester, repo: repo);

      expect(find.text(l10n.notificationsEmpty), findsOneWidget);
    });

    testWidgets('neprijavljen: prazno stanje, baza se ne pita', (tester) async {
      final repo = _MockNotifications();

      await _pump(tester, repo: repo, prijavljen: false);

      expect(find.text(l10n.notificationsEmpty), findsOneWidget);
      verifyNever(repo.mine);
    });
  });
}

class _MockNotifications extends Mock implements NotificationRepository {}

class _MockAppointments extends Mock implements AppointmentRepository {}

ClientNotification _obavijest({
  String tip = 'confirmed',
  bool procitano = false,
  String? radnik = 'Emir',
}) => ClientNotification(
  appointmentId: 'aa000000-0000-4000-8000-000000000001',
  type: tip,
  createdAt: DateTime(2026, 10, 13, 9, 12),
  read: procitano,
  date: LocalDate(2026, 10, 21),
  startTime: const LocalTime(14, 30),
  serviceName: 'Fade šišanje',
  employeeName: radnik,
);

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

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

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _MockNotifications repo,
  bool prijavljen = true,
}) async {
  tester.binding.platformDispatcher.defaultRouteNameTestValue =
      ClientRoute.notifications.path;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

  tester.view
    ..physicalSize = const Size(1200, 2400)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository(
    pocetnaSesija: prijavljen ? FakeAuthRepository.sesijaNakonPrijave : null,
  );
  addTearDown(auth.dispose);

  final termini = _MockAppointments();
  when(termini.forCurrentCustomer).thenAnswer((_) async => const []);

  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(_env),
      currentSalonIdProvider.overrideWithValue(_salonId),
      salonProvider.overrideWith((ref) async => _salon),
      servicesProvider.overrideWith((ref) async => const <Service>[]),
      employeesProvider.overrideWith((ref) async => const <Employee>[]),
      workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
      verticalProvider.overrideWith((ref) async => Vertical.fallback),
      authRepositoryProvider.overrideWithValue(auth),
      appointmentRepositoryProvider.overrideWithValue(termini),
      notificationRepositoryProvider.overrideWithValue(repo),
      notificationsNowProvider.overrideWithValue(DateTime(2026, 10, 13, 15)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SalonClientApp(),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}
