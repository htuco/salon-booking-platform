import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

/// Grupisanje slobodnih slotova za prikaz.
///
/// **Ovaj fajl nastaje tek u tasku 24, i to nakon što je bug već bio na ekranu.**
/// `distinctTimes` postoji od taska 11 i nosi komentar koji tačno opisuje zamku, ali nije imao
/// nijedan test. Admin ekran za ručni unos (task 24) je crtao sirovu listu i pokazivao
/// „09:00 09:00 09:15 09:15…" — po jedan chip za svakog slobodnog radnika.
///
/// Analiza to ne može vidjeti (oba tipa su `List`), a ni unit test repozitorija: i duplirana
/// lista je **ispravan** izlaz iz `get_available_slots`. Vidi se samo na ekranu, ili ovdje.
void main() {
  const emir = '20000000-0000-4000-8000-000000000001';
  const amar = '20000000-0000-4000-8000-000000000002';

  group('distinctTimes', () {
    test('isto vrijeme za dva radnika daje jedan chip', () {
      // Ovo je tačno ono što baza vrati za „bilo koji radnik": jedan red po (vrijeme, radnik).
      final slotovi = [
        const AvailableSlot(startTime: LocalTime(9, 0), employeeId: amar),
        const AvailableSlot(startTime: LocalTime(9, 0), employeeId: emir),
        const AvailableSlot(startTime: LocalTime(9, 15), employeeId: emir),
        const AvailableSlot(startTime: LocalTime(9, 15), employeeId: amar),
      ];

      expect(slotovi.distinctTimes, [
        const LocalTime(9, 0),
        const LocalTime(9, 15),
      ]);
    });

    test('sortira rastuće, bez obzira kako su redovi stigli', () {
      // Baza sortira, ali `order by 1, 2` nad dva radnika ne garantuje da će ekran dobiti
      // vremena u rastućem redu nakon bilo kakve izmjene upita.
      final slotovi = [
        const AvailableSlot(startTime: LocalTime(11, 30), employeeId: emir),
        const AvailableSlot(startTime: LocalTime(9, 0), employeeId: amar),
        const AvailableSlot(startTime: LocalTime(10, 15), employeeId: emir),
      ];

      expect(slotovi.distinctTimes, [
        const LocalTime(9, 0),
        const LocalTime(10, 15),
        const LocalTime(11, 30),
      ]);
    });

    test('jedan radnik — lista ostaje ista dužina', () {
      // Kad je radnik izabran, nema šta da se sažme; sažimanje ne smije pojesti vremena.
      final slotovi = [
        const AvailableSlot(startTime: LocalTime(9, 0), employeeId: emir),
        const AvailableSlot(startTime: LocalTime(9, 15), employeeId: emir),
        const AvailableSlot(startTime: LocalTime(9, 30), employeeId: emir),
      ];

      expect(slotovi.distinctTimes, hasLength(3));
    });

    test('prazna lista daje praznu listu, ne grešku', () {
      expect(const <AvailableSlot>[].distinctTimes, isEmpty);
    });

    test('rezultat je nepromjenjiv', () {
      // Ekran ga drži u `build`-u; slučajna izmjena bi bila bug koji se pojavi tek pri
      // sljedećem crtanju.
      final vremena = [
        const AvailableSlot(startTime: LocalTime(9, 0), employeeId: emir),
      ].distinctTimes;

      expect(() => vremena.add(const LocalTime(10, 0)), throwsUnsupportedError);
    });
  });

  group('employeesAt', () {
    test('vraća sve radnike slobodne u tom vremenu', () {
      final slotovi = [
        const AvailableSlot(startTime: LocalTime(9, 0), employeeId: amar),
        const AvailableSlot(startTime: LocalTime(9, 0), employeeId: emir),
        const AvailableSlot(startTime: LocalTime(9, 15), employeeId: emir),
      ];

      expect(slotovi.employeesAt(const LocalTime(9, 0)), [amar, emir]);
      expect(slotovi.employeesAt(const LocalTime(9, 15)), [emir]);
    });

    test('vrijeme koje nije slobodno daje praznu listu', () {
      final slotovi = [
        const AvailableSlot(startTime: LocalTime(9, 0), employeeId: emir),
      ];

      expect(slotovi.employeesAt(const LocalTime(12, 0)), isEmpty);
    });
  });
}
