/// Kontrast po WCAG 2.1 — jedino mjesto gdje se ovaj odnos računa.
///
/// Ovo nije kozmetika nego stvarni rizik iz `docs/02 §14`: vlasnik salona bira boju u
/// admin aplikaciji i može izabrati žutu. Bijeli tekst na žutoj je nečitljiv, a niko iz
/// tima to neće vidjeti jer se dešava tek na tom jednom tenantu, poslije builda.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Prag WCAG AA za normalan tekst. Ispod ovoga tekst se ne smije iscrtati.
const double kWcagAa = 4.5;

/// Odnos kontrasta dvije boje, 1.0–21.0.
///
/// Koristi `computeLuminance()`, koji već radi sRGB linearizaciju po WCAG formuli, pa se
/// ovdje ne ponavlja — ponovljena formula bi se raziš la sa Flutterovom na rubnim bojama.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Crna ili bijela — ona koja je čitljivija **na** `background`.
///
/// Prag nije 0.5 luminancije nego stvarno poređenje odnosa, jer luminancija nije linearna:
/// `#C6A667` (zlatna barbera) ima luminanciju oko 0.42, što bi naivni prag proglasio
/// tamnom i stavio bijeli tekst na nju — odnos 2.6:1, pao bi AA. Poređenje odnosa bira
/// crnu i daje 8:1.
Color onColorFor(Color background) {
  const black = Color(0xFF121212);
  const white = Color(0xFFFFFFFF);
  return contrastRatio(background, black) >= contrastRatio(background, white)
      ? black
      : white;
}

/// Da li par zadovoljava WCAG AA za normalan tekst.
bool meetsAa(Color foreground, Color background) =>
    contrastRatio(foreground, background) >= kWcagAa;

/// Ista boja, posvijetljena ili potamnjena taman toliko da bude čitljiva na `background`.
///
/// Brand boja salona se koristi i kao **tekst** (naslov sekcije, link, cijena), ne samo
/// kao pozadina dugmeta. Tu `onColorFor` ne pomaže — tekst mora ostati prepoznatljivo
/// brand boja. Zato se pomjera svjetlina u HSL-u dok odnos ne pređe prag, umjesto da se
/// odustane i padne na crnu.
///
/// Vraća najbolji pronađeni ton i kad prag nije dostižan (siva na sivoj): bolje
/// maksimalno čitljiva varijanta nego tiho zadržan nečitljiv original.
Color readableOn(
  Color foreground,
  Color background, {
  double target = kWcagAa,
}) {
  if (contrastRatio(foreground, background) >= target) return foreground;

  final hsl = HSLColor.fromColor(foreground);
  // Na tamnoj pozadini boju treba posvijetliti, na svijetloj potamniti.
  final smjer = background.computeLuminance() < 0.5 ? 1.0 : -1.0;

  var best = foreground;
  var bestRatio = contrastRatio(foreground, background);

  // Korak 2% svjetline; 50 koraka pokriva cijeli raspon od bilo kojeg polazišta.
  for (var i = 1; i <= 50; i++) {
    final lightness = (hsl.lightness + smjer * i * 0.02).clamp(0.0, 1.0);
    final kandidat = hsl.withLightness(lightness).toColor();
    final ratio = contrastRatio(kandidat, background);
    if (ratio > bestRatio) {
      best = kandidat;
      bestRatio = ratio;
    }
    if (ratio >= target) return kandidat;
    if (lightness == 0.0 || lightness == 1.0) break;
  }
  return best;
}
