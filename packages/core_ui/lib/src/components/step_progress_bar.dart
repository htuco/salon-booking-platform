import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

/// Koliko je koraka prošlo u višekoračnom flowu — `prototype/ui/SPEC.md` 5c–5f,
/// "back + Korak 1 od 4 + 4-segment progress".
///
/// Segmenti, ne `LinearProgressIndicator`: traka koja se puni kaže "nešto se učitava", a
/// ovdje se ništa ne učitava — korisnik gleda koliko je odluka ostalo. Četiri odvojena
/// polja to kažu i bez teksta, i rade isto kad vertikala ima drugi broj koraka.
///
/// Ne zna ništa o bookingu. Prima brojeve, pa ista traka služi i onboardingu i admin
/// flowu; naziv koraka daje ekran, jer tekst zavisi od vertikale.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    required this.totalSteps,
    required this.currentStep,
    this.semanticsLabel,
    super.key,
  });

  /// Ukupan broj koraka. Booking ih ima četiri (`docs/01 §12`).
  final int totalSteps;

  /// Trenutni korak, **brojan od 1**. Vrijednost van raspona se steže, jer je traka
  /// ukras stanja, a ne mjesto gdje se ruši ekran.
  final int currentStep;

  /// Tekstualna verzija za čitač ekrana ("Korak 2 od 4"). Sastavlja je ekran — `core_ui`
  /// ne zna jezik (`core_ui.dart`, pravilo 3).
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trenutni = currentStep.clamp(1, totalSteps);

    return Semantics(
      label: semanticsLabel,
      // Segmenti su ukras iste informacije koju nosi labela iznad; bez ovoga čitač
      // ekrana pročita četiri prazna okvira.
      excludeSemantics: true,
      child: Row(
        children: [
          for (var korak = 1; korak <= totalSteps; korak++) ...[
            if (korak > 1) const SizedBox(width: AppSize.stepBar),
            Expanded(
              child: AnimatedContainer(
                duration: AppDuration.fast,
                height: AppSize.stepBar,
                decoration: BoxDecoration(
                  color: korak <= trenutni
                      // Pređeni korak je u boji teksta, ne brenda: traka stoji uz CTA u
                      // brand boji, pa bi dvije brand površine na istom ekranu takmičile.
                      ? scheme.onSurface
                      // Prošli i budući koraci se razlikuju bojom brenda i neutralnom
                      // površinom, ne jačinom iste boje: `withOpacity` na zlatnoj i na
                      // roze daje dva različita kontrasta prema pozadini.
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
