import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Red od pet zvjezdica koji crta ocjenu (`01-pocetna.png`, `13-recenzije.png`).
///
/// **Uvijek se izvodi iz broja, nikad se ne prosljeđuje kao gotov broj punih zvjezdica.**
/// „4,8" i četiri zvjezdice na istom ekranu su greška koju niko ne prijavi, a svako
/// primijeti — a dogodi se čim dva mjesta računaju isto.
///
/// Boja dolazi iz teme (`onSurface` za punu, `onSurfaceVariant` za praznu), ne iz paleta
/// handoffa: zvjezdice su oblik, a oblik je platformski. Zlatna zvjezdica bi bila boja
/// jednog brenda na ekranu svakog tenanta.
class StarRating extends StatelessWidget {
  const StarRating({
    required this.value,
    this.size = 18,
    this.max = 5,
    this.semanticsLabel,
    super.key,
  });

  /// Ocjena, 0–[max]. Zaokružuje se na pola zvjezdice.
  final double value;

  final double size;
  final int max;

  /// Šta čitač ekrana pročita umjesto pet ikona („5 od 5 zvjezdica").
  ///
  /// Kad je `null`, zvjezdice su **nijeme** — tako treba tamo gdje isti broj već stoji
  /// kao tekst odmah pored njih (kartica na Početnoj), jer bi ga inače pročitao dvaput.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Zaokruživanje na pola: 4.8 daje pet punih, 4.2 četiri i po. Bez toga bi 4.8 dalo
    // četiri i ekran bi protivrječio broju pored sebe.
    final polovine = (value * 2).round();

    return Semantics(
      // Zvjezdice su slika broja — čitač ekrana bi inače pročitao pet bezimenih ikona.
      excludeSemantics: true,
      // **`container: true` nije višak.** Ikone same ne proizvode nijedan semantički
      // čvor, pa `label` bez ovoga nema na šta da se zakači i tiho nestane — labela
      // koja postoji u kodu a ne postoji u stablu.
      container: semanticsLabel != null,
      label: semanticsLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= max; i++)
            Icon(
              // Lucide nema punu zvjezdicu — cijeli set je linijski. Puna naspram prazne
              // se zato razlikuje **bojom**, a polovina vlastitim glifom.
              polovine == i * 2 - 1 ? LucideIcons.starHalf : LucideIcons.star,
              size: size,
              color: polovine >= i * 2 - 1
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}
