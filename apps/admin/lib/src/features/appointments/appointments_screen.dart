/// Termini i zahtjevi — prikazi `3d` (desktop) i `3m` (telefon).
///
/// **Jedna ruta, dva lica.** `/appointments` je puna lista dana;
/// `/appointments?status=pending` je ekran zahtjeva, koji handoff crta kao zaseban prikaz.
/// Zasebna ruta za zahtjeve bi punu listu ostavila bez ijednog ulaza iz navigacije (task
/// 29), pa je razlika u filteru, a ne u adresi stabla.
///
/// Zahtjevi se **ne drže jednog dana**: klijent traži termin i za sutra i za dvije sedmice,
/// pa filter dana u tom licu ekrana ne stoji. Puna lista bez filtera statusa je i dalje
/// dnevna, jer se raspored gleda po danu.
///
/// ## Placeholderi i ono što namjerno nije nacrtano
///
/// Kartice zahtjeva su u `zahtjev_kartica.dart`; tamo je i popis njihovih placeholdera.
/// Na nivou ekrana:
///
/// - **Tabovi „Odbijeni" i „Otkazali klijenti"** (`3d`) stoje bez brojke i tap kaže
///   „uskoro": brojka traži upit po `cancelled_by` kroz više dana, kojeg nema.
///   „Potvrđeni danas" ima brojku iz današnjih termina i vodi u punu listu.
/// - **„prosjek odgovora 8 min"** (`3m`) nema podatak (vrijeme odgovora se ne bilježi).
///   Na njegovom mjestu stoji starost najstarijeg zahtjeva, koja se zna iz `created_at`.
/// - **„Sukobi su označeni"** iz podnaslova `3d` se ne piše — sukobi se ne računaju.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/admin_refresh.dart';
import '../../core/format/datum.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/admin_verzal.dart';
import '../dashboard/dashboard_summary.dart'
    show najstarijiZahtjev, prijeKoliko;
import 'appointment_actions_bar.dart';
import 'appointment_card.dart';
import 'appointments_providers.dart';
import 'zahtjev_kartica.dart';

/// Najmanja širina na kojoj se kartica termina još da složiti.
///
/// Ranije je ovdje stajala granica **cijele liste** (1176 px, širina radne površine iz `3d`)
/// i lista je bila centrirana, pa je admin na 1920 i 2560 px imao po nekoliko stotina
/// piksela prazne margine sa svake strane umjesto radne površine.
///
/// Zamjena nije veća granica nego **donja**: višak prostora se troši na nove kolone, a broj
/// kolona ograničava ovo — ime klijenta, vrijeme i tri dugmeta u redu traže oko 360 px, pa
/// uža kartica lomi radnje u dva reda.
const double _minSirinaKartice = 360;

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  const AdminAppointmentsScreen({this.trazeniStatus, super.key});

  /// Status iz `?status=` u adresi, ili `null` za „svi".
  ///
  /// Dolazi iz **route buildera**, ne iz `GoRouterState` u ovom ekranu — v. komentar uz
  /// rutu. Zahvaljujući tome ekran se i dalje diže u testu bez routera.
  final AppointmentStatus? trazeniStatus;

  @override
  ConsumerState<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState
    extends ConsumerState<AdminAppointmentsScreen> {
  @override
  void initState() {
    super.initState();
    // Filter je app-scoped `Notifier`, a adresa je ono što korisnik vidi — kad se ekran
    // otvori sa `?status=`, adresa je jača. Upis ide poslije prvog frame-a jer se provider
    // ne smije mijenjati usred gradnje widgeta.
    final trazeni = widget.trazeniStatus;
    if (trazeni != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(appointmentsFilterProvider.notifier)
            .postaviStatusTacno(trazeni);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(appointmentsFilterProvider);
    final jeDesktop = AdminShell.jeDesktop(context);
    final zahtjevi = filter.status == AppointmentStatus.pending;

    // Zahtjevi gledaju naprijed kroz dane, puna lista gleda jedan dan.
    final lista = zahtjevi
        ? ref.watch(zahtjeviProvider)
        : ref.watch(filtriraniTerminiProvider);

    return AdminScaffold(
      // Naslov prati filter, jer ista ruta nosi dvije ćelije navigacije: „Zahtjevi" vode
      // ovdje sa `?status=pending`. Ekran naslovljen „Termini" poslije tapa na „Zahtjeve"
      // izgleda kao da je ćelija promašila.
      title: zahtjevi ? 'Zahtjevi' : 'Termini',
      aktivna: AdminRoute.appointments,
      sopstvenoZaglavlje: true,
      actions: jeDesktop
          ? [zahtjevi ? const _PotvrdiSveDugme() : const _NoviTerminDugme()]
          : null,
      // Ručni unos je jedini ulaz u `/appointments/new` — bez njega ekran postoji ali se do
      // njega ne može doći iz aplikacije, što je rupa koju je task 17 već jednom našao sa
      // `/account`. Na desktopu isto dugme stoji u top baru, pa se FAB ne crta dvaput.
      floatingActionButton: jeDesktop || zahtjevi
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(AdminRoute.appointmentNew.path),
              icon: const Icon(Icons.add),
              label: const Text('Novi termin'),
            ),
      body: Column(
        children: [
          _Zaglavlje(filter: filter, zahtjevi: zahtjevi, lista: lista),
          Expanded(
            child: lista.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AdminSpacing.xxl),
                child: AdminSkeletonList(),
              ),
              // Greška nosi dugme, ne samo tekst: admin koji izgubi vezu usred smjene mora
              // moći ponoviti bez zatvaranja app-e.
              error: (greska, _) => _Greska(
                poruka: greska is ApiError
                    ? 'Termini se ne mogu učitati.'
                    : 'Došlo je do greške.',
                onPonovi: () => ref.invalidate(
                  zahtjevi ? zahtjeviProvider : filtriraniTerminiProvider,
                ),
              ),
              data: (termini) => termini.isEmpty
                  ? _PrazanDan(filter: filter, zahtjevi: zahtjevi)
                  : AdminRefresh(
                      onRefresh: () async => ref.invalidate(
                        zahtjevi ? zahtjeviProvider : filtriraniTerminiProvider,
                      ),
                      child: _Lista(termini: termini, zahtjevi: zahtjevi),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Naslov, podnaslov, izbor dana i čipovi statusa.
class _Zaglavlje extends ConsumerWidget {
  const _Zaglavlje({
    required this.filter,
    required this.zahtjevi,
    required this.lista,
  });

  final AppointmentsFilter filter;
  final bool zahtjevi;
  final AsyncValue<List<Appointment>> lista;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jeDesktop = AdminShell.jeDesktop(context);
    final termini = lista.valueOrNull ?? const <Appointment>[];
    final broj = termini.length;

    // `3m` na telefonu naslovljava ekran imenom modula i broj spušta u podnaslov; `3d` na
    // desktopu broj stavlja u naslov, jer je ime modula već u breadcrumbu.
    final String naslov;
    final String podnaslov;
    if (!zahtjevi) {
      naslov = naslovDana(filter.dan);
      podnaslov = datumSaGodinom(filter.dan);
    } else if (jeDesktop) {
      naslov = broj == 0 ? 'Nema zahtjeva' : '$broj ${_cekajuTekst(broj)}';
      podnaslov = 'Klijent vidi „na čekanju" dok ne odgovorite.';
    } else {
      naslov = 'Zahtjevi';
      final najstariji = prijeKoliko(
        najstarijiZahtjev(termini),
        DateTime.now(),
      );
      podnaslov = broj == 0
          ? 'Nijedan ne čeka'
          : [
              '$broj ${_cekajuTekst(broj).split(' ').last}',
              if (najstariji != null) 'najstariji $najstariji',
            ].join(' · ');
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AdminShell.gutterOf(context),
        jeDesktop ? AdminSpacing.gutterDesktop : AdminSpacing.md,
        AdminShell.gutterOf(context),
        // Desktop zahtjevi: razmak do prve kartice daje lista (20, `3d`).
        zahtjevi && jeDesktop
            ? 0
            : zahtjevi
            ? AdminSpacing.md
            : AdminSpacing.lg,
      ),
      decoration: BoxDecoration(
        // Na telefonu je zaglavlje bijela traka iznad sive radne površine (`3m`); na
        // desktopu stoji **na** radnoj površini, jer je iznad njega već top bar.
        color: jeDesktop ? null : context.adminColors.surface,
        border: jeDesktop
            ? null
            : Border(
                bottom: BorderSide(
                  color: context.adminColors.separator,
                  width: AdminSize.hairline,
                ),
              ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        naslov,
                        style: jeDesktop
                            ? AdminText.display
                            : theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: AdminSpacing.xs),
                      Text(
                        podnaslov,
                        // `3d` 16 px, `3m` 15 px.
                        style:
                            (jeDesktop
                                    ? theme.textTheme.bodyLarge
                                    : theme.textTheme.bodyMedium)
                                ?.copyWith(
                                  color: context.adminColors.textSecondary,
                                ),
                      ),
                    ],
                  ),
                ),
                // `3m` zahtjevi nemaju dugme naloga u zaglavlju; nalog je iza „Još".
                if (!jeDesktop && !zahtjevi) const AdminNalogDugme(ikona: true),
              ],
            ),
            if (!zahtjevi) ...[
              const SizedBox(height: AdminSpacing.md),
              _IzborDana(filter: filter),
              const SizedBox(height: AdminSpacing.lg),
              _Cipovi(filter: filter),
            ] else if (jeDesktop) ...[
              const SizedBox(height: AdminSpacing.xl),
              _ZahtjeviTabovi(broj: broj),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dan naprijed/nazad i kalendar. Stoji samo u punoj listi — zahtjevi nisu dnevni.
class _IzborDana extends ConsumerWidget {
  const _IzborDana({required this.filter});

  final AppointmentsFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appointmentsFilterProvider.notifier);

    // `Flexible` oko datuma, uz `mainAxisSize.min`: bez njega dvije strelice plus
    // „19. septembar 2026." na 402 px izlaze 48 px van ekrana, a sa `Expanded` se dugme na
    // 1440 razvuče preko cijele radne površine. Prvo je našao test, drugo snimak.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => notifier.pomjeriDan(-1),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Prethodni dan',
        ),
        Flexible(
          child: OutlinedButton(
            onPressed: () async {
              final izabran = await showDatePicker(
                context: context,
                initialDate: filter.dan,
                // Prošli termini se gledaju (ko se nije pojavio, šta je odrađeno), pa raspon
                // ide i unazad — ne samo naprijed.
                firstDate: DateTime(2024),
                lastDate: DateTime(2030, 12, 31),
              );
              if (izabran != null) notifier.postaviDan(izabran);
            },
            child: Text(
              datumSaGodinom(filter.dan),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
          onPressed: () => notifier.pomjeriDan(1),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Sljedeći dan',
        ),
      ],
    );
  }
}

/// Čipovi statusa iz `3d`: izabrani je pun akcent, ostali su obrub.
class _Cipovi extends ConsumerWidget {
  const _Cipovi({required this.filter});

  final AppointmentsFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appointmentsFilterProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Cip(
            labela: 'Svi',
            izabran: filter.status == null,
            onTap: () => notifier.postaviStatus(null),
          ),
          // `unknown` se ne nudi kao filter: to je status koji ova verzija app-e ne
          // poznaje, a ne nešto što vlasnik bira.
          for (final status in AppointmentStatus.values)
            if (status != AppointmentStatus.unknown)
              _Cip(
                labela: statusLabela(status),
                izabran: filter.status == status,
                onTap: () => notifier.postaviStatus(status),
              ),
        ],
      ),
    );
  }
}

/// Tabovi iz `3d`: „Nepotvrđeni" je ovaj ekran, ostali vode dalje.
class _ZahtjeviTabovi extends ConsumerWidget {
  const _ZahtjeviTabovi({required this.broj});

  final int broj;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appointmentsFilterProvider.notifier);
    // Brojka dolazi iz današnjih termina koje dashboard već drži, ne iz novog upita.
    final potvrdjeniDanas = ref
        .watch(danasnjiTerminiProvider)
        .valueOrNull
        ?.where((t) => t.status == AppointmentStatus.confirmed)
        .length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Cip(labela: 'Nepotvrđeni ($broj)', izabran: true, onTap: () {}),
          _Cip(
            labela: potvrdjeniDanas == null
                ? 'Potvrđeni danas'
                : 'Potvrđeni danas ($potvrdjeniDanas)',
            izabran: false,
            onTap: () {
              final sada = DateTime.now();
              notifier
                ..postaviDan(DateTime(sada.year, sada.month, sada.day))
                ..postaviStatusTacno(AppointmentStatus.confirmed);
            },
          ),
          // Bez brojke: nema upita po `cancelled_by` kroz više dana.
          _Cip(
            labela: 'Odbijeni',
            izabran: false,
            onTap: () => pokaziUskoro(context, 'Pregled odbijenih'),
          ),
          _Cip(
            labela: 'Otkazali klijenti',
            izabran: false,
            onTap: () => pokaziUskoro(context, 'Pregled otkazivanja'),
          ),
        ],
      ),
    );
  }
}

/// Jedan tab/čip. Izabrani je koralna ispuna sa verzalom (`3d` „NEPOTVRĐENI (4)"),
/// ostali su bijeli sa obrubom kontrole i pišu se u rečenici.
class _Cip extends StatelessWidget {
  const _Cip({
    required this.labela,
    required this.izabran,
    required this.onTap,
  });

  final String labela;
  final bool izabran;
  final VoidCallback onTap;

  /// `3d`: tab je 38 px visok, tekst 18 px od ruba.
  static const double _visina = 38;
  static const double _uvlaka = 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boje = context.adminColors;

    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: Material(
        color: izabran ? boje.action : boje.surface,
        // Obrub ide kroz `shape`, pa `borderRadius` uz njega **nije dozvoljen** —
        // `Material` to provjerava assertom i ruši ekran, ne samo čip.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadius.base),
          side: BorderSide(
            color: izabran ? boje.action : boje.border,
            width: AdminSize.hairline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdminRadius.base),
          child: Container(
            height: _visina,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: _uvlaka),
            child: izabran
                ? DefaultTextStyle.merge(
                    style: AdminText.actionLabel.copyWith(color: boje.onAction),
                    child: AdminVerzal(labela),
                  )
                : Text(
                    labela,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: boje.ink,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Lista kartica, centrirana i ograničena po širini na desktopu.
class _Lista extends ConsumerWidget {
  const _Lista({required this.termini, required this.zahtjevi});

  final List<Appointment> termini;
  final bool zahtjevi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jeDesktop = AdminShell.jeDesktop(context);
    final usluge = ref.watch(uslugePoIdProvider);
    final radnici = ref.watch(radniciPoIdProvider);
    final gutter = AdminShell.gutterOf(context);

    // **`LayoutBuilder`, ne `MediaQuery`.** Ovaj ekran stoji u ljusci pored sidebara, pa je
    // dostupna širina za `AdminSize.sidebarWidth` manja od širine prozora; pojas izveden iz
    // prozora bi dao kolonu viška.
    return LayoutBuilder(
      builder: (context, constraints) {
        final band = AdminShell.bandZa(constraints.maxWidth);
        // Pojas kaže koliko kolona *smije*, a najmanja čitljiva kartica koliko ih *stane*.
        // Uzima se manje od toga: bez donje granice bi četiri kolone na 1200 px dale
        // kartice od 280 px, u kojima se ime, vrijeme i tri dugmeta ne mogu složiti.
        //
        // **`_minSirinaKartice` je *donja* granica, ne gornja.** Dijeljenje najvećom
        // dopuštenom širinom bi na 2324 px dalo jednu kolonu i vratilo tačno onu razvučenu
        // karticu preko cijelog stola koju FE-406 uklanja.
        final stane =
            ((constraints.maxWidth - gutter * 2 + AdminSpacing.md) /
                    (_minSirinaKartice + AdminSpacing.md))
                .floor();
        // **Zahtjevi ostaju jedna kolona.** `ZahtjevRedDesktop` je raspored iz `3d`: vrijeme
        // lijevo, podaci u sredini, radnje desno — tri zone u `Row`-u, računate za punu
        // radnu površinu. U koloni od ~560 px taj red prelije za 300 px. Handoff `3d` i
        // crta zahtjeve kao listu preko cijele širine, pa mreža ovdje nije ni tražena.
        final kolone = zahtjevi && jeDesktop
            ? 1
            : (band.kolone < stane ? band.kolone : stane.clamp(1, 4));

        // **Zahtjev ipak ima gornju granicu, i to je namjerno druga odluka od liste.**
        // Kad kartica u jednoj koloni dobije punu radnu površinu (2324 px na 2560), tri
        // zone se razvuku na krajeve stola: ime lijevo, „Potvrdi" desno, između prazno.
        // To je tačno ono protiv čega je stajala stara granica od 1176 px. Lista se od
        // viška prostora brani kolonama, zahtjev nema tu mogućnost, pa se brani mjerom.
        // **Viđeno u browseru na 1920 i 2560 px**, nije izvedeno iz koda.
        // Vlasnik je tražio punu širinu kao na „Danas", pa granice više nema.
        const double? maxKartica = null;

        Widget karticaZa(int i) {
          final termin = termini[i];
          final opis = opisTermina(termin, usluge: usluge, radnici: radnici);

          void otvori() => context.go('/appointments/${termin.id}');

          if (zahtjevi) {
            return jeDesktop
                ? ZahtjevRedDesktop(termin: termin, opis: opis, onTap: otvori)
                : ZahtjevKarticaTelefon(
                    termin: termin,
                    opis: opis,
                    onTap: otvori,
                  );
          }

          return AppointmentCard(
            termin: termin,
            opis: opis,
            onTap: otvori,
            podnozje: AppointmentActionsBar(termin: termin),
          );
        }

        // `3d`: 16 između redova zahtjeva, 20 od tabova do prvog; `3m`: 12 i 16.
        final razmak = zahtjevi && jeDesktop
            ? AdminSpacing.lg
            : AdminSpacing.md;
        final padding = EdgeInsets.fromLTRB(
          gutter,
          zahtjevi && jeDesktop ? AdminSpacing.xl : AdminSpacing.lg,
          gutter,
          40,
        );

        // Jedna kolona ostaje `ListView`: lijeni build nosi duge liste, a `Wrap` bi gradio
        // svaku karticu odjednom.
        if (kolone == 1) {
          final lista = ListView.separated(
            padding: padding,
            itemCount: termini.length,
            separatorBuilder: (_, _) => SizedBox(height: razmak),
            itemBuilder: (context, i) => karticaZa(i),
          );

          if (maxKartica == null) return lista;

          // Poravnato lijevo, ne centrirano: kartice stoje uz sidebar uz koji pripadaju,
          // umjesto da vise u sredini stola.
          return Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxKartica + gutter * 2),
              child: lista,
            ),
          );
        }

        final sirinaKolone =
            (constraints.maxWidth - gutter * 2 - razmak * (kolone - 1)) /
            kolone;

        return SingleChildScrollView(
          padding: padding,
          child: Wrap(
            spacing: razmak,
            runSpacing: razmak,
            children: [
              for (var i = 0; i < termini.length; i++)
                SizedBox(width: sirinaKolone, child: karticaZa(i)),
            ],
          ),
        );
      },
    );
  }
}

/// „+ Novi termin" u top baru pune liste.
class _NoviTerminDugme extends StatelessWidget {
  const _NoviTerminDugme();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => context.go(AdminRoute.appointmentNew.path),
      style: FilledButton.styleFrom(textStyle: AdminText.actionLabel),
      child: const AdminVerzal('+ Novi termin'),
    );
  }
}

/// „Potvrdi sve bez preklapanja" iz `3d`.
///
/// **Preklapanje ne provjerava aplikacija nego baza.** `appointments_no_overlap` je
/// exclusion constraint, pa potvrda zahtjeva koji se sudara sa već potvrđenim terminom
/// padne sa greškom; ovo dugme zato pokušava redom i **broji** šta je prošlo. Provjera u
/// Dartu bi bila druga istina o istom pravilu, i razišla bi se prvi put kad neko rezerviše
/// u međuvremenu.
class _PotvrdiSveDugme extends ConsumerStatefulWidget {
  const _PotvrdiSveDugme();

  @override
  ConsumerState<_PotvrdiSveDugme> createState() => _PotvrdiSveDugmeState();
}

class _PotvrdiSveDugmeState extends ConsumerState<_PotvrdiSveDugme> {
  bool _uToku = false;

  @override
  Widget build(BuildContext context) {
    final zahtjevi = ref.watch(zahtjeviProvider).valueOrNull ?? const [];

    // `3d`: dugme u top baru je 40 px visoko, tekst 16 px od ruba. Visina je 44 po
    // FE-502 — donja granica dodirne mete jača je od izmjerenog piksela.
    return SizedBox(
      height: AdminSize.touchTarget,
      child: OutlinedButton(
        onPressed: _uToku || zahtjevi.isEmpty
            ? null
            : () => _potvrdiSve(zahtjevi),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AdminSize.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.lg),
        ),
        child: Text(_uToku ? 'Potvrđujem…' : 'Potvrdi sve bez preklapanja'),
      ),
    );
  }

  Future<void> _potvrdiSve(List<Appointment> zahtjevi) async {
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrditi sve zahtjeve?'),
        content: Text(
          'Pokušat ću potvrditi ${zahtjevi.length} ${_zahtjevaTekst(zahtjevi.length)}. '
          'Onaj koji se preklapa sa već potvrđenim terminom ostaje na čekanju.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(textStyle: AdminText.actionLabel),
            child: const AdminVerzal('Potvrdi sve'),
          ),
        ],
      ),
    );
    if (potvrda != true || !mounted) return;

    setState(() => _uToku = true);
    var prosli = 0;
    var pali = 0;

    for (final zahtjev in zahtjevi) {
      try {
        await ref.read(appointmentActionsProvider).potvrdi(zahtjev.id);
        prosli++;
      } on ApiError catch (_) {
        pali++;
      }
    }

    if (!mounted) return;
    setState(() => _uToku = false);
    _poruka(
      context,
      pali == 0
          ? 'Potvrđeno $prosli ${_zahtjevaTekst(prosli)}.'
          : 'Potvrđeno $prosli, preskočeno $pali zbog preklapanja.',
    );
  }
}

class _PrazanDan extends ConsumerWidget {
  const _PrazanDan({required this.filter, required this.zahtjevi});

  final AppointmentsFilter filter;
  final bool zahtjevi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Prazno zbog statusa nije prazan dan; izlaz radi isto što i chip „Svi" (FE-501).
    final filtrirano = !zahtjevi && filter.status != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              zahtjevi ? Icons.mark_email_read_outlined : Icons.event_available,
              size: 48,
              color: context.adminColors.textMuted,
            ),
            const SizedBox(height: AdminSpacing.lg),
            Text(
              zahtjevi
                  ? 'Nijedan zahtjev ne čeka odgovor.'
                  : filter.status == null
                  ? 'Nema termina za ovaj dan.'
                  : 'Nema termina sa statusom „${statusLabela(filter.status!)}".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.adminColors.textSecondary,
              ),
            ),
            if (filtrirano) ...[
              const SizedBox(height: AdminSpacing.md),
              TextButton(
                onPressed: () => ref
                    .read(appointmentsFilterProvider.notifier)
                    .postaviStatusTacno(null),
                child: const Text('Prikaži sve statuse'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Greska extends StatelessWidget {
  const _Greska({required this.poruka, required this.onPonovi});

  final String poruka;
  final VoidCallback onPonovi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              size: 48,
              color: context.adminColors.textMuted,
            ),
            const SizedBox(height: AdminSpacing.lg),
            Text(poruka, textAlign: TextAlign.center),
            const SizedBox(height: AdminSpacing.lg),
            FilledButton(
              onPressed: onPonovi,
              child: const Text('Pokušaj opet'),
            ),
          ],
        ),
      ),
    );
  }
}

void _poruka(BuildContext context, String tekst) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tekst)));

String _cekajuTekst(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return 'zahtjeva čeka';
  if (zadnja == 1) return 'zahtjev čeka';
  if (zadnja >= 2 && zadnja <= 4) return 'zahtjeva čekaju';
  return 'zahtjeva čeka';
}

String _zahtjevaTekst(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return 'zahtjeva';
  if (zadnja == 1) return 'zahtjev';
  return zadnja >= 2 && zadnja <= 4 ? 'zahtjeva' : 'zahtjeva';
}
