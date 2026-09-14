import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../booking/date_labels.dart';

/// `/terms` i `/privacy` — numerisane sekcije pravnog dokumenta (`SPEC.md` 5o,
/// `15-pravila-koristenja.png`).
///
/// **Jedan ekran za oba dokumenta.** Razlikuju se samo naslovom i izvorom sekcija; oblik je
/// isti do zadnjeg razmaka. Dvije kopije bi se razišle pri prvoj izmjeni, i to na ekranu na
/// kojem se razlika ne primijeti dok je neko ne pročita.
///
/// ## Sekcije su dinamične, ne šest zakucanih
///
/// Handoff crta šest sekcija, ali ih ekran **ne zna unaprijed**: crta `01..NN` redom kojim
/// stignu iz baze. Salon može dodati svoju sekciju, a može i ne imati nijednu — beauty
/// tenant u seedu ima kraći dokument upravo zato da se to vidi u demou.
///
/// **Broj sekcije se računa, ne čita.** U bazi ga nema; upisan broj bi se razišao sa
/// prikazanim čim salon doda sekciju iznad.
///
/// ## Brojevi u tekstu dolaze iz živih podataka
///
/// Tijelo sekcije nosi placeholdere (`{minCancelHours}`, `{phone}`, `{email}`,
/// `{appointmentSingular}`) koje puni [policyPlaceholdersProvider]. Razlog je konkretan:
/// handoff piše „najkasnije 2 sata prije početka", a `cancel_appointment` provodi 3 za
/// barbera i 6 za beauty. Neriješen placeholder **ostaje vidljiv** — v.
/// [applyPolicyPlaceholders].
class PolicyDocumentScreen extends ConsumerWidget {
  const PolicyDocumentScreen({required this.document, this.from, super.key});

  final PolicyDocument document;

  /// Ime rute sa koje se došlo, iz `?from=`. Back header nosi ime **roditeljskog** ekrana,
  /// a do pravila se dolazi sa dva mjesta — iz Postavki i sa „O aplikaciji".
  final String? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sekcije = ref.watch(
      document == PolicyDocument.terms ? termsProvider : privacyPolicyProvider,
    );

    final naslov = switch (document) {
      PolicyDocument.terms => l10n.termsTitle,
      PolicyDocument.privacy => l10n.privacyTitle,
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: BackHeader(
                label: _labelaPovratka(l10n, from),
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go(ClientRoute.aboutApp.path),
              ),
            ),
            Expanded(
              child: switch (sekcije) {
                AsyncData(value: final lista) when lista.isNotEmpty => _Sadrzaj(
                  naslov: naslov,
                  sekcije: lista,
                  vrijednosti: ref.watch(policyPlaceholdersProvider),
                ),
                // Prazna lista i greška se crtaju isto, i to je odluka: korisniku je
                // svejedno je li tekst pao na mreži ili ga nema u bazi — oboje znači
                // „nemam šta pokazati". Pravni ekran koji baci izuzetak je gori od oba.
                AsyncData() || AsyncError() => _Prazno(naslov: naslov),
                _ => const _Kostur(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Labela back headera. Nepoznata vrijednost pada na „O aplikaciji", kako handoff i crta.
///
/// Prima ime rute, ne gotov tekst: `ClientRoute.title` je razvojno ime placeholdera i
/// izričito **nije** UI copy, pa tekst mora doći iz `.arb`-a.
String _labelaPovratka(AppLocalizations l10n, String? from) => switch (from) {
  'settings' => l10n.settingsTitle,
  _ => l10n.settingsAboutApp,
};

class _Sadrzaj extends StatelessWidget {
  const _Sadrzaj({
    required this.naslov,
    required this.sekcije,
    required this.vrijednosti,
  });

  final String naslov;
  final List<PolicySection> sekcije;
  final PolicyPlaceholders vrijednosti;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // „Zadnja izmjena" je najnoviji `updated_at` **preko cijelog dokumenta**. Datum jedne
    // sekcije bi tvrdio da se dokument nije mijenjao otkad je ta sekcija pisana.
    final zadnjaIzmjena = sekcije
        .map((s) => s.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    // Datum se piše brojčano (`14.09.2026.`), kao svuda u app-i. Handoff ovdje ima „1. maj
    // 2026.", ali imena mjeseci u `.arb`-u počinju verzalom („Maj") jer ih koristi
    // zaglavlje kalendara — usred rečenice bi to bilo pogrešno, a drugi set ključeva samo
    // zbog ovog reda je drugi izvor istine za isti podatak.
    final lokalno = zadnjaIzmjena.toLocal();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        Text(naslov, style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.policyLastUpdated(
            formatDate(LocalDate(lokalno.year, lokalno.month, lokalno.day)),
          ),
          style: theme.textTheme.bodySmall,
        ),
        for (var i = 0; i < sekcije.length; i++)
          _Sekcija(
            redniBroj: i + 1,
            sekcija: sekcije[i],
            vrijednosti: vrijednosti,
          ),
      ],
    );
  }
}

/// Jedna sekcija: kicker sa brojem, serif naslov, pa paragrafi.
class _Sekcija extends StatelessWidget {
  const _Sekcija({
    required this.redniBroj,
    required this.sekcija,
    required this.vrijednosti,
  });

  final int redniBroj;
  final PolicySection sekcija;
  final PolicyPlaceholders vrijednosti;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: AppSpacing.lg),
        // „01", „02" — dvocifreno kako handoff crta, sa razmakom iz kickera.
        Text(
          redniBroj.toString().padLeft(2, '0'),
          style: kicker(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(sekcija.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        for (final paragraf in sekcija.paragraphs) ...[
          Text(
            applyPolicyPlaceholders(paragraf, vrijednosti),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// Prazno stanje — naslov ostaje, jer ekran bez naslova iznad poruke izgleda kao da se
/// nije učitao (isti obrazac kao `/reviews`).
class _Prazno extends StatelessWidget {
  const _Prazno({required this.naslov});

  final String naslov;

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
          child: Text(naslov, style: Theme.of(context).textTheme.displaySmall),
        ),
        Expanded(child: EmptyState(message: l10n.policyEmpty)),
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
        const SkeletonLoader(height: 48),
        const SizedBox(height: AppSpacing.xl),
        for (var i = 0; i < 4; i++) ...[
          SkeletonLoader.card(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }
}
