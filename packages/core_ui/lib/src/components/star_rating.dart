import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Red od pet zvjezdica koji crta ocjenu (`01-pocetna.png`, `13-recenzije.png`).
///
/// **Uvijek se izvodi iz broja, nikad se ne prosljeđuje kao gotov broj punih zvjezdica.**
/// „4,8" i četiri zvjezdice na istom ekranu su greška koju niko ne prijavi, a svako
/// primijeti — a dogodi se čim dva mjesta računaju isto.
///
/// ## Zašto je ovo crtano, a ne Lucide ikona
///
/// Ostatak aplikacije koristi `lucide_icons_flutter`, ali **taj set nema punu zvjezdicu** —
/// cijeli je linijski (`star`, `starHalf`, `starOff`, nijedna popunjena). Prva verzija ovog
/// widgeta je zato punu od prazne razlikovala **bojom** iste linijske ikone, i to je na
/// živom ekranu palo: kartica sa peticom i kartica sa četvorkom su izgledale isto, jer je
/// razlika bila nijansa sive na obrisu od jednog piksela.
///
/// Uz to, razlika nošena **samo bojom** je i WCAG 1.4.1 problem: ocjena je informacija, a
/// informacija se ne smije prenositi isključivo bojom.
///
/// Puna zvjezdica je zato **ispunjena površina**, prazna je **obris**, i razlika se vidi
/// prije nego što se pročita broj pored nje.
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

  /// Šta čitač ekrana pročita umjesto pet oblika („5 od 5 zvjezdica").
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
      // Zvjezdice su slika broja — čitač ekrana bi inače pročitao pet bezimenih oblika.
      excludeSemantics: true,
      // **`container: true` nije višak.** Nacrtane zvjezdice ne proizvode nijedan
      // semantički čvor, pa `label` bez ovoga nema na šta da se zakači i tiho nestane —
      // labela koja postoji u kodu a ne postoji u stablu.
      container: semanticsLabel != null,
      label: semanticsLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= max; i++)
            CustomPaint(
              size: Size.square(size),
              painter: _Zvjezdica(
                // 2 = puna, 1 = polovina, 0 = prazna.
                popunjenost: (polovine - (i - 1) * 2).clamp(0, 2),
                puna: scheme.onSurface,
                prazna: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Jedna zvjezdica: ispunjena, polovična ili prazna.
class _Zvjezdica extends CustomPainter {
  const _Zvjezdica({
    required this.popunjenost,
    required this.puna,
    required this.prazna,
  });

  /// 0 prazna · 1 polovina · 2 puna.
  final int popunjenost;
  final Color puna;
  final Color prazna;

  /// Odnos unutrašnjeg i vanjskog poluprečnika. 0.48 drži oblik blizu Lucide zvjezdice —
  /// klasičnih 0.382 daje šiljatiju zvijezdu nego ostatak seta ikona.
  static const double _unutrasnji = 0.48;

  @override
  void paint(Canvas canvas, Size size) {
    // Mali unutrašnji rub, da obris prazne zvjezdice ne bude odsječen na ivici okvira.
    final r = size.width / 2 * 0.92;
    final centar = Offset(size.width / 2, size.height / 2);
    final putanja = _putanja(centar, r);

    // Prazna podloga se crta uvijek: ispod polovine mora stajati obris, inače polovična
    // zvjezdica izgleda kao odsječena.
    canvas.drawPath(
      putanja,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09
        ..strokeJoin = StrokeJoin.round
        ..color = popunjenost == 0 ? prazna : puna,
    );

    if (popunjenost == 0) return;

    final ispuna = Paint()..color = puna;
    if (popunjenost == 2) {
      canvas.drawPath(putanja, ispuna);
      return;
    }

    // Polovina: ista putanja, odsječena po sredini. Lijeva polovina, jer se čita slijeva.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width / 2, size.height));
    canvas.drawPath(putanja, ispuna);
    canvas.restore();
  }

  Path _putanja(Offset centar, double r) {
    final putanja = Path();
    // Kreće od vrha (-90°) pa naizmjenično vanjski/unutrašnji vrh, deset tačaka ukupno.
    for (var i = 0; i < 10; i++) {
      final poluprecnik = i.isEven ? r : r * _unutrasnji;
      final ugao = -math.pi / 2 + i * math.pi / 5;
      final tacka = Offset(
        centar.dx + poluprecnik * math.cos(ugao),
        centar.dy + poluprecnik * math.sin(ugao),
      );
      i == 0
          ? putanja.moveTo(tacka.dx, tacka.dy)
          : putanja.lineTo(tacka.dx, tacka.dy);
    }
    return putanja..close();
  }

  @override
  bool shouldRepaint(_Zvjezdica old) =>
      old.popunjenost != popunjenost ||
      old.puna != puna ||
      old.prazna != prazna;
}
