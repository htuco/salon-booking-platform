import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tap meta preko neprozirnog sadržaja (slike) — dodir, tastatura i **vidljiv fokus**.
///
/// FE-502: `GestureDetector` se ne da fokusirati, pa tastatura, switch access i čitač
/// ekrana na webu do njega ne dolaze. `InkWell` bi to riješio, ali njegov preklop se crta
/// na `Material` **ispod** djeteta — preko slike fokus ne bi bio vidljiv. Ovdje se prsten
/// fokusa crta **iznad** sadržaja, u `primary` boji tenanta.
///
/// Prsten je unutrašnji (ne širi metu) i uglat, kao sve u ovom sistemu (`SPEC.md`: radius 0).
class AppTappable extends StatefulWidget {
  const AppTappable({
    required this.onTap,
    required this.child,
    this.semanticLabel,
    super.key,
  });

  final VoidCallback? onTap;
  final Widget child;

  /// Ime mete za čitač ekrana. Slika ga sama nema.
  final String? semanticLabel;

  /// Debljina prstena fokusa. 2 px: 1 px hairline se na slici ne razlikuje od ivice.
  static const double focusRingWidth = 2;

  @override
  State<AppTappable> createState() => _AppTappableState();
}

class _AppTappableState extends State<AppTappable> {
  bool _fokus = false;

  @override
  Widget build(BuildContext context) {
    final aktivan = widget.onTap != null;

    return Semantics(
      button: aktivan,
      enabled: aktivan,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: aktivan,
        mouseCursor: aktivan ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _fokus = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call(),
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: _fokus
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: AppTappable.focusRingWidth,
                    )
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
