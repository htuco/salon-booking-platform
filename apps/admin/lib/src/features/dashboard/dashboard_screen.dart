/// „Danas" — prikazi `6a`–`6m` iz `prototype/adminv2/danas/` (task 55).
///
/// Zamjenjuje `3b`/`3k`. Redoslijed je fiksan: **šta čeka odgovor → šta slijedi → brojke.**
///
/// ## Isti ekran, tri rasporeda
///
/// - **≥ 840 px** — desktop ljuska: glavna kolona (zahtjevi, „je li došao?", raspored) i
///   bočna od 330 (Sljedeći, brojke, zauzetost).
/// - **≥ 1920 px prozora** — treća kolona: stalni kontekstni panel od 560 (`6b`). Ispod
///   toga se isti panel otvara kao drawer klikom na red.
/// - **< 840 px** — telefon: zahtjevi (jedan, pa „Još N"), Sljedeći, traka od tri brojke,
///   raspored.
///
/// ## Šta je namjerno drugačije od handoffa
///
/// - Zahtjevi su poredani po vremenu termina, ne po čekanju (`danas.dart`).
/// - Tekst nema padež imena ni rod radnika: „· Emir", ne „kod Emira".
/// - Radnik nema „Novi termin" ni „Blokiraj vrijeme" — ručni unos i blokade traže
///   `is_admin` u bazi (task 47), a dugme koje uvijek padne je gore od dugmeta kojeg nema.
/// - Novi zahtjev uživo ne klizi u listu: realtime (`main.dart`) osvježi liste, a red se
///   pojavi na svom mjestu bez animacije.
library;

import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/datum.dart';
import '../../core/format/tekst.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_refresh.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_verzal.dart';
import '../appointments/appointments_providers.dart';
import 'danas.dart';
import 'danas_blokovi.dart';
import 'danas_providers.dart';
import 'danas_raspored.dart';
import 'dashboard_summary.dart';
import 'kontekst_panel.dart';

export 'danas_providers.dart'
    show dashboardBlokadeProvider, dashboardRasporedProvider;

/// Širina bočne kolone iz `6a`.
const double kSirinaBocneKolone = 330;

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jeDesktop = AdminShell.jeDesktop(context);
    final radnik = ref.watch(adminRadnikIdProvider) != null;

    return AdminScaffold(
      title: 'Danas',
      actions: jeDesktop && !radnik ? const [_BrzeAkcije()] : null,
      body: AdminRefresh(
        onRefresh: () async {
          ref
            ..invalidate(danasnjiTerminiProvider)
            ..invalidate(pendingCountProvider)
            ..invalidate(zahtjeviProvider)
            ..invalidate(dashboardRasporedProvider)
            ..invalidate(dashboardBlokadeProvider)
            ..invalidate(sedmicaProvider)
            ..invalidate(sljedeciRadniDanProvider);
        },
        child: jeDesktop ? const _Desktop() : const _Telefon(),
      ),
    );
  }
}

/// Brze akcije top bara — `6a`. Samo vlasnik.
class _BrzeAkcije extends StatelessWidget {
  const _BrzeAkcije();

  @override
  Widget build(BuildContext context) {
    // `6a`: 40 px, padding 16 (18 za glavnu), 14,5 px u rečenici, 13,5 px u verzalu.
    final sporedno = kompaktnoDugme(
      visina: 40,
      padding: 16,
      tekst: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14.5),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: () => context.go(AdminRoute.calendarBlock.path),
          style: sporedno,
          child: const Text('Blokiraj vrijeme'),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: () => context.go(AdminRoute.services.path),
          style: sporedno,
          child: const Text('Dodaj uslugu'),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: () => context.push(AdminRoute.appointmentNew.path),
          style: kompaktnoDugme(
            visina: 40,
            padding: 18,
            tekst: AdminText.actionLabel.copyWith(fontSize: 13.5),
          ),
          child: const AdminVerzal('+ Novi termin'),
        ),
      ],
    );
  }
}

/// Da li salon danas radi; `true` dok raspored ne stigne, da ekran ne bljesne
/// „Danas ne radimo" na svakom ulasku.
bool _radiDanas(WidgetRef ref, DateTime sada) {
  final raspored = ref.watch(dashboardRasporedProvider).valueOrNull;
  return raspored == null || raspored.isEmpty || salonRadi(raspored, sada);
}

// ---------------------------------------------------------------------------
// Desktop
// ---------------------------------------------------------------------------

class _Desktop extends ConsumerWidget {
  const _Desktop();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sada = sadaEkrana(ref);
    final radi = _radiDanas(ref, sada);
    final radnik = ref.watch(adminRadnikIdProvider) != null;

    final glavna = <Widget>[
      if (!radi) ...[
        NeradniDanKartica(sada: sada),
        const SizedBox(height: AdminSpacing.xl),
      ],
      const ZahtjeviBlok(),
      if (radi) ...[
        const BezOznakeBlok(),
        const SizedBox(height: AdminSpacing.xxl),
        const RasporedBlok(),
      ] else ...[
        const SizedBox(height: AdminSpacing.xl),
        const SljedeciRadniDanKartica(),
      ],
    ];
    final bocna = <Widget>[
      if (radi) ...[
        const SljedeciKartica(),
        const SizedBox(height: AdminSpacing.lg),
        const BrojkeKartica(),
        if (!radnik) ...[
          const SizedBox(height: AdminSpacing.lg),
          const ZauzetostKartica(),
        ],
      ],
    ];

    final sadrzaj = LayoutBuilder(
      builder: (context, constraints) {
        final uskoro = AdminShell.bandZa(constraints.maxWidth).jeCompact;
        return ListView(
          padding: const EdgeInsets.all(AdminSpacing.gutterDesktop),
          children: [
            const _NaslovDana(),
            const SizedBox(height: AdminSpacing.xl),
            if (uskoro || bocna.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...glavna,
                  if (bocna.isNotEmpty) ...[
                    const SizedBox(height: AdminSpacing.xxl),
                    ...bocna,
                  ],
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: glavna,
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.xxl),
                  SizedBox(
                    width: kSirinaBocneKolone,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: bocna,
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );

    if (!imaStalniPanel(context)) return sadrzaj;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: sadrzaj),
        const SizedBox(width: kSirinaPanela, child: KontekstPanel()),
      ],
    );
  }
}

/// „Ponedjeljak, 18. maj" i red ispod — `6a`/`6d`.
class _NaslovDana extends ConsumerWidget {
  const _NaslovDana();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sada = sadaEkrana(ref);
    final smjene = ref.watch(dashboardSmjeneProvider);
    final radnik = ref.watch(adminRadnikIdProvider) != null;
    final termini = ref.watch(danasPrikazProvider).valueOrNull;
    final raspored = ref.watch(dashboardRasporedProvider).valueOrNull;
    final brojTermina = termini == null
        ? null
        : BrojkeDana.izracunaj(termini, const {}).termina;

    // Bez padeža: „U smjeni 3", ne „3 majstora u smjeni" — rječnik vertikale nema genitiv
    // množine, a „3 kozmetičara" bi bio pogrešan rod za salon sa kozmetičarkama.
    final smjena = smjene.firstOrNull;
    final dijelovi = [
      if (radnik && smjena != null)
        'Smjena ${hhmm(smjena.od)}–${hhmm(smjena.doMinute)}'
      else if (!radnik && smjene.isNotEmpty)
        'U smjeni ${smjene.length}',
      if (brojTermina != null) terminaTekst(brojTermina),
    ];

    final otvoreno = raspored == null
        ? null
        : otvorenoDo(raspored, sada.weekday, minutaDana(sada));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(datumDugo(sada), style: AdminText.display),
              if (dijelovi.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(dijelovi.join(' · '), style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
        if (otvoreno != null)
          _OtvorenoDo(stanje: otvoreno.stanje, tekst: otvoreno.tekst),
      ],
    );
  }
}

class _OtvorenoDo extends StatelessWidget {
  const _OtvorenoDo({required this.stanje, required this.tekst});

  final StanjeSalona stanje;
  final String tekst;

  @override
  Widget build(BuildContext context) {
    // Zelena tačka samo kad je stvarno otvoreno — ista boja uz „Zatvoreno" bi se čitala
    // kao „radi".
    final boja = stanje == StanjeSalona.otvoreno
        ? context.adminColors.positiveInk
        : context.adminColors.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: boja, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          tekst,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: boja, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Telefon
// ---------------------------------------------------------------------------

class _Telefon extends ConsumerWidget {
  const _Telefon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sada = sadaEkrana(ref);
    final radi = _radiDanas(ref, sada);

    return Column(
      children: [
        const _MobilnoZaglavlje(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.gutterMobile,
              AdminSpacing.lg,
              AdminSpacing.gutterMobile,
              AdminSpacing.xxl,
            ),
            children: [
              if (!radi) ...[
                NeradniDanKartica(sada: sada),
                const SizedBox(height: AdminSpacing.xl),
              ],
              if (radi) ...[
                const SljedeciKartica(telefon: true),
                const SizedBox(height: AdminSpacing.lg),
              ],
              const ZahtjeviBlok(telefon: true),
              if (radi) ...[
                const BezOznakeBlok(telefon: true),
                const SizedBox(height: AdminSpacing.lg),
                const RasporedBlok(telefon: true),
                const SizedBox(height: AdminSpacing.xl),
                const BrojkeTraka(),
              ] else ...[
                const SizedBox(height: AdminSpacing.lg),
                const SljedeciRadniDanKartica(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Datum i radni status u jednom redu (`mobile-refresh`): „Uto, 6. okt · ● Zatvoreno".
///
/// Bez naslova ekrana — aktivni tab „Danas" u donjoj traci već kaže gdje smo.
class _MobilnoZaglavlje extends ConsumerWidget {
  const _MobilnoZaglavlje();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sada = sadaEkrana(ref);
    final raspored = ref.watch(dashboardRasporedProvider).valueOrNull;
    final stanje = raspored == null
        ? null
        : otvorenoDo(raspored, sada.weekday, minutaDana(sada));
    final boje = context.adminColors;
    final tekst = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.gutterMobile,
        vertical: AdminSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: boje.separator, width: AdminSize.hairline),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${kDaniSedmice[sada.weekday - 1].substring(0, 3)}, '
            '${sada.day}. ${kMjeseci[sada.month - 1].substring(0, 3)}',
            style: tekst.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: AdminSpacing.md),
          // Status uz desnu ivicu; dug status („Otvoreno do 20:00 · …") se skrati, ne preliva.
          if (stanje != null)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: boje.positiveInk,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      stanje.tekst,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tekst.bodySmall?.copyWith(color: boje.positiveInk),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
