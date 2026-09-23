/// Živi primjeri uz vremenske postavke (task 44).
///
/// Vlasnik ne zna šta „3 sata" znači za klijenta dok ne vidi primjer na satu. Svaki primjer
/// je **tekst izveden iz jedne postavke**, na fiksnom terminu u 9:00 — ne izračunat slot.
/// Računanje slotova u Dartu bi bio drugi availability engine; ovdje se samo sabira i
/// oduzima sat, pa tekst ne može tvrditi ništa što baza ne provodi drugačije.
///
/// `null` znači da polje trenutno nije broj (prazno ili u kucanju) — primjer se tada ne
/// prikazuje, umjesto da laže sa starom vrijednošću.
library;

/// Početak termina na kojem se svi primjeri računaju.
const _terminMinuta = 9 * 60;

String _sat(int minutaUDanu) {
  final m = minutaUDanu % (24 * 60);
  return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
}

String _sati(int h) => switch (h % 10) {
  1 when h % 100 != 11 => '$h sat',
  2 || 3 || 4 when h % 100 < 12 || h % 100 > 14 => '$h sata',
  _ => '$h sati',
};

String _dana(int d) => d % 10 == 1 && d % 100 != 11 ? '$d dan' : '$d dana';

/// „prethodnog dana u 21:00", „2 dana ranije u 9:00" ili „u 6:00" (isti dan).
String _trenutakPrije(int satiPrije) {
  final minuta = _terminMinuta - satiPrije * 60;
  if (minuta >= 0) return 'u ${_sat(minuta)}';
  final danaRanije = (-minuta + 24 * 60 - 1) ~/ (24 * 60);
  final vrijeme = _sat(minuta + danaRanije * 24 * 60);
  return danaRanije == 1
      ? 'prethodnog dana u $vrijeme'
      : '${_dana(danaRanije)} ranije u $vrijeme';
}

/// `min_cancel_hours`.
String? primjerRokaOtkazivanja(int? sati) {
  if (sati == null) return null;
  if (sati == 0) {
    return 'Primjer: termin u 9:00 klijent može otkazati sve do 9:00. '
        'Vrijedi odmah — i za već zakazane termine.';
  }
  return 'Primjer: sa ${_sati(sati)} klijent termin u 9:00 može otkazati '
      'najkasnije ${_trenutakPrije(sati)} — poslije toga mora nazvati salon. '
      'Vrijedi odmah — i za već zakazane termine.';
}

/// `min_advance_booking_hours`.
String? primjerNajranijeg(int? sati) {
  if (sati == null) return null;
  if (sati == 0) {
    return 'Primjer: klijent može zakazati i termin koji počinje za par minuta.';
  }
  return 'Primjer: sa ${_sati(sati)} termin u 9:00 klijent može zakazati '
      'najkasnije ${_trenutakPrije(sati)}.';
}

/// `max_advance_booking_days`.
String? primjerKalendara(int? dana) {
  if (dana == null) return null;
  return 'Primjer: klijent danas vidi termine za narednih ${_dana(dana)}; '
      'dan poslije toga se otvara sutra.';
}

/// `slot_step_minutes` — salonski korak, osim za usluge koje imaju svoj (task 43).
String? primjerKoraka(int? minuta) {
  if (minuta == null || minuta <= 0) return null;
  final pocetci = [for (var i = 0; i < 3; i++) _sat(_terminMinuta + i * minuta)]
      .join(', ');
  return 'Primjer: klijentu se nude početci $pocetci… '
      'Usluga sa svojim korakom ima prednost.';
}

/// `buffer_minutes`.
String? primjerPauze(int? minuta) {
  if (minuta == null) return null;
  if (minuta == 0) {
    return 'Primjer: poslije termina 9:00–9:30 sljedeći može početi odmah u 9:30.';
  }
  return 'Primjer: poslije termina 9:00–9:30 sljedeći može početi '
      'najranije u ${_sat(_terminMinuta + 30 + minuta)}.';
}
