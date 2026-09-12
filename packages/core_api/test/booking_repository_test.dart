import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Isti obrazac kao `catalog_repository_test.dart`: gađa se mapiranje, ne `.rpc(...)`.
///
/// Redovi u testu su prepisani iz oblika koji funkcije iz taska 05 stvarno vraćaju —
/// `get_available_slots` kao `table (start_time time, employee_id uuid)`, pa PostgREST
/// šalje `start_time` kao `HH:mm:ss` string.
void main() {
  const employeeA = '20000000-0000-4000-8000-000000000001';
  const employeeB = '20000000-0000-4000-8000-000000000002';

  group('availableSlotsFromRows', () {
    test('mapira redove kakve vraća get_available_slots', () {
      final slots = availableSlotsFromRows([
        {'start_time': '09:00:00', 'employee_id': employeeA},
        {'start_time': '09:30:00', 'employee_id': employeeA},
      ]);

      expect(slots, hasLength(2));
      expect(slots.first.startTime, const LocalTime(9, 0));
      expect(slots.first.employeeId, employeeA);
    });

    test('prazan dan je prazna lista, ne greška', () {
      // Dan bez slobodnih termina je normalan ishod (salon zatvoren, sve zauzeto).
      // Da je greška, ekran bi na neradnu nedjelju prikazao "pokušaj ponovo".
      expect(availableSlotsFromRows(const []), isEmpty);
      expect(availableSlotsFromRows(null), isEmpty);
    });

    test('neispravan red je MappingError, ne goli TypeError', () {
      expect(
        () => availableSlotsFromRows([
          {'start_time': '09:00:00'},
        ]),
        throwsA(isA<MappingError>()),
      );
    });

    test('odgovor koji nije lista je MappingError', () {
      expect(
        () => availableSlotsFromRows({'start_time': '09:00:00'}),
        throwsA(isA<MappingError>()),
      );
    });
  });

  group('grupisanje slotova za prikaz', () {
    test('"bilo koji radnik" daje isto vrijeme više puta, prikaz ga svodi na jedno', () {
      // Ovo je stvarni oblik odgovora kad p_employee_id ostane null: red po
      // slobodnom radniku. Bez svođenja bi korisnik vidio "09:00" dvaput.
      final slots = availableSlotsFromRows([
        {'start_time': '09:00:00', 'employee_id': employeeA},
        {'start_time': '09:00:00', 'employee_id': employeeB},
        {'start_time': '10:00:00', 'employee_id': employeeB},
      ]);

      expect(slots.distinctTimes, [
        const LocalTime(9, 0),
        const LocalTime(10, 0),
      ]);
      expect(slots.employeesAt(const LocalTime(9, 0)), [employeeA, employeeB]);
      expect(slots.employeesAt(const LocalTime(10, 0)), [employeeB]);
    });

    test('vremena su sortirana bez obzira na redoslijed iz baze', () {
      final slots = availableSlotsFromRows([
        {'start_time': '14:30:00', 'employee_id': employeeA},
        {'start_time': '09:00:00', 'employee_id': employeeA},
      ]);

      expect(slots.distinctTimes, [
        const LocalTime(9, 0),
        const LocalTime(14, 30),
      ]);
    });
  });

  group('availableDatesFromRows', () {
    test('čita `available_date` iz mape, ne goli string', () {
      // Funkcija je `returns table (available_date date)` — svaki red je mapa sa
      // jednim ključem. `rows.cast<String>()` bi prošao analizu i pao u runtimeu.
      final dates = availableDatesFromRows([
        {'available_date': '2026-09-15'},
        {'available_date': '2026-09-16'},
      ]);

      expect(dates, [
        const LocalDate(2026, 9, 15),
        const LocalDate(2026, 9, 16),
      ]);
    });

    test('prazan raspon je prazna lista', () {
      expect(availableDatesFromRows(const []), isEmpty);
    });

    test('neispravan datum je MappingError', () {
      expect(
        () => availableDatesFromRows([
          {'available_date': 'petnaesti'},
        ]),
        throwsA(isA<MappingError>()),
      );
    });
  });

  group('appointmentFromRpcRow', () {
    Map<String, dynamic> row() => {
      'id': '30000000-0000-4000-8000-000000000001',
      'salon_id': '550e8400-e29b-41d4-a716-446655440000',
      'service_id': '10000000-0000-4000-8000-000000000001',
      'employee_id': employeeA,
      'customer_id': '40000000-0000-4000-8000-000000000001',
      'auth_identity_id': null,
      'device_id': null,
      'customer_name': 'Amir Hodžić',
      'customer_phone': '+38761000000',
      'customer_note': null,
      'date': '2026-09-15',
      'start_time': '09:00:00',
      'end_time': '09:30:00',
      'buffer_minutes': 10,
      'status': 'pending',
      'source': 'app',
      'cancel_reason': null,
      'cancelled_by': null,
      'pending_expires_at': '2026-09-12T09:00:00Z',
    };

    test('termin nastaje kao pending, ne kao confirmed', () {
      // `book_appointment` uvijek upisuje 'pending' — i kad salon radi u auto modu,
      // potvrdu dodjeljuje baza. Success ekran zato kaže "zahtjev poslan" (01 §18).
      final appointment = appointmentFromRpcRow(row());

      expect(appointment.status, AppointmentStatus.pending);
      expect(appointment.blocksSlot, isTrue);
    });

    test('radnik kojeg je dodijelila baza stiže nazad u odgovoru', () {
      // Kad korisnik izabere "bilo koji", employee_id ide kao null a vraća se popunjen:
      // ekran potvrde tako zna koga je klijent dobio.
      final appointment = appointmentFromRpcRow(row());

      expect(appointment.employeeId, employeeA);
    });

    test('buffer je zapamćen na terminu, ne čitan iz postavki', () {
      final appointment = appointmentFromRpcRow(row());

      expect(appointment.bufferMinutes, 10);
      expect(appointment.durationMinutes, 30);
    });

    test('odgovor u listi od jednog reda se takođe mapira', () {
      // Ako potpis funkcije ikad pređe na `setof`, isti poziv počne vraćati listu.
      expect(appointmentFromRpcRow([row()]).status, AppointmentStatus.pending);
    });

    test('prazan odgovor je MappingError, ne tihi null', () {
      expect(
        () => appointmentFromRpcRow(const []),
        throwsA(isA<MappingError>()),
      );
      expect(() => appointmentFromRpcRow(null), throwsA(isA<MappingError>()));
    });
  });
}
