import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

/// Payloadi su prepisani iz `supabase/seed.sql` — isti `id`-evi, ista imena kolona, iste
/// vrijednosti. Ne izmišljaj ih: test nad izmišljenim payloadom dokazuje da model mapira
/// sam sebe, a ne da mapira ono što baza stvarno vraća.
///
/// PostgREST vraća `time` kao `HH:mm:ss`, `date` kao `yyyy-MM-dd`, a `numeric` kao broj —
/// zato su vrijednosti ovdje u tom obliku, ne u Dart tipovima.
void main() {
  _task22();
  group('Salon', () {
    // seed.sql:25
    final row = <String, dynamic>{
      'id': '550e8400-e29b-41d4-a716-446655440000',
      'name': 'Barber Studio Vitez',
      'slug': 'barberstudiovitez',
      'description': 'Precizni rezovi, svjež izgled i vrijeme samo za vas.',
      'logo_url': null,
      'cover_image_url': null,
      'primary_color': '#C6A667',
      'secondary_color': '#171717',
      'theme': 'modern_barber',
      'address': '',
      'city': 'Vitez',
      'phone': null,
      'email': null,
      'instagram_url': null,
      'facebook_url': null,
      'vertical_pack_key': 'barber',
    };

    test('mapira snake_case kolone na polja modela', () {
      final salon = Salon.fromJson(row);

      expect(salon.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(salon.name, 'Barber Studio Vitez');
      expect(salon.slug, 'barberstudiovitez');
      expect(salon.city, 'Vitez');
      // Kolone koje se lako pobrkaju jer im se imena razlikuju samo po prefiksu.
      expect(salon.primaryColor, '#C6A667');
      expect(salon.secondaryColor, '#171717');
      expect(salon.verticalPackKey, 'barber');
      expect(salon.logoUrl, isNull);
    });

    test('nedostajuće opcione kolone padaju na default, ne na null', () {
      final salon = Salon.fromJson({
        'id': 'x',
        'name': 'Bez ičega',
        'slug': 'bez-icega',
        'city': 'Sarajevo',
      });

      expect(salon.description, '');
      expect(salon.primaryColor, '#C6A667');
      expect(salon.verticalPackKey, 'generic');
    });
  });

  group('Service', () {
    // seed.sql:41
    test('mapira uslugu i čita cijenu kao broj', () {
      final service = Service.fromJson({
        'id': '10000000-0000-4000-8000-000000000001',
        'salon_id': '550e8400-e29b-41d4-a716-446655440000',
        'name': 'Muško šišanje',
        'description': '',
        'category': 'Šišanje',
        'price': 15,
        'duration_minutes': 30,
      });

      expect(service.name, 'Muško šišanje');
      expect(service.category, 'Šišanje');
      expect(service.durationMinutes, 30);
      expect(service.price, 15.0);
    });

    test('numeric stiže i kao decimalni broj', () {
      // `numeric(10,2)` — PostgREST zna vratiti 15 ili 15.5; oba moraju proći.
      final service = Service.fromJson({
        'id': 'x',
        'salon_id': 'y',
        'name': 'Pramenovi',
        'price': 99.99,
        'duration_minutes': 150,
      });

      expect(service.price, closeTo(99.99, 0.001));
    });
  });

  group('Employee', () {
    // seed.sql:52
    test('mapira radnika', () {
      final employee = Employee.fromJson({
        'id': '20000000-0000-4000-8000-000000000001',
        'salon_id': '550e8400-e29b-41d4-a716-446655440000',
        'name': 'Emir',
        'role': 'Barber',
        'bio': 'Precizno šišanje i oblikovanje brade.',
        'image_url': null,
      });

      expect(employee.name, 'Emir');
      expect(employee.role, 'Barber');
      expect(employee.imageUrl, isNull);
    });
  });

  group('WorkingHour', () {
    // seed.sql:64 — svaki dan 09:00, subota do 14:00, nedjelja zatvoreno.
    test('parsira time kolone u LocalTime, bez zone', () {
      final hour = WorkingHour.fromJson({
        'id': 'wh-1',
        'salon_id': '550e8400-e29b-41d4-a716-446655440000',
        'employee_id': null,
        'day_of_week': 1,
        'start_time': '09:00:00',
        'end_time': '17:00:00',
        'break_start_time': null,
        'break_end_time': null,
        'is_closed': false,
      });

      expect(hour.startTime, const LocalTime(9, 0));
      expect(hour.endTime, const LocalTime(17, 0));
      expect(hour.dayOfWeek, 1);
      expect(hour.isSalonWide, isTrue);
      expect(hour.hasBreak, isFalse);
    });

    test('nedjelja je zatvorena iako vremena i dalje stoje', () {
      final hour = WorkingHour.fromJson({
        'id': 'wh-7',
        'salon_id': 's',
        'day_of_week': 7,
        'start_time': '09:00:00',
        'end_time': '17:00:00',
        'is_closed': true,
      });

      // Zamka: vremena nisu null kad je dan zatvoren — nose default iz baze.
      expect(hour.isClosed, isTrue);
      expect(hour.startTime, const LocalTime(9, 0));
    });

    test('pauza se čita kao par', () {
      final hour = WorkingHour.fromJson({
        'id': 'wh-p',
        'salon_id': 's',
        'day_of_week': 3,
        'start_time': '09:00:00',
        'end_time': '17:00:00',
        'break_start_time': '12:00:00',
        'break_end_time': '12:30:00',
      });

      expect(hour.hasBreak, isTrue);
      expect(hour.breakStartTime, const LocalTime(12, 0));
      expect(hour.breakEndTime, const LocalTime(12, 30));
    });

    test('red sa radnikom nije salonski', () {
      final hour = WorkingHour.fromJson({
        'id': 'wh-e',
        'salon_id': 's',
        'employee_id': '20000000-0000-4000-8000-000000000001',
        'day_of_week': 2,
        'start_time': '10:00:00',
        'end_time': '18:00:00',
      });

      expect(hour.isSalonWide, isFalse);
      expect(hour.employeeId, '20000000-0000-4000-8000-000000000001');
    });
  });

  group('SalonSettings', () {
    // seed.sql:37 — barber salon.
    test('mapira booking pravila', () {
      final settings = SalonSettings.fromJson({
        'id': 'st-1',
        'salon_id': '550e8400-e29b-41d4-a716-446655440000',
        'booking_mode': 'manual',
        'booking_granularity': 'exact_slot',
        'buffer_minutes': 5,
        'slot_step_minutes': 15,
        'min_advance_booking_hours': 2,
        'max_advance_booking_days': 30,
        'pending_expiry_hours': 12,
        'min_cancel_hours': 3,
        'require_staff_choice': false,
        'show_prices_in_app': true,
        'timezone': 'Europe/Sarajevo',
        'language': 'bs',
      });

      expect(settings.bufferMinutes, 5);
      expect(settings.slotStepMinutes, 15);
      expect(settings.minAdvanceBookingHours, 2);
      expect(settings.maxAdvanceBookingDays, 30);
      expect(settings.timezone, 'Europe/Sarajevo');
      expect(settings.isDateOnly, isFalse);
      expect(settings.confirmsAutomatically, isFalse);
    });

    test('date_only i auto mod se čitaju kroz izvedena polja', () {
      final settings = SalonSettings.fromJson({
        'id': 'st-2',
        'salon_id': 's',
        'booking_mode': 'auto',
        'booking_granularity': 'date_only',
      });

      expect(settings.isDateOnly, isTrue);
      expect(settings.confirmsAutomatically, isTrue);
    });
  });

  group('Appointment', () {
    // Seed nema `appointments` redova, pa je payload složen po koloni iz
    // init_schema.sql — isti oblik koji `book_appointment` vraća.
    final row = <String, dynamic>{
      'id': 'ap-1',
      'salon_id': '550e8400-e29b-41d4-a716-446655440000',
      'service_id': '10000000-0000-4000-8000-000000000001',
      'service_name': 'Musko sisanje',
      'service_price': 20.0,
      'service_duration_minutes': 30,
      'employee_id': '20000000-0000-4000-8000-000000000001',
      'customer_id': 'cu-1',
      'auth_identity_id': null,
      'device_id': null,
      'customer_name': 'Adnan',
      'customer_phone': '+38761000000',
      'customer_note': null,
      'date': '2026-09-14',
      'start_time': '09:00:00',
      'end_time': '09:30:00',
      'buffer_minutes': 5,
      'status': 'pending',
      'source': 'app',
      'cancel_reason': null,
      'cancelled_by': null,
      'pending_expires_at': '2026-09-12T08:00:00+00:00',
    };

    test('mapira termin, datum i vremena bez zone', () {
      final appointment = Appointment.fromJson(row);

      expect(appointment.date, const LocalDate(2026, 9, 14));
      expect(appointment.startTime, const LocalTime(9, 0));
      expect(appointment.endTime, const LocalTime(9, 30));
      expect(appointment.durationMinutes, 30);
      expect(appointment.bufferMinutes, 5);
      expect(appointment.serviceName, 'Musko sisanje');
      expect(appointment.servicePrice, 20);
      expect(appointment.serviceDurationMinutes, 30);
    });

    test('status je tipiziran, ne string', () {
      expect(Appointment.fromJson(row).status, AppointmentStatus.pending);
      expect(
        Appointment.fromJson({...row, 'status': 'no_show'}).status,
        AppointmentStatus.noShow,
      );
    });

    test('nepoznat status iz novije baze ne ruši mapiranje', () {
      // App u storeu je starija od baze: `alter type ... add value` se desi bez
      // novog submissiona. Bez fallbacka bi ovo bio CastError usred liste.
      final appointment = Appointment.fromJson({
        ...row,
        'status': 'rescheduled',
      });

      expect(appointment.status, AppointmentStatus.unknown);
      expect(appointment.customerName, 'Adnan');
    });

    test('pending i confirmed drže slot, ostali ne', () {
      expect(AppointmentStatus.pending.blocksSlot, isTrue);
      expect(AppointmentStatus.confirmed.blocksSlot, isTrue);
      expect(AppointmentStatus.cancelled.blocksSlot, isFalse);
      expect(AppointmentStatus.completed.blocksSlot, isFalse);
      expect(AppointmentStatus.noShow.blocksSlot, isFalse);
    });

    test('pending_expires_at je timestamptz, pa jeste DateTime', () {
      // Jedino vrijeme u šemi koje je stvarni trenutak, a ne zidno vrijeme salona.
      final appointment = Appointment.fromJson(row);

      expect(appointment.pendingExpiresAt, isNotNull);
      expect(appointment.pendingExpiresAt!.toUtc().hour, 8);
    });
  });
}

/// Task 22: dvije kolone koje handoff traži, a šema ih do sada nije imala.
///
/// Obje su nullable **namjerno** — salon bez fotografija i radnik bez unesenog staža su
/// uredna stanja, ne nepotpuni podaci. Uz to: app iz storea je starija od baze, pa red
/// **bez tih kolona** mora proći kroz `fromJson`, inače jedan stariji build pada na svakom
/// odgovoru servera.
void _task22() {
  group('Service.imageUrl', () {
    test('fotografija se čita kad postoji', () {
      final s = Service.fromJson(const {
        'id': 's1',
        'salon_id': 'sa1',
        'name': 'Fade',
        'price': 20,
        'duration_minutes': 40,
        'image_url': 'https://images.demo.invalid/barber/fade.jpg',
      });

      expect(s.imageUrl, 'https://images.demo.invalid/barber/fade.jpg');
    });

    test('red bez kolone i red sa `null` su oba uredni', () {
      const bez = {
        'id': 's2',
        'salon_id': 'sa1',
        'name': 'Brada',
        'price': 10,
        'duration_minutes': 20,
      };

      expect(Service.fromJson(bez).imageUrl, isNull);
      expect(Service.fromJson({...bez, 'image_url': null}).imageUrl, isNull);
    });
  });

  group('Employee.experienceYears', () {
    test('staž se čita i `hasExperience` ga potvrđuje', () {
      final e = Employee.fromJson(const {
        'id': 'e1',
        'salon_id': 'sa1',
        'name': 'Emir',
        'role': 'Barber',
        'experience_years': 9,
      });

      expect(e.experienceYears, 9);
      expect(e.hasExperience, isTrue);
    });

    test('radnik bez staža nije radnik sa nulom', () {
      // Razlika je vidljiva na ekranu: `null` znači „ne prikazuj ništa", a `0` bi bilo
      // „Barber · 0 godina" — rečenica koju niko ne bi svjesno napisao.
      const bez = {'id': 'e2', 'salon_id': 'sa1', 'name': 'Lejla'};

      expect(Employee.fromJson(bez).experienceYears, isNull);
      expect(Employee.fromJson(bez).hasExperience, isFalse);
      expect(
        Employee.fromJson({...bez, 'experience_years': 0}).hasExperience,
        isFalse,
      );
    });
  });
}
