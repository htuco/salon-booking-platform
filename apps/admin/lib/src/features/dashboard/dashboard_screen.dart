/// „Danas" — prikazi `3b` (desktop) i `3k` (telefon).
///
/// **Sažetak dana, ne zaseban izvor.** Čita iste repozitorije kao lista termina; da ima
/// svoje upite, „14 termina" na ovom ekranu i 14 redova na listi bi se jednog dana
/// raziđu.
///
/// ## Isti ekran, dva rasporeda
///
/// Desktop crta radnu površinu: naslov dana, red kartica sa brojkama, pa tabelu rasporeda
/// uz kolonu sa zahtjevima i zauzetošću. Telefon crta isti sadržaj kao niz kartica ispod
/// vlastitog zaglavlja — tabela na 402 px nije tabela nego horizontalni skrol
/// (`SPEC.md`: „Tabele na uskim širinama prelaze u kartice/liste").
///
/// ## Šta canvas traži, a ovdje nije nacrtano
///
/// - **Kartica „Slobodno vrijeme"** i **procenat zauzetosti** traže smjene radnika, koje
///   dolaze u tasku 33 — v. `dashboard_summary.dart`.
/// - **„Otvoreno do 20:00"** traži radno vrijeme salona, koje dobija svoj ekran u tasku 34.
/// - **Pretraga klijenta** u top baru traži modul klijenata (task 35); polje koje ne traži
///   ništa je gore od polja kojeg nema.
/// - **Birač lokacije** (`▾` uz ime salona) je `3a`, izvan sprinta: admin dobija tačno jedan
///   salon iz membershipa.
/// - **Avatar** uz zaglavlje: `employees.image_url` postoji, ali `public.users` nema sliku,
///   a ovo je prijavljeni **član osoblja**, ne radnik iz kataloga.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/datum.dart';
import '../../core/format/tekst.dart';
import '../../core/navigation/admin_destinations.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../appointments/appointment_card.dart';
import '../appointments/appointments_providers.dart';
import '../appointments/status_pill.dart';
import 'dashboard_summary.dart';

/// Koliko zahtjeva stane u karticu na desktopu prije „Vidi sve".
///
/// Canvas crta dva. Kartica koja bi izlistala svih dvanaest bi zauzela kolonu i gurnula
/// zauzetost ispod pregiba, a ona je drugi razlog zbog kojeg se u tu kolonu gleda.
const int kZahtjevaUKartici = 2;

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jeDesktop = AdminShell.jeDesktop(context);

    return AdminScaffold(
      // Navigacija ovaj modul zove „Danas" (`kAdminDestinations`), a ekran se do taska 30
      // zvao „Pregled" — ista stvar pod dva imena na dva mjesta istog ekrana.
      title: 'Danas',
      aktivna: AdminRoute.dashboard,
      // `3k` iznad sadržaja crta veliki naslov sa datumom i brojem termina; `AppBar` sa
      // sitnim „Danas" bi stajao iznad njega i ponavljao istu riječ.
      sopstvenoZaglavlje: true,
      actions: jeDesktop ? const [_TopBarAkcije()] : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(danasnjiTerminiProvider)
            ..invalidate(pendingCountProvider)
            ..invalidate(zahtjeviProvider);
        },
        child: jeDesktop ? const _Desktop() : const _Telefon(),
      ),
    );
  }
}

/// Akcije desktop top bara iz `3b`.
class _TopBarAkcije extends StatelessWidget {
  const _TopBarAkcije();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton(
          // `/calendar/block` je do taska 34 placeholder, ali **ruta postoji** i vodi u
          // ljusku sa navigacijom. Isto pravilo kao kod ćelija u tasku 29: ulaz koji
          // pokazuje gdje će stvar biti je bolji od ulaza kojeg nema.
          onPressed: () => context.go(AdminRoute.calendarBlock.path),
          child: const Text('Blokiraj termin'),
        ),
        const SizedBox(width: AdminSpacing.md),
        FilledButton(
          onPressed: () => context.go(AdminRoute.appointmentNew.path),
          child: const Text('+ Novi termin'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop `3b`
// ---------------------------------------------------------------------------

class _Desktop extends ConsumerWidget {
  const _Desktop();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AdminSpacing.gutterDesktop),
      children: const [
        _NaslovDana(),
        SizedBox(height: 22),
        _KarticeMetrika(),
        SizedBox(height: AdminSpacing.xxl),
        _DvijeKolone(),
      ],
    );
  }
}

/// `Ponedjeljak, 18. maj` i red ispod njega.
class _NaslovDana extends ConsumerWidget {
  const _NaslovDana();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termini = ref.watch(danasnjiTerminiProvider).valueOrNull ?? const [];
    final uDanu = termini.where(terminSeRacuna).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(datumDugo(DateTime.now()), style: AdminText.display),
        const SizedBox(height: 7),
        Text(
          uDanu.isEmpty
              ? 'Danas nema zakazanih termina.'
              : '${terminaTekst(uDanu.length)} · prvi '
                    '${vrijemeHhMm(uDanu.first.startTime)} · zadnji '
                    '${vrijemeHhMm(uDanu.last.startTime)}',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: context.adminColors.textSecondary),
        ),
      ],
    );
  }
}

/// Tri kartice sa brojkama. Četvrta iz canvasa traži smjene — v. `dashboard_summary.dart`.
class _KarticeMetrika extends ConsumerWidget {
  const _KarticeMetrika();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sazetak = ref.watch(_sazetakProvider);
    final naCekanju = ref.watch(pendingCountProvider).valueOrNull ?? 0;

    final kartice = [
      _Metrika(
        labela: 'Termina danas',
        vrijednost: '${sazetak.ukupno}',
        opis: '${sazetak.zavrseno} završeno · ${sazetak.predstoji} predstoji',
      ),
      _Metrika(
        labela: 'Čeka potvrdu',
        vrijednost: '$naCekanju',
        opis: naCekanju == 0 ? 'nema novih zahtjeva' : 'traže odgovor',
        istaknuta: naCekanju > 0,
      ),
      _Metrika(
        labela: 'Promet danas',
        vrijednost: iznosKm(sazetak.prometDoSada),
        opis: 'prognoza ${iznosKm(sazetak.prometPrognoza)}',
      ),
    ];

    // **`LayoutBuilder`, ne `MediaQuery`** — isti razlog kao u FE-406: ovaj ekran stoji u
    // ljusci pored sidebara, pa je dostupna širina za `AdminSize.sidebarWidth` manja od
    // širine prozora. Pojas izveden iz prozora bi na 1100 px tvrdio da ima mjesta za tri
    // kartice, a stvarno ih stane jedna.
    return LayoutBuilder(
      builder: (context, constraints) {
        final uJednuKolonu = AdminShell.bandZa(constraints.maxWidth).jeCompact;

        if (uJednuKolonu) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, kartica) in kartice.indexed) ...[
                if (i > 0) const SizedBox(height: AdminSpacing.md),
                kartica,
              ],
            ],
          );
        }

        // `IntrinsicHeight` da sve tri kartice budu jednako visoke kao u canvasu: `stretch`
        // sam u `ListView`-u traži beskonačnu visinu i ruši layout.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, kartica) in kartice.indexed) ...[
                if (i > 0) const SizedBox(width: AdminSpacing.lg),
                Expanded(child: kartica),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Metrika extends StatelessWidget {
  const _Metrika({
    required this.labela,
    required this.vrijednost,
    required this.opis,
    this.istaknuta = false,
  });

  final String labela;
  final String vrijednost;
  final String opis;

  /// Kartica koja traži radnju nosi akcentni obrub i akcentnu brojku (`3b`, „Čeka potvrdu").
  final bool istaknuta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        side: BorderSide(
          // **Obrub je koralan, brojka ostaje plava** — izmjereno iz `3b`, ne pretpostavljeno.
          // Kartica „Čeka potvrdu" ima obrub `#EE6C4D`, a njena velika brojka je `#3D5A80`,
          // ista kao u ostalim karticama. Koralna kaže „ovdje treba nešto uraditi", plava
          // ostaje boja podatka; da su obje koralne, brojka bi se čitala kao upozorenje.
          color: istaknuta
              ? context.adminColors.action
              : context.adminColors.border,
          width: AdminSize.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labela,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.adminColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AdminSpacing.sm),
            Text(
              vrijednost,
              style: AdminText.metricNumber.copyWith(
                color: istaknuta
                    ? context.adminColors.accent
                    : context.adminColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              opis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.adminColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Raspored lijevo, zahtjevi i zauzetost desno — `3b` ih dijeli 1.62 : 1.
class _DvijeKolone extends StatelessWidget {
  const _DvijeKolone();

  @override
  Widget build(BuildContext context) {
    // **I ovaj raspored se preslaže ispod 900 px**, ne samo kartice metrika. To je našao
    // test: na radnoj površini od 864 px desna kolona dobije ~330 px, a zaglavlje kartice
    // „Zahtjevi" (naslov plus „N novih") tu prelije za 31 px. Dvije kolone od kojih je
    // jedna preuska nisu raspored nego greška koja se vidi tek na uskom prozoru.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AdminShell.bandZa(constraints.maxWidth).jeCompact) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RasporedDana(),
              SizedBox(height: AdminSpacing.xl),
              _ZahtjeviKartica(),
              SizedBox(height: 18),
              _ZauzetostKartica(),
            ],
          );
        }

        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Omjer, a ne dvije fiksne širine: radna površina na 1920 je 1684 px, a tabela
            // na 1440 je crtana za 880. Fiksna kolona bi ostatak monitora ostavila praznim.
            Expanded(flex: 162, child: _RasporedDana()),
            SizedBox(width: AdminSpacing.xl),
            Expanded(
              flex: 100,
              child: Column(
                children: [
                  _ZahtjeviKartica(),
                  SizedBox(height: 18),
                  _ZauzetostKartica(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tabela dana iz `3b`.
class _RasporedDana extends ConsumerWidget {
  const _RasporedDana();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final termini = ref.watch(danasnjiTerminiProvider);
    final usluge = ref.watch(uslugePoIdProvider);
    final radnici = ref.watch(radniciPoIdProvider);
    final sada = DateTime.now();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Row(
              children: [
                Text('Raspored dana', style: theme.textTheme.headlineSmall),
                const Spacer(),
                Text(
                  radnici.isEmpty
                      ? ''
                      : '${radnici.length} ${_majstoraTekst(radnici.length)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.adminColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const _ZaglavljeTabele(),
          termini.when(
            loading: () => const _SkeletonRasporeda(),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(AdminSpacing.xxl),
              child: Text('Termini se ne mogu učitati.'),
            ),
            data: (lista) => lista.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AdminSpacing.xxxl),
                    child: Text('Danas nema zakazanih termina.'),
                  )
                : Column(
                    children: [
                      for (final termin in lista)
                        _RedTabele(
                          termin: termin,
                          opis: opisTermina(
                            termin,
                            usluge: usluge,
                            radnici: radnici,
                            saCijenom: false,
                          ),
                          uToku: terminUToku(termin, sada),
                          zadnji: termin == lista.last,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Širine kolona tabele iz `3b`: `76px minmax(140px,1.3fr) 162px 92px 102px`.
///
/// Klijent je jedina kolona koja raste — ime je jedini podatak koji nema gornju granicu, a
/// ostale kolone rastegnute na 1920 bi ostavile prazan pojas između vremena i statusa.
const double _kolonaVrijeme = 76;
const double _kolonaUsluga = 162;
const double _kolonaMajstor = 92;
const double _kolonaStatus = 102;

/// Skeleton reda rasporeda — **umjesto spinnera**, jer je dashboard prvi ekran poslije
/// prijave i indikator se na njemu vidi na *svakom* ulasku.
///
/// Spinner kaže „nešto se dešava"; skeleton kaže „ovdje dolazi tabela sa ovoliko redova",
/// pa se raspored ne pomjeri kad podaci stignu. Trake su u `neutralTint` i **blago pulsiraju**
/// — statične trake na sporoj vezi izgledaju kao da se učitavanje zaglavilo.
class _SkeletonRasporeda extends StatefulWidget {
  const _SkeletonRasporeda({this.redova = 5});

  final int redova;

  @override
  State<_SkeletonRasporeda> createState() => _SkeletonRasporedaState();
}

class _SkeletonRasporedaState extends State<_SkeletonRasporeda>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontroler = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Širine su nejednake namjerno: jednake trake izgledaju kao tabela, a ne kao tekst
    // koji tek dolazi. Prate kolone iz `_ZaglavljeTabele` — vrijeme, klijent, usluga,
    // majstor, status.
    const udjeli = [0.08, 0.22, 0.26, 0.14, 0.12];

    return AnimatedBuilder(
      animation: _kontroler,
      builder: (context, _) => Opacity(
        opacity: 0.45 + 0.35 * _kontroler.value,
        child: Column(
          children: [
            for (var red = 0; red < widget.redova; red++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.adminColors.separator,
                      width: AdminSize.hairline,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    for (final (i, udio) in udjeli.indexed) ...[
                      if (i > 0) const Spacer(),
                      Expanded(
                        flex: (udio * 100).round(),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: context.adminColors.neutralTint,
                            borderRadius: BorderRadius.circular(
                              AdminRadius.base,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZaglavljeTabele extends StatelessWidget {
  const _ZaglavljeTabele();

  @override
  Widget build(BuildContext context) {
    Widget celija(String tekst) => Text(
      tekst.toUpperCase(),
      style: AdminText.eyebrow.copyWith(
        color: context.adminColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: _kolonaVrijeme, child: celija('Vrijeme')),
          Expanded(child: celija('Klijent')),
          SizedBox(width: _kolonaUsluga, child: celija('Usluga')),
          SizedBox(width: _kolonaMajstor, child: celija('Majstor')),
          SizedBox(width: _kolonaStatus, child: celija('Status')),
        ],
      ),
    );
  }
}

class _RedTabele extends StatelessWidget {
  const _RedTabele({
    required this.termin,
    required this.opis,
    required this.uToku,
    required this.zadnji,
  });

  final Appointment termin;
  final TerminOpis opis;
  final bool uToku;
  final bool zadnji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zatvoren = termin.status.isClosed;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Termin koji traje je istaknut tintom, kako ga canvas crta; završen je stišan.
        color: uToku ? context.adminColors.accentTint : null,
        border: zadnji
            ? null
            : Border(
                bottom: BorderSide(
                  color: context.adminColors.separator,
                  width: AdminSize.hairline,
                ),
              ),
      ),
      child: Opacity(
        opacity: zatvoren ? 0.5 : 1,
        child: InkWell(
          onTap: () => context.go('/appointments/${termin.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            child: Row(
              children: [
                SizedBox(
                  width: _kolonaVrijeme,
                  child: Text(
                    vrijemeHhMm(termin.startTime),
                    style: AdminText.timeLarge.copyWith(
                      color: context.adminColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    termin.customerName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: uToku ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  width: _kolonaUsluga,
                  child: Text(
                    opis.usluga ?? '—',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.adminColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: _kolonaMajstor,
                  child: Text(
                    // Prazno, ne „—": termin bez radnika znači „bilo ko", a crtica se čita
                    // kao nedostajući podatak.
                    opis.majstor ?? 'bilo ko',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.adminColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: _kolonaStatus,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppointmentStatusPill(
                      status: termin.status,
                      uToku: uToku,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartica zahtjeva iz `3b` — prva dva, pa ulaz u punu listu.
class _ZahtjeviKartica extends ConsumerWidget {
  const _ZahtjeviKartica();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final zahtjevi = ref.watch(zahtjeviProvider).valueOrNull ?? const [];
    final broj = ref.watch(pendingCountProvider).valueOrNull ?? 0;
    final usluge = ref.watch(uslugePoIdProvider);
    final radnici = ref.watch(radniciPoIdProvider);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        side: BorderSide(
          color: broj > 0
              ? context.adminColors.accent
              : context.adminColors.border,
          width: AdminSize.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.adminColors.separator,
                  width: AdminSize.hairline,
                ),
              ),
            ),
            child: Row(
              children: [
                Text('Zahtjevi', style: theme.textTheme.headlineSmall),
                const Spacer(),
                Text(
                  broj == 0 ? 'nema novih' : '$broj ${_novihTekst(broj)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: broj > 0
                        ? context.adminColors.accent
                        : context.adminColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (zahtjevi.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AdminSpacing.xl),
              child: Text('Nijedan zahtjev ne čeka odgovor.'),
            )
          else ...[
            for (final zahtjev in zahtjevi.take(kZahtjevaUKartici))
              _ZahtjevRed(
                termin: zahtjev,
                opis: opisTermina(
                  zahtjev,
                  usluge: usluge,
                  radnici: radnici,
                  saCijenom: false,
                ),
              ),
            InkWell(
              onTap: () => context.go(kZahtjeviPutanja),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Text(
                  broj > kZahtjevaUKartici
                      ? 'Vidi svih $broj ${_zahtjevaTekst(broj)} →'
                      : 'Otvori zahtjeve →',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: context.adminColors.accentInk,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Jedan zahtjev u kartici: ko, šta i kada, pa dvije radnje.
class _ZahtjevRed extends ConsumerStatefulWidget {
  const _ZahtjevRed({required this.termin, required this.opis});

  final Appointment termin;
  final TerminOpis opis;

  @override
  ConsumerState<_ZahtjevRed> createState() => _ZahtjevRedState();
}

class _ZahtjevRedState extends ConsumerState<_ZahtjevRed> {
  /// Sprječava drugi tap dok prvi traje — isto pravilo kao u `AppointmentActionsBar`.
  bool _uToku = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final termin = widget.termin;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(termin.customerName, style: theme.textTheme.titleSmall),
          const SizedBox(height: AdminSpacing.xs),
          Text(
            [
              ?widget.opis.usluga,
              '${naslovDanaZaDatum(termin.date).toLowerCase()} '
                  '${vrijemeHhMm(termin.startTime)}',
              widget.opis.majstor ?? 'bilo ko',
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.adminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              SizedBox(
                height: AdminSize.buttonHeight + 2,
                child: FilledButton(
                  onPressed: _uToku ? null : _potvrdi,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text('Potvrdi'),
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                height: AdminSize.buttonHeight + 2,
                child: OutlinedButton(
                  onPressed: _uToku ? null : _odbij,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Odbij'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _potvrdi() => _izvrsi(
    () => ref.read(appointmentActionsProvider).potvrdi(widget.termin.id),
    uspjeh: 'Termin je potvrđen.',
  );

  /// Odbijanje **bez obrazloženja** ovdje, za razliku od liste termina.
  ///
  /// Kartica na dashboardu je brza odluka nad jednim od dva vidljiva zahtjeva; dijalog sa
  /// poljem za tekst je isti tok kao na listi, gdje ga `AppointmentActionsBar` i nudi.
  /// Obrazloženje je ionako opciono (`reject` prima `null`).
  Future<void> _odbij() => _izvrsi(
    () => ref.read(appointmentActionsProvider).odbij(widget.termin.id),
    uspjeh: 'Zahtjev je odbijen.',
  );

  Future<void> _izvrsi(
    Future<Appointment?> Function() poziv, {
    required String uspjeh,
  }) async {
    setState(() => _uToku = true);
    try {
      await poziv();
      if (!mounted) return;
      _poruka(uspjeh);
    } on ApiError catch (_) {
      if (!mounted) return;
      // Greška se prikazuje, ne guta: akcija koja tiho ne uradi ništa ostavlja vlasnika u
      // uvjerenju da je odgovorio, a klijent i dalje čeka.
      _poruka('Akcija nije uspjela. Pokušajte ponovo.');
    } finally {
      if (mounted) setState(() => _uToku = false);
    }
  }

  void _poruka(String tekst) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tekst)));
}

/// Ko je danas koliko zauzet — traka je **relativna**, v. `zauzetostPoRadniku`.
class _ZauzetostKartica extends ConsumerWidget {
  const _ZauzetostKartica();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final termini = ref.watch(danasnjiTerminiProvider).valueOrNull ?? const [];
    final radnici = ref.watch(radniciPoIdProvider);

    final zauzetost = zauzetostPoRadniku(termini, {
      for (final unos in radnici.entries) unos.key: unos.value.name,
    });
    final najvise = zauzetost.isEmpty ? 0 : zauzetost.first.minuta;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zauzetost majstora', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 14),
            if (zauzetost.isEmpty)
              Text(
                'Danas nijedan termin nije vezan za majstora.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.adminColors.textSecondary,
                ),
              )
            else
              for (final radnik in zauzetost)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            radnik.ime,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            // `terminaTekst` **nosi i broj** — prvi prolaz ga je ispisao
                            // dvaput („3 3 termina"). Testovi su gledali samo `40m`, pa to
                            // nije uhvatio nijedan; vidjelo se tek na snimku.
                            '${terminaTekst(radnik.termina)}'
                            ' · ${trajanjeKratko(radnik.minuta)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.adminColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: najvise == 0 ? 0 : radnik.minuta / najvise,
                          minHeight: 7,
                          backgroundColor: context.adminColors.neutralTint,
                          valueColor: AlwaysStoppedAnimation(
                            context.adminColors.accent,
                          ),
                        ),
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

// ---------------------------------------------------------------------------
// Telefon `3k`
// ---------------------------------------------------------------------------

class _Telefon extends ConsumerWidget {
  const _Telefon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termini = ref.watch(danasnjiTerminiProvider);
    final usluge = ref.watch(uslugePoIdProvider);
    final radnici = ref.watch(radniciPoIdProvider);
    final sada = DateTime.now();

    return Column(
      children: [
        const _MobilnoZaglavlje(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.gutterMobile,
              14,
              AdminSpacing.gutterMobile,
              22,
            ),
            children: [
              const _SalonKartica(),
              const SizedBox(height: AdminSpacing.md),
              const _ZahtjeviTraka(),
              const SizedBox(height: AdminSpacing.md),
              const _MobilneMetrike(),
              const SizedBox(height: AdminSpacing.xl),
              Text(
                'Raspored',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              termini.when(
                loading: () => const _SkeletonRasporeda(redova: 3),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(AdminSpacing.lg),
                  child: Text('Termini se ne mogu učitati.'),
                ),
                data: (lista) => lista.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AdminSpacing.xxl,
                        ),
                        child: Text('Danas nema zakazanih termina.'),
                      )
                    : Column(
                        children: [
                          for (final termin in lista)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppointmentCard(
                                termin: termin,
                                opis: opisTermina(
                                  termin,
                                  usluge: usluge,
                                  radnici: radnici,
                                ),
                                uToku: terminUToku(termin, sada),
                                onTap: () =>
                                    context.go('/appointments/${termin.id}'),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Zaglavlje iz `3k`: „Danas", datum i broj termina, pa nalog.
class _MobilnoZaglavlje extends ConsumerWidget {
  const _MobilnoZaglavlje();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final termini = ref.watch(danasnjiTerminiProvider).valueOrNull ?? const [];
    final uDanu = termini.where(terminSeRacuna).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.gutterMobile,
        AdminSpacing.md,
        AdminSpacing.sm,
        AdminSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.adminColors.surface,
        border: Border(
          bottom: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Danas', style: theme.textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Text(
                    '${datumDugo(DateTime.now())} · '
                    '${terminaTekst(uDanu)}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: context.adminColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const AdminNalogDugme(ikona: true),
          ],
        ),
      ),
    );
  }
}

/// Ime salona iz `3k`. **Bez birača lokacije** — to je `3a`, izvan sprinta.
class _SalonKartica extends ConsumerWidget {
  const _SalonKartica();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salon = ref.watch(adminSalonProvider).valueOrNull;
    if (salon == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 20,
              color: context.adminColors.textSecondary,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                salon.name,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Traka zahtjeva iz `3k` — jedno veliko dugme, jer je to jedina radnja na ovom ekranu.
class _ZahtjeviTraka extends ConsumerWidget {
  const _ZahtjeviTraka();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final broj = ref.watch(pendingCountProvider).valueOrNull ?? 0;
    if (broj == 0) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        side: BorderSide(
          color: context.adminColors.accent,
          width: AdminSize.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$broj ${_zahtjevaTekst(broj)} ${_cekaTekst(broj)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: context.adminColors.accentInk,
              ),
            ),
            const SizedBox(height: AdminSpacing.md),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: () => context.go(kZahtjeviPutanja),
                style: FilledButton.styleFrom(
                  textStyle: theme.textTheme.titleMedium,
                ),
                child: const Text('Pregledaj zahtjeve'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dvije kartice iz `3k`: „Predstoji danas" i „Promet do sada".
class _MobilneMetrike extends ConsumerWidget {
  const _MobilneMetrike();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sazetak = ref.watch(_sazetakProvider);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MalaMetrika(
              labela: 'Predstoji danas',
              vrijednost: '${sazetak.predstoji}',
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: _MalaMetrika(
              labela: 'Promet do sada',
              vrijednost: iznosKm(sazetak.prometDoSada),
            ),
          ),
        ],
      ),
    );
  }
}

class _MalaMetrika extends StatelessWidget {
  const _MalaMetrika({required this.labela, required this.vrijednost});

  final String labela;
  final String vrijednost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labela,
              style: theme.textTheme.labelSmall?.copyWith(
                color: context.adminColors.textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              vrijednost,
              style: AdminText.metricNumber.copyWith(fontSize: 28),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zajedničko
// ---------------------------------------------------------------------------

/// Sažetak dana iz termina i cjenovnika.
///
/// Provider, a ne račun u `build`-u: isti sažetak čitaju tri mjesta na desktopu i dva na
/// telefonu, a ovako se računa jednom po promjeni podataka.
final _sazetakProvider = Provider<DashboardSazetak>((ref) {
  final termini = ref.watch(danasnjiTerminiProvider).valueOrNull ?? const [];
  return DashboardSazetak.izracunaj(termini, ref.watch(cijenePoUsluziProvider));
});

String _zahtjevaTekst(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return 'zahtjeva';
  if (zadnja == 1) return 'zahtjev';
  if (zadnja >= 2 && zadnja <= 4) return 'zahtjeva';
  return 'zahtjeva';
}

String _cekaTekst(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return 'čeka';
  if (zadnja == 1) return 'čeka';
  return zadnja >= 2 && zadnja <= 4 ? 'čekaju' : 'čeka';
}

String _novihTekst(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return 'novih';
  if (zadnja == 1) return 'nov';
  return zadnja >= 2 && zadnja <= 4 ? 'nova' : 'novih';
}

String _majstoraTekst(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return 'majstora';
  if (zadnja == 1) return 'majstor';
  return zadnja >= 2 && zadnja <= 4 ? 'majstora' : 'majstora';
}
