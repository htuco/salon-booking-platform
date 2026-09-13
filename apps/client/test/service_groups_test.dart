import 'package:client/src/features/services/service_groups.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Grupisanje cjenovnika po kategoriji — jedino pravilo ekrana `/services`.
///
/// Testira se ovdje, na čistoj funkciji, a ne kroz `pumpWidget`: rubni slučajevi
/// (prazna kategorija, jedna grupa, razmaci u unosu) su jeftini ovdje i skupi u widget
/// testu, pa bi se u praksi provjerio samo sretan slučaj.
void main() {
  Service usluga(String name, {String category = ''}) => Service(
    id: name,
    salonId: 's',
    name: name,
    category: category,
    price: 15,
    durationMinutes: 30,
  );

  test('prazna lista daje nula grupa, ne jednu praznu', () {
    expect(groupByCategory(const []), isEmpty);
  });

  test('sve bez kategorije je jedna grupa, i ta grupa je „bez kategorije"', () {
    // Ovo je stanje oba demo salona i stanje sa `09-usluge.png`: ekran tada ne crta
    // nijedno zaglavlje i lista je ravna.
    final grupe = groupByCategory([usluga('Fade'), usluga('Brada')]);

    expect(grupe, hasLength(1));
    expect(grupe.single.isUncategorized, isTrue);
    expect(grupe.single.services.map((s) => s.name), ['Fade', 'Brada']);
  });

  test('usluge se razvrstavaju po kategoriji', () {
    final grupe = groupByCategory([
      usluga('Brijanje', category: 'Brada'),
      usluga('Oblikovanje', category: 'Brada'),
      usluga('Fade', category: 'Šišanje'),
    ]);

    expect(grupe.map((g) => g.category), ['Brada', 'Šišanje']);
    expect(grupe.first.services.map((s) => s.name), [
      'Brijanje',
      'Oblikovanje',
    ]);
    expect(grupe.last.services.map((s) => s.name), ['Fade']);
  });

  test('redoslijed grupa je redoslijed u kojem su stigle, ne abecedni', () {
    // `ServiceRepository.forSalon` već sortira uzlazno po kategoriji. Drugo sortiranje
    // ovdje bi značilo dva izvora istine za isti poredak.
    final grupe = groupByCategory([
      usluga('Pranje', category: 'Njega'),
      usluga('Fade', category: 'Šišanje'),
      usluga('Brijanje', category: 'Brada'),
    ]);

    expect(grupe.map((g) => g.category), ['Njega', 'Šišanje', 'Brada']);
  });

  test('razmaci oko kategorije ne prave drugu grupu', () {
    // Kategorija se unosi rukom iz admina; ' Brada' i 'Brada' su ista kategorija sa
    // jednom greškom u kucanju, i salon ne bi razumio zašto se pojavila dvaput.
    final grupe = groupByCategory([
      usluga('Brijanje', category: 'Brada'),
      usluga('Oblikovanje', category: '  Brada  '),
    ]);

    expect(grupe, hasLength(1));
    expect(grupe.single.category, 'Brada');
  });

  test('kategorija od samih razmaka je „bez kategorije"', () {
    final grupe = groupByCategory([usluga('Fade', category: '   ')]);

    expect(grupe.single.isUncategorized, isTrue);
  });

  test('razlika u velikim slovima ostaje razlika', () {
    // Namjerno: 'Brada' i 'brada' su dva različita unosa, i spajanje bi sakrilo grešku
    // umjesto da je pokaže salonu.
    final grupe = groupByCategory([
      usluga('Brijanje', category: 'Brada'),
      usluga('Oblikovanje', category: 'brada'),
    ]);

    expect(grupe.map((g) => g.category), ['Brada', 'brada']);
  });

  test('usluge bez kategorije ostaju svoja grupa uz imenovane', () {
    final grupe = groupByCategory([
      usluga('Nešto'),
      usluga('Fade', category: 'Šišanje'),
    ]);

    expect(grupe, hasLength(2));
    expect(grupe.first.isUncategorized, isTrue);
    expect(grupe.last.category, 'Šišanje');
  });

  test('nijedna usluga se ne izgubi ni ne ponovi', () {
    final ulaz = [
      usluga('a', category: 'X'),
      usluga('b'),
      usluga('c', category: 'X'),
      usluga('d', category: 'Y'),
    ];

    final izlaz = groupByCategory(ulaz).expand((g) => g.services).toList();

    expect(izlaz, hasLength(ulaz.length));
    expect(izlaz.toSet(), ulaz.toSet());
  });
}
