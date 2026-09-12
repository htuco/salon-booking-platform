import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Isti obrazac kao ostali repozitoriji: gađa se mapiranje, ne `.from(...)`.
///
/// Autorizacija i rok za otkazivanje su svojstva baze i dokazuju se u
/// `supabase/tests/004_cancel_appointment.test.sql`. Dart test koji bi ih „provjerio" nad
/// lažnim klijentom dokazivao bi samo da mock vraća ono što mu je rečeno.
void main() {
  Map<String, dynamic> red({String status = 'pending', String? cancelledBy}) =>
      {
        'id': '40000000-0000-4000-8000-000000000001',
        'salon_id': '550e8400-e29b-41d4-a716-446655440000',
        'service_id': '10000000-0000-4000-8000-000000000001',
        'employee_id': '20000000-0000-4000-8000-000000000001',
        'customer_id': '30000000-0000-4000-8000-000000000001',
        'auth_identity_id': null,
        'device_id': null,
        'customer_name': 'Amina',
        'customer_phone': null,
        'customer_note': null,
        'date': '2026-09-16',
        'start_time': '10:00:00',
        'end_time': '10:40:00',
        'buffer_minutes': 5,
        'status': status,
        'source': 'app',
        'cancel_reason': null,
        'cancelled_by': cancelledBy,
        'pending_expires_at': null,
      };

  group('appointmentFromRow', () {
    test('mapira red kakav vraća PostgREST', () {
      final a = appointmentFromRow(red());

      expect(a.status, AppointmentStatus.pending);
      expect(a.date, const LocalDate(2026, 9, 16));
      expect(a.startTime, const LocalTime(10, 0));
      expect(a.durationMinutes, 40);
      expect(a.blocksSlot, isTrue);
    });

    test('nepoznat status ne ruši listu nego pada na unknown', () {
      // App u storeu je uvijek starija od baze; `alter type ... add value` niko ne prati
      // po verzijama storea. Bez fallbacka bi jedan novi status bio CastError usred liste.
      final a = appointmentFromRow(red(status: 'rescheduled'));

      expect(a.status, AppointmentStatus.unknown);
      expect(a.blocksSlot, isFalse);
    });

    test('otkazan termin nosi ko je otkazao', () {
      final a = appointmentFromRow(
        red(status: 'cancelled', cancelledBy: 'salon'),
      );

      expect(a.status, AppointmentStatus.cancelled);
      expect(a.status.isClosed, isTrue);
      expect(a.cancelledBy, 'salon');
    });

    test('prazan red je MappingError, ne null koji putuje dalje', () {
      expect(() => appointmentFromRow(const {}), throwsA(isA<MappingError>()));
      expect(() => appointmentFromRow(null), throwsA(isA<MappingError>()));
    });

    test('red kojem fali obavezna kolona je MappingError', () {
      // Skoro uvijek znači da su se šema i model razišli — kolona preimenovana u
      // migraciji, a `@JsonKey` ostao stari.
      final krnji = red()..remove('start_time');
      expect(() => appointmentFromRow(krnji), throwsA(isA<MappingError>()));
    });
  });

  group('appointmentsFromRows', () {
    test('mapira listu i čuva redoslijed', () {
      final lista = appointmentsFromRows([red(), red(status: 'cancelled')]);

      expect(lista, hasLength(2));
      expect(lista.first.status, AppointmentStatus.pending);
      expect(lista.last.status, AppointmentStatus.cancelled);
    });

    test('prazna lista je prazno stanje, ne greška', () {
      expect(appointmentsFromRows(const []), isEmpty);
    });

    test('odgovor koji nije lista je MappingError', () {
      expect(
        () => appointmentsFromRows(const {'id': 1}),
        throwsA(isA<MappingError>()),
      );
    });
  });
}
