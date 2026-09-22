import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/formatters.dart';
import '../../core/router/app_router.dart';
import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'service_groups.dart';

/// `/services` — pun cjenovnik, `prototype/ui/SPEC.md` **5i** (`09-usluge.png`).
///
/// Korijen taba **Usluge**, prve ćelije u traci. Početna nosi isječak (tri usluge i put
/// ovamo); ovdje stoji sve što salon nudi, grupisano po kategoriji.
///
/// ## Red usluge je dodirna meta, ne red u tabeli
///
/// Tap vodi **pravo u booking** sa preselektovanom uslugom, preskačući korak 1 kao izbor
/// — `?serviceId=` router čita od taska 11, isto kao sa Početne. Zato podnaslov ekrana
/// to i kaže: cjenovnik koji se može dodirnuti, a ne izgleda tako, se čita kao statična
/// lista i korisnik se vraća na dugme „Zakaži".
///
/// ## Grupisanje se vidi samo kad ima šta da se vidi
///
/// Kad sve usluge dijele jednu kategoriju — ili kad je nijedna nema — zaglavlja nema i
/// lista je ravna, tačno kao `09-usluge.png`. Jedno zaglavlje iznad cijele liste ne
/// grupiše ništa, a oduzima prvi ekran telefona. Razvrstavanje radi [groupByCategory].
///
/// Radi **bez prijave**: `servicesProvider` čita javni katalog pod `anon` politikom.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final vertical = verticalOf(ref);
    final services = ref.watch(servicesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.lg,
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Naslov je `servicePlural`, ne `.arb` literal: ordinacija ovdje ima
                    // „Pregledi", a ćelija trake ispod već nosi isti taj tekst.
                    Text(
                      vertical.terms.servicePlural,
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.servicesHint,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            switch (services) {
              AsyncData(:final value) when value.isEmpty => SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  message: l10n.servicesEmpty,
                  icon: LucideIcons.inbox,
                ),
              ),
              AsyncData(:final value) => _Lista(
                groups: groupByCategory(value),
                prikaziCijene: vertical.features.prices,
              ),
              AsyncError() => SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  message: l10n.bookingServicesUnavailable,
                  icon: LucideIcons.cloudOff,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(servicesProvider),
                ),
              ),
              _ => const SliverToBoxAdapter(child: _Kostur()),
            },
            // Zadnji red bi inače završio tačno ispod trake; razmak je da se može
            // pročitati kad se skrol dovede do dna.
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }
}

/// Cjenovnik — grupe sa zaglavljem, ili ravna lista kad je grupa jedna.
class _Lista extends StatelessWidget {
  const _Lista({required this.groups, required this.prikaziCijene});

  final List<ServiceGroup> groups;

  /// `VerticalFeatures.prices` — ordinacija ne objavljuje cijene pregleda.
  final bool prikaziCijene;

  @override
  Widget build(BuildContext context) {
    // Jedna grupa = nema šta da se grupiše. Zaglavlje bi tada bilo naslov iznad cijele
    // liste, što `09-usluge.png` nema.
    final saZaglavljima = groups.length > 1;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      sliver: SliverList.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) => _Grupa(
          group: groups[index],
          prikaziZaglavlje: saZaglavljima,
          prikaziCijene: prikaziCijene,
          prviRazmak: index > 0,
        ),
      ),
    );
  }
}

class _Grupa extends StatelessWidget {
  const _Grupa({
    required this.group,
    required this.prikaziZaglavlje,
    required this.prikaziCijene,
    required this.prviRazmak,
  });

  final ServiceGroup group;
  final bool prikaziZaglavlje;
  final bool prikaziCijene;
  final bool prviRazmak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prviRazmak) const SizedBox(height: AppSpacing.xxl),
        if (prikaziZaglavlje) ...[
          Text(
            // Grupa bez kategorije uz imenovane grupe mora dobiti ime, inače joj redovi
            // izgledaju kao nastavak prethodne. Salonov tekst se ne izmišlja — „Ostalo"
            // je naše, i zato je u `.arb`-u.
            group.isUncategorized ? l10n.servicesUncategorized : group.category,
            style: kicker(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final (index, service) in group.services.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.md),
          SelectableRow(
            title: service.name,
            subtitle: formatDurationLong(service.durationMinutes),
            // Prazan okvir kad fotografije nema je predviđeno stanje (task 22).
            imageUrl: service.imageUrl,
            trailingText: prikaziCijene ? formatPrice(service.price) : null,
            onTap: () => context.go(
              '${ClientRoute.bookService.path}?serviceId=${service.id}',
            ),
          ),
        ],
      ],
    );
  }
}

/// Skeleton u tenant temi, ne spinner (`docs/02 §14`).
class _Kostur extends StatelessWidget {
  const _Kostur();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        children: [
          SkeletonLoader.card(),
          const SizedBox(height: AppSpacing.md),
          SkeletonLoader.card(),
          const SizedBox(height: AppSpacing.md),
          SkeletonLoader.card(),
          const SizedBox(height: AppSpacing.md),
          SkeletonLoader.card(),
        ],
      ),
    );
  }
}
