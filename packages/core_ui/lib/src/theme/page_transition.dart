import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;

/// Jedan prelaz između ekrana za sve platforme: kratak fade uz pomak po X osi.
///
/// Zamjenjuje par `FadeForwardsPageTransitionsBuilder` (Android) +
/// `CupertinoPageTransitionsBuilder` (iOS), zbog kojeg je isti push izgledao
/// različito na dva telefona (FE-201). Trajanje i krive su iz handoffa i ostaju
/// ispod 300 ms iz `docs/02 §14`.
///
/// Stari ekran se ne pomjera: novi se pretapa **preko** njega, pa ispod nikad
/// nema praznog platna koje bi bljesnulo bijelo.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  /// Pomak novog ekrana na početku prelaza, u logičkim pikselima.
  static const double pomak = 10;

  static const Duration push = Duration(milliseconds: 220);
  static const Duration pop = Duration(milliseconds: 180);

  @override
  Duration get transitionDuration => push;

  @override
  Duration get reverseTransitionDuration => pop;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Tokom povlačenja prstom prelaz prati prst linearno, bez krive.
    final Animation<double> tok = route.popGestureInProgress
        ? animation
        : CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

    Widget prelaz = FadeTransition(opacity: tok, child: child);
    // Reduce Motion: ostaje samo fade.
    if (!MediaQuery.disableAnimationsOf(context)) {
      prelaz = AnimatedBuilder(
        animation: tok,
        builder: (context, dijete) => Transform.translate(
          offset: Offset((1 - tok.value) * pomak, 0),
          child: dijete,
        ),
        child: prelaz,
      );
    }

    // Swipe-back je na iOS-u dio Cupertino rute, ne prelaza — bez ovoga bi ga
    // zamjena buildera tiho ukinula.
    final platforma = Theme.of(context).platform;
    if (platforma == TargetPlatform.iOS || platforma == TargetPlatform.macOS) {
      prelaz = _PovlacenjeNazad<T>(route: route, child: prelaz);
    }
    return prelaz;
  }
}

/// Povlačenje sa lijeve ivice vraća na prethodni ekran, kao na iOS-u.
///
/// Koristi javni predictive-back ugovor rute (`handleStartBackGesture` …), pa ne
/// zavisi od privatnog Cupertino detektora.
class _PovlacenjeNazad<T> extends StatefulWidget {
  const _PovlacenjeNazad({required this.route, required this.child});

  final PageRoute<T> route;
  final Widget child;

  @override
  State<_PovlacenjeNazad<T>> createState() => _PovlacenjeNazadState<T>();
}

class _PovlacenjeNazadState<T> extends State<_PovlacenjeNazad<T>> {
  /// Širina ivice koja hvata povlačenje — ista kao u Cupertino ruti.
  static const double _ivica = 20;

  bool _aktivno = false;

  double get _sirina => context.size?.width ?? 1;

  void _pocni(DragStartDetails _) {
    if (!widget.route.popGestureEnabled) return;
    _aktivno = true;
    widget.route.handleStartBackGesture(progress: 1);
  }

  void _pomjeri(DragUpdateDetails d) {
    if (!_aktivno) return;
    final napredak = (widget.route.animation!.value - d.primaryDelta! / _sirina)
        .clamp(0.0, 1.0);
    widget.route.handleUpdateBackGestureProgress(progress: napredak);
  }

  void _zavrsi(DragEndDetails d) {
    if (!_aktivno) return;
    _aktivno = false;
    // Brzina u širinama ekrana po sekundi, kao u Cupertino ruti.
    final brzina = (d.primaryVelocity ?? 0) / _sirina;
    final nazad = brzina.abs() >= 1
        ? brzina > 0
        : widget.route.animation!.value < 0.5;
    if (nazad) {
      widget.route.handleCommitBackGesture();
    } else {
      widget.route.handleCancelBackGesture();
    }
  }

  void _prekini() {
    if (!_aktivno) return;
    _aktivno = false;
    widget.route.handleCancelBackGesture();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: _ivica + MediaQuery.paddingOf(context).left,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: _pocni,
            onHorizontalDragUpdate: rtl
                ? (d) => _pomjeri(
                    DragUpdateDetails(
                      globalPosition: d.globalPosition,
                      delta: -d.delta,
                      primaryDelta: -d.primaryDelta!,
                    ),
                  )
                : _pomjeri,
            onHorizontalDragEnd: rtl
                ? (d) => _zavrsi(
                    DragEndDetails(
                      velocity: d.velocity,
                      primaryVelocity: -(d.primaryVelocity ?? 0),
                    ),
                  )
                : _zavrsi,
            onHorizontalDragCancel: _prekini,
          ),
        ),
      ],
    );
  }
}
