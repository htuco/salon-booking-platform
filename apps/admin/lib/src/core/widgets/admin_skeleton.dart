import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';
import '../theme/admin_tokens.dart';

/// Kostur učitavanja za admin — ono što stoji umjesto `CircularProgressIndicator`-a.
///
/// Klijentska aplikacija ovo već ima (`core_ui` `SkeletonLoader`) i admin ga **ne može
/// uvesti**: `core_ui` gradi temu iz tenant boja, a admin je jedan build za sve salone i
/// ima vlastite tokene. To pravilo drži `apps/admin/test/no_hardcoded_colors_test.dart`
/// („admin ne uvozi core_ui"), pa je ovo namjerni blizanac, ne duplikat iz nemara.
///
/// Zašto uopšte: spinner kaže „čekaj", kostur kaže „evo šta stiže" i **zadržava
/// raspored**, pa ekran ne poskoči kad podaci dođu. Uz to, spinner je Material potpis —
/// debljina, tempo i luk se ne daju uskladiti sa ostatkom redizajna.
class AdminSkeleton extends StatefulWidget {
  const AdminSkeleton({
    required this.height,
    this.width = double.infinity,
    this.radius = AdminRadius.base,
    super.key,
  });

  /// Jedan red tabele ili liste.
  factory AdminSkeleton.row({Key? key}) =>
      AdminSkeleton(key: key, height: 44, radius: AdminRadius.base);

  /// Kartica metrike ili panel.
  factory AdminSkeleton.card({Key? key, double height = 96}) =>
      AdminSkeleton(key: key, height: height, radius: AdminRadius.base);

  /// Jedan red teksta.
  factory AdminSkeleton.text({Key? key, double width = 160}) =>
      AdminSkeleton(key: key, height: 14, width: width);

  final double height;
  final double width;
  final double radius;

  @override
  State<AdminSkeleton> createState() => _AdminSkeletonState();
}

class _AdminSkeletonState extends State<AdminSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;

    // `docs/02 §14` trazi postovanje `reduce motion`. Korisnik koji je ugasio animacije
    // to najcesce radi zbog mucnine ili migrene, a puls koji se ponavlja u nedogled je
    // tacno ono sto to izaziva — pa se iscrta mirna povrsina.
    final bezAnimacije = MediaQuery.disableAnimationsOf(context);

    final povrsina = DecoratedBox(
      decoration: BoxDecoration(
        color: boje.neutralTint,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: SizedBox(height: widget.height, width: widget.width),
    );

    if (bezAnimacije) return ExcludeSemantics(child: povrsina);

    return ExcludeSemantics(
      child: FadeTransition(
        // Ne ide do pune prozirnosti: kostur koji nestane pa se vrati izgleda kao
        // treptaj sadrzaja, a ne kao ucitavanje.
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
        child: povrsina,
      ),
    );
  }
}

/// Lista kostura — najčešći oblik, jer većina admin ekrana učitava tabelu ili listu.
///
/// **Broj redova se prilagođava visini, ne piše fiksno.** Prva verzija je crtala šest
/// redova uvijek i time prelivala uski prikaz za 68 px — kostur koji prelijeva je gori
/// od spinnera, jer prelivanje ostane i kad podaci stignu u testu. Zato se crta onoliko
/// redova koliko stane, najviše [redova].
class AdminSkeletonList extends StatelessWidget {
  const AdminSkeletonList({this.redova = 6, this.razmak, super.key});

  /// Gornja granica, ne fiksan broj.
  final int redova;
  final double? razmak;

  @override
  Widget build(BuildContext context) {
    final gap = razmak ?? AdminSpacing.md;
    const visinaReda = 44.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        var koliko = redova;
        if (constraints.maxHeight.isFinite) {
          // Koliko punih (red + razmak) stane u raspoloživu visinu.
          final stane = ((constraints.maxHeight + gap) / (visinaReda + gap))
              .floor();
          koliko = stane.clamp(1, redova);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < koliko; i++) ...[
              if (i > 0) SizedBox(height: gap),
              AdminSkeleton.row(),
            ],
          ],
        );
      },
    );
  }
}

/// Indikator unutar dugmeta dok radnja traje.
///
/// `CircularProgressIndicator` je Material potpis — debljina, tempo i luk se ne daju
/// uskladiti sa ostatkom redizajna, a unutar dugmeta je i najvidljiviji. Ovo su tri
/// tačke koje pulsiraju u nizu, u **boji teksta tog dugmeta**: na koralnom dugmetu bijele
/// tačke nestanu isto kao što bi i bijeli tekst.
class AdminButtonBusy extends StatefulWidget {
  const AdminButtonBusy({this.color, super.key});

  /// Boja tačaka. Kad je `null`, uzima se `DefaultTextStyle` dugmeta.
  final Color? color;

  @override
  State<AdminButtonBusy> createState() => _AdminButtonBusyState();
}

class _AdminButtonBusyState extends State<AdminButtonBusy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boja = widget.color ?? DefaultTextStyle.of(context).style.color;
    final bezAnimacije = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Radnja je u toku',
      child: SizedBox(
        height: 16,
        width: 40,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AdminSpacing.xs),
                Opacity(
                  // Bez animacije sve tri stoje na punoj vidljivosti — poruka je i dalje
                  // „radi se", samo se ne mice.
                  opacity: bezAnimacije ? 1 : _opacityZa(i, _controller.value),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: boja,
                      borderRadius: BorderRadius.circular(AdminRadius.base),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Tri tacke, svaka pomjerena za trecinu ciklusa. Ne gasi se do nule, jer tacka koja
  /// nestane izgleda kao da je nema, a ne kao da ceka.
  static double _opacityZa(int index, double t) {
    final faza = (t + index / 3) % 1.0;
    return 0.35 + 0.65 * (faza < 0.5 ? faza * 2 : (1 - faza) * 2);
  }
}
