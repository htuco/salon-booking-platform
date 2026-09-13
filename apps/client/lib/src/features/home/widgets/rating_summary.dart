import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../salon_rating.dart';

/// Kartica sa ocjenom salona — prosjek u serifu, zvjezdice, broj ocjena i citat
/// (`01-pocetna.png`, sekcija "Recenzije").
///
/// Zvjezdice se crtaju iz prosjeka, ne prosljeđuju kao gotov broj: "4,8" i četiri
/// zvjezdice na istom ekranu su greška koju niko ne prijavi, a svako primijeti.
class RatingSummary extends StatelessWidget {
  const RatingSummary({
    required this.rating,
    required this.countLabel,
    required this.averageLabel,
    super.key,
  });

  final SalonRating rating;

  /// "142 ocjene" — ICU plural sastavlja ekran.
  final String countLabel;

  /// Prosjek u lokalnom formatu ("4,8"), jer zarez naspram tačke zna ekran.
  final String averageLabel;

  static const int _maxZvjezdica = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(averageLabel, style: theme.textTheme.displayMedium),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Zvjezdice(average: rating.average),
                    const SizedBox(height: AppSpacing.xs),
                    Text(countLabel, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (rating.quote != null && rating.quote!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('„${rating.quote!}"', style: theme.textTheme.bodyLarge),
            if (rating.author != null && rating.author!.isNotEmpty)
              Text('— ${rating.author!}', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Zvjezdice extends StatelessWidget {
  const _Zvjezdice({required this.average});

  final double average;

  static const double _velicina = 18;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Zaokruživanje na pola zvjezdice: 4.8 daje pet punih, 4.2 četiri i po. Bez toga
    // bi 4.8 dalo četiri i ekran bi protivrječio broju pored sebe.
    final polovine = (average * 2).round();

    return Semantics(
      // Zvjezdice su slika istog broja koji stoji lijevo od njih — čitač ekrana bi
      // inače pročitao pet bezimenih ikona.
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= RatingSummary._maxZvjezdica; i++)
            Icon(
              // Lucide nema punu zvjezdicu — cijeli set je linijski. Puna naspram
              // prazne se zato razlikuje **bojom**, a polovina vlastitim glifom.
              polovine == i * 2 - 1 ? LucideIcons.starHalf : LucideIcons.star,
              size: _velicina,
              color: polovine >= i * 2 - 1
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}
