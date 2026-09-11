import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';

/// Korak booking flowa — `docs/01 §12`.
///
/// Enum, ne indeks: `step + 1` je izraz koji kompajler ne provjerava, a `date_only` grana
/// preskače izbor vremena pa aritmetika nad indeksom tiho promaši.
enum BookingStep {
  service('/book/service'),
  employee('/book/employee'),
  slot('/book/slot'),
  details('/book/details');

  const BookingStep(this.path);

  /// Ruta koraka — ista vrijednost kao `ClientRoute`, da se navigacija i stanje ne raziđu.
  final String path;
}

/// Šta je korisnik izabrao u booking flowu — jedan nepromjenjiv snimak.
///
/// **Ovdje nema nijednog slobodnog termina.** Stanje nosi *izbor* korisnika; koji su
/// termini slobodni pita se baza pri svakom prikazu koraka (task 05). Keširana lista
/// slotova u stanju bi značila da korisnik nakon povratka nazad bira iz zastarjele liste i
/// dobije `409` na potvrdi — tačno ono što ovaj flow postoji da izbjegne.
///
/// Zato su polja samo identifikatori i vrijeme: to je sve što `book_appointment` traži.
@immutable
class BookingFlowState {
  const BookingFlowState({
    this.serviceId,
    this.employeeId,
    this.employeeChosen = false,
    this.date,
    this.startTime,
    this.note,
  });

  /// Prazan flow — početno stanje i ono na koje "kreni ispočetka" vraća.
  static const BookingFlowState empty = BookingFlowState();

  /// Izabrana usluga. Home ekran je preselektuje kroz `?serviceId=` na `/book/service`.
  final String? serviceId;

  /// Izabrani radnik, ili `null` za "bilo koji".
  ///
  /// **`null` je ovdje legitiman izbor, ne "nije izabrano".** Kad vertikala ne traži izbor
  /// radnika (`requireStaffChoice = false`), korisnik svjesno bira "bilo koji" i flow ide
  /// dalje sa `null`-om, kojeg `book_appointment` popuni sam. Zbog toga postoji
  /// [employeeChosen] — uslov `employeeId != null` bi značio da "bilo koji" nikad ne prođe
  /// validaciju koraka i da korisnik zaglavi na drugom ekranu.
  final String? employeeId;

  /// Da li je korak izbora radnika prošao. Razlikuje "bilo koji" od "još nije biran".
  final bool employeeChosen;

  /// Izabrani datum.
  final LocalDate? date;

  /// Izabrano vrijeme. Ostaje `null` u `date_only` modu — vrijeme dodjeljuje salon
  /// (`docs/05 §4.1`).
  final LocalTime? startTime;

  /// Napomena salonu. Opciono polje zadnjeg koraka.
  final String? note;

  /// Kopija sa izmijenjenim poljima.
  ///
  /// **Ne može obrisati polje** — `copyWith(employeeId: null)` vraća staru vrijednost, kao
  /// i svuda gdje je `copyWith` pisan ovako. Brisanje izbora je [clearFrom], koje čisti
  /// korak *i sve nakon njega*, jer djelimično očišćeno stanje (bez datuma, sa vremenom)
  /// nije stanje koje ijedan korak zna prikazati.
  BookingFlowState copyWith({
    String? serviceId,
    String? employeeId,
    bool? employeeChosen,
    LocalDate? date,
    LocalTime? startTime,
    String? note,
  }) => BookingFlowState(
    serviceId: serviceId ?? this.serviceId,
    employeeId: employeeId ?? this.employeeId,
    employeeChosen: employeeChosen ?? this.employeeChosen,
    date: date ?? this.date,
    startTime: startTime ?? this.startTime,
    note: note ?? this.note,
  );

  /// Bira "bilo koji radnik" — prolazi korak bez radnika.
  BookingFlowState withAnyEmployee() => BookingFlowState(
    serviceId: serviceId,
    employeeChosen: true,
    date: date,
    startTime: startTime,
    note: note,
  );

  /// Briše izbor na zadanom koraku i na svim koracima nakon njega.
  ///
  /// Promjena usluge mora oboriti i radnika i termin: druga usluga ima drugo trajanje i
  /// druge radnike, pa slot izabran za prethodnu više ne postoji u listi koju će baza
  /// vratiti. Bez ovoga korisnik nosi nevažeći termin do potvrde i tamo dobije `409` koji
  /// izgleda kao tuđa krivica.
  BookingFlowState clearFrom(BookingStep step) => switch (step) {
    BookingStep.service => empty,
    BookingStep.employee => BookingFlowState(serviceId: serviceId),
    BookingStep.slot => BookingFlowState(
      serviceId: serviceId,
      employeeId: employeeId,
      employeeChosen: employeeChosen,
    ),
    BookingStep.details => BookingFlowState(
      serviceId: serviceId,
      employeeId: employeeId,
      employeeChosen: employeeChosen,
      date: date,
      startTime: startTime,
    ),
  };

  /// Da li je [step] popunjen dovoljno da se ide dalje.
  ///
  /// [dateOnly] dolazi iz `vertical.bookingRules.granularity`: u `date_only` modu je datum
  /// dovoljan, jer vrijeme dodjeljuje salon.
  bool isStepComplete(BookingStep step, {required bool dateOnly}) =>
      switch (step) {
        BookingStep.service => serviceId != null,
        BookingStep.employee => employeeChosen,
        BookingStep.slot =>
          date != null && (dateOnly || startTime != null),
        BookingStep.details => true,
      };

  /// Prvi korak koji nije popunjen, ili `null` kad je flow spreman za slanje.
  ///
  /// Ekran ga koristi kao guard: korisnik koji otvori `/book/slot` iz deep linka bez
  /// izabrane usluge mora nazad na prvi nepopunjen korak, a ne vidjeti prazan spisak
  /// termina za uslugu koja ne postoji.
  BookingStep? firstIncompleteStep({required bool dateOnly}) {
    for (final step in BookingStep.values) {
      if (!isStepComplete(step, dateOnly: dateOnly)) return step;
    }
    return null;
  }

  /// Flow je spreman za `book_appointment`.
  bool isReadyToSubmit({required bool dateOnly}) =>
      firstIncompleteStep(dateOnly: dateOnly) == null;

  @override
  bool operator ==(Object other) =>
      other is BookingFlowState &&
      other.serviceId == serviceId &&
      other.employeeId == employeeId &&
      other.employeeChosen == employeeChosen &&
      other.date == date &&
      other.startTime == startTime &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    serviceId,
    employeeId,
    employeeChosen,
    date,
    startTime,
    note,
  );

  @override
  String toString() =>
      'BookingFlowState(service: $serviceId, employee: $employeeId, '
      'chosen: $employeeChosen, date: $date, time: $startTime)';
}
