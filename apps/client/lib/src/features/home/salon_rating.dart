import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sažetak ocjena salona — prosjek, broj ocjena i jedna istaknuta recenzija.
///
/// Odgovara sekciji "Recenzije" sa `01-pocetna.png`: "4,8 ★★★★★ 142 ocjene" i citat.
class SalonRating {
  const SalonRating({
    required this.average,
    required this.count,
    this.quote,
    this.author,
  });

  /// Prosjek od 1 do 5.
  final double average;

  /// Broj ocjena iza prosjeka.
  final int count;

  /// Istaknuta recenzija i njen potpis ("Nedim H."). Oboje može izostati — salon sa
  /// ocjenama a bez napisanog teksta je uredno stanje.
  final String? quote;
  final String? author;
}

/// Ocjena salona, ili `null` dok je nema.
///
/// **Danas je uvijek `null`, i to nije previd.** Šema nema tabelu `reviews` — pravi je
/// [task 20](../../../../tasks/sprint-2/20-galerija-recenzije.md), čiji DoD (red 17) nosi
/// i tabelu i RLS i seed. Dok toga nema, sekcija na Početnoj se **sakriva**, po istom
/// pravilu po kojem se sakriva i galerija salona bez slika (DoD taska 20, red 19):
/// Početna crta ono što postoji i ćuti o ostalom.
///
/// Provider stoji ovdje, a ne u `core_api`, upravo zato što iza njega nema repozitorija.
/// Kad task 20 donese tabelu, tijelo ide u `ReviewRepository` i ovaj fajl nestaje —
/// sekcija i njen test ostaju netaknuti.
final salonRatingProvider = FutureProvider<SalonRating?>((ref) async => null);
