import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/formatters.dart';
import 'time_ago.dart';

/// `/reviews` — prosjek, histogram 5→1 i lista recenzija (`SPEC.md` 5m, `13-recenzije.png`).
///
/// **Pod-ekran bez tab bara**, kao i `/gallery`.
///
/// ## Read-only, i to je odluka a ne nedostatak
///
/// Handoff na dnu crta dugme „Ostavi recenziju". Ekran ga nema: recenzije dolaze iz admina
/// ili importa (task 20, Zamke), klijent nad `reviews` nema nijedan write grant, a dugme
/// koje otvori formu koja ne može spasiti tekst je gore od dugmeta kojeg nema. Kad pisanje
/// dobije svoj task, dugme se vraća zajedno sa RPC-om koji ga podupire.
///
/// ## Dva izvora, jedan ekran
///
/// Prosjek i histogram računa baza nad **svim** ocjenama; lista prikazuje samo recenzije
/// **sa tekstom**. Zato salon može imati 142 ocjene i tri kartice, i to nije nesklad nego
/// tačno ono što handoff crta.
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(salonRatingProvider);
    final reviews = ref.watch(salonReviewsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // **Back header, ne `AppBar`.** Handoff (`13-recenzije.png`) crta „← Početna"
            // pa „Recenzije" kao veliki serif u tijelu. `AppBar` daje mali sans naslov i
            // platformski chevron — isti ekran, ali vizuelno iz druge aplikacije.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: BackHeader(
                label: l10n.navHome,
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go(ClientRoute.home.path),
              ),
            ),
            Expanded(
              child: switch (summary) {
                AsyncLoading() => const _Kostur(),
                AsyncError() => _Prazno(poruka: l10n.reviewsEmpty),
                // Salon bez ijedne ocjene nema red u agregatu — `null`, ne red sa nulama.
                AsyncData(value: null) => _Prazno(poruka: l10n.reviewsEmpty),
                AsyncData(:final value?) => _Sadrzaj(
                  summary: value,
                  reviews: reviews.valueOrNull ?? const <Review>[],
                ),
                _ => const _Kostur(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Sadrzaj extends StatelessWidget {
  const _Sadrzaj({required this.summary, required this.reviews});

  final SalonRatingSummary summary;
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sada = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          l10n.reviewsTitle,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        _Sazetak(summary: summary),
        const SizedBox(height: AppSpacing.xl),
        // Salon sa ocjenama a bez ijedne napisane recenzije: prazna lista ispod „142
        // ocjene" izgleda kao podatak koji se nije učitao, pa se objašnjava jednom
        // rečenicom umjesto da se ćuti.
        if (reviews.isEmpty)
          Text(l10n.reviewsNoText, style: Theme.of(context).textTheme.bodySmall)
        else
          for (final review in reviews) ...[
            _Kartica(review: review, sada: sada),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

/// Prosjek lijevo u serifu, histogram desno — okvir iz handoffa.
class _Sazetak extends StatelessWidget {
  const _Sazetak({required this.summary});

  final SalonRatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(border: Border.all(color: scheme.outline)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatRating(summary.average),
                style: theme.textTheme.displayLarge,
              ),
              Text(l10n.reviewsOutOfFive, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 5 pa naniže, kao u handoffu — rastući histogram bi najbolju ocjenu
                // gurnuo na dno, gdje je oko ne traži.
                for (var zvjezdica = 5; zvjezdica >= 1; zvjezdica--) ...[
                  _Red(
                    zvjezdica: zvjezdica,
                    udio: summary.share(zvjezdica),
                    label: l10n.reviewsHistogramLabel(
                      zvjezdica,
                      summary.countFor(zvjezdica),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.homeRatingCount(summary.total),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Red extends StatelessWidget {
  const _Red({
    required this.zvjezdica,
    required this.udio,
    required this.label,
  });

  final int zvjezdica;
  final double udio;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      label: label,
      excludeSemantics: true,
      // Traka je obojeni pravougaonik i ne proizvodi semantički čvor; bez `container`
      // labela nema na šta da se zakači (v. `StarRating`).
      container: true,
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text('$zvjezdica', style: theme.textTheme.bodySmall),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: scheme.surfaceContainerHighest),
                  FractionallySizedBox(
                    widthFactor: udio.clamp(0, 1),
                    child: Container(color: scheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Jedna recenzija — ime, datum, zvjezdice, tekst.
class _Kartica extends StatelessWidget {
  const _Kartica({required this.review, required this.sada});

  final Review review;
  final DateTime sada;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  review.authorName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                timeAgo(l10n, review.createdAt, now: sada),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Zvjezdice su ikone; vrijednost za čitač ekrana nosi labela, ne one same.
          StarRating(
            value: review.rating.toDouble(),
            size: 20,
            semanticsLabel: l10n.reviewsStarsLabel(review.rating),
          ),
          if (review.hasComment) ...[
            const SizedBox(height: AppSpacing.md),
            Text(review.comment!, style: theme.textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }
}

/// Prazno stanje pod back headerom — naslov ostaje, jer ekran bez naslova iznad poruke
/// izgleda kao da se nije učitao.
class _Prazno extends StatelessWidget {
  const _Prazno({required this.poruka});

  final String poruka;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            0,
          ),
          child: Text(
            l10n.reviewsTitle,
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        Expanded(child: EmptyState(message: poruka)),
      ],
    );
  }
}

class _Kostur extends StatelessWidget {
  const _Kostur();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        const SkeletonLoader(height: 140),
        const SizedBox(height: AppSpacing.xl),
        for (var i = 0; i < 3; i++) ...[
          SkeletonLoader.card(),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
