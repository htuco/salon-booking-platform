import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/datum.dart';
import '../../core/format/tekst.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/admin_verzal.dart';
import '../appointments/status_pill.dart';
import 'clients_providers.dart';

/// Ime klijenta kako ga ekran smije prikazati.
///
/// **Brisanje naloga (task 17) anonimizira red**: `customers.name` je `not null`, pa
/// obrisan klijent dobije tekst „Obrisan klijent" umjesto imena. Uz to red iz starijeg
/// importa može nositi prazan string. Oboje ovdje izgleda isto — prazno mjesto na kojem
/// treba stajati ime je gore od riječi koja kaže da imena nema.
String imeKlijenta(Customer klijent) {
  final ime = klijent.name.trim();
  return ime.isEmpty ? 'Bez imena' : ime;
}

/// Inicijal za avatar.
///
/// Canvas `3e` crta fotografije, ali `customers` nema sliku — kao i kod kolone radnika u
/// kalendaru (task 31), stoji inicijal umjesto slomljene slike.
String inicijal(Customer klijent) {
  final ime = imeKlijenta(klijent);
  return ime.characters.first.toUpperCase();
}

/// Telefon, ili ono što stoji umjesto njega.
///
/// **Klijent bez broja nije greška.** Prijavljen korisnik ga nikad nije morao ostaviti, a
/// anonimizacija ga briše. Prazno mjesto bi izgledalo kao da se podatak nije učitao.
String telefonKlijenta(Customer klijent) =>
    klijent.hasPhone ? klijent.phone!.trim() : 'Bez broja';

/// Pretraga stoji u top baru tek kad stane uz breadcrumb i „+ Novi klijent" (288 + 136
/// px iz `3e`); ispod toga prelazi u tijelo ekrana, umjesto da top bar prelije.
bool _pretragaUTopBaru(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 1000;

/// Kontrola iz `3e`/`3o` iza koje još nema radnje. Vidljiva je jer je dio ekrana, ali ne
/// glumi da je nešto uradila.
void _uskoro(BuildContext context, String sta) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$sta — uskoro.')));
}

class AdminClientsScreen extends ConsumerWidget {
  const AdminClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = AdminShell.jeDesktop(context);
    return AdminScaffold(
      title: 'Klijenti',
      aktivna: AdminRoute.clients,
      // `3o` crta veliki naslov u tijelu, ne `AppBar`.
      sopstvenoZaglavlje: true,
      actions: desktop ? const [_TopBarAkcije()] : null,
      body: desktop ? const _Desktop() : const _Telefon(),
    );
  }
}

/// Akcije top bara iz `3e`: pretraga 288 × 42 i koralno „+ NOVI KLIJENT".
class _TopBarAkcije extends StatelessWidget {
  const _TopBarAkcije();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_pretragaUTopBaru(context)) ...[
          const SizedBox(width: 288, child: _Pretraga()),
          const SizedBox(width: AdminSpacing.md),
        ],
        SizedBox(
          height: AdminSize.touchTarget,
          child: FilledButton(
            onPressed: () => _uskoro(context, 'Novi klijent'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AdminSize.touchTarget),
              padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.lg),
              textStyle: AdminText.actionLabel,
            ),
            child: const AdminVerzal('+ Novi klijent'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pomoćne funkcije za tekst
// ---------------------------------------------------------------------------

/// Množina na bosanskom: 1 dolazak, 2 dolaska, 5 dolazaka — 11–14 idu u treći oblik.
String _mnozina(int n, String jedan, String dva, String pet) {
  final z = n % 10;
  final zz = n % 100;
  if (z == 1 && zz != 11) return jedan;
  if (z >= 2 && z <= 4 && (zz < 12 || zz > 14)) return dva;
  return pet;
}

String _dolazaka(int n) => _mnozina(n, 'dolazak', 'dolaska', 'dolazaka');

String _nedolazaka(int n) =>
    _mnozina(n, 'nedolazak', 'nedolaska', 'nedolazaka');

String _dvije(int n) => n.toString().padLeft(2, '0');

/// `02.05.2026.` — brojčani datum, kako ga `3e` piše u koloni „Zadnji dolazak".
String _datumBrojevima(DateTime d) =>
    '${_dvije(d.day)}.${_dvije(d.month)}.${d.year}.';

/// `02.05.` — datum u istoriji profila, bez godine (`3e`).
String _danIMjesec(LocalDate d) => '${_dvije(d.day)}.${_dvije(d.month)}.';

/// Zadnji dolazak, ili `—`.
///
/// `null` znači „nijedan termin nije održan". `3e` tu crta crticu, a oznaka „Novi" u
/// istom redu kaže zašto datuma nema — crtica se zato ne čita kao greška u učitavanju.
String _zadnjiDolazak(Customer klijent) {
  final zadnji = klijent.lastVisitAt;
  return zadnji == null ? '—' : _datumBrojevima(zadnji.toLocal());
}

/// `danas`, `sutra`, inače `četvrtak, 02.10.`.
///
/// Razlika dana se računa nad UTC ponoćima: lokalne ponoći oko prelaska na ljetno
/// vrijeme su 23 sata razmaka, pa bi `inDays` sutrašnji dan proglasio današnjim.
String _danTermina(LocalDate d, DateTime sada) {
  final razlika = DateTime.utc(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime.utc(sada.year, sada.month, sada.day)).inDays;
  if (razlika == 0) return 'danas';
  if (razlika == 1) return 'sutra';
  final dan = DateTime(d.year, d.month, d.day);
  return '${kDaniSedmice[dan.weekday - 1].toLowerCase()}, ${_danIMjesec(d)}';
}

// ---------------------------------------------------------------------------
// Desktop `3e` — tabela lijevo, profil desno
// ---------------------------------------------------------------------------

class _Desktop extends ConsumerWidget {
  const _Desktop();

  /// Širina profila po pojasu. `3e` na 1440 crta 380; na širim ekranima profil dobija
  /// malo više, a ostatak ide tabeli.
  static double _sirinaProfila(AdminWidthBand pojas) => switch (pojas) {
    AdminWidthBand.compact || AdminWidthBand.regular => 380,
    AdminWidthBand.wide => 400,
    AdminWidthBand.ultraWide => 440,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izabrani = ref.watch(izabraniKlijentProvider);
    // `3e` uvijek crta otvoren profil. Dok korisnik ne izabere nikoga, prikazuje se prvi
    // red liste — bez upisa u provider, pa izbor ostaje korisnikov.
    final prvi = ref.watch(adminKlijentiProvider).valueOrNull?.firstOrNull?.id;

    return LayoutBuilder(
      builder: (context, constraints) {
        final pojas = AdminShell.bandZa(constraints.maxWidth);

        // Ispod 900 px radne površine tabela i profil ne stanu jedno uz drugo: profil
        // tada zamjenjuje tabelu, kao na telefonu.
        if (pojas.jeCompact) {
          if (izabrani != null) {
            return ColoredBox(
              color: context.adminColors.surface,
              child: _Profil(customerId: izabrani, saZatvaranjem: true),
            );
          }
          return const _DesktopLista(prikazan: null);
        }

        final prikazan = izabrani ?? prvi;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _DesktopLista(prikazan: prikazan)),
            if (prikazan != null)
              SizedBox(
                width: _sirinaProfila(pojas) + AdminSize.hairline,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.adminColors.surface,
                    border: Border(
                      left: BorderSide(
                        color: context.adminColors.separator,
                        width: AdminSize.hairline,
                      ),
                    ),
                  ),
                  child: _Profil(customerId: prikazan),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Koje kolone tabele stanu u datu širinu, i koliko su široke.
///
/// Mjere su iz `3e` na 1440 (tabela 771 px): zadnji dolazak 150, dolazaka 110, status
/// 130. Kolona „Potrošeno" je sklonjena po zahtjevu vlasnika proizvoda.
///
/// - **Šira tabela razvlači kolone srazmjerno** (do 2×), inače bi na 2560 ime i datum
///   stajali 1500 px jedno od drugog.
/// - **Uža tabela skida kolone**, a ne sužava ih: prvo „Dolazaka" (prelazi u red ispod
///   imena), pa „Zadnji dolazak". Ime i status ostaju uvijek.
class _Kolone {
  const _Kolone({
    required this.datum,
    required this.dolasci,
    required this.faktor,
  });

  factory _Kolone.za(double sirina) => _Kolone(
    datum: sirina >= 500,
    dolasci: sirina >= 640,
    faktor: (sirina / _referentna).clamp(1.0, 2.0),
  );

  static const double _referentna = 771;

  final bool datum;
  final bool dolasci;
  final double faktor;

  double get sirinaDatuma => 150 * faktor;
  double get sirinaDolazaka => 110 * faktor;
  double get sirinaStatusa => 130 * faktor;
}

class _DesktopLista extends ConsumerWidget {
  const _DesktopLista({required this.prikazan});

  /// Klijent čiji je profil otvoren — njegov red je istaknut.
  final String? prikazan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klijenti = ref.watch(adminKlijentiProvider);
    final boje = context.adminColors;
    const gutter = AdminSpacing.gutterDesktop;
    final pretragaUTijelu = !_pretragaUTopBaru(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final kolone = _Kolone.za(constraints.maxWidth - 2 * gutter);

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                gutter,
                AdminSpacing.gutterDesktop,
                gutter,
                AdminSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Zaglavlje(),
                    if (pretragaUTijelu) ...[
                      const SizedBox(height: AdminSpacing.lg),
                      const _Pretraga(),
                    ],
                  ],
                ),
              ),
            ),
            ...klijenti.when(
              loading: () => const [
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  sliver: SliverToBoxAdapter(child: AdminSkeletonList()),
                ),
              ],
              error: (_, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Greska(
                    poruka: 'Klijenti se ne mogu učitati.',
                    ponovo: () => ref.invalidate(adminKlijentiProvider),
                  ),
                ),
              ],
              data: (redovi) => redovi.isEmpty
                  ? const [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Prazno(),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          gutter,
                          0,
                          gutter,
                          AdminSpacing.gutterDesktop,
                        ),
                        // Kartica je visoka koliko ima redova (`3e`), a ne do dna
                        // ekrana; lista ostaje lijena i sa 200 klijenata.
                        sliver: DecoratedSliver(
                          decoration: BoxDecoration(
                            color: boje.surface,
                            borderRadius: BorderRadius.circular(
                              AdminRadius.small,
                            ),
                            border: Border.all(
                              color: boje.cardEdge,
                              width: AdminSize.hairline,
                            ),
                          ),
                          sliver: SliverMainAxisGroup(
                            slivers: [
                              SliverToBoxAdapter(
                                child: _ZaglavljeTabele(kolone: kolone),
                              ),
                              SliverList.builder(
                                itemCount: redovi.length,
                                itemBuilder: (context, i) => _Red(
                                  klijent: redovi[i],
                                  izabran: redovi[i].id == prikazan,
                                  zadnji: i == redovi.length - 1,
                                  kolone: kolone,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
            ),
          ],
        );
      },
    );
  }
}

/// `342 ukupno · 68 redovnih`, ili „prikazano" kad lista nije cijeli adresar.
///
/// „Ukupno" smije stajati samo kad je to istina: bez filtera, bez pretrage i ispod
/// granice upita (200 redova). Inače brojka opisuje ono što je na ekranu.
String? _podnaslov(WidgetRef ref) {
  final redovi = ref.watch(adminKlijentiProvider).valueOrNull;
  if (redovi == null) return null;

  final cijeliAdresar =
      ref.watch(clientsFilterProvider) == ClientsFilter.svi &&
      ref.watch(clientsPretragaProvider).trim().isEmpty &&
      redovi.length < 200;
  final redovnih = redovi
      .where((k) => k.visitCount >= ClientsFilter.pragRedovnog)
      .length;
  final rijec = cijeliAdresar ? 'ukupno' : 'prikazano';
  return '${redovi.length} $rijec · $redovnih redovnih';
}

class _Zaglavlje extends ConsumerWidget {
  const _Zaglavlje();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podnaslov = _podnaslov(ref);

    final naslov = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Klijenti', style: AdminText.display),
        const SizedBox(height: AdminSpacing.xs),
        Text(
          podnaslov ?? 'Učitavanje…',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );

    // Naslov i četiri filtera stoje u jednom redu dok ima mjesta (`3e`); na uskoj tabeli
    // filteri prelaze ispod naslova umjesto da ga guraju.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              naslov,
              const SizedBox(height: AdminSpacing.lg),
              const _FilteriDesktop(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: naslov),
            const SizedBox(width: AdminSpacing.lg),
            const _FilteriDesktop(),
          ],
        );
      },
    );
  }
}

class _Pretraga extends ConsumerStatefulWidget {
  const _Pretraga({this.telefon = false});

  /// `3o` crta polje sa lupom, visoko 48; `3e` bez ikone, visoko 42.
  final bool telefon;

  @override
  ConsumerState<_Pretraga> createState() => _PretragaState();
}

class _PretragaState extends ConsumerState<_Pretraga> {
  late final TextEditingController _kontroler;

  @override
  void initState() {
    super.initState();
    // Polje se gradi iz stanja, a ne obrnuto: prelazak sa telefona na desktop podiže
    // drugi widget, i unos bi se izgubio da se čita samo iz kontrolera.
    _kontroler = TextEditingController(text: ref.read(clientsPretragaProvider));
  }

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telefon = widget.telefon;
    // Pretragu može poništiti i prazno stanje („Poništi pretragu", FE-501). Bez ovoga
    // bi lista bila puna, a polje bi i dalje pokazivalo stari izraz.
    ref.listen(clientsPretragaProvider, (_, izraz) {
      if (_kontroler.text == izraz) return;
      _kontroler.text = izraz;
      setState(() {});
    });
    return TextField(
      controller: _kontroler,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: 'Ime ili broj telefona',
        isDense: true,
        // FE-502: gusto polje ne smije pasti ispod dodirne mete.
        constraints: const BoxConstraints(minHeight: AdminSize.touchTarget),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AdminSpacing.md,
          vertical: telefon ? 13 : 10,
        ),
        prefixIcon: telefon ? const Icon(Icons.search, size: 20) : null,
        // Bez ovoga `IconButton` za brisanje digne polje na 48 px čim se nešto upiše.
        suffixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        suffixIcon: _kontroler.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Očisti pretragu',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _kontroler.clear();
                  ref.read(clientsPretragaProvider.notifier).postavi('');
                  setState(() {});
                },
              ),
      ),
      onChanged: (izraz) {
        ref.read(clientsPretragaProvider.notifier).postavi(izraz);
        setState(() {});
      },
    );
  }
}

/// Četiri dugmeta filtera iz `3e`: izabrano je koralno i u verzalu („SVI"), ostala su
/// obrubljena i u rečenici.
class _FilteriDesktop extends ConsumerWidget {
  const _FilteriDesktop();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izabran = ref.watch(clientsFilterProvider);
    final labela = Theme.of(context).textTheme.labelMedium;
    // `3e` crta 38; FE-502 traži dodirnu metu.
    const visina = AdminSize.touchTarget;
    const padding = EdgeInsets.symmetric(horizontal: AdminSpacing.lg);

    // `Wrap`: na uskoj tabeli dugmad prelaze u drugi red umjesto da prelijevaju (task 34).
    return Wrap(
      spacing: AdminSpacing.sm,
      runSpacing: AdminSpacing.sm,
      children: [
        for (final filter in ClientsFilter.values)
          Semantics(
            selected: filter == izabran,
            child: SizedBox(
              height: visina,
              child: filter == izabran
                  ? FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, visina),
                        padding: padding,
                        textStyle: AdminText.actionLabel,
                      ),
                      child: AdminVerzal(filter.label),
                    )
                  : OutlinedButton(
                      onPressed: () => ref
                          .read(clientsFilterProvider.notifier)
                          .postavi(filter),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, visina),
                        padding: padding,
                        textStyle: labela,
                      ),
                      child: Text(filter.label),
                    ),
            ),
          ),
      ],
    );
  }
}

class _ZaglavljeTabele extends StatelessWidget {
  const _ZaglavljeTabele({required this.kolone});

  final _Kolone kolone;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.xl,
        vertical: AdminSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: boje.separator, width: AdminSize.hairline),
        ),
      ),
      child: Row(
        children: [
          const Expanded(child: _CelijaZaglavlja('Klijent')),
          if (kolone.datum)
            SizedBox(
              width: kolone.sirinaDatuma,
              child: const _CelijaZaglavlja('Zadnji dolazak'),
            ),
          if (kolone.dolasci)
            SizedBox(
              width: kolone.sirinaDolazaka,
              child: const _CelijaZaglavlja('Dolazaka'),
            ),
          SizedBox(
            width: kolone.sirinaStatusa,
            child: const _CelijaZaglavlja('Status'),
          ),
        ],
      ),
    );
  }
}

class _CelijaZaglavlja extends StatelessWidget {
  const _CelijaZaglavlja(this.tekst);

  final String tekst;

  @override
  Widget build(BuildContext context) => Text(
    tekst.toUpperCase(),
    semanticsLabel: tekst,
    style: AdminText.eyebrow.copyWith(color: context.adminColors.textSecondary),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

/// Red tabele iz `3e`: 70 px, avatar 38, ime 16/600, telefon 14, datum 16, broj 15/500.
class _Red extends ConsumerWidget {
  const _Red({
    required this.klijent,
    required this.izabran,
    required this.zadnji,
    required this.kolone,
  });

  final Customer klijent;
  final bool izabran;
  final bool zadnji;
  final _Kolone kolone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;
    final sporedno = barlowTabular(
      size: 14,
      height: 1.2,
      color: boje.textSecondary,
    );

    // Kolona koja ne stane ne nestaje: njen podatak prelazi u red ispod imena.
    final ispodImena = [
      telefonKlijenta(klijent),
      if (!kolone.dolasci)
        '${klijent.visitCount} ${_dolazaka(klijent.visitCount)}',
      if (!kolone.datum) 'zadnji ${_zadnjiDolazak(klijent)}',
    ].join(' · ');

    return Material(
      color: izabran ? boje.accentTint : Colors.transparent,
      child: InkWell(
        onTap: () =>
            ref.read(izabraniKlijentProvider.notifier).izaberi(klijent.id),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.xl,
            vertical: AdminSpacing.lg,
          ),
          decoration: BoxDecoration(
            border: zadnji
                ? null
                : Border(
                    bottom: BorderSide(
                      color: boje.separator,
                      width: AdminSize.hairline,
                    ),
                  ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _Avatar(klijent: klijent, promjer: 38),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            imeKlijenta(klijent),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(height: 1.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            ispodImena,
                            style: sporedno,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                  ],
                ),
              ),
              if (kolone.datum)
                SizedBox(
                  width: kolone.sirinaDatuma,
                  child: Text(
                    _zadnjiDolazak(klijent),
                    style: barlowTabular(size: 16, color: boje.textSecondary),
                  ),
                ),
              if (kolone.dolasci)
                SizedBox(
                  width: kolone.sirinaDolazaka,
                  child: Text(
                    '${klijent.visitCount}',
                    style: AdminText.timeLarge,
                  ),
                ),
              SizedBox(
                width: kolone.sirinaStatusa,
                child: _Oznaka(klijent: klijent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar klijenta: ista siva kugla kao placeholder u ljusci (`AdminScaffold`), sa
/// inicijalom — `customers` nema sliku.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.klijent, required this.promjer});

  final Customer klijent;
  final double promjer;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Container(
      width: promjer,
      height: promjer,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [boje.sidebarMuted, boje.sidebarSelected],
        ),
      ),
      child: Text(
        inicijal(klijent),
        style: barlow(
          size: promjer * 0.4,
          weight: 600,
          height: 1,
          color: boje.sidebarAccentForeground,
        ),
      ),
    );
  }
}

/// Oznaka klijenta — jedna po redu, po prioritetu.
///
/// VIP je iznad ostalog jer ga salon dodjeljuje ručno: odluka čovjeka ide ispred
/// brojača. Nedolasci su iznad „Redovan" — `3e` Kenana sa 9 dolazaka označava sa
/// „3 nedolaska", jer je to ono što vlasnik treba vidjeti.
///
/// Nedolasci se crtaju drugačije po širini, kako ih crtaju izvozi: `3e` crven tekst na
/// blijedoj podlozi, `3o` koralna pilula.
class _Oznaka extends StatelessWidget {
  const _Oznaka({required this.klijent, this.telefon = false});

  final Customer klijent;
  final bool telefon;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final nedolasci = klijent.noShowCount;

    final (tekst, pozadina, tekstBoja) = switch (klijent) {
      final k when k.isVip => ('VIP', boje.accentTint, boje.accent),
      _ when nedolasci >= ClientsFilter.pragNedolaska => (
        '$nedolasci ${_nedolazaka(nedolasci)}',
        telefon ? boje.waitingTint : boje.destructive.withValues(alpha: 0.12),
        telefon ? boje.waitingInk : boje.destructive,
      ),
      final k when k.visitCount >= ClientsFilter.pragRedovnog => (
        'Redovan',
        boje.neutralTint,
        boje.textSecondary,
      ),
      final k when k.visitCount == 0 => ('Novi', boje.accentTint, boje.accent),
      _ => ('Aktivan', boje.neutralTint, boje.textSecondary),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: pozadina,
          borderRadius: BorderRadius.circular(AdminRadius.pill),
        ),
        child: Text(
          tekst,
          style: AdminText.statusLabel.copyWith(color: tekstBoja),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profil
// ---------------------------------------------------------------------------

class _Profil extends ConsumerWidget {
  const _Profil({required this.customerId, this.saZatvaranjem = false});

  final String customerId;

  /// Telefon i uzak desktop profil otvaraju preko liste, pa mu treba izlaz.
  final bool saZatvaranjem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klijent = ref.watch(klijentProvider(customerId));

    return klijent.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AdminSpacing.xxl),
        child: AdminSkeletonList(),
      ),
      error: (_, _) => _Greska(
        poruka: 'Profil se ne može učitati.',
        ponovo: () => ref.invalidate(klijentProvider(customerId)),
      ),
      // `null` je predviđeno stanje: red je obrisan, ili je od tuđeg salona i RLS ga nije
      // propustio. Ekran oba prikazuje isto — poruka „nemate pravo" bi potvrdila da taj
      // klijent postoji, a to je kod baš ove tabele podatak o konkurenciji.
      data: (red) => red == null
          ? const _Greska(poruka: 'Ovaj klijent više ne postoji.')
          : _ProfilSadrzaj(klijent: red, saZatvaranjem: saZatvaranjem),
    );
  }
}

/// Profil iz `3e`: zaglavlje sa dvije metrike, pa ispod linije sljedeći termin,
/// istorija, bilješka i akcije. Isti sadržaj nosi i telefon.
class _ProfilSadrzaj extends ConsumerWidget {
  const _ProfilSadrzaj({required this.klijent, required this.saZatvaranjem});

  final Customer klijent;
  final bool saZatvaranjem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final istorija = ref.watch(klijentIstorijaProvider(klijent.id));
    final boje = context.adminColors;
    final tekst = Theme.of(context).textTheme;
    final termini = istorija.valueOrNull;
    final sljedeci = termini == null
        ? null
        : sljedeciTermin(termini, DateTime.now());
    final brojevi = termini == null ? null : brojDolazaka(termini, klijent);
    final naslovSekcije = tekst.headlineSmall;
    final biljeska = klijent.note?.trim() ?? '';

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.xxl,
            AdminSpacing.gutterDesktop,
            AdminSpacing.xxl,
            AdminSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Avatar(klijent: klijent, promjer: 64),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          imeKlijenta(klijent),
                          style: tekst.headlineLarge?.copyWith(fontSize: 26),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          telefonKlijenta(klijent),
                          style: barlowTabular(
                            size: 16,
                            color: boje.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (saZatvaranjem)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Zatvori profil',
                      onPressed: () => ref
                          .read(izabraniKlijentProvider.notifier)
                          .izaberi(null),
                    ),
                ],
              ),
              // Telefonski klijent nema nalog, i to je ispravno stanje, ne greška —
              // salon ga je unio po pozivu. Rečenica stoji da se prazan
              // `auth_identity_id` ne bi čitao kao neispravan red.
              if (klijent.isWalkin) ...[
                const SizedBox(height: AdminSpacing.md),
                Text(
                  'Unesen u salonu — nema nalog u aplikaciji.',
                  style: tekst.bodySmall?.copyWith(color: boje.textSecondary),
                ),
              ],
              const SizedBox(height: AdminSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: _Metrika(
                      broj: brojevi == null ? '—' : '${brojevi.dolasci}',
                      labela: _dolazaka(brojevi?.dolasci ?? 0),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: _Metrika(
                      broj: brojevi == null ? '—' : '${brojevi.nedolasci}',
                      labela: _nedolazaka(brojevi?.nedolasci ?? 0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(height: AdminSize.hairline, color: boje.separator),
        Padding(
          padding: const EdgeInsets.all(AdminSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sljedeći termin', style: naslovSekcije),
              const SizedBox(height: AdminSpacing.md),
              _SljedeciTermin(istorija: istorija, termin: sljedeci),
              const SizedBox(height: AdminSpacing.xxl),
              Text('Historija', style: naslovSekcije),
              const SizedBox(height: AdminSpacing.sm),
              istorija.when(
                loading: () => const AdminSkeletonList(redova: 3),
                error: (_, _) => _Greska(
                  poruka: 'Historija se ne može učitati.',
                  ponovo: () =>
                      ref.invalidate(klijentIstorijaProvider(klijent.id)),
                ),
                data: (sve) {
                  // Sljedeći termin već stoji u svojoj kartici iznad.
                  final ranije = [
                    for (final t in sve)
                      if (t.id != sljedeci?.id) t,
                  ];
                  if (ranije.isEmpty) {
                    return Text(
                      'Nema ranijih termina.',
                      style: tekst.bodyMedium?.copyWith(
                        color: boje.textSecondary,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < ranije.length; i++)
                        _RedIstorije(
                          termin: ranije[i],
                          zadnji: i == ranije.length - 1,
                        ),
                    ],
                  );
                },
              ),
              if (biljeska.isNotEmpty) ...[
                const SizedBox(height: AdminSpacing.xxl),
                Text('Bilješka', style: naslovSekcije),
                const SizedBox(height: AdminSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AdminSpacing.lg),
                  decoration: BoxDecoration(
                    color: boje.ground,
                    borderRadius: BorderRadius.circular(AdminRadius.small),
                  ),
                  child: Text(
                    biljeska,
                    style: tekst.bodyLarge?.copyWith(color: boje.textSecondary),
                  ),
                ),
              ],
              const SizedBox(height: AdminSpacing.xl),
              Wrap(
                spacing: AdminSpacing.sm,
                runSpacing: AdminSpacing.sm,
                children: [
                  SizedBox(
                    height: AdminSize.touchTarget,
                    child: FilledButton(
                      onPressed: () =>
                          _uskoro(context, 'Zakazivanje iz profila'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, AdminSize.touchTarget),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AdminSpacing.xxl,
                        ),
                        textStyle: AdminText.actionLabel,
                      ),
                      child: const AdminVerzal('Zakaži termin'),
                    ),
                  ),
                  SizedBox(
                    height: AdminSize.touchTarget,
                    child: OutlinedButton(
                      onPressed: () => _uskoro(context, 'Poziv iz profila'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, AdminSize.touchTarget),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AdminSpacing.xxl,
                        ),
                        textStyle: tekst.labelMedium,
                      ),
                      child: const Text('Pozovi'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metrika extends StatelessWidget {
  const _Metrika({required this.broj, required this.labela});

  final String broj;
  final String labela;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: boje.ground,
        borderRadius: BorderRadius.circular(AdminRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            // `3e`: brojka metrike u profilu je 25 px, manja od 36 na „Danas".
            child: Text(
              broj,
              style: AdminText.metricNumber.copyWith(fontSize: 25),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            labela,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: boje.textSecondary, height: 1.2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Kartica „Sljedeći termin" iz `3e`: `14:20 danas`, pa usluga i radnik.
///
/// Računa se iz istorije (v. [sljedeciTermin]) — novog upita nema. Kad klijent nema
/// zakazan termin, kartica ostaje i kaže to, da mjesto ne izgleda kao neučitano.
class _SljedeciTermin extends StatelessWidget {
  const _SljedeciTermin({required this.istorija, required this.termin});

  final AsyncValue<List<Appointment>> istorija;
  final Appointment? termin;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tekst = Theme.of(context).textTheme;
    final vrijemeStil = AdminText.metricNumber.copyWith(
      fontSize: 30,
      color: boje.accent,
    );
    final opisStil = tekst.bodyLarge?.copyWith(color: boje.accent);
    final t = termin;

    final String vrijeme;
    final String? dan;
    final String opis;
    if (istorija.isLoading && !istorija.hasValue) {
      (vrijeme, dan, opis) = ('—', null, 'Učitavanje…');
    } else if (istorija.hasError && !istorija.hasValue) {
      (vrijeme, dan, opis) = ('—', null, 'Termini se ne mogu učitati.');
    } else if (t == null) {
      (vrijeme, dan, opis) = ('—', null, 'Nema zakazanog termina.');
    } else {
      final radnik = t.employeeName?.trim() ?? '';
      opis = [
        t.serviceName?.trim().isNotEmpty == true
            ? t.serviceName!.trim()
            : 'Usluga',
        if (radnik.isNotEmpty) radnik,
        // Nepotvrđen termin drži slot, ali salon mora znati da još nije dogovoren.
        if (t.status == AppointmentStatus.pending) 'čeka potvrdu',
      ].join(' · ');
      vrijeme = vrijemeHhMm(t.startTime);
      dan = _danTermina(t.date, DateTime.now());
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.lg,
        vertical: AdminSpacing.md,
      ),
      decoration: BoxDecoration(
        color: boje.accentTint,
        borderRadius: BorderRadius.circular(AdminRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(vrijeme, style: vrijemeStil),
              if (dan != null) ...[
                const SizedBox(width: AdminSpacing.md),
                Flexible(
                  child: Text(
                    dan,
                    style: tekst.titleSmall?.copyWith(color: boje.accent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AdminSpacing.xs),
          Text(opis, style: opisStil),
        ],
      ),
    );
  }
}

/// Red istorije iz `3e`: usluga 15/600, `02.05. · Emir`, cijena desno u sivoj.
class _RedIstorije extends StatelessWidget {
  const _RedIstorije({required this.termin, required this.zadnji});

  final Appointment termin;
  final bool zadnji;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tekst = Theme.of(context).textTheme;
    final cijena = termin.servicePrice;
    final radnik = termin.employeeName?.trim() ?? '';
    final datum = _danIMjesec(termin.date);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AdminSpacing.md),
      decoration: BoxDecoration(
        border: zadnji
            ? null
            : Border(
                bottom: BorderSide(
                  color: boje.separator,
                  width: AdminSize.hairline,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  termin.serviceName ?? 'Usluga',
                  style: tekst.titleSmall?.copyWith(height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // `employee_name` je nullable — termin na „bilo ko", ili obrisan radnik.
                Text(
                  radnik.isEmpty ? datum : '$datum · $radnik',
                  style: barlowTabular(
                    size: 14,
                    height: 1.2,
                    color: boje.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AdminSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (cijena != null)
                Text(
                  iznosKm(cijena),
                  style: barlowTabular(
                    size: 15,
                    weight: 600,
                    height: 1.2,
                    color: boje.textSecondary,
                  ),
                ),
              // `3e` crta samo održane termine, bez oznake. Otkazani, nedošli i
              // zakazani **ostaju u listi sa svojom oznakom**: istorija bez njih ne bi
              // objasnila broj nedolazaka iznad.
              if (termin.status != AppointmentStatus.completed) ...[
                const SizedBox(height: AdminSpacing.xs),
                AppointmentStatusPill(status: termin.status),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Telefon `3o` — lista, profil preko nje
// ---------------------------------------------------------------------------

class _Telefon extends ConsumerWidget {
  const _Telefon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izabrani = ref.watch(izabraniKlijentProvider);
    final boje = context.adminColors;
    final gutter = AdminShell.gutterOf(context);
    final razdjelnik = Container(
      height: AdminSize.hairline,
      color: boje.separator,
    );

    // Profil **zamjenjuje** listu umjesto da se otvara kao sheet: sadržaj je predugačak
    // za sheet na 402 px.
    if (izabrani != null) {
      return ColoredBox(
        color: boje.surface,
        child: SafeArea(
          bottom: false,
          child: _Profil(customerId: izabrani, saZatvaranjem: true),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: boje.surface,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                AdminSpacing.lg,
                gutter,
                AdminSpacing.lg,
              ),
              child: const _TelefonNaslov(),
            ),
          ),
        ),
        razdjelnik,
        ColoredBox(
          color: boje.surface,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              AdminSpacing.md,
              gutter,
              AdminSpacing.md,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Pretraga(telefon: true),
                SizedBox(height: AdminSpacing.sm),
                _FilteriTelefon(),
              ],
            ),
          ),
        ),
        razdjelnik,
        const Expanded(child: _MobilnaLista()),
        // „+ NOVI KLIJENT" stoji iznad donje navigacije, preko cijele širine (`3o`).
        DecoratedBox(
          decoration: BoxDecoration(
            color: boje.surface,
            border: Border(
              top: BorderSide(color: boje.separator, width: AdminSize.hairline),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: gutter,
              vertical: AdminSpacing.md,
            ),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => _uskoro(context, 'Novi klijent'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: AdminText.actionLabel.copyWith(fontSize: 16),
                ),
                child: const AdminVerzal('+ Novi klijent'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TelefonNaslov extends ConsumerWidget {
  const _TelefonNaslov();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tekst = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Klijenti', style: tekst.displaySmall),
        const SizedBox(height: AdminSpacing.xs),
        Text(
          _podnaslov(ref) ?? 'Učitavanje…',
          style: tekst.bodyLarge?.copyWith(
            color: context.adminColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Filteri iz `3o`: pilule, izabrana u plavoj podlozi bez obruba.
class _FilteriTelefon extends ConsumerWidget {
  const _FilteriTelefon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izabran = ref.watch(clientsFilterProvider);
    final boje = context.adminColors;
    final labela = Theme.of(context).textTheme.labelMedium;

    return Wrap(
      spacing: AdminSpacing.sm,
      children: [
        for (final filter in ClientsFilter.values)
          Semantics(
            button: true,
            selected: filter == izabran,
            // Pilula je 36 px kako je `3o` crta, a dodirna meta ostaje 44.
            child: InkWell(
              onTap: () =>
                  ref.read(clientsFilterProvider.notifier).postavi(filter),
              customBorder: const StadiumBorder(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AdminSize.touchTarget,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AdminSpacing.lg,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filter == izabran ? boje.accentTint : boje.surface,
                      borderRadius: BorderRadius.circular(AdminRadius.pill),
                      border: filter == izabran
                          ? null
                          : Border.all(
                              color: boje.border,
                              width: AdminSize.hairline,
                            ),
                    ),
                    child: Text(
                      filter.label,
                      style: labela?.copyWith(
                        color: filter == izabran
                            ? boje.accent
                            : boje.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MobilnaLista extends ConsumerWidget {
  const _MobilnaLista();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klijenti = ref.watch(adminKlijentiProvider);
    final gutter = AdminShell.gutterOf(context);

    return klijenti.when(
      loading: () => Padding(
        padding: EdgeInsets.all(gutter),
        child: const AdminSkeletonList(),
      ),
      error: (_, _) => _Greska(
        poruka: 'Klijenti se ne mogu učitati.',
        ponovo: () => ref.invalidate(adminKlijentiProvider),
      ),
      data: (redovi) => redovi.isEmpty
          ? const _Prazno()
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                gutter,
                AdminSpacing.lg,
                gutter,
                AdminSpacing.lg,
              ),
              itemCount: redovi.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AdminSpacing.sm),
              itemBuilder: (context, i) => _MobilnaKartica(klijent: redovi[i]),
            ),
    );
  }
}

/// Kartica iz `3o`: avatar 46, ime 17/600, `telefon · 11 dolazaka`, oznaka, strelica.
class _MobilnaKartica extends ConsumerWidget {
  const _MobilnaKartica({required this.klijent});

  final Customer klijent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;
    final radius = BorderRadius.circular(AdminRadius.small);

    return Material(
      color: boje.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: boje.cardEdge, width: AdminSize.hairline),
      ),
      child: InkWell(
        onTap: () =>
            ref.read(izabraniKlijentProvider.notifier).izaberi(klijent.id),
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.lg,
            vertical: AdminSpacing.md,
          ),
          child: Row(
            children: [
              _Avatar(klijent: klijent, promjer: 46),
              const SizedBox(width: AdminSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      imeKlijenta(klijent),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 17, height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${telefonKlijenta(klijent)} · '
                      '${klijent.visitCount} ${_dolazaka(klijent.visitCount)}',
                      style: barlowTabular(size: 14, color: boje.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AdminSpacing.xs),
                    _Oznaka(klijent: klijent, telefon: true),
                  ],
                ),
              ),
              const SizedBox(width: AdminSpacing.sm),
              Icon(Icons.chevron_right, size: 20, color: boje.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zajednička prazna i greška stanja
// ---------------------------------------------------------------------------

class _Prazno extends ConsumerWidget {
  const _Prazno();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pretraga = ref.watch(clientsPretragaProvider).trim();
    final filter = ref.watch(clientsFilterProvider);
    final boje = context.adminColors;

    // Tri prazna stanja, jer tri različita razloga traže tri različita sljedeća koraka.
    final poruka = pretraga.isNotEmpty
        ? 'Nema klijenta koji odgovara pretrazi „$pretraga".'
        : filter == ClientsFilter.svi
        ? 'Adresar je još prazan. Klijent se upiše kad zakaže prvi termin.'
        : 'Nema klijenta u grupi „${filter.label}".';

    // Filtrirano prazno ima izlaz: prazna lista zbog filtera nije prazan adresar, i
    // korisnik ne treba tražiti gdje se filter poništava (FE-501).
    final (String, VoidCallback)? izlaz = pretraga.isNotEmpty
        ? (
            'Poništi pretragu',
            () => ref.read(clientsPretragaProvider.notifier).postavi(''),
          )
        : filter == ClientsFilter.svi
        ? null
        : (
            'Prikaži sve klijente',
            () => ref
                .read(clientsFilterProvider.notifier)
                .postavi(ClientsFilter.svi),
          );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              poruka,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: boje.textSecondary),
            ),
            if (izlaz != null)
              TextButton(onPressed: izlaz.$2, child: Text(izlaz.$1)),
          ],
        ),
      ),
    );
  }
}

class _Greska extends StatelessWidget {
  const _Greska({required this.poruka, this.ponovo});

  final String poruka;
  final VoidCallback? ponovo;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AdminSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(poruka, textAlign: TextAlign.center),
          if (ponovo != null)
            TextButton(onPressed: ponovo, child: const Text('Pokušaj ponovo')),
        ],
      ),
    ),
  );
}
