import 'package:client/src/features/booking/booking_flow_provider.dart';
import 'package:client/src/features/booking/booking_flow_state.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Notifier se testira bez podizanja app-e: `ProviderContainer` je dovoljan, a nijedna
/// metoda ne dodiruje mrežu.
///
/// `bookingFlowProvider` je `autoDispose`, pa ga test mora držati preko `listen` — bez
/// slušaoca ga Riverpod odbaci između poziva i svaki `read` vrati početno stanje.
void main() {
  const service = '10000000-0000-4000-8000-000000000001';
  const otherService = '10000000-0000-4000-8000-000000000002';
  const employee = '20000000-0000-4000-8000-000000000001';
  const otherEmployee = '20000000-0000-4000-8000-000000000002';
  const date = LocalDate(2026, 9, 15);
  const time = LocalTime(9, 0);

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    // Drzi provider zivim dok test traje.
    container.listen(bookingFlowProvider, (_, _) {}, fireImmediately: true);
  });

  tearDown(() => container.dispose());

  BookingFlowNotifier notifier() =>
      container.read(bookingFlowProvider.notifier);
  BookingFlowState state() => container.read(bookingFlowProvider);

  test('flow počinje prazan', () {
    expect(state(), BookingFlowState.empty);
  });

  test('puni flow kroz sve korake', () {
    notifier()
      ..chooseService(service)
      ..chooseEmployee(employee)
      ..chooseSlot(date: date, startTime: time)
      ..setNote('Molim kratko sa strane');

    expect(state().serviceId, service);
    expect(state().employeeId, employee);
    expect(state().date, date);
    expect(state().startTime, time);
    expect(state().note, 'Molim kratko sa strane');
    expect(state().isReadyToSubmit(dateOnly: false), isTrue);
  });

  test('promjena usluge briše radnika i termin', () {
    notifier()
      ..chooseService(service)
      ..chooseEmployee(employee)
      ..chooseSlot(date: date, startTime: time)
      ..chooseService(otherService);

    expect(state().serviceId, otherService);
    expect(state().employeeChosen, isFalse);
    expect(state().date, isNull);
    expect(state().startTime, isNull);
  });

  test('ponovni izbor iste usluge ne briše ništa', () {
    // Korisnik se vrati na prvi korak i potvrdi isti izbor — termin mora preživjeti,
    // inace svaki pogled unazad znaci ponovno biranje.
    notifier()
      ..chooseService(service)
      ..chooseEmployee(employee)
      ..chooseSlot(date: date, startTime: time)
      ..chooseService(service);

    expect(state().startTime, time);
    expect(state().employeeId, employee);
  });

  test('promjena radnika briše termin', () {
    notifier()
      ..chooseService(service)
      ..chooseEmployee(employee)
      ..chooseSlot(date: date, startTime: time)
      ..chooseEmployee(otherEmployee);

    expect(state().employeeId, otherEmployee);
    expect(state().date, isNull);
    expect(state().startTime, isNull);
  });

  test('"bilo koji radnik" briše prethodno izabranog', () {
    // Bez brisanja bi employeeId ostao popunjen i poziv bi trazio bas tog radnika,
    // iako je korisnik na ekranu izabrao "bilo koji".
    notifier()
      ..chooseService(service)
      ..chooseEmployee(employee)
      ..chooseAnyEmployee();

    expect(state().employeeId, isNull);
    expect(state().employeeChosen, isTrue);
  });

  test('promjena datuma briše vrijeme', () {
    notifier()
      ..chooseService(service)
      ..chooseAnyEmployee()
      ..chooseSlot(date: date, startTime: time)
      ..chooseDate(const LocalDate(2026, 9, 16));

    expect(state().date, const LocalDate(2026, 9, 16));
    expect(state().startTime, isNull);
  });

  test('date_only flow je spreman sa samim datumom', () {
    notifier()
      ..chooseService(service)
      ..chooseAnyEmployee()
      ..chooseDate(date);

    expect(state().startTime, isNull);
    expect(state().isReadyToSubmit(dateOnly: true), isTrue);
    expect(state().isReadyToSubmit(dateOnly: false), isFalse);
  });

  test('prazna napomena se pamti kao null, ne kao prazan string', () {
    notifier()
      ..chooseService(service)
      ..setNote('   ');

    expect(state().note, isNull);
  });

  test('reset vraća prazan flow', () {
    notifier()
      ..chooseService(service)
      ..chooseEmployee(employee)
      ..chooseSlot(date: date, startTime: time)
      ..reset();

    expect(state(), BookingFlowState.empty);
  });

  group('SlotQuery', () {
    test('isti argumenti su isti ključ — inače svaki rebuild ide u bazu', () {
      const a = SlotQuery(serviceId: service, date: date, employeeId: employee);
      const b = SlotQuery(serviceId: service, date: date, employeeId: employee);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('"bilo koji radnik" je drugi ključ od konkretnog radnika', () {
      const any = SlotQuery(serviceId: service, date: date);
      const specific = SlotQuery(
        serviceId: service,
        date: date,
        employeeId: employee,
      );

      expect(any, isNot(specific));
    });
  });
}
