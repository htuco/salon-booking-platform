import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../home/salon_schedule.dart';
import 'about_sections.dart';
import '../home/widgets/home_hero.dart';

/// `/about` — „O nama", `prototype/ui/SPEC.md` **5b** (`02-o-nama.png`).
///
/// Podruta Početne, ne šesti tab: traka ostaje, sa **Početna aktivna**, kako handoff i
/// traži. Odozgo: hero sa imenom salona, sekundarni CTA, priča salona, par fotografija,
/// radno vrijeme i kontakt.
///
/// ## Sekcije dijeli sa Početnom, i to je namjerno
///
/// Iste četiri sekcije (`about_sections.dart`) crta i Početna, inline — v. `HomeScreen`
/// za razlog. Ovaj ekran ostaje kao **ruta i deep link** na oblik iz handoffa: ime salona
/// preko fotografije, pa priča. Dvije kopije sekcija bi se razišle pri prvoj izmjeni, i to
/// bi se vidjelo tek na onom ekranu koji niko nije otvorio — zato su izvučene, a ne
/// prepisane.
///
/// ## Puna sedmica umjesto jednog reda — svjesno odstupanje od handoffa
///
/// `02-o-nama.png` radno vrijeme svodi na jedan red („Radno vrijeme · 09:00 – 20:00").
/// To je tačno samo za salon koji svaki dan radi isto. Demo barber ne radi nedjeljom, a
/// subota mu je kraća — jedan red bi na takvom salonu **lagao**, i to bi se primijetilo
/// tek kad neko dođe pred zatvorena vrata. Zato ovdje stoji cijela sedmica, sa današnjim
/// danom podebljanim; oblik reda i kartice je i dalje iz handoffa.
///
/// ## Sekcija bez podataka se sakriva
///
/// Isto pravilo kao na Početnoj: priča bez `salon.description`, fotografije bez
/// `gallery_urls`, mreže bez `vertical.features.socialLinks` — nestaju. Prazan naslov
/// izgleda kao app koji nije učitao podatke, a salonu bez opisa je to trajno stanje.
///
/// Radi **bez prijave** — svi provideri na ovom ekranu čitaju javni katalog.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final salon = ref.watch(salonProvider);

    return Scaffold(
      body: switch (salon) {
        AsyncData(:final value) => _Ucitan(salon: value),
        AsyncError() => EmptyState(
          message: l10n.salonUnavailable,
          icon: LucideIcons.cloudOff,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(salonProvider),
        ),
        _ => const _Kostur(),
      },
    );
  }
}

class _Ucitan extends ConsumerWidget {
  const _Ucitan({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vertical = verticalOf(ref);
    final hours = ref.watch(workingHoursProvider);
    final gallery = ref.watch(salonGalleryProvider);

    final schedule = SalonSchedule.fromHours(
      hours.valueOrNull ?? const <WorkingHour>[],
    );
    final status = schedule.statusAt(DateTime.now());

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: HomeHero(
            salon: salon,
            status: _statusTekst(l10n, status),
            otvoren: status is SalonOpen,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.xxxl,
            ),
            // **Outline, ne primarni CTA** (`02-o-nama.png`). Zakazivanje nije svrha
            // ovog ekrana — ono je na Početnoj i u traci — pa dugme stoji kao izlaz, ne
            // kao poziv. Dva puna CTA-a na susjednim ekranima se takmiče međusobno.
            child: AppButton(
              label: vertical.terms.bookCta,
              variant: AppButtonVariant.outline,
              onPressed: () => context.go(ClientRoute.bookService.path),
            ),
          ),
        ),
        SliverToBoxAdapter(child: AboutStory(opis: salon.description)),
        SliverToBoxAdapter(child: AboutPhotoPair(urls: gallery)),
        SliverToBoxAdapter(
          child: WorkingHoursSection(
            schedule: schedule,
            ucitava: hours.isLoading,
          ),
        ),
        SliverToBoxAdapter(
          child: ContactSection(
            salon: salon,
            prikaziMreze: vertical.features.socialLinks,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }
}

String _statusTekst(AppLocalizations l10n, SalonStatus status) =>
    switch (status) {
      SalonOpen(:final until) => l10n.openUntil(until.format()),
      SalonOpensLater(:final at) => l10n.closedOpensAt(at.format()),
      SalonClosedToday() => l10n.closedToday,
    };

/// Skeleton koji ponavlja raspored ekrana, pa sadržaj ne poskoči kad stigne.
class _Kostur extends StatelessWidget {
  const _Kostur();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SkeletonLoader(height: 320, radius: 0),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Column(
              children: [
                const SkeletonLoader(height: AppSize.ctaHeight),
                const SizedBox(height: AppSpacing.xxl),
                SkeletonLoader.text(width: 220),
                const SizedBox(height: AppSpacing.lg),
                const SkeletonLoader(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
