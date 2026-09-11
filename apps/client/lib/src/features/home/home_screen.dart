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
import 'formatters.dart';
import 'salon_schedule.dart';
import 'widgets/contact_card.dart';
import 'widgets/home_section.dart';
import 'widgets/salon_hero.dart';
import 'widgets/team_row.dart';
import 'widgets/working_hours_card.dart';

/// Home ekran — prvi pravi ekran i šablon za sve ostale (`docs/02 §3`).
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
/// Radi **bez prijave** (`docs/06 §1.1`): javni katalog ima `anon` politiku, pa nijedan
/// provider na ovom ekranu ne traži korisnički token.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final salon = ref.watch(salonProvider);

    return Scaffold(
      body: switch (salon) {
        AsyncData(:final value) => _Ucitan(salon: value),
        AsyncError() => _Greska(
          message: l10n.salonUnavailable,
          retryLabel: l10n.retry,
          onRetry: () => ref.invalidate(salonProvider),
        ),
        _ => const _Kostur(),
      },
      // CTA stoji van `switch`-a i van skrola: `docs/02 §3` ga zove jedinim razlogom
      // postojanja ovog ekrana. Onemogućen je dok salon ne stigne, ali je **vidljiv** —
      // dugme koje iskoči nakon učitavanja pomjeri sadržaj pod prstom koji već ide ka
      // njemu.
      bottomNavigationBar: _StickyCta(enabled: salon.hasValue),
    );
  }
}

/// Sretan slučaj — salon je tu, ostatak stiže svaki svojim tempom.
///
/// Usluge, tim i radno vrijeme se čitaju zasebno i **ne blokiraju ekran**: salon koji
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

    final schedule = SalonSchedule.fromHours(
      hours.valueOrNull ?? const <WorkingHour>[],
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SalonHero(
            salon: salon,
            tagline: salon.description,
            status: _statusTekst(l10n, schedule),
          ),
        ),
        if (salon.description.isEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        SliverToBoxAdapter(
          child: _UslugeSekcija(
            naslov: vertical.terms.servicePlural,
            services: services,
            prikaziCijene: vertical.features.prices,
          ),
        ),
        if (vertical.features.team)
          SliverToBoxAdapter(
            child: _TimSekcija(
              naslov: vertical.terms.staffPlural,
              employees: employees,
            ),
          ),
        SliverToBoxAdapter(
          child: _RadnoVrijemeSekcija(
            schedule: schedule,
            loading: hours.isLoading,
          ),
        ),
        SliverToBoxAdapter(
          child: _KontaktSekcija(
            salon: salon,
            prikaziDrustvene: vertical.features.socialLinks,
          ),
        ),
        // Zadnja sekcija bi inače završila tačno ispod sticky CTA — razmak je da se
        // posljednji red može pročitati kad se skrol dovede do dna.
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }
}

/// Živi status iz `docs/02 §3`, računat iz `WorkingHour`-a, ne napisan.
String _statusTekst(AppLocalizations l10n, SalonSchedule schedule) =>
    switch (schedule.statusAt(DateTime.now())) {
      SalonOpen(:final until) => l10n.openUntil(until.format()),
      SalonOpensLater(:final at) => l10n.closedOpensAt(at.format()),
      SalonClosedToday() => l10n.closedToday,
    };

class _UslugeSekcija extends StatelessWidget {
  const _UslugeSekcija({
    required this.naslov,
    required this.services,
    required this.prikaziCijene,
  });

  final String naslov;
  final AsyncValue<List<Service>> services;

  /// `VerticalFeatures.prices` — stomatolog ne objavljuje cjenovnik na home ekranu.
  final bool prikaziCijene;

  @override
  Widget build(BuildContext context) {
    // Salon bez usluga sakriva sekciju umjesto da prikaže prazan naslov (`docs/02 §3`).
    // Isto vrijedi za grešku: lista usluga koja ne stigne ne smije oboriti ekran čija
    // je glavna svrha dugme "Zakaži".
    final lista = services.valueOrNull;
    if (services.hasError || (lista != null && lista.isEmpty)) {
      return const SizedBox.shrink();
    }

    return HomeSection(
      title: naslov,
      child: lista == null
          ? const _KosturListe()
          : Column(
              children: [
                for (final (index, service) in lista.indexed) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.md),
                  ServiceCard(
                    name: service.name,
                    duration: formatDuration(service.durationMinutes),
                    price: prikaziCijene ? formatPrice(service.price) : null,
                    description: service.description,
                    // Tap vodi direktno u booking sa preselektovanom uslugom
                    // (`docs/02 §3`) — task 11 prima `serviceId` iz query parametra.
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

class _TimSekcija extends StatelessWidget {
  const _TimSekcija({required this.naslov, required this.employees});

  final String naslov;
  final AsyncValue<List<Employee>> employees;

  @override
  Widget build(BuildContext context) {
    final lista = employees.valueOrNull;
    if (employees.hasError || (lista != null && lista.isEmpty)) {
      return const SizedBox.shrink();
    }

    return HomeSection(
      title: naslov,
      child: lista == null
          ? const SizedBox(height: 132, child: _KosturListe())
          : TeamRow(employees: lista),
    );
  }
}

class _RadnoVrijemeSekcija extends StatelessWidget {
  const _RadnoVrijemeSekcija({required this.schedule, required this.loading});

  final SalonSchedule schedule;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (schedule.isEmpty && !loading) return const SizedBox.shrink();

    final danas = DateTime.now().weekday;

    return HomeSection(
      title: l10n.workingHours,
      child: loading && schedule.isEmpty
          ? const _KosturListe()
          : WorkingHoursCard(
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

String _imeDana(AppLocalizations l10n, int weekday) => switch (weekday) {
  DateTime.monday => l10n.dayMonday,
  DateTime.tuesday => l10n.dayTuesday,
  DateTime.wednesday => l10n.dayWednesday,
  DateTime.thursday => l10n.dayThursday,
  DateTime.friday => l10n.dayFriday,
  DateTime.saturday => l10n.daySaturday,
  _ => l10n.daySunday,
};

class _KontaktSekcija extends StatelessWidget {
  const _KontaktSekcija({required this.salon, required this.prikaziDrustvene});

  final Salon salon;
  final bool prikaziDrustvene;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final redovi = <Widget>[
      if (salon.address.isNotEmpty)
        ContactRow(
          icon: Icons.place_outlined,
          label: '${salon.address}, ${salon.city}',
          onTap: () => _otvori(
            Uri.parse(
              'geo:0,0?q=${Uri.encodeComponent('${salon.address}, ${salon.city}')}',
            ),
          ),
        ),
      if (salon.phone != null && salon.phone!.isNotEmpty)
        ContactRow(
          icon: Icons.call_outlined,
          label: salon.phone!,
          onTap: () => _otvori(Uri.parse('tel:${salon.phone}')),
        ),
      if (salon.email != null && salon.email!.isNotEmpty)
        ContactRow(
          icon: Icons.mail_outline,
          label: salon.email!,
          onTap: () => _otvori(Uri.parse('mailto:${salon.email}')),
        ),
      if (prikaziDrustvene && _neprazno(salon.instagramUrl))
        ContactRow(
          icon: Icons.camera_alt_outlined,
          label: l10n.instagram,
          onTap: () => _otvori(Uri.parse(salon.instagramUrl!)),
        ),
      if (prikaziDrustvene && _neprazno(salon.facebookUrl))
        ContactRow(
          icon: Icons.thumb_up_outlined,
          label: l10n.facebook,
          onTap: () => _otvori(Uri.parse(salon.facebookUrl!)),
        ),
    ];

    if (redovi.isEmpty) return const SizedBox.shrink();

    return HomeSection(
      title: l10n.contact,
      child: ContactCard(children: redovi),
    );
  }
}

bool _neprazno(String? value) => value != null && value.isNotEmpty;

/// Otvara `tel:`, `mailto:`, `geo:` ili profil na mreži.
///
/// Greška se guta namjerno: uređaj bez aplikacije za pozive ili mape nije stanje koje
/// korisnik može popraviti, a izuzetak iz `onTap`-a bi srušio ekran.
Future<void> _otvori(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Namjerno bez poruke — v. dokumentaciju iznad.
  }
}

/// Primarni CTA, uvijek vidljiv (`docs/02 §3`).
///
/// Tekst je `terms.bookCta`, ne `.arb`: "Zakaži termin" kod barbera je "Zakaži pregled"
/// kod stomatologa, a to je razlika koju nosi vertikala, ne jezik.
class _StickyCta extends ConsumerWidget {
  const _StickyCta({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vertical = verticalOf(ref);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppButton(
            label: vertical.terms.bookCta,
            onPressed: enabled
                ? () => context.go(ClientRoute.bookService.path)
                : null,
          ),
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
          const SkeletonLoader(height: 220, radius: 0),
          const SizedBox(height: AppSpacing.xl),
          SkeletonLoader.text(width: 200),
          const SizedBox(height: AppSpacing.lg),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
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
