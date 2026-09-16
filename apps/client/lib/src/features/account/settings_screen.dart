import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import 'account_rows.dart';
import 'delete_account_action.dart';

/// `/settings` — „Postavke", `prototype/ui/SPEC.md` **5k** (`11-postavke.png`).
///
/// Peta ćelija trake. Do ovog taska je bio `PlaceholderScreen`, i **nijedan task ga nije
/// preuzimao**: task 17 ga navodi kao referencu ali gradi `/account`, a komentar uz
/// `ClientRoute.settings` ga je pripisivao tasku 21 — čiji DoD nabraja samo
/// `/notifications`, `/about-app` i `/terms`.
///
/// Posljedica te rupe je bila da `/account` nema ulaz iz aplikacije. Ekran za brisanje
/// naloga do kojeg se ne može doći pada na Apple reviewu — jedini razlog zašto task 17
/// postoji. Zato je 5k ušao u ovaj task.
///
/// ## „Izbriši račun" stoji **ovdje**, ne samo na „Mom računu"
///
/// Tako crta handoff, i tako je bolje: Apple traži da brisanje bude dostupno iz aplikacije,
/// a svaki dodatni ekran između je dodatno mjesto gdje se korisnik izgubi. „Moj račun" ga
/// nosi takođe, ali oba zovu isti [obrisiNalog] — dvije kopije destruktivne radnje bi se
/// razišle pri prvoj izmjeni.
///
/// ## Odjavljeno stanje postoji, iako ga handoff ne crta
///
/// `11-postavke.png` pokazuje samo prijavljenog korisnika. Ali Postavke su **ćelija trake**
/// i otvaraju se bez prijave — katalog, cjenovnik i slobodni termini se gledaju prije
/// prijave (`docs/06 §1.1`). Kartica profila zato u odjavljenom stanju nosi poziv na
/// prijavu umjesto imena, a račun, odjava i brisanje nestaju: redovi koji ne mogu ništa
/// uraditi izgledaju kao pokvarena app.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sesija = ref.watch(currentAuthSessionProvider);
    final prijavljen = sesija != null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Text(l10n.settingsTitle, style: theme.textTheme.displaySmall),
            const SizedBox(height: AppSpacing.xl),

            _KarticaProfila(sesija: sesija),
            const SizedBox(height: AppSpacing.lg),

            // Grupa redova je **jedan okvir sa hairline razdjelnicima**, ne pet zasebnih
            // kartica — tako stoji u handoffu, i tako se čita kao jedna lista a ne kao pet
            // nepovezanih dugmadi.
            LinkRowGroup(
              rows: [
                // „Moj račun" ima smisla samo prijavljenom. Neprijavljenom bi vodio na
                // ekran koji nema šta pokazati.
                if (prijavljen)
                  LinkRow(
                    label: l10n.settingsAccount,
                    onTap: () => context.push(ClientRoute.account.path),
                  ),
                LinkRow(
                  label: l10n.settingsNotifications,
                  onTap: () => context.go(ClientRoute.notifications.path),
                ),
                // Jezik je zasad jedan, pa red **nema** `onTap`. Red koji izgleda dodirno
                // a ne radi ništa je gori od reda koji to ne glumi; `LinkRow` bez
                // `onTap` nema chevron i ne prima fokus.
                LinkRow(
                  label: l10n.settingsLanguage(l10n.settingsLanguageCurrent),
                ),
                LinkRow(
                  label: l10n.settingsAboutApp,
                  onTap: () => context.push(ClientRoute.aboutApp.path),
                ),
                // Do taska 21 je ovaj red vodio na `/terms` — jedini pravni ekran koji je
                // tada postojao. Sada „Politika privatnosti" vodi na politiku privatnosti.
                //
                // `?from=settings` mijenja samo labelu back headera: do pravnih ekrana se
                // dolazi i odavde i sa „O aplikaciji", a header nosi ime ekrana na koji
                // se vraća.
                LinkRow(
                  label: l10n.settingsPrivacy,
                  onTap: () =>
                      context.push('${ClientRoute.privacy.path}?from=settings'),
                ),
              ],
            ),

            if (prijavljen) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.settingsSignOut,
                variant: AppButtonVariant.secondary,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref.read(authRepositoryProvider).signOut();
                  } on ApiError {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.genericError)),
                    );
                    return;
                  }
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.settingsSignedOutNotice)),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DeleteAccountButton(
                label: l10n.accountDelete,
                onPressed: () => obrisiNalog(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kartica na vrhu: okvir za sliku, ime i mail — ili poziv na prijavu.
class _KarticaProfila extends ConsumerWidget {
  const _KarticaProfila({required this.sesija});

  final AuthSession? sesija;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final okvir = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(border: Border.all(color: scheme.outline)),
      child: sesija == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsGuestTitle,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.settingsGuestBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: l10n.settingsSignIn,
                  onPressed: () => context.push(ClientRoute.login.path),
                ),
              ],
            )
          : Row(
              children: [
                // Nalog nema avatar ni na jednom provideru koji app podržava — email + lozinka
                // ga ne daje. Okvir sa inicijalom je zato **predviđeno** stanje, isto kao
                // kod radnika bez fotografije, a ne rupa koja čeka sliku.
                PhotoFrame(
                  size: 56,
                  placeholder: Text(
                    _inicijal(sesija!),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sesija!.email ?? l10n.accountNoEmail,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.accountProviderEmail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );

    return okvir;
  }

  /// Prvo slovo maila, verzalom. Nalog bez maila daje neutralan znak umjesto praznog
  /// okvira — prazan okvir izgleda kao slika koja se nije učitala.
  String _inicijal(AuthSession sesija) {
    final mail = sesija.email?.trim() ?? '';
    if (mail.isEmpty) return '·';
    return mail.characters.first.toUpperCase();
  }
}
