import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Kartica sa ocjenom salona — prosjek u serifu, zvjezdice, broj ocjena i citat
/// (`01-pocetna.png`, sekcija „Recenzije").
///
/// Sažetak i citat dolaze iz dva izvora, i to je namjerno: prosjek računa baza nad **svim**
/// ocjenama, a citat je najnovija recenzija **sa tekstom**. Salon može imati 140 ocjena i
/// nijednu napisanu — tada kartica pokaže broj bez citata, umjesto da izmisli tekst.
class RatingSummary extends StatelessWidget {
  const RatingSummary({
    required this.summary,
    required this.countLabel,
    required this.averageLabel,
    this.quote,
    super.key,
  });

  final SalonRatingSummary summary;

  /// „142 ocjene" — ICU plural sastavlja ekran.
  final String countLabel;

  /// Prosjek u lokalnom formatu („4,8"), jer zarez naspram tačke zna ekran.
  final String averageLabel;

  /// Istaknuta recenzija, ako je ima.
  final Review? quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final istaknuta = quote;

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
                    StarRating(value: summary.average),
                    const SizedBox(height: AppSpacing.xs),
                    Text(countLabel, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (istaknuta != null && istaknuta.hasComment) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('„${istaknuta.comment!}"', style: theme.textTheme.bodyLarge),
            Text('— ${istaknuta.authorName}', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
