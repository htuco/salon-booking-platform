/// Imena dana i zapis datuma za booking ekrane.
///
/// Ne koristi `intl` `DateFormat`: on traži učitane locale podatke za `bs`, kojih u
/// `flutter_test` okruženju nema, pa bi traka datuma radila u app-i a padala u testu.
/// Imena dana su ionako već u `.arb`-u — radno vrijeme ih koristi od taska 10.
///
/// Datum se piše brojčano (`14.09.2026.`), bez imena mjeseca. Imena mjeseci bi bila
/// dvanaest novih `.arb` ključeva za podatak koji u traci od sedam dana nikome ne treba,
/// a u sažetku ga nosi ime dana ("Petak, 14.09.2026.").
library;

import 'package:core_domain/core_domain.dart';

import '../../l10n/generated/app_localizations.dart';

/// Puno ime dana za [LocalDate.weekday] (1 = ponedjeljak, po `DateTime`).
String weekdayLong(AppLocalizations l10n, int weekday) => switch (weekday) {
  DateTime.monday => l10n.dayMonday,
  DateTime.tuesday => l10n.dayTuesday,
  DateTime.wednesday => l10n.dayWednesday,
  DateTime.thursday => l10n.dayThursday,
  DateTime.friday => l10n.dayFriday,
  DateTime.saturday => l10n.daySaturday,
  _ => l10n.daySunday,
};

/// Kratko ime dana za traku datuma.
String weekdayShort(AppLocalizations l10n, int weekday) => switch (weekday) {
  DateTime.monday => l10n.dayShortMonday,
  DateTime.tuesday => l10n.dayShortTuesday,
  DateTime.wednesday => l10n.dayShortWednesday,
  DateTime.thursday => l10n.dayShortThursday,
  DateTime.friday => l10n.dayShortFriday,
  DateTime.saturday => l10n.dayShortSaturday,
  _ => l10n.dayShortSunday,
};

/// `14.09.2026.`
String formatDate(LocalDate date) =>
    '${date.day.toString().padLeft(2, '0')}.'
    '${date.month.toString().padLeft(2, '0')}.'
    '${date.year}.';

/// `Petak, 14.09.2026.` — zapis za sažetak zadnjeg koraka i success ekran.
String formatDateWithWeekday(AppLocalizations l10n, LocalDate date) =>
    '${weekdayLong(l10n, date.weekday)}, ${formatDate(date)}';

/// [count] uzastopnih dana počevši od [start].
///
/// Računa se preko `DateTime(y, m, d + i)`, koji sam normalizuje prelaz mjeseca i godine.
/// **Ne** preko `add(Duration(days: 1))`: to je aritmetika nad trajanjem, pa na dan
/// prelaska na ljetno računanje vremena pomjeri i datum.
///
/// Ovo je kalendar, ne dostupnost: koji od ovih dana ima slobodan termin zna samo
/// `get_available_dates` (task 05).
List<LocalDate> daysFrom(LocalDate start, int count) {
  final dani = <LocalDate>[];
  for (var i = 0; i < count; i++) {
    final dan = DateTime(start.year, start.month, start.day + i);
    dani.add(LocalDate(dan.year, dan.month, dan.day));
  }
  return dani;
}

/// Kratke oznake dana za zaglavlje kalendara, od ponedjeljka: `P U S Č P S N`.
///
/// Prvo slovo punog imena, a ne zasebni `.arb` ključevi: "Ponedjeljak" → "P". Kad se ime
/// dana promijeni (ili prevod stigne), zaglavlje ide s njim.
///
/// `substring`, ne `characters.first`: ovaj fajl namjerno ne uvozi Flutter (`characters`
/// dolazi kroz njega), a sva slova bosanske abecede su jedna UTF-16 jedinica.
List<String> weekdayInitials(AppLocalizations l10n) => [
  for (var dan = DateTime.monday; dan <= DateTime.sunday; dan++)
    weekdayLong(l10n, dan).substring(0, 1).toUpperCase(),
];

/// "Maj 2026" — zaglavlje kalendara.
String formatMonth(AppLocalizations l10n, LocalDate date) =>
    '${_mjesec(l10n, date.month)} ${date.year}';

String _mjesec(AppLocalizations l10n, int month) => switch (month) {
  DateTime.january => l10n.monthJanuary,
  DateTime.february => l10n.monthFebruary,
  DateTime.march => l10n.monthMarch,
  DateTime.april => l10n.monthApril,
  DateTime.may => l10n.monthMay,
  DateTime.june => l10n.monthJune,
  DateTime.july => l10n.monthJuly,
  DateTime.august => l10n.monthAugust,
  DateTime.september => l10n.monthSeptember,
  DateTime.october => l10n.monthOctober,
  DateTime.november => l10n.monthNovember,
  _ => l10n.monthDecember,
};

/// Prvi dan mjeseca pomjerenog za [offset] mjeseci od [start].
///
/// `DateTime(y, m + offset, 1)` sam normalizuje prelaz godine — decembar + 1 je januar
/// sljedeće godine, bez ijednog uslova.
LocalDate monthOffsetFrom(LocalDate start, int offset) {
  final prvi = DateTime(start.year, start.month + offset);
  return LocalDate(prvi.year, prvi.month, 1);
}

/// Svi dani mjeseca kojem [anyDayInMonth] pripada.
///
/// Broj dana se ne nabraja tabelom: `DateTime(y, m + 1, 0)` je zadnji dan tekućeg mjeseca,
/// pa prijestupna godina izlazi sama.
List<LocalDate> daysOfMonth(LocalDate anyDayInMonth) {
  final zadnji = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 0).day;
  return [
    for (var dan = 1; dan <= zadnji; dan++)
      LocalDate(anyDayInMonth.year, anyDayInMonth.month, dan),
  ];
}
