import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Testira se **mapiranje**, ne PostgREST builder lanac.
///
/// `.from().select().eq()` je tuđi kod; lažirati ga znači napisati mock koji dokazuje da
/// mock radi. Zato repozitoriji drže mapiranje u izdvojenim `@visibleForTesting`
/// funkcijama — isti obrazac koji je uveo `VerticalRepository` u tasku 06 — i test gađa
/// njih, sa redovima kakve baza stvarno vraća.
void main() {
  group('salonFromRow', () {
    test('mapira red iz seeda', () {
      final salon = salonFromRow({
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'name': 'Barber Studio Vitez',
        'slug': 'barberstudiovitez',
        'description': 'Precizni rezovi, svjež izgled i vrijeme samo za vas.',
        'primary_color': '#C6A667',
        'secondary_color': '#171717',
        'theme': 'modern_barber',
        'city': 'Vitez',
        'vertical_pack_key': 'barber',
      });

      expect(salon, isA<Salon>());
      expect(salon.name, 'Barber Studio Vitez');
      expect(salon.verticalPackKey, 'barber');
    });

    test('neispravan red je MappingError, ne goli TypeError', () {
      // `name` nedostaje — bez mapiranja bi ovo bio TypeError iz generisanog koda,
      // koji ekran ne zna razlikovati od kvara na serveru.
      expect(
        () => salonFromRow({'id': 'x', 'slug': 's', 'city': 'Vitez'}),
        throwsA(isA<MappingError>()),
      );
    });
  });

  group('servicesFromRows', () {
    test('mapira listu usluga', () {
      final services = servicesFromRows([
        {
          'id': '10000000-0000-4000-8000-000000000001',
          'salon_id': '550e8400-e29b-41d4-a716-446655440000',
          'name': 'Muško šišanje',
          'category': 'Šišanje',
          'price': 15,
          'duration_minutes': 30,
        },
        {
          'id': '10000000-0000-4000-8000-000000000003',
          'salon_id': '550e8400-e29b-41d4-a716-446655440000',
          'name': 'Šišanje + brada',
          'category': 'Paketi',
          'price': 25,
          'duration_minutes': 45,
        },
      ]);

      expect(services, hasLength(2));
      expect(services.first, isA<Service>());
      expect(services.map((s) => s.name), ['Muško šišanje', 'Šišanje + brada']);
    });

    test('prazan salon daje praznu listu, ne grešku', () {
      // Tek postavljen tenant nema usluga — to je uredno stanje, ne kvar.
      expect(servicesFromRows(const []), isEmpty);
    });
  });

  group('employeesFromRows / employeeServicesFromRows', () {
    test('mapira radnike i veze radnik–usluga', () {
      final employees = employeesFromRows([
        {
          'id': '20000000-0000-4000-8000-000000000001',
          'salon_id': '550e8400-e29b-41d4-a716-446655440000',
          'name': 'Emir',
          'role': 'Barber',
          'bio': 'Precizno šišanje i oblikovanje brade.',
        },
      ]);
      final links = employeeServicesFromRows([
        {
          'id': 'es-1',
          'salon_id': '550e8400-e29b-41d4-a716-446655440000',
          'employee_id': '20000000-0000-4000-8000-000000000001',
          'service_id': '10000000-0000-4000-8000-000000000001',
        },
      ]);

      expect(employees.single.name, 'Emir');
      expect(links.single.employeeId, '20000000-0000-4000-8000-000000000001');
      expect(links.single.serviceId, '10000000-0000-4000-8000-000000000001');
    });
  });

  group('workingHoursFromRows', () {
    test('mapira sedmicu iz seeda — subota kraća, nedjelja zatvorena', () {
      // seed.sql:64 generiše tačno ovo: 09:00–17:00, subota do 14:00, nedjelja zatvorena.
      final rows = [
        for (var day = 1; day <= 7; day++)
          {
            'id': 'wh-$day',
            'salon_id': '550e8400-e29b-41d4-a716-446655440000',
            'employee_id': null,
            'day_of_week': day,
            'start_time': '09:00:00',
            'end_time': day == 6 ? '14:00:00' : '17:00:00',
            'is_closed': day == 7,
          },
      ];

      final hours = workingHoursFromRows(rows);

      expect(hours, hasLength(7));
      expect(hours[5].endTime, const LocalTime(14, 0), reason: 'subota');
      expect(hours[6].isClosed, isTrue, reason: 'nedjelja');
      expect(hours.every((h) => h.isSalonWide), isTrue);
    });
  });

  group('workingHoursFor', () {
    final salonMonday = WorkingHour.fromJson({
      'id': 'wh-s',
      'salon_id': 's',
      'employee_id': null,
      'day_of_week': 1,
      'start_time': '09:00:00',
      'end_time': '17:00:00',
    });
    final emirMonday = WorkingHour.fromJson({
      'id': 'wh-e',
      'salon_id': 's',
      'employee_id': 'emir',
      'day_of_week': 1,
      'start_time': '10:00:00',
      'end_time': '18:00:00',
    });
    final all = [salonMonday, emirMonday];

    test('radnikov red nadjačava salonski', () {
      final hours = workingHoursFor(all, dayOfWeek: 1, employeeId: 'emir');

      expect(hours?.startTime, const LocalTime(10, 0));
    });

    test('radnik bez svog reda dobija salonski', () {
      final hours = workingHoursFor(all, dayOfWeek: 1, employeeId: 'amar');

      expect(hours?.startTime, const LocalTime(9, 0));
      expect(hours?.isSalonWide, isTrue);
    });

    test('bez radnika vraća salonski raspored', () {
      expect(workingHoursFor(all, dayOfWeek: 1)?.isSalonWide, isTrue);
    });

    test('dan bez ijednog reda znači da salon ne radi', () {
      expect(workingHoursFor(all, dayOfWeek: 3), isNull);
    });
  });

  group('salonSettingsFromRow', () {
    test('mapira postavke iz seeda', () {
      final settings = salonSettingsFromRow({
        'id': 'st-1',
        'salon_id': '550e8400-e29b-41d4-a716-446655440000',
        'buffer_minutes': 5,
        'slot_step_minutes': 15,
        'min_advance_booking_hours': 2,
        'max_advance_booking_days': 30,
        'pending_expiry_hours': 12,
        'min_cancel_hours': 3,
      });

      expect(settings, isA<SalonSettings>());
      expect(settings.bufferMinutes, 5);
      expect(settings.timezone, 'Europe/Sarajevo');
    });
  });

  test('nijedan repozitorij ne vraća Map', () {
    // Ugovor sloja, provjeren na tipovima: da neka metoda vraća `Map`, dodjela ispod
    // ne bi kompajlirala. Pozivi se ne izvršavaju — dovoljno je da se tipovi slože.
    final client = _never();
    final Future<Salon> Function(String) byId = SalonRepository(client).byId;
    final Future<List<Service>> Function(String) services = ServiceRepository(
      client,
    ).forSalon;
    final Future<List<Employee>> Function(String) employees =
        EmployeeRepository(client).forSalon;
    final Future<List<EmployeeService>> Function(String) links =
        EmployeeRepository(client).serviceLinksForSalon;
    final Future<List<WorkingHour>> Function(String) hours =
        WorkingHoursRepository(client).forSalon;
    final Future<SalonSettings> Function(String) settings = SettingsRepository(
      client,
    ).forSalon;

    expect([
      byId,
      services,
      employees,
      links,
      hours,
      settings,
    ], everyElement(isNotNull));
  });
}

/// Klijent koji se nikad ne dodirne — testu iznad trebaju samo tipovi, ne mreža.
class _MockSupabaseClient extends Mock implements SupabaseClient {}

SupabaseClient _never() => _MockSupabaseClient();
