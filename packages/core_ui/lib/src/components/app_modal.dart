import 'package:flutter/material.dart';

/// Jedan jezik otvaranja modala i bottom sheeta (FE-203).
///
/// `showDialog` ne gleda `pageTransitionsTheme`, pa prelaz ekrana (FE-201) modale ne
/// pokriva — svaki poziv nosi svoju animaciju. Zato su obje ovdje, na jednom mjestu.
abstract final class AppModal {
  /// Modal: scrim se pretapa, dijalog uz to raste sa 0,98 na 1.
  static const Duration dialogTrajanje = Duration(milliseconds: 180);

  /// Početna veličina dijaloga. Mala razlika — pokret se osjeti, ne vidi.
  static const double dialogPocetnaSkala = 0.98;

  /// Bottom sheet: klizanje iz dna.
  static const Duration sheetTrajanje = Duration(milliseconds: 240);

  /// Otvara dijalog sa animacijom iz handoffa.
  ///
  /// Dodir na scrim i sistemski „nazad" zatvaraju ga kad je [barrierDismissible].
  /// Scrim je `colorScheme.scrim` — neutralan token teme, nikad brand boja.
  static Future<T?> dialog<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) => showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Theme.of(context).colorScheme.scrim,
    transitionDuration: dialogTrajanje,
    pageBuilder: (context, _, _) => SafeArea(child: Builder(builder: builder)),
    transitionBuilder: (context, animacija, _, dijete) {
      final kriva = CurvedAnimation(
        parent: animacija,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: kriva,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: MediaQuery.disableAnimationsOf(context)
                ? 1
                : dialogPocetnaSkala,
            end: 1,
          ).animate(kriva),
          child: dijete,
        ),
      );
    },
  );

  /// Otvara bottom sheet: klizi iz dna, zatvara se povlačenjem nadolje.
  ///
  /// Sheet sa listom koja se skroluje treba `DraggableScrollableSheet` unutar
  /// [builder]-a: tada gesta skrola ne zatvara sheet dok lista nije na vrhu.
  static Future<T?> sheet<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) => showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    enableDrag: true,
    showDragHandle: false,
    barrierColor: Theme.of(context).colorScheme.scrim,
    sheetAnimationStyle: const AnimationStyle(
      duration: sheetTrajanje,
      reverseDuration: sheetTrajanje,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
  );
}
