import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import 'account_rows.dart';
import 'delete_account_action.dart';

/// `/account` — „Moj račun". Task 17, `docs/06` §8.2.
///
/// Pushed ispod Postavki, ne ćelija trake: `SPEC.md` 5k je **Postavke**, a „Moj račun" je
/// uži ekran ispod njega. Handoff mu ne daje vlastiti nacrt, pa oblik dolazi iz 5k —
/// ista grupa redova, isti okvir, isto destruktivno dugme.
///
/// ## Šta ovdje stoji, a šta ne
///
/// Ono što app **zna pouzdano**: email i način prijave, oboje iz [AuthSession]. Ime se ne
/// prikazuje, iako ga `customers` nosi — to je ime **po salonu** (isti čovjek može biti
/// „Emir" u jednom i „Emir H." u drugom), a ovaj ekran govori o nalogu, koji je iznad
/// salona. Prikazati jedno od njih kao „vaše ime" značilo bi tvrditi nešto što nije tačno
/// u drugom salonu.
///
/// ## Brisanje je i ovdje, i na Postavkama
///
/// Oba zovu isti [obrisiNalog]. Handoff crta dugme na 5k, a DoD taska traži ga i ovdje;
/// jedna funkcija za oba znači da se potvrda, obrada greške i povratak u javno stanje ne
/// mogu razići.
///
/// ## Odjavljen korisnik ovdje ne može doći
///
/// Red „Moj račun" na Postavkama postoji samo za prijavljene. Ali ruta je i deep link, pa
/// ekran mora izdržati i direktan dolazak bez sesije — tada nema šta pokazati i vraća
/// prazno stanje umjesto da pukne na `sesija!`.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sesija = ref.watch(currentAuthSessionProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // **Back header, ne `AppBar`.** Ekran je pushed ispod Postavki, pa nosi isto
            // zaglavlje kao ostali pushed ekrani (`SPEC.md`): strelica plus ime ekrana na
            // koji se vraća, a naslov u tijelu kao veliki serif. Do taska 20 je ovdje
            // stajao `AppBar` — mali sans naslov i platformski chevron, jedini takav
            // ekran u app-i.
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.lg,
                AppSpacing.gutter,
                AppSpacing.xl,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.accountTitle,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ),
            Expanded(
              child: sesija == null
                  // Deep link bez sesije. `EmptyState` umjesto praznog ekrana — prazan ekran se
                  // čita kao app koja se nije učitala.
                  ? EmptyState(message: l10n.settingsGuestBody)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        0,
                        AppSpacing.gutter,
                        AppSpacing.xxl,
                      ),
                      children: [
                        SpecCard(
                          rows: [
                            SpecRow(
                              label: l10n.accountEmail,
                              // Apple private relay i gost nemaju mail. Tekst umjesto praznog
                              // reda — prazan red izgleda kao podatak koji se nije učitao.
                              value: sesija.email ?? l10n.accountNoEmail,
                            ),
                            SpecRow(
                              label: l10n.accountSignedInWith,
                              value: l10n.accountProviderEmail,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        DeleteAccountButton(
                          label: l10n.accountDelete,
                          onPressed: () => obrisiNalog(context, ref),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
