import 'package:client/src/features/booking/booking_flow_state.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stanje flowa je čista logika — testira se bez `pumpWidget`, kao `SalonSchedule` iz
/// taska 10.
///
/// Ovo su pravila koja ekrani samo prikazuju: šta se briše kad se izbor promijeni, kad je
/// korak popunjen, i gdje `date_only` grana odstupa. Ista provjera kroz podizanje četiri
/// ekrana bi trajala dvadeset puta duže i padala iz razloga koji nemaju veze sa pravilom.
void main() {
  const service = '10000000-0000-4000-8000-000000000001';
  const otherService = '10000000-0000-4000-8000-000000000002';
  const employee = '20000000-0000-4000-8000-000000000001';
  const date = LocalDate(2026, 9, 15);
  const time = LocalTime(9, 0);

  /// Potpuno popunjen flow sa izabranim radnikom.
  BookingFlowState full() => const BookingFlowState(
    serviceId: service,
    employeeId: employee,
    employeeChosen: true,
    date: date,
    startTime: time,
  );

  group('izbor radnika', () {
    test('"bilo koji" prolazi korak iako je employeeId null', () {
      // Zamka: uslov `employeeId != null` bi zaključao korisnika na drugom koraku
      // svaki put kad vertikala ne traži izbor radnika.
      final state = const BookingFlowState(serviceId: service)
          .withAnyEmployee();

      expect(state.employeeId, isNull);
      expect(state.employeeChosen, isTrue);
      expect(
        state.isStepComplete(BookingStep.employee, dateOnly: false),
        isTrue,
      );
    });

    test('neizabran radnik ne prolazi korak', () {
      const state = BookingFlowState(serviceId: service);

      expect(
        state.isStepComplete(BookingStep.employee, dateOnly: false),
        isFalse,
      );
    });
  });

  group('promjena izbora briše ono što više ne važi', () {
    test('promjena usluge obara radnika i termin', () {
      // Druga usluga ima drugo trajanje i moguće druge radnike — zadržan slot bi
      // preživio do potvrde i tamo pao kao 409 koji izgleda kao tuđa krivica.
      final state = full().clearFrom(BookingStep.employee);

      expect(state.serviceId, service);
      expect(state.employeeChosen, isFalse);
      expect(state.date, isNull);
      expect(state.startTime, isNull);
    });

    test('promjena radnika obara termin, ali čuva uslugu', () {
      final state = full().clearFrom(BookingStep.slot);

      expect(state.serviceId, service);
      expect(state.employeeId, employee);
      expect(state.employeeChosen, isTrue);
      expect(state.date, isNull);
      expect(state.startTime, isNull);
    });

    test('povratak na zadnji korak ne gubi ništa', () {
      // DoD: "povratak nazad ne gubi izbor". Korak `details` nema šta obarati —
      // iza njega nema izbora.
      final state = full().clearFrom(BookingStep.details);

      expect(state, full());
    });

    test('restart čisti sve', () {
      expect(full().clearFrom(BookingStep.service), BookingFlowState.empty);
    });
  });

  group('spremnost za slanje', () {
    test('exact_slot traži i datum i vrijeme', () {
      const bezVremena = BookingFlowState(
        serviceId: service,
        employeeChosen: true,
        date: date,
      );

      expect(bezVremena.isReadyToSubmit(dateOnly: false), isFalse);
      expect(bezVremena.firstIncompleteStep(dateOnly: false), BookingStep.slot);
      expect(full().isReadyToSubmit(dateOnly: false), isTrue);
    });

    test('date_only traži samo datum — vrijeme dodjeljuje salon', () {
      // docs/05 §4.1: ordinacija nudi "dođite ujutro". Bez ove grane bi korisnik
      // ordinacije zaglavio na koraku koji mu ne nudi nijedno vrijeme.
      const bezVremena = BookingFlowState(
        serviceId: service,
        employeeChosen: true,
        date: date,
      );

      expect(bezVremena.isReadyToSubmit(dateOnly: true), isTrue);
      expect(bezVremena.firstIncompleteStep(dateOnly: true), isNull);
    });

    test('prvi nepopunjen korak je onaj na koji guard vraća', () {
      // Korisnik koji otvori /book/slot iz deep linka bez izabrane usluge mora
      // nazad na prvi korak, a ne vidjeti prazan spisak termina.
      expect(
        BookingFlowState.empty.firstIncompleteStep(dateOnly: false),
        BookingStep.service,
      );
      expect(
        const BookingFlowState(serviceId: service)
            .firstIncompleteStep(dateOnly: false),
        BookingStep.employee,
      );
    });
  });

  group('jednakost', () {
    test('isti izbori su isto stanje', () {
      expect(full(), full());
      expect(full().hashCode, full().hashCode);
    });

    test('druga usluga je drugo stanje', () {
      expect(full(), isNot(full().copyWith(serviceId: otherService)));
    });

    test('"bilo koji" se razlikuje od "još nije biran"', () {
      const neizabran = BookingFlowState(serviceId: service);

      expect(neizabran.withAnyEmployee(), isNot(neizabran));
    });
  });
}
