import 'package:flutter/material.dart';

/// Kontejner grana `StatefulShellRoute`-a: kao `IndexedStack`, ali sa cross-fadeom.
///
/// `StatefulShellRoute.indexedStack` mijenja tab u jednom frameu — ekran „skoči".
/// Handoff (FE-202) traži kratko pretapanje bez klizanja. Sve grane ostaju žive, kao
/// i u `IndexedStack`-u, pa skrol i stack svakog taba prežive prebacivanje.
///
/// Neaktivne grane su `Offstage` i bez tickera: ne crtaju se, ne primaju dodir i ne
/// vrte animacije. Tokom pretapanja se crtaju samo dvije: dolazeća se pretapa preko
/// odlazeće.
class TabCrossFade extends StatefulWidget {
  const TabCrossFade({
    required this.currentIndex,
    required this.children,
    super.key,
  });

  final int currentIndex;
  final List<Widget> children;

  static const Duration trajanje = Duration(milliseconds: 120);

  @override
  State<TabCrossFade> createState() => _TabCrossFadeState();
}

class _TabCrossFadeState extends State<TabCrossFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontroler = AnimationController(
    vsync: this,
    duration: TabCrossFade.trajanje,
    value: 1,
  );

  int? _odlazeci;

  @override
  void didUpdateWidget(TabCrossFade stari) {
    super.didUpdateWidget(stari);
    if (stari.currentIndex == widget.currentIndex) return;
    _odlazeci = stari.currentIndex;
    _kontroler.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted) setState(() => _odlazeci = null);
    });
  }

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduce Motion: prebacivanje bez pretapanja.
    final bezAnimacije = MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Aktivna grana ide **zadnja**, dakle iznad odlazeće: pretapa se preko nje, a
        // odlazeća ostaje puna ispod. Da blijede obje, na pola prelaza bi kroz njih
        // provirila pozadina. Ključ po indeksu čuva stanje grane kad joj se mijenja mjesto.
        for (var i = 0; i < widget.children.length; i++)
          if (i != widget.currentIndex) _grana(i, bezAnimacije),
        _grana(widget.currentIndex, bezAnimacije),
      ],
    );
  }

  Widget _grana(int i, bool bezAnimacije) {
    final aktivna = i == widget.currentIndex;
    final odlazi = !bezAnimacije && i == _odlazeci;
    final vidljiva = aktivna || odlazi;

    // `FadeTransition` stoji **uvijek**, i kad ne animira: uslovno umotavanje mijenja
    // oblik stabla, a Flutter tada gradi granu iznova — i gubi joj skrol i stack.
    final Animation<double> providnost =
        aktivna && !bezAnimacije && _odlazeci != null
        ? _kontroler
        : kAlwaysCompleteAnimation;
    return Offstage(
      key: ValueKey<int>(i),
      offstage: !vidljiva,
      child: TickerMode(
        enabled: aktivna,
        // Odlazeći tab ne prima dodir dok nestaje.
        child: IgnorePointer(
          ignoring: !aktivna,
          child: FadeTransition(opacity: providnost, child: widget.children[i]),
        ),
      ),
    );
  }
}
