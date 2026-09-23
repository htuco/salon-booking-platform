import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// Povlačenje nadolje za osvježavanje u adminu — ono što stoji umjesto
/// `RefreshIndicator`-ovog spinnera (FE-501).
///
/// Namjerni blizanac `AppRefresh`-a iz `core_ui`, iz istog razloga kao
/// `AdminSkeleton`: admin ne uvozi `core_ui` (`no_hardcoded_colors_test.dart`), jer ima
/// vlastite tokene, a ne tenant temu.
///
/// Gestu, prag i semantiku daje `RefreshIndicator.noSpinner`. Umjesto spinnera ide
/// hairline traka na vrhu, u boji teksta (`ink`), dok [onRefresh] traje. Sadržaj ostaje
/// na mjestu, pa tabela ne trepne.
class AdminRefresh extends StatefulWidget {
  const AdminRefresh({required this.onRefresh, required this.child, super.key});

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  State<AdminRefresh> createState() => _AdminRefreshState();
}

class _AdminRefreshState extends State<AdminRefresh> {
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
        if (_radi)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(child: _Traka()),
          ),
      ],
    );
  }
}

class _Traka extends StatefulWidget {
  const _Traka();

  @override
  State<_Traka> createState() => _TrakaState();
}

class _TrakaState extends State<_Traka> with SingleTickerProviderStateMixin {
  late final AnimationController _kontroler = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;

    // `reduce motion` (`docs/02 §14`) — mirna traka umjesto segmenta koji klizi.
    if (MediaQuery.disableAnimationsOf(context)) {
      return ExcludeSemantics(
        child: SizedBox(height: 2, child: ColoredBox(color: boje.ink)),
      );
    }

    return ExcludeSemantics(
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
                  ColoredBox(
                    color: boje.neutralTint,
                    child: const SizedBox.expand(),
                  ),
                  Positioned(
                    left: -segment + (sirina + segment) * _kontroler.value,
                    top: 0,
                    bottom: 0,
                    width: segment,
                    child: ColoredBox(color: boje.ink),
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
