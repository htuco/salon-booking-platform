/// OKLCH — perceptualni prostor boja u kojem se brand boja potamnjuje (ADR-0025).
///
/// `readableOn` u `contrast.dart` pomjera svjetlinu u HSL-u, što je dovoljno za tekst koji
/// samo treba preći prag. Za **uloge teme** (`primary`, `brandLine`, `brandInk`) to nije
/// dovoljno: HSL svjetlina nije perceptualna, pa roze potamnjena u HSL-u ode u smeđu. OKLCH
/// drži ton (H) i zasićenost (C) dok se mijenja samo L — boja ostaje ista, samo tamnija.
///
/// Formule su Björn Ottossonove (Oklab, 2020), iste kao u referentnoj JS implementaciji na
/// dnu `prototype/beauty/Beauty Tema.dc.html`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'contrast.dart';

/// Boja u OKLCH: svjetlina 0–1, hroma ≥ 0, ton u stepenima 0–360.
@immutable
class Oklch {
  const Oklch(this.l, this.c, this.h);

  factory Oklch.fromColor(Color color) {
    final r = _uLinearno(color.r);
    final g = _uLinearno(color.g);
    final b = _uLinearno(color.b);

    final lk = _kubniKorijen(
      0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
    );
    final mk = _kubniKorijen(
      0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
    );
    final sk = _kubniKorijen(
      0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
    );

    final okL = 0.2104542553 * lk + 0.7936177850 * mk - 0.0040720468 * sk;
    final okA = 1.9779984951 * lk - 2.4285922050 * mk + 0.4505937099 * sk;
    final okB = 0.0259040371 * lk + 0.7827717662 * mk - 0.8086757660 * sk;

    final c = math.sqrt(okA * okA + okB * okB);
    var h = math.atan2(okB, okA) * 180 / math.pi;
    if (h < 0) h += 360;
    return Oklch(okL, c, h);
  }

  final double l;
  final double c;
  final double h;

  Oklch withL(double value) => Oklch(value.clamp(0.0, 1.0), c, h);

  /// Nazad u sRGB. Boja van gamuta se **siječe** po kanalu — za potamnjivanje brand boje to
  /// je dovoljno, jer tamniji ton iste hrome uvijek ostaje unutar gamuta ili vrlo blizu.
  Color toColor({double alpha = 1.0}) {
    final hRad = h * math.pi / 180;
    final okA = c * math.cos(hRad);
    final okB = c * math.sin(hRad);

    final lk = l + 0.3963377774 * okA + 0.2158037573 * okB;
    final mk = l - 0.1055613458 * okA - 0.0638541728 * okB;
    final sk = l - 0.0894841775 * okA - 1.2914855480 * okB;

    final ll = lk * lk * lk;
    final mm = mk * mk * mk;
    final ss = sk * sk * sk;

    final r = 4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss;
    final g = -1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss;
    final b = -0.0041960863 * ll - 0.7034186147 * mm + 1.7076147010 * ss;

    return Color.from(
      alpha: alpha,
      red: _uGamu(r),
      green: _uGamu(g),
      blue: _uGamu(b),
    );
  }
}

/// Potamni [color] u OKLCH (korak 0.004 u L, isti C i H) dok kontrast sa [background] ne
/// pređe [target]. Ako je prag već pređen, vraća boju netaknutu.
///
/// Korak je iz handoffa. Vraća crnu tek kad L dođe do nule — na bijeloj pozadini svaki
/// prag do 21:1 se dostigne prije toga.
Color darkenTo(Color color, Color background, double target) {
  if (contrastRatio(color, background) >= target) return color;
  var oklch = Oklch.fromColor(color);
  var kandidat = color;
  while (oklch.l > 0 && contrastRatio(kandidat, background) < target) {
    oklch = oklch.withL(oklch.l - 0.004);
    kandidat = oklch.toColor();
  }
  return kandidat;
}

double _uLinearno(double kanal) => kanal <= 0.04045
    ? kanal / 12.92
    : math.pow((kanal + 0.055) / 1.055, 2.4).toDouble();

double _uGamu(double linearno) {
  final v = linearno <= 0.0031308
      ? 12.92 * linearno
      : 1.055 * math.pow(linearno, 1 / 2.4).toDouble() - 0.055;
  return v.clamp(0.0, 1.0);
}

double _kubniKorijen(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
