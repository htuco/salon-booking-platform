/// Formatiranje cijene i trajanja za prikaz.
///
/// Stoji u aplikaciji, ne u `core_ui`: komponente primaju gotove stringove baš zato što
/// ne znaju jezik ni valutu (`core_ui.dart`, pravilo 3). Ne stoji ni u `core_domain` —
/// model nosi `double price`, a kako se taj broj piše zavisi od tržišta, ne od domena.
library;

/// Cijena u konvertibilnim markama.
///
/// Cijela vrijednost se piše bez decimala ("15 KM", ne "15.00 KM") jer su cijene usluga
/// u praksi cijeli brojevi, a dvije nule na svakoj kartici samo zauzmu širinu koju
/// dugačka imena usluga trebaju.
String formatPrice(double price) {
  final zaokruzeno = price.roundToDouble();
  final tekst = price == zaokruzeno
      ? price.toStringAsFixed(0)
      : price.toStringAsFixed(2);
  return '$tekst KM';
}

/// Trajanje usluge: "45 min", "1 h", "1 h 30 min".
///
/// Preko sat vremena se piše u satima jer "120 min" traži od korisnika da računa —
/// farbanje i pramenovi u beauty vertikali su redovno toliko dugi (`docs/02 §3`).
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';

  final sati = minutes ~/ 60;
  final ostatak = minutes % 60;
  return ostatak == 0 ? '$sati h' : '$sati h $ostatak min';
}

/// Trajanje ispisano punom riječju: "30 minuta", "1 sat", "2 sata i 30 minuta".
///
/// Handoff u listi usluga piše "30 minuta", ne "30 min" — kratica je za gusta mjesta
/// (chip, badge), a red usluge ima prostora i čita se kao rečenica.
///
/// Bosanski broji u tri oblika, ne u dva: **1** minuta, **2–4** minute, **5+** minuta, i
/// isto se ponavlja od 21 nadalje. `'$n min'` to izbjegne, ali puna riječ ne može —
/// "2 minuta" je greška koju svako primijeti.
String formatDurationLong(int minutes) {
  if (minutes < 60) return '$minutes ${_minuta(minutes)}';

  final sati = minutes ~/ 60;
  final ostatak = minutes % 60;
  final satiTekst = '$sati ${_sat(sati)}';

  return ostatak == 0 ? satiTekst : '$satiTekst i $ostatak ${_minuta(ostatak)}';
}

/// `minuta` · `minute` · `minuta` — po zadnjoj cifri, uz izuzetak za 11–14.
String _minuta(int n) => switch (_oblik(n)) {
  _Oblik.jedan => 'minuta',
  _Oblik.malo => 'minute',
  _Oblik.mnogo => 'minuta',
};

/// `sat` · `sata` · `sati`.
String _sat(int n) => switch (_oblik(n)) {
  _Oblik.jedan => 'sat',
  _Oblik.malo => 'sata',
  _Oblik.mnogo => 'sati',
};

enum _Oblik { jedan, malo, mnogo }

/// Slavenski oblik množine: 1 → jedan, 2–4 → malo, ostalo → mnogo. Brojevi 11–14 idu u
/// `mnogo` bez obzira na zadnju cifru ("11 minuta", ne "11 minuta" preko pravila za 1).
_Oblik _oblik(int n) {
  final zadnjeDvije = n % 100;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return _Oblik.mnogo;

  return switch (n % 10) {
    1 => _Oblik.jedan,
    2 || 3 || 4 => _Oblik.malo,
    _ => _Oblik.mnogo,
  };
}
