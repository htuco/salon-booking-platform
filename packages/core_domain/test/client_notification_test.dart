import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('ClientNotification.fromJson', () {
    test('mapira red iz my_notifications', () {
      final n = ClientNotification.fromJson({
        'appointment_id': 'aa000000-0000-4000-8000-000000000001',
        'type': 'confirmed',
        'created_at': '2026-10-13T09:12:00+00:00',
        'read': false,
        'service_name': 'Fade šišanje',
        'employee_name': 'Emir',
        'date': '2026-10-20',
        'start_time': '14:30:00',
      });

      expect(n.type, 'confirmed');
      expect(n.read, isFalse);
      expect(n.date, LocalDate(2026, 10, 20));
      expect(n.startTime, const LocalTime(14, 30));
      expect(n.createdAt.toUtc().hour, 9);
      expect(n.serviceName, 'Fade šišanje');
    });

    test('nepoznat tip prolazi — baza dodaje tipove brže od store-a', () {
      final n = ClientNotification.fromJson({
        'appointment_id': 'a',
        'type': 'reminder_d1',
        'created_at': '2026-10-13T09:12:00Z',
        'read': true,
        'date': '2026-10-20',
        'start_time': '14:30',
      });

      expect(n.type, 'reminder_d1');
      expect(n.serviceName, isNull);
    });

    test('ponuda liste čekanja nema termin ni vrijeme', () {
      final n = ClientNotification.fromJson({
        'appointment_id': null,
        'type': 'waitlist_offer',
        'created_at': '2026-10-13T09:12:00Z',
        'read': false,
        'service_name': 'Fade šišanje',
        'employee_name': null,
        'date': '2026-10-20',
        'start_time': null,
      });

      expect(n.appointmentId, isNull);
      expect(n.startTime, isNull);
      expect(n.date, LocalDate(2026, 10, 20));
    });

    test('pola termina je FormatException', () {
      expect(
        () => ClientNotification.fromJson({
          'appointment_id': 'a',
          'type': 'confirmed',
          'created_at': '2026-10-13T09:12:00Z',
          'date': '2026-10-20',
        }),
        throwsFormatException,
      );
    });

    test('red bez termina je FormatException', () {
      expect(
        () => ClientNotification.fromJson({
          'type': 'confirmed',
          'created_at': '2026-10-13T09:12:00Z',
        }),
        throwsFormatException,
      );
    });
  });
}
