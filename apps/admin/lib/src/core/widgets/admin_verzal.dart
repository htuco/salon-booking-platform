import 'package:flutter/material.dart';

/// Tekst primarnog dugmeta **u verzalu** — `+ NOVI TERMIN`, `POTVRDI` (`adminv2/export/`).
///
/// Flutter nema `text-transform`, pa verzal mora biti u stringu. `semanticsLabel` zato
/// nosi original: čitač ekrana „POTVRDI" čita slovo po slovo kao skraćenicu.
///
/// Stil dolazi od dugmeta (`AdminText.actionLabel` kroz `styleFrom(textStyle: …)`); ovaj
/// widget mijenja samo slova.
class AdminVerzal extends StatelessWidget {
  const AdminVerzal(this.tekst, {this.style, super.key});

  final String tekst;

  /// Stil teksta; bez njega važi stil roditelja (dugme, `DefaultTextStyle`).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      Text(tekst.toUpperCase(), semanticsLabel: tekst, style: style);
}
