import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/formatters.dart';
import '../../core/router/app_router.dart';
import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../about/about_sections.dart';
import 'salon_schedule.dart';
import 'widgets/gallery_grid.dart';
import 'widgets/home_hero.dart';
import 'widgets/home_section.dart';
import 'widgets/rating_summary.dart';
import 'widgets/staff_grid.dart';

/// Home ekran — prvi pravi ekran i šablon za sve ostale (`docs/02 §3`).
///
/// Raspored je iz handoffa (`prototype/ui/` `01-pocetna.png`), odozgo: hero fotografija sa
/// imenom salona i živim statusom, primarni CTA, **Cjenovnik** (tri usluge i put do svih),
/// **Majstori**, **Galerija**, **Recenzije**.
///
/// ## Tri pravila koja se odavde kopiraju
///
/// 1. **Podaci dolaze iz providera, ne iz repozitorija.** Ekran nigdje ne dodiruje
///    `salonRepositoryProvider` — `ref.watch(salonProvider)` je cijeli pristup podacima.
/// 2. **Tekst koji se mijenja po vertikali ide kroz `vertical.terms`,** ostatak kroz
///    `.arb`. Literal "Zakaži termin" ovdje bi značio da stomatološka app zove pregled
///    terminom, a to se ne vidi dok se ne otvori treći tenant.
/// 3. **Tri stanja prije sretnog slučaja.** Skeleton, greška sa retryjem, prazno —
///    `docs/02 §14`. Redoslijed nije stilski: ekran napisan "prvo sretan slučaj" dobije
///    spinner preko bijele površine, i to ostane.
///
/// ## Sekcija bez podataka se sakriva
///
/// Cjenovnik, Majstori, Galerija i Recenzije nestaju kad iza njih nema reda. To je pravilo
/// iz DoD-a taska 20 (red 19) i vrijedi za sve četiri: **Početna crta ono što postoji i
/// ćuti o ostalom.** Prazna mreža sa naslovom iznad izgleda kao app koji nije učitao
/// podatke, a salonu koji nema galeriju je to trajno stanje, ne trenutak.
///
/// ## „O nama" je na ovom ekranu, ne iza chevrona — odstupanje od handoffa
///
/// `SPEC.md` priču salona, par fotografija, radno vrijeme i kontakt drži na zasebnom
/// ekranu 5b (`02-o-nama.png`). Task 18 ih je po tome skinuo sa Početne, pa ih aplikacija
/// nekoliko commitova **nije imala nigdje** — salon nije imao gdje pokazati kad radi.
///
/// Task 19 ih vraća ovdje, inline, umjesto da ih ostavi za jedan tap dalje: to su podaci
/// zbog kojih se salon i otvara na telefonu, a ekran koji handoff nijednim nacrtanim
/// ekranom ne otvara ih ne bi pokazao nikome. Iste sekcije crta i `/about`, koji ostaje
/// kao ruta i kao deep link; dijele se kroz `about_sections.dart`, pa ne postoje dvaput.
///
/// Radi **bez prijave** (`docs/06 §1.1`): javni katalog ima `anon` politiku, pa nijedan
/// provider na ovom ekranu ne traži korisnički token.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final salon = ref.watch(salonProvider);

    return Scaffold(
      // **Bez `bottomNavigationBar`.** Do taska 18 je tu stajao sticky CTA; sada ispod
      // ekrana stoji tab bar iz `ClientShell`, a CTA je u sadržaju, odmah ispod heroja —
      // tako ga handoff i ima. Dva zalijepljena elementa bi pojela trećinu ekrana.
      body: switch (salon) {
        AsyncData(:final value) => _Ucitan(salon: value),
        AsyncError() => _Greska(
          message: l10n.salonUnavailable,
          retryLabel: l10n.retry,
          onRetry: () => ref.invalidate(salonProvider),
        ),
        _ => const _Kostur(),
      },
    );
  }
}

/// Sretan slučaj — salon je tu, ostatak stiže svaki svojim tempom.
///
/// Usluge, tim, galerija i ocjena se čitaju zasebno i **ne blokiraju ekran**: salon koji
/// se prikazao, a čeka listu usluga, je upotrebljiv; salon koji čeka sve odjednom je
/// prazan ekran onoliko dugo koliko traje najsporiji upit.
class _Ucitan extends ConsumerWidget {
  const _Ucitan({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vertical = verticalOf(ref);
    final services = ref.watch(servicesProvider);
    final employees = ref.watch(employeesProvider);
    final hours = ref.watch(workingHoursProvider);
    final gallery = ref.watch(salonGalleryProvider);
    final rating = ref.watch(salonRatingProvider);
    final reviews = ref.watch(salonReviewsProvider);

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
            child: _Cta(),
          ),
        ),
        SliverToBoxAdapter(
          child: _CjenovnikSekcija(
            services: services,
            prikaziCijene: vertical.features.prices,
            naslovBezCijena: vertical.terms.servicePlural,
          ),
        ),
        if (vertical.features.team)
          SliverToBoxAdapter(
            child: _MajstoriSekcija(
              naslov: vertical.terms.staffPlural,
              employees: employees,
            ),
          ),
        SliverToBoxAdapter(child: _GalerijaSekcija(urls: gallery)),
        SliverToBoxAdapter(
          child: _RecenzijeSekcija(rating: rating, reviews: reviews),
        ),
        // „O nama" je **na Početnoj, ne iza chevrona** — v. doc komentar klase. Iste
        // sekcije crta i `/about`; dijele se kroz `about_sections.dart`.
        SliverToBoxAdapter(child: AboutStory(opis: salon.description)),
        // **Bez `AboutPhotoPair` ovdje.** Par uzima prve dvije slike iz iste
        // `gallery_urls` liste koju Galerija odmah iznad već crta u mreži — na ovom
        // ekranu bi to bile iste dvije fotografije dvaput, sa pet centimetara razmaka.
        // Na `/about`, gdje mreže nema, par ostaje.
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
        // Zadnja sekcija bi inače završila tačno ispod tab bara — razmak je da se
        // posljednji red može pročitati kad se skrol dovede do dna.
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }
}

/// Živi status iz `docs/02 §3`, računat iz `WorkingHour`-a, ne napisan.
String _statusTekst(AppLocalizations l10n, SalonStatus status) =>
    switch (status) {
      SalonOpen(:final until) => l10n.openUntil(until.format()),
      SalonOpensLater(:final at) => l10n.closedOpensAt(at.format()),
      SalonClosedToday() => l10n.closedToday,
    };

/// Primarni CTA — jedini razlog postojanja ovog ekrana (`docs/02 §3`).
///
/// Tekst je `terms.bookCta`, ne `.arb`: "Zakaži termin" kod barbera je "Zakaži pregled"
/// kod stomatologa, a to je razlika koju nosi vertikala, ne jezik.
class _Cta extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vertical = verticalOf(ref);

    return AppButton(
      label: vertical.terms.bookCta,
      onPressed: () => context.go(ClientRoute.bookService.path),
    );
  }
}

/// Cjenovnik — tri usluge i put do ostalih (`01-pocetna.png`).
class _CjenovnikSekcija extends StatelessWidget {
  const _CjenovnikSekcija({
    required this.services,
    required this.prikaziCijene,
    required this.naslovBezCijena,
  });

  final AsyncValue<List<Service>> services;

  /// `VerticalFeatures.prices` — stomatolog ne objavljuje cjenovnik na home ekranu.
  final bool prikaziCijene;

  /// Naslov kad cijena nema. Sekcija bez cijena nije cjenovnik, pa se i ne zove tako.
  final String naslovBezCijena;

  /// Koliko usluga stane na Početnu prije "Prikaži svih N" (`01-pocetna.png`: tri).
  static const int _naPocetnoj = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Salon bez usluga sakriva sekciju umjesto da prikaže prazan naslov (`docs/02 §3`).
    // Isto vrijedi za grešku: lista usluga koja ne stigne ne smije oboriti ekran čija
    // je glavna svrha dugme "Zakaži".
    final lista = services.valueOrNull;
    if (services.hasError || (lista != null && lista.isEmpty)) {
      return const SizedBox.shrink();
    }

    final prikazane = lista?.take(_naPocetnoj).toList();
    final ukupno = lista?.length ?? 0;

    return HomeSection(
      title: prikaziCijene ? l10n.homePriceList : naslovBezCijena,
      action: ukupno > _naPocetnoj
          ? AppButton(
              label: l10n.homeShowAllServices(ukupno),
              variant: AppButtonVariant.outline,
              onPressed: () => context.go(ClientRoute.services.path),
            )
          : null,
      child: prikazane == null
          ? const _KosturListe()
          : Column(
              children: [
                for (final (index, service) in prikazane.indexed) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.md),
                  SelectableRow(
                    title: service.name,
                    subtitle: formatDurationLong(service.durationMinutes),
                    // Prazan okvir kad fotografije nema je predviđeno stanje, ne rupa
                    // (task 22). `PhotoFrame` ga crta sam.
                    imageUrl: service.imageUrl,
                    trailingText: prikaziCijene
                        ? formatPrice(service.price)
                        : null,
                    // Tap vodi direktno u booking sa preselektovanom uslugom
                    // (`docs/02 §3`) — korak 1 prima `serviceId` iz query parametra.
                    onTap: () => context.go(
                      '${ClientRoute.bookService.path}?serviceId=${service.id}',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _MajstoriSekcija extends StatelessWidget {
  const _MajstoriSekcija({required this.naslov, required this.employees});

  final String naslov;
  final AsyncValue<List<Employee>> employees;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lista = employees.valueOrNull;
    if (employees.hasError || (lista != null && lista.isEmpty)) {
      return const SizedBox.shrink();
    }

    return HomeSection(
      title: naslov,
      child: lista == null
          ? const _KosturListe()
          : StaffGrid(
              employees: lista,
              subtitleOf: (employee) => _titulaIStaz(l10n, employee),
            ),
    );
  }
}

/// „Barber · 9 godina", ili samo ono što postoji.
///
/// Staž se prikazuje **samo kad postoji** (`experience_years` je nullable): red bez njega
/// mora izgledati uredno, a ne kao red kojem fali podatak.
String _titulaIStaz(AppLocalizations l10n, Employee employee) => [
  if (employee.role.isNotEmpty) employee.role,
  if (employee.hasExperience) l10n.experienceYears(employee.experienceYears!),
].join(' · ');

/// Galerija — tri kolone, i ništa kad slika nema.
///
/// Barber u seedu ima dvanaest fotografija, beauty nijednu — pa se ista sekcija u demou
/// vidi na jednom tenantu i uredno nestaje na drugom. Prazna mreža bi tvrdila da slike
/// postoje pa se nisu učitale.
///
/// Na Početnoj stoji **izlog od šest**; cijelu listu i lightbox nosi `/gallery`.
class _GalerijaSekcija extends StatelessWidget {
  const _GalerijaSekcija({required this.urls});

  final AsyncValue<List<String>> urls;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lista = urls.valueOrNull;

    // Dok lista nije stigla, sekcija se ne najavljuje skeletonom: galerija je ukras, a
    // sivi kvadrati koji se pretvore u ništa pomjere sve ispod sebe.
    if (lista == null || lista.isEmpty) return const SizedBox.shrink();

    return HomeSection(
      title: l10n.homeGallery,
      trailing: _SekcijaLink(
        label: l10n.homeSeeAll,
        onTap: () => context.push(ClientRoute.gallery.path),
      ),
      // Tap na ćeliju vodi na `/gallery`, ne direktno u lightbox: Početna pokazuje šest
      // od dvanaest, pa bi lightbox otvoren odavde listao krnju listu i brojač bi pisao
      // „4 / 6" nad galerijom koja ih ima dvanaest.
      child: GalleryGrid(
        urls: lista,
        onTap: (_) => context.push(ClientRoute.gallery.path),
      ),
    );
  }
}

/// Recenzije — prosjek, zvjezdice i jedan citat.
///
/// **Sakriva se kad salon nema nijednu ocjenu**, po istom pravilu kao galerija: agregat
/// tada nema red (`null`), a ne red sa nulama, pa se „0,0 od 5" nikad ne nacrta. Beauty
/// salon u seedu je tačno taj slučaj.
///
/// Citat je najnovija recenzija **sa tekstom**, a broj iznad njega je broj **svih** ocjena.
/// Razlika je namjerna i vidi se na `/reviews`: 142 ocjene, tri kartice.
class _RecenzijeSekcija extends ConsumerWidget {
  const _RecenzijeSekcija({required this.rating, required this.reviews});

  final AsyncValue<SalonRatingSummary?> rating;
  final AsyncValue<List<Review>> reviews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vrijednost = rating.valueOrNull;
    if (vrijednost == null) return const SizedBox.shrink();

    return HomeSection(
      title: l10n.homeReviews,
      trailing: _SekcijaLink(
        label: l10n.homeSeeAll,
        onTap: () => context.push(ClientRoute.reviews.path),
      ),
      child: RatingSummary(
        summary: vrijednost,
        averageLabel: formatRating(vrijednost.average),
        countLabel: l10n.homeRatingCount(vrijednost.total),
        quote: reviews.valueOrNull?.firstOrNull,
      ),
    );
  }
}

/// Link desno od naslova sekcije — „Sve ›" (`01-pocetna.png`).
///
/// Cijeli red je dodirna meta visine 44px, ne samo tekst: `SPEC.md` traži ≥44px svugdje,
/// a dvorječni link je inače meta od jedanaest piksela visine.
class _SekcijaLink extends StatelessWidget {
  const _SekcijaLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const Icon(LucideIcons.chevronRight, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Stanje učitavanja — skeleton u tenant temi, ne spinner (`docs/02 §14`).
///
/// Ponavlja raspored pravog ekrana (hero, pa lista), pa sadržaj ne poskoči kad stigne.
class _Kostur extends StatelessWidget {
  const _Kostur();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SkeletonLoader(height: 320, radius: 0),
          const SizedBox(height: AppSpacing.xl),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: SkeletonLoader(height: AppSize.ctaHeight),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SkeletonLoader.text(width: 200),
          const SizedBox(height: AppSpacing.lg),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.gutter),
            child: _KosturListe(),
          ),
        ],
      ),
    );
  }
}

class _KosturListe extends StatelessWidget {
  const _KosturListe();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SkeletonLoader.card(),
        const SizedBox(height: AppSpacing.md),
        SkeletonLoader.card(),
        const SizedBox(height: AppSpacing.md),
        SkeletonLoader.card(),
      ],
    );
  }
}

/// Greška — poruka i retry, nikad prazan ekran (`docs/02 §14`).
class _Greska extends StatelessWidget {
  const _Greska({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    message: message,
    icon: Icons.cloud_off_outlined,
    actionLabel: retryLabel,
    onAction: onRetry,
  );
}
