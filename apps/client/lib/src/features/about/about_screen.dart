import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/app_router.dart';
import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../home/salon_schedule.dart';
import '../home/widgets/contact_card.dart';
import '../home/widgets/home_hero.dart';
import '../home/widgets/home_section.dart';
import '../home/widgets/working_hours_card.dart';

/// `/about` — „O nama", `prototype/ui/SPEC.md` **5b** (`02-o-nama.png`).
///
/// Podruta Početne, ne šesti tab: traka ostaje, sa **Početna aktivna**, kako handoff i
/// traži. Odozgo: hero sa imenom salona, sekundarni CTA, priča salona, par fotografija,
/// radno vrijeme i kontakt.
///
/// ## Ovaj ekran zatvara regresiju, ne samo DoD stavku
///
/// Task 18 je **skinuo radno vrijeme i kontakt sa Početne**, jer ih `SPEC.md` 5b drži
/// ovdje. Dok ovog ekrana nije bilo, salon nije imao gdje pokazati kad radi ni gdje se
/// nalazi — u cijeloj aplikaciji. `WorkingHoursCard` i `ContactCard` su sve to vrijeme
/// stajali bez ijednog korisnika; ovdje ih ekran preuzima.
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
          icon: Icons.cloud_off_outlined,
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
        SliverToBoxAdapter(child: _Prica(opis: salon.description)),
        SliverToBoxAdapter(child: _FotoPar(urls: gallery)),
        SliverToBoxAdapter(
          child: _RadnoVrijeme(schedule: schedule, ucitava: hours.isLoading),
        ),
        SliverToBoxAdapter(
          child: _Kontakt(
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

/// Priča salona — kicker, serif naslov, tekst. Sve centrirano, kao u handoffu.
///
/// Jedina sekcija ekrana koja **ne** koristi `HomeSection`: naslov joj nije lijevo
/// poravnat naziv sekcije nego pitanje u sredini („Ko smo mi?"), sa verzalnim kickerom
/// iznad. To je oblik iz `02-o-nama.png` i ne ponavlja se nigdje drugdje.
class _Prica extends StatelessWidget {
  const _Prica({required this.opis});

  final String opis;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Salon bez opisa nema priču. Kicker i naslov bez teksta ispod bi bili obećanje koje
    // ekran ne ispunjava.
    if (opis.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        bottom: AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.aboutKicker,
            textAlign: TextAlign.center,
            style: kicker(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.aboutHeadline,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            opis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dvije fotografije jedna uz drugu (`SPEC.md`: „2-col photo pairs").
///
/// Uzima prve dvije iz galerije salona. Salon sa jednom slikom dobija jednu preko pola
/// širine, jer je to i dalje istinit prikaz onoga što salon ima — a rastegnuta jedna
/// slika preko cijele širine bi se tukla sa herojem odmah iznad.
class _FotoPar extends StatelessWidget {
  const _FotoPar({required this.urls});

  final AsyncValue<List<String>> urls;

  @override
  Widget build(BuildContext context) {
    final lista = urls.valueOrNull;
    if (lista == null || lista.isEmpty) return const SizedBox.shrink();

    final par = lista.take(2).toList();

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        bottom: AppSpacing.xxl,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final strana = (constraints.maxWidth - AppSpacing.sm) / 2;

          return Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final url in par) PhotoFrame(imageUrl: url, size: strana),
            ],
          );
        },
      ),
    );
  }
}

/// Radno vrijeme — puna sedmica, današnji dan podebljan.
class _RadnoVrijeme extends StatelessWidget {
  const _RadnoVrijeme({required this.schedule, required this.ucitava});

  final SalonSchedule schedule;

  /// Dok upit traje, `SalonSchedule` je prazan — a prazan raspored i raspored koji nije
  /// stigao izgledaju isto. Bez ove razlike bi ekran u sekundi učitavanja tvrdio da je
  /// salon zatvoren svih sedam dana.
  final bool ucitava;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (ucitava) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.gutter,
          right: AppSpacing.gutter,
          bottom: AppSpacing.xxl,
        ),
        child: SkeletonLoader(height: 220),
      );
    }

    // Salon bez ijednog reda radnog vremena sakriva sekciju. To je stanje tek postavljenog
    // tenanta, ne greška — sedam redova „Zatvoreno" bi tvrdilo da salon ne radi nikad.
    if (schedule.isEmpty) return const SizedBox.shrink();

    final danas = DateTime.now().weekday;

    return HomeSection(
      title: l10n.workingHours,
      child: WorkingHoursCard(
        rows: [
          for (final day in schedule.week)
            rowFor(
              day,
              label: _imeDana(l10n, day.weekday),
              closedLabel: l10n.closed,
              isToday: day.weekday == danas,
            ),
        ],
      ),
    );
  }
}

/// 1–7 → ime dana. Mapa, a ne `.arb` sa brojem kao placeholderom: prevodilac koji vidi
/// „Ponedjeljak" zna šta prevodi, a onaj koji vidi `{day}` ne zna.
String _imeDana(AppLocalizations l10n, int weekday) => switch (weekday) {
  1 => l10n.dayMonday,
  2 => l10n.dayTuesday,
  3 => l10n.dayWednesday,
  4 => l10n.dayThursday,
  5 => l10n.dayFriday,
  6 => l10n.daySaturday,
  _ => l10n.daySunday,
};

/// Kontakt i mreže — adresa, telefon, Instagram, Facebook (`02-o-nama.png`).
///
/// Red bez podatka se **ne crta**. Salon bez Instagrama ne dobija prazan red, jer bi to
/// izgledalo kao da profil postoji pa se nije učitao.
class _Kontakt extends StatelessWidget {
  const _Kontakt({required this.salon, required this.prikaziMreze});

  final Salon salon;

  /// `VerticalFeatures.socialLinks` — ordinacija nema društvene mreže u aplikaciji.
  final bool prikaziMreze;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final adresa = [
      salon.address,
      salon.city,
    ].where((dio) => dio.trim().isNotEmpty).join(', ');
    final telefon = salon.phone;
    final instagram = salon.instagramUrl;
    final facebook = salon.facebookUrl;

    final redovi = <Widget>[
      if (adresa.isNotEmpty)
        ContactRow(
          label: l10n.address,
          value: adresa,
          // `geo:` ne radi na iOS-u, a `maps:` ne radi na Androidu — univerzalni
          // `https://maps.google.com/?q=` otvara mapu na obje platforme i na webu.
          onTap: () =>
              _otvori(Uri.https('maps.google.com', '/', {'q': adresa})),
        ),
      if (telefon != null && telefon.trim().isNotEmpty)
        ContactRow(
          label: l10n.phone,
          value: telefon,
          onTap: () => _otvori(Uri(scheme: 'tel', path: telefon)),
        ),
      if (prikaziMreze) ...[
        if (instagram != null && instagram.trim().isNotEmpty)
          ContactRow(
            label: l10n.instagram,
            value: _handle(instagram, prefiks: '@'),
            onTap: () => _otvori(Uri.parse(instagram)),
          ),
        if (facebook != null && facebook.trim().isNotEmpty)
          ContactRow(
            label: l10n.facebook,
            value: _handle(facebook, prefiks: '/'),
            onTap: () => _otvori(Uri.parse(facebook)),
          ),
      ],
    ];

    if (redovi.isEmpty) return const SizedBox.shrink();

    return HomeSection(
      title: l10n.contact,
      child: ContactCard(children: redovi),
    );
  }
}

/// Pun URL profila → ono što handoff pokazuje: `@barberstudiovitez`, `/barberstudiovitez`.
///
/// Baza čuva cijeli URL (`instagram_url`), jer je to ono što se otvara. Na ekranu je
/// `https://instagram.com/…` šum koji zauzme širinu i prelomi se u dva reda, a korisnik
/// prepoznaje profil po nadimku.
///
/// URL koji se ne da razložiti se prikazuje kakav jeste — prazan red bi bio gori.
String _handle(String url, {required String prefiks}) {
  final segmenti = Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty);
  if (segmenti == null || segmenti.isEmpty) return url;
  return '$prefiks${segmenti.last}';
}

/// Otvara link izvan aplikacije.
///
/// Greška se **guta namjerno**: uređaj bez mail klijenta, bez telefonske aplikacije ili
/// sa blokiranim `tel:` shemom nije stanje na koje korisnik može odgovoriti, a poruka
/// preko ekrana bi ga zaustavila usred čitanja adrese.
Future<void> _otvori(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Namjerno prazno — v. doc iznad.
  }
}

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
