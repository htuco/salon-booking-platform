import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/load_error.dart';
import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';

/// Mail razvojnog tima za „Prijavite problem".
///
/// **Namjerno prazan.** Adresa još nije data, a prijava problema koja ode na salonov mail
/// završi kod čovjeka koji ne može ništa uraditi sa stack traceom. Dok je prazna, red se
/// **ne crta** — red koji otvori mail bez primaoca je gori od reda kojeg nema.
///
/// Kad adresa stigne, mijenja se samo ova konstanta.
const supportEmail = '';

/// Verzija i build broj iz `package_info_plus`.
///
/// Provider, a ne direktan poziv u `build`: `PackageInfo.fromPlatform()` ide na platformski
/// kanal, kojeg u `flutter_test` okruženju nema, pa bi ekran radio u app-i a padao u testu.
/// Test ga override-uje i ne dodiruje platformu.
final appPackageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// `/about-app` — „O aplikaciji" (`SPEC.md` 5n, `14-o-aplikaciji.png`).
///
/// Pod-ekran bez tab bara, pushed iz Postavki, pa nosi `BackHeader` sa labelom „Postavke".
///
/// ## Šta je uzeto iz handoffa, a šta nije
///
/// - **Monogram je tekst, ne slika.** `SPEC.md` §Assets to kaže doslovno („the »BV« monogram
///   in 5n is a text placeholder"), pa se inicijali izvode iz imena salona i ne traže asset
///   po tenantu.
/// - **Verzija dolazi iz `package_info_plus`**, ne iz konstante koja zastari — DoD taska 21
///   to traži izričito.
/// - **„Dobijete podsjetnik" je izostavljeno.** Handoff ga crta kao treći korak, ali
///   podsjetnika nema: `send-reminders` i `send-push` su danas samo `README` (task 25).
///   Ekran koji u storeu obeća push koji ne postoji je obećanje koje prvi korisnik
///   demantuje, pa treći korak opisuje ono što app stvarno radi — status u „Moji termini".
/// - **„Ocijenite aplikaciju" ostaje vidljiv, ali neaktivan.** Traži App Store / Play ID,
///   a aplikacije nisu objavljene. Sakriti ga značilo bi da se lista mijenja pod korisnikom
///   kad app ode u store; prazan tap je gori od reda koji vidljivo čeka.
class AboutAppScreen extends ConsumerWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final salon = ref.watch(salonProvider);

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
                label: l10n.settingsTitle,
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go(ClientRoute.settings.path),
              ),
            ),
            Expanded(
              child: switch (salon) {
                AsyncData(:final value) => _Sadrzaj(salon: value),
                // Ranije je ovdje stajala poruka o praznim pravilima, na ekranu koji
                // nije pravilo nego podaci salona (FE-501).
                AsyncError(:final error) => LoadError(
                  error: error,
                  onRetry: () => ref.invalidate(salonProvider),
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

class _Sadrzaj extends ConsumerWidget {
  const _Sadrzaj({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        Text(l10n.settingsAboutApp, style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.aboutAppSubtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xl),

        _KarticaVerzije(salon: salon),
        const SizedBox(height: AppSpacing.xxl),

        Text(l10n.aboutAppHowItWorks, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        _Korak(
          broj: 1,
          naslov: l10n.aboutAppStep1Title,
          tijelo: l10n.aboutAppStep1Body,
        ),
        const SizedBox(height: AppSpacing.md),
        _Korak(
          broj: 2,
          naslov: l10n.aboutAppStep2Title,
          tijelo: l10n.aboutAppStep2Body,
        ),
        const SizedBox(height: AppSpacing.md),
        _Korak(
          broj: 3,
          naslov: l10n.aboutAppStep3Title,
          tijelo: l10n.aboutAppStep3Body,
        ),
        const SizedBox(height: AppSpacing.xxl),

        LinkRowGroup(
          rows: [
            // `?from=aboutApp` je podrazumijevano, pa se ne šalje — back header pada na
            // „O aplikaciji" kad parametra nema.
            LinkRow(
              label: l10n.termsTitle,
              onTap: () => context.push(ClientRoute.terms.path),
            ),
            LinkRow(
              label: l10n.privacyTitle,
              onTap: () => context.push(ClientRoute.privacy.path),
            ),
            LinkRow(
              label: l10n.aboutAppRate,
              note: l10n.aboutAppRateNote,
              disabled: true,
            ),
            if (supportEmail.isNotEmpty)
              LinkRow(
                label: l10n.aboutAppReportProblem,
                onTap: () =>
                    _prijaviProblem(l10n.aboutAppReportSubject(salon.name)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),

        _KontaktSalona(salon: salon),
        const SizedBox(height: AppSpacing.xxl),

        // Naziv pravnog lica nije dat, pa podnožje nosi ime salona. Kad stigne, mijenja se
        // jedan string.
        Text(
          l10n.aboutAppFooter('${DateTime.now().year}', salon.name),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Naslov nosi ime app-e, da prijava iz dva tenanta ne završi u istoj niti.
  Future<void> _prijaviProblem(String naslov) async {
    final adresa = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': naslov},
    );
    await launchUrl(adresa);
  }
}

/// Monogram, ime salona i verzija — okvir sa vrha handoffa.
class _KarticaVerzije extends ConsumerWidget {
  const _KarticaVerzije({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = ref.watch(appPackageInfoProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          PhotoFrame(
            size: 64,
            placeholder: Text(
              monogram(salon.name),
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(salon.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(switch (info) {
                  AsyncData(:final value) => l10n.aboutAppVersion(
                    value.version,
                    value.buildNumber,
                  ),
                  // Crtica, ne prazan red: prazno mjesto ispod imena izgleda kao da se
                  // nešto nije učitalo, a ovdje se samo čeka platformski kanal.
                  _ => '—',
                }, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Jedan korak sekcije „Kako radi": serif broj lijevo, naslov i tekst desno.
class _Korak extends StatelessWidget {
  const _Korak({
    required this.broj,
    required this.naslov,
    required this.tijelo,
  });

  final int broj;
  final String naslov;
  final String tijelo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text('$broj', style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(naslov, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(tijelo, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Telefon, adresa i Instagram — iz `salons`, bez ijednog novog polja.
///
/// **Red bez podatka se ne crta.** Beauty tenant u seedu nema ni telefon ni adresu, pa je
/// prazna kartica stvarno stanje, a ne rub slučaj: „Telefon salona" sa prazninom desno
/// izgleda kao podatak koji se nije učitao.
class _KontaktSalona extends StatelessWidget {
  const _KontaktSalona({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final redovi = <SpecRow>[
      if (_neprazno(salon.phone) != null)
        SpecRow(label: l10n.aboutAppContactPhone, value: salon.phone),
      if (_neprazno(salon.address) != null)
        SpecRow(label: l10n.aboutAppContactAddress, value: salon.address),
      if (instagramHandle(salon.instagramUrl) case final handle?)
        SpecRow(label: l10n.aboutAppContactInstagram, value: handle),
    ];

    if (redovi.isEmpty) return const SizedBox.shrink();
    return SpecCard(rows: redovi);
  }

  static String? _neprazno(String? vrijednost) {
    final skraceno = vrijednost?.trim() ?? '';
    return skraceno.isEmpty ? null : skraceno;
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
        for (var i = 0; i < 3; i++) ...[
          SkeletonLoader.card(),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// Inicijali imena salona, verzalom: „Barber Studio Vitez" → „BV".
///
/// **Prva i zadnja riječ, ne prve dvije.** Handoff crta „BV", a prve dvije bi dale „BS" —
/// srednja riječ je u imenima salona najčešće generička („Studio", „Salon", „Beauty Bar"),
/// pa nosi najmanje. Zadnja je grad ili prezime i to je ono što razlikuje dva salona istog
/// lanca.
///
/// Dva slova, ne tri: treće u kvadratu od 64 px počne da se stiska. Ime od jedne riječi
/// daje jedno slovo — „B" je bolje od „BA", koje izgleda kao skraćenica koju niko nije
/// birao.
@visibleForTesting
String monogram(String imeSalona) {
  final rijeci = imeSalona
      .split(RegExp(r'\s+'))
      .where((rijec) => rijec.trim().isNotEmpty)
      .toList();

  if (rijeci.isEmpty) return '·';

  String prvoSlovo(String rijec) => rijec.substring(0, 1).toUpperCase();
  if (rijeci.length == 1) return prvoSlovo(rijeci.first);
  return '${prvoSlovo(rijeci.first)}${prvoSlovo(rijeci.last)}';
}

/// `https://instagram.com/barberstudiovitez` → `@barberstudiovitez`.
///
/// Vraća `null` kad URL-a nema ili kad iz njega ne izlazi handle — red se tada ne crta.
/// Handoff pokazuje handle, ne URL: puni URL u koloni vrijednosti se prelomi u dva reda i
/// razbije ritam kartice.
@visibleForTesting
String? instagramHandle(String? url) {
  final sirovo = url?.trim() ?? '';
  if (sirovo.isEmpty) return null;

  final putanja = Uri.tryParse(sirovo)?.pathSegments
      .where((dio) => dio.isNotEmpty);
  if (putanja == null || putanja.isEmpty) return null;

  return '@${putanja.first}';
}
