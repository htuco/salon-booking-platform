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
/// ## 1:1 sa `3b` (ADR-0020)
///
/// Do ADR-0020 je ovdje stajala lista od pet stvari koje canvas crta, a ekran ne. Tri su
/// čekale taskove 33–35, koji su zatvoreni, a jedna (`created_at`) je tvrdila da kolona ne
/// postoji, iako postoji od init migracije. Sve četiri su sada nacrtane: kartica „Slobodno
/// vrijeme", procenat zauzetosti, „Otvoreno do", pretraga klijenta i „prije 26 min".
///
/// Jedino što `3b` crta, a ovdje ne postoji, je **prelaz na mrežu lokacija** (`▾` uz ime
/// salona i „‹ Nazad na mrežu") — to je ekran `3a`, koji nema ni rutu ni podatak: admin
/// dobija tačno jedan salon iz membershipa. V. `admin_scaffold.dart`.
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
import '../clients/clients_providers.dart';
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
            ..invalidate(zahtjeviProvider)
            ..invalidate(dashboardRasporedProvider)
            ..invalidate(dashboardBlokadeProvider);
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
      // Bez ovoga se red razvuce preko ostatka top bara i dugmad ostanu na njegovom
      // pocetku, a ne uz desnu ivicu.
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pretraga ide samo kad stane uz obje akcije i breadcrumb. Ispod 1200 px prozora
        // top bar je prelio za 43 px (test na 1100) — polje se tada izostavlja, a ne
        // sužava: pretraga uža od imena koje se traži nije pretraga. `/clients` je u
        // sidebaru jedan klik dalje.
        if (MediaQuery.sizeOf(context).width >= 1200) ...[
          const _PretragaKlijenta(),
          const SizedBox(width: 10),
        ],
        SizedBox(
          height: 42,
          child: OutlinedButton(
            onPressed: () => context.go(AdminRoute.calendarBlock.path),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Blokiraj termin'),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 42,
          child: FilledButton(
            onPressed: () => context.go(AdminRoute.appointmentNew.path),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              textStyle: AdminText.actionLabel,
            ),
            child: const _Verzal('+ Novi termin'),
          ),
        ),
      ],
    );
  }
}

/// Polje „Pretraži klijenta" iz `3b` — 268 × 42.
///
/// Ne traži na licu mjesta: izraz se upiše u `clientsPretragaProvider` i otvori se
/// `/clients`, koji ga već zna čitati (task 35). Druga lista rezultata u padajućem meniju
/// top bara bi bila drugi adresar sa svojim upitom.
class _PretragaKlijenta extends ConsumerStatefulWidget {
  const _PretragaKlijenta();

  @override
  ConsumerState<_PretragaKlijenta> createState() => _PretragaKlijentaState();
}

class _PretragaKlijentaState extends ConsumerState<_PretragaKlijenta> {
  final _kontroler = TextEditingController();

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 268,
      height: 42,
      child: TextField(
        controller: _kontroler,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: const InputDecoration(
          hintText: 'Pretraži klijenta',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
        onSubmitted: (izraz) {
          ref.read(clientsPretragaProvider.notifier).postavi(izraz.trim());
          context.go(AdminRoute.clients.path);
        },
      ),
    );
  }
}

/// Tekst primarnog dugmeta **u verzalu** — `+ NOVI TERMIN`, `POTVRDI` (`3b`).
///
/// Flutter nema `text-transform`, pa verzal mora biti u stringu. `semanticsLabel` zato
/// nosi original: čitač ekrana „POTVRDI" čita slovo po slovo kao skraćenicu.
class _Verzal extends StatelessWidget {
  const _Verzal(this.tekst);

  final String tekst;

  @override
  Widget build(BuildContext context) =>
      Text(tekst.toUpperCase(), semanticsLabel: tekst);
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
        SizedBox(height: 20),
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
    final smjene = ref.watch(_smjeneProvider);
    final salon = ref.watch(_otvorenoProvider);

    // `3b`: „3 majstora u smjeni · prvi termin 09:00 · zadnji 19:20". Broj u smjeni ide
    // samo kad je raspored stigao — „0 majstora u smjeni" prije učitavanja bi tvrdilo da
    // salon danas ne radi.
    final dijelovi = [
      if (smjene.isNotEmpty)
        '${smjene.length} ${_majstoraTekst(smjene.length)} u smjeni',
      if (uDanu.isEmpty)
        'nema zakazanih termina'
      else ...[
        'prvi termin ${vrijemeHhMm(uDanu.first.startTime)}',
        'zadnji ${vrijemeHhMm(uDanu.last.startTime)}',
      ],
    ];
    final podnaslov = dijelovi.join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(datumDugo(DateTime.now()), style: AdminText.display),
              const SizedBox(height: 7),
              Text(
                podnaslov[0].toUpperCase() + podnaslov.substring(1),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        if (salon != null)
          _OtvorenoDo(stanje: salon.stanje, tekst: salon.tekst),
      ],
    );
  }
}

/// „● Otvoreno do 20:00" desno od podnaslova (`3b`).
class _OtvorenoDo extends StatelessWidget {
  const _OtvorenoDo({required this.stanje, required this.tekst});

  final StanjeSalona stanje;
  final String tekst;

  @override
  Widget build(BuildContext context) {
    // Zelena tačka samo kad je stvarno otvoreno — tačka iste boje uz „Zatvoreno" bi se
    // čitala kao „radi".
    final boja = stanje == StanjeSalona.otvoreno
        ? context.adminColors.positiveInk
        : context.adminColors.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: boja, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Text(
          tekst,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.adminColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Četiri kartice sa brojkama iz `3b`.
class _KarticeMetrika extends ConsumerWidget {
  const _KarticeMetrika();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sazetak = ref.watch(_sazetakProvider);
    final naCekanju = ref.watch(pendingCountProvider).valueOrNull ?? 0;
    final zahtjevi = ref.watch(zahtjeviProvider).valueOrNull ?? const [];
    final najstariji = prijeKoliko(najstarijiZahtjev(zahtjevi), DateTime.now());
    final slobodno = ref.watch(_slobodnoProvider);
    final rupa = slobodno?.najvecaRupa;

    final kartice = [
      _Metrika(
        labela: 'Termina danas',
        vrijednost: '${sazetak.ukupno}',
        opis: '${sazetak.zavrseno} završeno · ${sazetak.predstoji} predstoji',
      ),
      _Metrika(
        labela: 'Čeka potvrdu',
        vrijednost: '$naCekanju',
        opis: naCekanju == 0
            ? 'nema novih zahtjeva'
            : najstariji == null
            ? 'traže odgovor'
            : 'najstariji $najstariji',
        istaknuta: naCekanju > 0,
      ),
      _Metrika(
        labela: 'Slobodno vrijeme',
        // Crtica dok raspored ne stigne, ne „0m": nula bi rekla da je dan pun.
        vrijednost: slobodno == null ? '—' : trajanjeKratko(slobodno.minuta),
        opis: slobodno == null
            ? 'nema smjena za danas'
            : rupa == null
            ? 'nema slobodnih rupa'
            : 'najveća rupa ${_hhmm(rupa.od)}–${_hhmm(rupa.doMinute)}',
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
              : context.adminColors.cardEdge,
          width: AdminSize.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
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
                  radnici.isEmpty ? '' : _svihMajstora(radnici.length),
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
          child: Container(
            // `3b`: red je 54 px, sa pilulom ili bez nje. Visina iz paddinga bi zavisila od
            // toga koji je element u redu najviši.
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                SizedBox(
                  width: _kolonaVrijeme,
                  child: Text(
                    vrijemeHhMm(termin.startTime),
                    // Vrijeme je u `3b` boje imena, ne sporednog teksta — ono je ključ reda.
                    style: AdminText.timeLarge.copyWith(
                      color: context.adminColors.ink,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    termin.customerName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
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
                    // kao nedostajući podatak. **Samo ime** — `3b` piše „Emir", a kolona
                    // od 92 px pod punim imenom i prezimenom reže svaki red.
                    opis.majstor == null ? 'bilo ko' : _ime(opis.majstor!),
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
          // Koralna, kao obrub kartice „Čeka potvrdu" — izmjereno iz `3b` (`#EE6C4D`).
          // Plava je ovdje ostala kad je FE-402 prebacio samo karticu metrike.
          color: broj > 0
              ? context.adminColors.action
              : context.adminColors.cardEdge,
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
                      ? 'Vidi ${_sveSvih(broj)} $broj ${_zahtjevaTekst(broj)} →'
                      : 'Otvori zahtjeve →',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: context.adminColors.accentInk,
                    fontWeight: FontWeight.w600,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  termin.customerName,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 16),
                ),
              ),
              if (prijeKoliko(termin.createdAt, DateTime.now())
                  case final prije?)
                Text(
                  prije,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.adminColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AdminSpacing.xs),
          Text(
            [
              ?widget.opis.usluga,
              '${naslovDanaZaDatum(termin.date).toLowerCase()} '
                  '${vrijemeHhMm(termin.startTime)}',
              if (widget.opis.majstor case final majstor?)
                _ime(majstor)
              else
                'bilo ko',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14.5,
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
                    textStyle: AdminText.actionLabel,
                  ),
                  child: const _Verzal('Potvrdi'),
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
      for (final unos in radnici.entries) unos.key: _ime(unos.value.name),
    }, smjene: ref.watch(_smjeneProvider));
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
                            '${terminaTekst(radnik.termina)} · '
                            '${radnik.procenat == null ? trajanjeKratko(radnik.minuta) : '${radnik.procenat}%'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: context.adminColors.ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AdminRadius.small),
                        // Traka podatka, ne indikator ucitavanja: `value` je udio
                        // minuta tog radnika u najduzem danu, boje su iz tokena.
                        // FE-205 sklanja spinnere, ne mjerila.
                        // ignore: FE-205 traka podatka
                        child: LinearProgressIndicator(
                          // Procenat smjene kad postoji (`3b`), inače relativno prema
                          // najzauzetijem — radnik bez smjene nema kapacitet.
                          value: radnik.procenat != null
                              ? radnik.procenat! / 100
                              : najvise == 0
                              ? 0
                              : radnik.minuta / najvise,
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

/// Raspored salona — salonski redovi i oni po radniku, jedno čitanje.
///
/// Zaseban od `kalendarRadnoVrijemeProvider`: onaj je `autoDispose` uz kalendar, a
/// dashboard ne smije zavisiti od toga da li je kalendar otvoren.
final dashboardRasporedProvider = FutureProvider<List<WorkingHour>>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(workingHoursRepositoryProvider).forSalon(salonId);
});

/// Današnje blokade — ulaze u „Slobodno vrijeme" kao zauzeto.
final dashboardBlokadeProvider = FutureProvider<List<BlockedSlot>>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];
  return ref
      .watch(blockedSlotRepositoryProvider)
      .forDay(salonId: salonId, day: DateTime.now());
});

/// Ko je danas u smjeni. Prazno dok raspored ili radnici ne stignu.
final _smjeneProvider = Provider<List<SmjenaDana>>((ref) {
  final raspored = ref.watch(dashboardRasporedProvider).valueOrNull;
  final radnici = ref.watch(radniciPoIdProvider);
  if (raspored == null || radnici.isEmpty) return const [];
  return smjeneDana(raspored, radnici.keys, DateTime.now().weekday);
});

/// Slobodno vrijeme od sada; `null` kad danas niko nije u smjeni.
final _slobodnoProvider = Provider<SlobodnoVrijeme?>((ref) {
  final smjene = ref.watch(_smjeneProvider);
  if (smjene.isEmpty) return null;
  final sada = DateTime.now();
  return slobodnoVrijeme(
    smjene: smjene,
    termini: ref.watch(danasnjiTerminiProvider).valueOrNull ?? const [],
    blokade: ref.watch(dashboardBlokadeProvider).valueOrNull ?? const [],
    sadaMinuta: sada.hour * 60 + sada.minute,
  );
});

/// „Otvoreno do 20:00"; `null` dok raspored ne stigne.
final _otvorenoProvider = Provider<({StanjeSalona stanje, String tekst})?>((
  ref,
) {
  final raspored = ref.watch(dashboardRasporedProvider).valueOrNull;
  if (raspored == null) return null;
  final sada = DateTime.now();
  return otvorenoDo(raspored, sada.weekday, sada.hour * 60 + sada.minute);
});

/// Minute od ponoći kao `17:20`.
String _hhmm(int minuta) =>
    '${(minuta ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuta % 60).toString().padLeft(2, '0')}';

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

/// Prvo ime — „Emir" iz „Emir Barucija", kako `3b` piše majstora u tabeli i zauzetosti.
String _ime(String punoIme) {
  final dijelovi = punoIme.trim().split(RegExp(r'\s+'));
  return dijelovi.isEmpty || dijelovi.first.isEmpty ? punoIme : dijelovi.first;
}

/// „Sva tri majstora" (`3b`), „Oba majstora", „Svih 5 majstora".
String _svihMajstora(int broj) => switch (broj) {
  1 => '1 majstor',
  2 => 'Oba majstora',
  3 => 'Sva tri majstora',
  4 => 'Sva četiri majstora',
  _ => 'Svih $broj majstora',
};

/// „sva 4" za 2–4, „svih 12" za ostalo — „Vidi sva 4 zahtjeva" u `3b`.
String _sveSvih(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return 'svih';
  return zadnja >= 2 && zadnja <= 4 ? 'sva' : 'svih';
}
