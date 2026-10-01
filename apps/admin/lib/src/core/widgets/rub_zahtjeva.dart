/// Isprekidan rub zahtjeva na čekanju — kalendar (`3c`, FE-403) i Danas (`6a`).
///
/// Zahtjev se odvaja **oblikom**, ne samo bojom (WCAG 1.4.1). Bio je u `calendar_screen.dart`
/// dok ga je čitao samo kalendar; Danas crta isti rub na zahtjevu, u rasporedu i u panelu.
library;

import 'package:flutter/material.dart';

import '../theme/admin_tokens.dart';

/// Isprekidan rub oko termina koji čeka potvrdu — `3c`, DoD FE-403.
///
/// **Zašto rub, a ne još jedna boja.** „Čeka potvrdu" već ima svoj par iz
/// [AdminStatusColors.waiting], ali na mreži sa pet statusa nijansa podloge nije dovoljna
/// da se zahtjev odvoji od termina koji je već dogovoren — a to je jedina razlika koja
/// vlasniku mijenja radnju: potvrđen termin se gleda, zahtjev se rješava. Isprekidana
/// linija to nosi **oblikom**, pa radi i kad boje nema (WCAG 1.4.1), isto kao što
/// [_Srafura] nosi neradno vrijeme.
///
/// Crta se preko sadržaja, ne ispod: blok ima svoju podlogu, pa bi rub ispod nje nestao.
class _RubZahtjevaPainter extends CustomPainter {
  const _RubZahtjevaPainter({required this.boja, required this.radius});

  final Color boja;
  final double radius;

  /// Crta i razmak. Par 4/3 daje oko 14 crta na tipičnoj širini bloka — dovoljno gusto da
  /// se na 51 px visokom bloku ne pročita kao puna linija.
  static const double _crta = 4;
  static const double _razmak = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final olovka = Paint()
      ..color = boja
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Pola debljine unutra, inače `stroke` izađe iz `Size` i gornja crta se odsiječe.
    final putanja = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
          Radius.circular(radius),
        ),
      );

    for (final mjera in putanja.computeMetrics()) {
      for (var d = 0.0; d < mjera.length; d += _crta + _razmak) {
        canvas.drawPath(
          mjera.extractPath(d, (d + _crta).clamp(0.0, mjera.length)),
          olovka,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RubZahtjevaPainter old) =>
      old.boja != boja || old.radius != radius;
}

/// Omotač koji doda [_RubZahtjevaPainter] samo kad [ceka], inače propusti [child] netaknut.
///
/// Postoji da uslov ne uđe u stablo kao `ceka ? CustomPaint(...) : child`: taj oblik
/// mijenja tip čvora na istom mjestu, pa `InkWell` ispod izgubi stanje kad se status
/// termina promijeni iz „čeka potvrdu" u „potvrđeno".
class RubZahtjeva extends StatelessWidget {
  const RubZahtjeva({
    required this.ceka,
    required this.boja,
    required this.child,
    this.radius = AdminRadius.base,
    super.key,
  });

  final bool ceka;
  final Color boja;
  final Widget child;

  /// Radius kartice ili pilule oko koje se rub crta.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: ceka
          ? _RubZahtjevaPainter(boja: boja, radius: radius)
          : null,
      child: child,
    );
  }
}
