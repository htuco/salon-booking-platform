/// Datum i vrijeme na bosanskom — jedno mjesto za cijelu admin app.
///
/// **Bez `intl` paketa i bez `.arb` fajlova**, za razliku od klijentske app-e. Klijent se
/// prevodi (`app_bs.arb` + generisani `AppLocalizations`) jer ide u store i jednog dana
/// dobija drugi jezik; admin je interna alatka koja govori jezikom repoa. Uvođenje
/// lokalizacije ovdje bi značilo drugi mehanizam za dvanaest imena mjeseci.
///
/// Prije taska 30 su ova imena stajala kao privatne statike u `appointments_screen.dart`.
/// Drugi ekran kojem je zatrebao datum bi ih prepisao kod sebe — i od tog trenutka bi
/// „juni" na jednom ekranu bio „jun" na drugom, a niko to ne bi vidio dok se ne otvore
/// jedan uz drugi.
library;

import 'package:core_domain/core_domain.dart';

const List<String> kDaniSedmice = [
  'Ponedjeljak',
  'Utorak',
  'Srijeda',
  'Četvrtak',
  'Petak',
  'Subota',
  'Nedjelja',
];

/// Nominativ, kako ga canvas i piše: `Ponedjeljak, 18. maj`.
const List<String> kMjeseci = [
  'januar',
  'februar',
  'mart',
  'april',
  'maj',
  'juni',
  'juli',
  'august',
  'septembar',
  'oktobar',
  'novembar',
  'decembar',
];

/// `Ponedjeljak, 18. maj` — naslov dana iz `3b`.
///
/// Bez godine: raspored se gleda za dan koji traje, a godina u naslovu odvlači oko na
/// podatak koji se ne mijenja.
String datumDugo(DateTime dan) =>
    '${kDaniSedmice[dan.weekday - 1]}, ${dan.day}. ${kMjeseci[dan.month - 1]}';

/// `18. maj 2026.` — datum kad dan nije današnji i mora se prepoznati bez konteksta.
String datumSaGodinom(DateTime dan) =>
    '${dan.day}. ${kMjeseci[dan.month - 1]} ${dan.year}.';

/// `Danas`, `Sutra`, `Jučer`, inače ime dana u sedmici.
String naslovDana(DateTime dan, {DateTime? danas}) {
  final sada = danas ?? DateTime.now();
  final razlika = DateTime(
    dan.year,
    dan.month,
    dan.day,
  ).difference(DateTime(sada.year, sada.month, sada.day)).inDays;

  return switch (razlika) {
    0 => 'Danas',
    1 => 'Sutra',
    -1 => 'Jučer',
    _ => kDaniSedmice[dan.weekday - 1],
  };
}

/// `13:00` — vrijeme termina, bez sekundi.
///
/// Sekunde u rasporedu ne znače ništa, a `LocalTime.toString()` ih nosi.
String vrijemeHhMm(LocalTime vrijeme) =>
    '${vrijeme.hour.toString().padLeft(2, '0')}:'
    '${vrijeme.minute.toString().padLeft(2, '0')}';

/// Isto što i [naslovDana], ali nad datumom iz baze.
///
/// `LocalDate` namjerno nema `DateTime` (v. njegov doc: `DateTime.parse('2026-09-11')` daje
/// UTC ponoć, a Sarajevo je istočno od Greenwicha). Ovdje se gradi **lokalna** ponoć iz tri
/// broja, što tu zamku zaobilazi, i koristi se samo za poređenje kalendarskih dana.
String naslovDanaZaDatum(LocalDate dan, {DateTime? danas}) =>
    naslovDana(DateTime(dan.year, dan.month, dan.day), danas: danas);
