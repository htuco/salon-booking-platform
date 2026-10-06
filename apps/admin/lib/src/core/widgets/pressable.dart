/// Dodirna površina bez ripplea: pritisnuto stanje je providnost, kao na iOS-u.
///
/// Za dugmad u zaglavlju i tekst koji je dugme (naslov sa biračem salona, „Otkaži",
/// „Sačuvaj"). Meta je najmanje 44 × 44 bez obzira na veličinu sadržaja.
library;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.pressedOpacity = 0.5,
    this.minSize = AdminSize.touchTarget,
    super.key,
  });

  final Widget child;

  /// `null` je onemogućeno stanje: bez dodira i bez pritisnutog stanja.
  final VoidCallback? onTap;

  /// Ime za čitač ekrana kad sadržaj nije tekst (ikona).
  final String? semanticLabel;
  final double pressedOpacity;
  final double minSize;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pritisnut = false;
  bool _fokusVidljiv = false;

  void _postavi(bool vrijednost) {
    if (_pritisnut != vrijednost) setState(() => _pritisnut = vrijednost);
  }

  @override
  Widget build(BuildContext context) {
    final aktivan = widget.onTap != null;
    final boje = context.adminColors;
    // Fokusabilno i aktivno sa tastature (Enter, razmak), kao svaka meta u adminu.
    return FocusableActionDetector(
      enabled: aktivan,
      onShowFocusHighlight: (v) => setState(() => _fokusVidljiv = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: aktivan,
        label: widget.semanticLabel,
        excludeSemantics: widget.semanticLabel != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: aktivan ? (_) => _postavi(true) : null,
          onTapUp: aktivan ? (_) => _postavi(false) : null,
          onTapCancel: aktivan ? () => _postavi(false) : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminRadius.small),
              border: Border.all(
                color: boje.action.withValues(alpha: _fokusVidljiv ? 1 : 0),
                width: 2,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: widget.minSize,
                minHeight: widget.minSize,
              ),
              child: AnimatedOpacity(
                opacity: _pritisnut ? widget.pressedOpacity : 1,
                duration: const Duration(milliseconds: 90),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
