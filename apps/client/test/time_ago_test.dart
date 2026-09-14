import 'package:client/src/features/reviews/time_ago.dart';
import 'package:client/src/l10n/generated/app_localizations_bs.dart';
import 'package:flutter_test/flutter_test.dart';

/// `timeAgo` je jedina čista funkcija u tasku 20, pa se mjeri bez ijednog widgeta.
///
/// **`now` se prosljeđuje, ne čita iz sata.** Task 17 je u ovom repou našao tri zatečena
/// testa koja su bila zelena samo u dijelu dana ili sedmice; funkcija koja sama zove
/// `DateTime.now()` je tačno taj rod greške.
void main() {
  final l10n = AppLocalizationsBs();
  final sada = DateTime.utc(2026, 9, 14, 12);

  String prije(Duration koliko) =>
      timeAgo(l10n, sada.subtract(koliko), now: sada);

  test('danas nije „prije 0 dana"', () {
    expect(prije(Duration.zero), 'danas');
    expect(prije(const Duration(hours: 5)), 'danas');
  });

  test('dani, sa bosanskim pluralom', () {
    expect(prije(const Duration(days: 1)), 'prije 1 dan');
    expect(prije(const Duration(days: 3)), 'prije 3 dana');
    expect(prije(const Duration(days: 6)), 'prije 6 dana');
  });

  test('sedmica je jednina bez broja', () {
    // „prije 1 sedmicu" nije rečenica koju bi neko napisao.
    expect(prije(const Duration(days: 7)), 'prije sedmicu');
    expect(prije(const Duration(days: 14)), 'prije 2 sedmice');
  });

  test('mjesec je jednina bez broja — doslovno sa handoffa', () {
    expect(prije(const Duration(days: 31)), 'prije mjesec');
    expect(prije(const Duration(days: 70)), 'prije 2 mjeseca');
  });

  test('godina', () {
    expect(prije(const Duration(days: 365)), 'prije godinu');
    expect(prije(const Duration(days: 800)), 'prije 2 godine');
  });

  group('granice biraju najveću jedinicu koja daje broj veći od nule', () {
    test('6 dana je još uvijek u danima, 7 prelazi u sedmice', () {
      expect(prije(const Duration(days: 6)), contains('dana'));
      expect(prije(const Duration(days: 7)), contains('sedmicu'));
    });

    test('29 dana je u sedmicama, 30 prelazi u mjesece', () {
      expect(prije(const Duration(days: 29)), contains('sedmic'));
      expect(prije(const Duration(days: 30)), contains('mjesec'));
    });

    test('364 dana je u mjesecima, 365 prelazi u godine', () {
      expect(prije(const Duration(days: 364)), contains('mjesec'));
      expect(prije(const Duration(days: 365)), contains('godinu'));
    });
  });

  test('datum u budućnosti ne daje „prije -2 dana"', () {
    // Sat uređaja koji kasni ili pogrešan unos pri importu. Negativan broj u ovom
    // tekstu izgleda kao kvar aplikacije, a nije.
    expect(
      timeAgo(l10n, sada.add(const Duration(days: 2)), now: sada),
      'danas',
    );
  });
}
