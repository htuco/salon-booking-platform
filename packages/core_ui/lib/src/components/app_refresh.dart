import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

/// Povlačenje nadolje za osvježavanje, bez Material spinnera (FE-501).
///
/// Gestu, prag povlačenja i semantiku („osvježi") daje `RefreshIndicator.noSpinner`.
/// To je platformsko ponašanje i ovdje se ne piše ponovo. Crta se samo ono što
/// je Material crtao: umjesto kružnog spinnera ide **hairline traka na vrhu liste**, u
/// boji teksta, dok [onRefresh] traje.
///
/// Traka, ne skeleton: sadržaj je već na ekranu i ne smije nestati dok se osvježava.
/// Skeleton bi ga zamijenio kosturom i vratio, pa bi lista trepnula. Traka kaže samo
/// „nešto se dešava", a ostalo ostaje na mjestu.
///
/// [child] mora biti scrollable sa `AlwaysScrollableScrollPhysics`, isto kao kod
/// `RefreshIndicator`. Kratka ili prazna lista inače ne prima povlačenje.
class AppRefresh extends StatefulWidget {
  const AppRefresh({required this.onRefresh, required this.child, super.key});

  /// Ponovo traži podatke od izvora. Traka stoji dok se `Future` ne završi.
  final RefreshCallback onRefresh;

  final Widget child;

  @override
  State<AppRefresh> createState() => _AppRefreshState();
}

class _AppRefreshState extends State<AppRefresh> {
  var _radi = false;

  Future<void> _osvjezi() async {
    setState(() => _radi = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _radi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator.noSpinner(onRefresh: _osvjezi, child: widget.child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _radi ? 1 : 0,
              duration: AppDuration.fast,
              child: _radi ? const _Traka() : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Segment koji klizi preko hairline trake. Širina je trećina, trajanje je gornja
/// granica iz tokena (`AppDuration.slow`) puta četiri, da pokret ne bude nervozan.
class _Traka extends StatefulWidget {
  const _Traka();

  @override
  State<_Traka> createState() => _TrakaState();
}

class _TrakaState extends State<_Traka> with SingleTickerProviderStateMixin {
  late final AnimationController _kontroler = AnimationController(
    vsync: this,
    duration: AppDuration.slow * 4,
  )..repeat();

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      // Traka je ukras stanja koje `RefreshIndicator` već najavljuje čitaču ekrana.
      excludeSemantics: true,
      child: SizedBox(
        height: 2,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sirina = constraints.maxWidth;
            final segment = sirina / 3;
            return AnimatedBuilder(
              animation: _kontroler,
              builder: (context, _) => Stack(
                children: [
                  Container(color: scheme.surfaceContainerHighest),
                  Positioned(
                    left: -segment + (sirina + segment) * _kontroler.value,
                    top: 0,
                    bottom: 0,
                    width: segment,
                    child: ColoredBox(color: scheme.onSurface),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
