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
