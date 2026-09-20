/// `/calendar` — dan po radnicima (`3c`) i isti dan kao lista (`3l`).
///
/// **Dva rasporeda, jedan model.** Desktop crta mrežu sa kolonom po radniku, telefon listu
/// po vremenu; oboje čita `calendar_day.dart`. Stisnuta mreža na 402 px nije mobilni
/// raspored (`SPEC.md`: „Horizontalno skalirani desktop nije prihvatljiv mobilni layout").
///
/// ## Šta canvas crta, a ovdje namjerno nema
///
/// - **`Dan · Sedmica · Mjesec`** iz top bara `3c`. Ovaj task je „Kalendar **dana**";
///   prekidač sa dvije opcije koje ne rade je gori od prekidača kojeg nema.
/// - **„Dodaj pauzu" i „Zatvori dan"** iz bočne trake. Oba su pisanje, a pisanje ide kroz
///   validirane `rpc` funkcije kojih za radno vrijeme još nema — task 34. „Blokiraj
///   vrijeme" ostaje jer ruta `/calendar/block` postoji i vodi u ljusku, isto pravilo kao
///   na dashboardu.
/// - **Fotografija radnika** u zaglavlju kolone. `employees.image_url` je nullable i u
///   seedu prazan, pa bi svaka kolona nosila slomljenu sliku; inicijal radi isti posao.
///   Slike radnika dobijaju svoj modul u tasku 33.
library;

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/datum.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../appointments/appointment_card.dart';
import '../appointments/appointments_providers.dart';
import 'calendar_day.dart';
import 'calendar_providers.dart';

/// Širina vremenske ose lijevo od kolona. Canvas: `grid-template-columns:76px …`.
const double _sirinaOse = 76;

/// Najuža kolona radnika prije nego mreža počne skrolati vodoravno.
///
/// Canvas crta tri kolone na 1440 px, što daje ~370 px po koloni. Salon sa osam radnika bi
/// na istoj širini dobio 145 px po koloni, u koje ime klijenta ne stane — tada je skrol
/// pošteniji od stiskanja.
///
/// **240, a ne 190.** Mjera mora primiti i podnaslov zaglavlja: 190 minus padding (2×18),
/// inicijal (34) i razmak (11) ostavlja 109 px za `09:00–17:00 · 3 termina`, koje traži oko
/// 150 — broj termina bi se odsjekao prvi, a on je razlog zbog kojeg se u zaglavlje gleda.
const double _minSirinaKolone = 240;

/// Razmak bloka od ivice kolone. Canvas: `left:8px;right:8px`.
const double _uvlakaBloka = 8;

class AdminCalendarScreen extends ConsumerWidget {
  const AdminCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jeDesktop = AdminShell.jeDesktop(context);

    return AdminScaffold(
      title: 'Kalendar',
      aktivna: AdminRoute.calendar,
      // `3l` iznad sadržaja crta veliki naslov „Kalendar" sa strelicama za dan; `AppBar` sa
      // sitnim naslovom bi istu riječ napisao dvaput.
      sopstvenoZaglavlje: true,
      actions: jeDesktop ? const [_TopBarAkcije()] : null,
      body: jeDesktop ? const _Desktop() : const _Telefon(),
    );
  }
}

/// Akcije desktop top bara.
class _TopBarAkcije extends StatelessWidget {
  const _TopBarAkcije();

  @override
  Widget build(BuildContext context) {
    // Samo jedna radnja: „Blokiraj vrijeme" stoji u bočnoj traci, kako ga canvas i crta.
    // Prva verzija ga je imala na oba mjesta — dva ista dugmeta u istom vidnom polju uče
    // vlasnika da pogodi koje je „pravo".
    return FilledButton(
      onPressed: () => context.go(AdminRoute.appointmentNew.path),
      child: const Text('+ Novi termin'),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop `3c`
// ---------------------------------------------------------------------------

class _Desktop extends ConsumerWidget {
  const _Desktop();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dan = ref.watch(kalendarDanProvider);

    return Column(
      children: [
        const _ZaglavljeDana(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: dan.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      _Greska(onPonovi: () => osvjeziKalendar(ref)),
                  data: (dan) => _Mreza(dan: dan),
                ),
              ),
              const _BocnaTraka(),
            ],
          ),
        ),
      ],
    );
  }
}

/// `‹ › Ponedjeljak, 18. maj — Danas`.
///
/// Canvas ovo crta **u top baru**; ovdje stoji u tijelu ekrana, jer top bar admin ljuske
/// nosi breadcrumb `Vitez / Kalendar` i akcije koje su iste za sve ekrane (task 30).
/// Dashboard svoj naslov dana crta na istom mjestu, pa se dva ekrana čitaju isto.
class _ZaglavljeDana extends ConsumerWidget {
  const _ZaglavljeDana();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dan = ref.watch(kalendarDatumProvider);
    final sada = ref.watch(sadaProvider).valueOrNull ?? DateTime.now();
    final jeDanas = _istiDan(dan, sada);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.gutterDesktop,
        vertical: AdminSpacing.lg,
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
      child: Row(
        children: [
          _StrelicaDana(
            ikona: Icons.chevron_left,
            opis: 'Prethodni dan',
            onTap: () => ref.read(kalendarDatumProvider.notifier).pomjeri(-1),
          ),
          const SizedBox(width: AdminSpacing.sm),
          _StrelicaDana(
            ikona: Icons.chevron_right,
            opis: 'Sljedeći dan',
            onTap: () => ref.read(kalendarDatumProvider.notifier).pomjeri(1),
          ),
          const SizedBox(width: AdminSpacing.md),
          Text(
            datumDugo(dan),
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: AdminSpacing.md),
          // „Danas" nestaje kad se već gleda danas: dugme koje ne mijenja ništa uči
          // vlasnika da ga ignoriše.
          if (!jeDanas)
            TextButton(
              onPressed: () => ref.read(kalendarDatumProvider.notifier).danas(),
              child: const Text('Danas'),
            ),
        ],
      ),
    );
  }
}

/// Strelica za dan — zaobljen kvadrat, ne krug.
///
/// **Meta je 38 px na desktopu i [AdminSize.touchTarget] na telefonu.** 38 je canvas mjera
/// i tačna je za miš; na telefonu je ista strelica primarna navigacija ekrana, a `SPEC.md`
/// traži „velike touch mete". Prva verzija je nosila 38 na obje širine.
class _StrelicaDana extends StatelessWidget {
  const _StrelicaDana({
    required this.ikona,
    required this.opis,
    required this.onTap,
  });

  final IconData ikona;
  final String opis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mjera = AdminShell.jeDesktop(context) ? 38.0 : AdminSize.touchTarget;

    return Tooltip(
      message: opis,
      child: IconButton.outlined(
        onPressed: onTap,
        icon: Icon(ikona),
        // Bez ovoga `IconButton` nosi Material default od 48 px i razmak između strelica
        // postaje veći nego u canvasu.
        constraints: BoxConstraints.tightFor(width: mjera, height: mjera),
        padding: EdgeInsets.zero,
        iconSize: 20,
        tooltip: null,
        style: IconButton.styleFrom(
          // Canvas crta `border-radius:6px`, a `IconButton.outlined` je po defaultu krug.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminRadius.base),
          ),
        ),
      ),
    );
  }
}

/// Mreža: osa lijevo, kolona po radniku desno.
class _Mreza extends ConsumerWidget {
  const _Mreza({required this.dan});

  final KalendarDan dan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (dan.kolone.isEmpty) return const _NemaRadnika();

    return LayoutBuilder(
      builder: (context, constraints) {
        final dostupno = constraints.maxWidth - _sirinaOse;
        final sirinaKolone = (dostupno / dan.kolone.length) < _minSirinaKolone
            ? _minSirinaKolone
            : dostupno / dan.kolone.length;
        final ukupno = _sirinaOse + sirinaKolone * dan.kolone.length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: ukupno,
            height: constraints.maxHeight,
            child: Column(
              children: [
                _ZaglavljaKolona(dan: dan, sirinaKolone: sirinaKolone),
                Expanded(
                  child: SingleChildScrollView(
                    child: _Osa(dan: dan, sirinaKolone: sirinaKolone),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Red sa imenima radnika iznad mreže.
class _ZaglavljaKolona extends StatelessWidget {
  const _ZaglavljaKolona({required this.dan, required this.sirinaKolone});

  final KalendarDan dan;
  final double sirinaKolone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.adminColors.surface,
        border: Border(
          bottom: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: _sirinaOse),
          for (final kolona in dan.kolone)
            SizedBox(
              width: sirinaKolone,
              child: _ZaglavljeKolone(kolona: kolona),
            ),
        ],
      ),
    );
  }
}

class _ZaglavljeKolone extends StatelessWidget {
  const _ZaglavljeKolone({required this.kolona});

  final KolonaRadnika kolona;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: AdminSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          _Inicijal(ime: kolona.ime),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kolona.ime,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    // Radnik koji danas ne radi nije isto što i radnik bez termina;
                    // stišan naslov to kaže prije nego se pročita podnaslov.
                    color: kolona.radi ? null : context.adminColors.textMuted,
                  ),
                ),
                Text(
                  kolona.podnaslov,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.adminColors.textSecondary,
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

/// Krug sa prvim slovom imena — zamjena za fotografiju iz canvasa.
class _Inicijal extends StatelessWidget {
  const _Inicijal({required this.ime});

  final String ime;

  @override
  Widget build(BuildContext context) {
    final slovo = ime.trim().isEmpty ? '?' : ime.trim()[0].toUpperCase();

    // Čitač ekrana inače pročita usamljeno slovo prije imena koje stoji odmah pored.
    return ExcludeSemantics(
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.adminColors.accentTint,
          shape: BoxShape.circle,
        ),
        child: Text(
          slovo,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.adminColors.accentInk,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Satna mreža sa kolonama i linijom „sada".
class _Osa extends ConsumerWidget {
  const _Osa({required this.dan, required this.sirinaKolone});

  final KalendarDan dan;
  final double sirinaKolone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sada = ref.watch(sadaProvider).valueOrNull;
    final yLinije = sada == null ? null : dan.yLinijeSada(sada);

    return SizedBox(
      height: dan.osa.visina,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _sirinaOse,
                child: _SatiOse(osa: dan.osa),
              ),
              for (final kolona in dan.kolone)
                SizedBox(
                  width: sirinaKolone,
                  child: _Kolona(
                    kolona: kolona,
                    osa: dan.osa,
                    sada: sada,
                    sirina: sirinaKolone,
                  ),
                ),
            ],
          ),
          if (yLinije != null && sada != null)
            _LinijaSada(y: yLinije, sada: sada),
        ],
      ),
    );
  }
}

/// Satne oznake lijevo. Mono, desno poravnate — canvas `text-align:right`.
class _SatiOse extends StatelessWidget {
  const _SatiOse({required this.osa});

  final KalendarOsa osa;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final minuta in osa.sati)
          SizedBox(
            height: kVisinaSata,
            child: Padding(
              padding: const EdgeInsets.only(top: 7, right: 12, left: 12),
              child: Align(
                alignment: Alignment.topRight,
                child: Text(
                  vrijemeOse(minuta),
                  style: AdminText.dataInline.copyWith(
                    color: context.adminColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Jedna kolona: satne linije, pozadinski pojasevi, pa blokovi termina.
class _Kolona extends StatelessWidget {
  const _Kolona({
    required this.kolona,
    required this.osa,
    required this.sada,
    required this.sirina,
  });

  final KolonaRadnika kolona;
  final KalendarOsa osa;
  final DateTime? sada;

  /// Širina kolone. Dolazi odozgo, iz `_Mreza`, a **ne iz `LayoutBuilder`-a ovdje**:
  /// `Positioned` mora biti neposredno dijete `Stack`-a, pa bi `LayoutBuilder` između njih
  /// oborio layout (`Incorrect use of ParentDataWidget`). Prva verzija je tako i pala.
  final double sirina;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Satne linije idu ispod svega — blok koji ih prekriva je zauzeto vrijeme.
          Positioned.fill(
            child: CustomPaint(
              painter: _SatneLinije(
                broj: osa.sati.length,
                boja: context.adminColors.separator,
              ),
            ),
          ),
          for (final stavka in kolona.pozadina)
            Positioned(
              top: osa.yZa(stavka.odMinuta),
              left: _uvlakaBloka,
              right: _uvlakaBloka,
              height: osa.visinaZa(stavka.odMinuta, stavka.doMinuta),
              child: _Pojas(stavka: stavka),
            ),
          for (final stavka in kolona.termini)
            Positioned(
              top: osa.yZa(stavka.odMinuta),
              left: _uvlakaBloka + _sirinaTrake(stavka) * stavka.traka,
              width: _sirinaTrake(stavka),
              // Dva piksela manje od punog trajanja: bez razmaka se dva uzastopna termina
              // stope u jedan blok, pa 09:00–10:00 i 10:00–11:00 izgledaju kao dvosatni.
              height: osa.visinaZa(stavka.odMinuta, stavka.doMinuta) - 2,
              child: _BlokTermina(
                stavka: stavka,
                sada: sada,
                visina: osa.visinaZa(stavka.odMinuta, stavka.doMinuta) - 2,
              ),
            ),
        ],
      ),
    );
  }

  double _sirinaTrake(StavkaKalendara stavka) =>
      (sirina - 2 * _uvlakaBloka) / stavka.brojTraka;
}

/// Termin kao blok — `3c`.
class _BlokTermina extends ConsumerWidget {
  const _BlokTermina({
    required this.stavka,
    required this.sada,
    required this.visina,
  });

  final StavkaKalendara stavka;
  final DateTime? sada;

  /// Visina bloka u pikselima.
  ///
  /// Padding i drugi red se biraju po **njoj**, ne po trajanju: tipičan termin od 40
  /// minuta je na osi od 80 px/sat visok 51 px, a dva reda teksta sa punim paddingom traže
  /// 56 — pa se rep slova „š" u „Fade šišanje" odsijecao. Vidio snimak, ne test.
  final double visina;

  /// Ispod ove visine drugi red teksta nema gdje; iznad nje ide uži padding.
  static const double _zaPunPadding = 64;
  static const double _zaDrugiRed = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prag se poredi sa visinom koju tekst **stvarno** traži: uvećan sistemski font je isto
    // što i niži blok.
    final skala = MediaQuery.textScalerOf(context).scale(1);
    final termin = stavka.termin!;
    final uToku = sada != null && terminUToku(termin, sada!);
    final ton = _tonTermina(context, termin.status, uToku: uToku);
    final oznaka = uToku ? kOznakaUToku : statusOznaka(termin.status);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Semantics(
        button: true,
        label: oznakaTermina(
          termin,
          status: oznaka,
          usluga: ref.watch(uslugePoIdProvider)[termin.serviceId]?.name,
          radnik: ref.watch(radniciPoIdProvider)[termin.employeeId]?.name,
        ),
        child: ExcludeSemantics(
          child: Material(
            color: ton.pozadina,
            borderRadius: BorderRadius.circular(AdminRadius.base),
            child: InkWell(
              // `push`, ne `go` — v. isti komentar uz mobilni red.
              onTap: () => context.push('/appointments/${termin.id}'),
              borderRadius: BorderRadius.circular(AdminRadius.base),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AdminRadius.base),
                  border: Border(left: BorderSide(color: ton.rub, width: 3)),
                ),
                padding: EdgeInsets.fromLTRB(
                  12,
                  visina < _zaPunPadding * skala ? 6 : 9,
                  12,
                  visina < _zaPunPadding * skala ? 6 : 9,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // I naslov je `Flexible`: na uvećanom sistemskom fontu jedan red zna
                    // biti viši od cijelog bloka, a `Column` sa čvrstom visinom tada
                    // prelije.
                    Flexible(
                      child: Text(
                        termin.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: ton.tekst,
                          fontWeight: FontWeight.w600,
                          // Otkazan termin se ne briše iz rasporeda nego se precrtava:
                          // slot je bio zauzet pa oslobođen, i vlasnik to mora vidjeti.
                          decoration: _precrtan(termin.status)
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    // Nizak blok nema mjesta za drugi red. Vrijeme se i tako čita sa ose, a
                    // ime klijenta je ono zbog čega se u blok gleda — status tada ostaje samo
                    // u oznaci za čitač ekrana i u tooltipu, v. `Semantics` niže.
                    if (visina >= _zaDrugiRed * skala)
                      Flexible(
                        child: Text(
                          _opisBloka(
                            stavka,
                            ref.watch(uslugePoIdProvider),
                            status: uToku
                                ? kOznakaUToku
                                : statusOznaka(termin.status),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ton.tekstTih,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `11:00–12:20 · Potvrđeno · Fade + brada` — drugi red bloka.
///
/// Usluga dolazi iz mape, ne iz termina: `appointments` nosi samo `service_id`, pa bi blok
/// koji sam traži svoju uslugu pokrenuo upit po svakom terminu u mreži.
String _opisBloka(
  StavkaKalendara stavka,
  Map<String, Service> usluge, {
  required String status,
}) {
  final usluga = usluge[stavka.termin!.serviceId]?.name;

  return [
    '${vrijemeOse(stavka.odMinuta)}–${vrijemeOse(stavka.doMinuta)}',
    status,
    if (usluga != null && usluga.isNotEmpty) usluga,
  ].join(' · ');
}

/// Oznaka jednog termina za čitač ekrana.
///
/// Blok i red su **dva teksta jedan ispod drugog**; bez spajanja ih TalkBack pročita kao
/// dva nepovezana čvora, bez statusa i bez radnika. Radnik ulazi zato što kolona, koja ga
/// na ekranu nosi, čitaču ne znači ništa.
String oznakaTermina(
  Appointment termin, {
  required String status,
  String? usluga,
  String? radnik,
}) => [
  '${vrijemeHhMm(termin.startTime)}–${vrijemeHhMm(termin.endTime)}',
  termin.customerName,
  status,
  if (usluga != null && usluga.isNotEmpty) usluga,
  if (radnik != null && radnik.isNotEmpty) radnik,
].join(', ');

/// Pozadinski pojas: pauza, blokada ili neradno vrijeme.
///
/// **Kosa šrafura, ne puna boja.** Puna siva bi izgledala kao još jedan termin, a razlika
/// između „zauzeto" i „ne radi se" je ono zbog čega vlasnik u kalendar i gleda.
class _Pojas extends StatelessWidget {
  const _Pojas({required this.stavka});

  final StavkaKalendara stavka;

  @override
  Widget build(BuildContext context) {
    final neradno = stavka.vrsta == VrstaStavke.neradno;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AdminRadius.base),
      child: CustomPaint(
        // **Razliku nosi gustina, ne samo boja.** Prva verzija je „ne radi" i „pauzu"
        // razlikovala po `border` naspram `separator` — a u tamnoj paleti su ta dva tokena
        // ista boja (`#373A40`), pa su dvije različite stvari izgledale identično. Korak
        // šrafure radi u obje teme, i vidi ga i onaj ko boje ne razlikuje.
        painter: _Srafura(
          podloga: context.adminColors.ground,
          crta: neradno
              ? context.adminColors.border
              : context.adminColors.separator,
          korak: neradno ? 10 : 16,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _TekstPojasa(stavka: stavka, visina: constraints.maxHeight),
        ),
      ),
    );
  }
}

/// Natpis pojasa, onoliko koliko ga stane.
///
/// **Mjeri se u pikselima, ne u minutama.** Prvi pokušaj je pisao naslov za pojas duži od
/// 20 minuta, a vrijeme za duži od 40 — i 40-minutna pauza je prelila `Column` za 0,67 px,
/// jer dva reda teksta i vertikalni padding traže 53 px, a pojas ih ima 53,3. Minuta nije
/// mjera visine: ista pauza je na gušćoj osi niža, a veći `textScaleFactor` je čini
/// pretijesnom bez ijedne promjene u podacima.
class _TekstPojasa extends StatelessWidget {
  const _TekstPojasa({required this.stavka, required this.visina});

  final StavkaKalendara stavka;
  final double visina;

  /// Visine ispod kojih natpis ne stane. Mjereno nad `bodyMedium` (≈20 px) i
  /// `dataInline` (≈17 px), uz padding koji se i sam smanjuje.
  /// Mjereno bez uvećanja sistemskog fonta, pa se množe skalom — v. `_BlokTermina`.
  static const double _zaNaslov = 30;
  static const double _zaVrijeme = 62;

  @override
  Widget build(BuildContext context) {
    final skala = MediaQuery.textScalerOf(context).scale(1);
    if (visina < _zaNaslov * skala) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final usko = visina < _zaVrijeme * skala;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, usko ? 5 : 9, 12, usko ? 5 : 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stavka.tekst ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.adminColors.textSecondary,
            ),
          ),
          // Neradni pojas nosi vrijeme već u naslovu („Ne radi do 12:00"), pa bi drugi red
          // isti podatak napisao dvaput.
          if (!usko && stavka.vrsta != VrstaStavke.neradno)
            Text(
              '${vrijemeOse(stavka.odMinuta)}–${vrijemeOse(stavka.doMinuta)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdminText.dataInline.copyWith(
                color: context.adminColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// Crvena linija sa vremenom — `3c` je crta preko cijele mreže.
class _LinijaSada extends StatelessWidget {
  const _LinijaSada({required this.y, required this.sada});

  final double y;
  final DateTime sada;

  @override
  Widget build(BuildContext context) {
    final boja = context.adminColors.destructive;

    return Positioned(
      top: y,
      left: 0,
      right: 0,
      child: Row(
        children: [
          SizedBox(
            width: _sirinaOse,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: boja,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    vrijemeOse(sada.hour * 60 + sada.minute),
                    style: AdminText.dataInline.copyWith(
                      color: context.adminColors.onDestructive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: Container(height: 2, color: boja)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop — bočna traka
// ---------------------------------------------------------------------------

/// 268 px desno: mjesečni birač, legenda, blokada.
class _BocnaTraka extends ConsumerWidget {
  const _BocnaTraka();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 268,
      decoration: BoxDecoration(
        color: context.adminColors.ground,
        border: Border(
          left: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        children: [
          const _MiniMjesec(),
          const SizedBox(height: AdminSpacing.xl),
          const _Legenda(),
          const SizedBox(height: AdminSpacing.xl),
          OutlinedButton(
            onPressed: () => context.go(AdminRoute.calendarBlock.path),
            child: const Text('Blokiraj vrijeme'),
          ),
        ],
      ),
    );
  }
}

/// Mjesec izabranog dana, kao birač datuma.
class _MiniMjesec extends ConsumerWidget {
  const _MiniMjesec();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izabran = ref.watch(kalendarDatumProvider);
    final prvi = DateTime(izabran.year, izabran.month);
    final danaUMjesecu = DateTime(izabran.year, izabran.month + 1, 0).day;
    // ISO: ponedjeljak je 1, a mreža počinje ponedjeljkom — prazna polja prije prvog.
    final praznih = prvi.weekday - 1;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: AdminSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${kMjeseci[izabran.month - 1].toUpperCase()} ${izabran.year}',
              style: AdminText.eyebrow.copyWith(
                color: context.adminColors.textSecondary,
              ),
            ),
            const SizedBox(height: AdminSpacing.md),
            Row(
              children: [
                for (final slovo in const ['P', 'U', 'S', 'Č', 'P', 'S', 'N'])
                  Expanded(
                    child: Center(
                      child: Text(
                        slovo,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: context.adminColors.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.25,
              children: [
                for (var i = 0; i < praznih; i++) const SizedBox.shrink(),
                for (var d = 1; d <= danaUMjesecu; d++)
                  _DanMjeseca(
                    dan: DateTime(izabran.year, izabran.month, d),
                    izabran: d == izabran.day,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DanMjeseca extends ConsumerWidget {
  const _DanMjeseca({required this.dan, required this.izabran});

  final DateTime dan;
  final bool izabran;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Vikend je stišan, kako ga canvas i crta — ne znači da se ne radi, nego da se
    // mjesec čita brže kad sedmica ima vidljiv kraj.
    final vikend = dan.weekday >= DateTime.saturday;

    return Semantics(
      button: true,
      selected: izabran,
      label: datumDugo(dan),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => ref.read(kalendarDatumProvider.notifier).postavi(dan),
          // Canvas: `padding:6px 0;border-radius:4px` — sitnija mjera od [AdminRadius.base],
          // izmjerena, jer ćelija od 20 px sa radijusom 6 izgleda kao pilula.
          borderRadius: BorderRadius.circular(4),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: izabran ? context.adminColors.accent : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${dan.day}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: izabran
                    ? context.adminColors.onAccent
                    : vikend
                    ? context.adminColors.textMuted
                    : null,
                fontWeight: izabran ? FontWeight.w600 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Legenda boja.
///
/// **Ima pet redova, canvas ima četiri.** Peti je „Otkazano": canvas ga ne crta jer ga
/// njegov demo dan nema, a ovaj kalendar otkazane termine **prikazuje** (v.
/// `StaffAppointmentRepository.forDay`). Boja bez objašnjenja u legendi je gora od
/// legende koja je za jedan red duža.
class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    final statusi = context.statusColors;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: AdminSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legenda',
              style: AdminText.eyebrow.copyWith(
                color: context.adminColors.textSecondary,
              ),
            ),
            const SizedBox(height: AdminSpacing.md),
            // **Nazivi dolaze iz `statusOznaka`, ne kao literali.** Canvas piše „Čeka
            // potvrdu", a pilula uz termin „Na čekanju" — ista stvar pod dva imena na
            // istom ekranu je greška koju je task 30 već jednom vadio iz dashboarda
            // („Pregled" naspram „Danas"). Legenda zato govori jezikom pilule.
            //
            // **Kvadratić nosi `background`, ne `foreground`.** Blok termina je ispunjen
            // podlogom tona, a `foreground` je tekst na njoj — legenda po njemu je
            // pokazivala boju koje na rasporedu nema, a za „Otkazano" (`onDestructive`,
            // skoro bijela) kvadratić se nije ni vidio. Našao snimak, ne test: widget test
            // vidi da red postoji, ne i da mu je uzorak nevidljiv.
            for (final status in const [
              AppointmentStatus.confirmed,
              AppointmentStatus.pending,
              AppointmentStatus.completed,
              AppointmentStatus.cancelled,
            ])
              _RedLegende(
                // Isti izvor boje koji koristi i blok, i statusna pilula uz termin.
                ton: statusTon(statusi, status),
                tekst: statusOznaka(status),
              ),
            _RedLegende(
              ton: AdminStatusTone(
                background: context.adminColors.accent,
                foreground: context.adminColors.onAccent,
              ),
              tekst: kOznakaUToku,
            ),
          ],
        ),
      ),
    );
  }
}

class _RedLegende extends StatelessWidget {
  const _RedLegende({required this.ton, required this.tekst});

  final AdminStatusTone ton;
  final String tekst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: ton.background,
              borderRadius: BorderRadius.circular(3),
              // Obrub u boji teksta: „Završeno" je gotovo bijelo na bijeloj kartici, pa bi
              // se bez njega kvadratić stopio sa podlogom.
              border: Border.all(
                color: ton.foreground,
                width: AdminSize.hairline,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            tekst,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.adminColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Telefon `3l`
// ---------------------------------------------------------------------------

class _Telefon extends ConsumerWidget {
  const _Telefon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dan = ref.watch(kalendarDanProvider);

    return Column(
      children: [
        const _MobilnoZaglavlje(),
        const _TrakaDana(),
        if (dan.valueOrNull case final ucitan?) _TrakaRadnika(dan: ucitan),
        Expanded(
          child: dan.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _Greska(onPonovi: () => osvjeziKalendar(ref)),
            // `await` na `future`, ne goli `invalidate`: `invalidate` je sinhron, pa bi
            // se spinner ugasio prije nego ijedan od četiri upita vrati odgovor — korisnik
            // vidi „osvježeno" dok se još učitava.
            data: (dan) => RefreshIndicator(
              onRefresh: () async {
                osvjeziKalendar(ref);
                await ref.read(kalendarDanProvider.future);
              },
              child: _MobilnaLista(dan: dan),
            ),
          ),
        ),
        const _MobilnaTraka(),
      ],
    );
  }
}

/// Veliki naslov i strelice — `3l`.
class _MobilnoZaglavlje extends ConsumerWidget {
  const _MobilnoZaglavlje();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: context.adminColors.surface,
      padding: EdgeInsets.fromLTRB(
        AdminSpacing.gutterMobile,
        MediaQuery.paddingOf(context).top + AdminSpacing.lg,
        AdminSpacing.gutterMobile,
        AdminSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // `display`, ne `metricNumber`: to je naslov ekrana, isti koji nose
                // „Danas" i „Termini". `metricNumber` je brojka u kartici metrike i
                // promjena njene veličine ne smije pomjeriti naslov.
                Text('Kalendar', style: AdminText.display),
                Text(
                  datumDugo(ref.watch(kalendarDatumProvider)),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: context.adminColors.textSecondary),
                ),
              ],
            ),
          ),
          _StrelicaDana(
            ikona: Icons.chevron_left,
            opis: 'Prethodni dan',
            onTap: () => ref.read(kalendarDatumProvider.notifier).pomjeri(-1),
          ),
          const SizedBox(width: 7),
          _StrelicaDana(
            ikona: Icons.chevron_right,
            opis: 'Sljedeći dan',
            onTap: () => ref.read(kalendarDatumProvider.notifier).pomjeri(1),
          ),
        ],
      ),
    );
  }
}

/// Sedmica izabranog dana, ćelija po danu.
class _TrakaDana extends ConsumerWidget {
  const _TrakaDana();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izabran = ref.watch(kalendarDatumProvider);
    // Sedmica počinje ponedjeljkom, i kad je izabrana nedjelja — inače bi traka „skočila"
    // kad se pređe iz nedjelje u ponedjeljak.
    final ponedjeljak = izabran.subtract(Duration(days: izabran.weekday - 1));

    return Container(
      color: context.adminColors.surface,
      padding: const EdgeInsets.only(bottom: AdminSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.gutterMobile,
        ),
        child: Row(
          children: [
            for (var i = 0; i < 7; i++)
              Padding(
                padding: const EdgeInsets.only(right: AdminSpacing.sm),
                child: _CelijaDana(
                  dan: ponedjeljak.add(Duration(days: i)),
                  izabran: i == izabran.weekday - 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CelijaDana extends ConsumerWidget {
  const _CelijaDana({required this.dan, required this.izabran});

  final DateTime dan;
  final bool izabran;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: izabran,
      // Bez ovoga čitač pročita „SUB" pa „19" kao dva nepovezana čvora, bez mjeseca i bez
      // toga koji je dan izabran.
      label: datumDugo(dan),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => ref.read(kalendarDatumProvider.notifier).postavi(dan),
          borderRadius: BorderRadius.circular(AdminRadius.base),
          child: Container(
            width: 56,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: izabran ? context.adminColors.accent : null,
              borderRadius: BorderRadius.circular(AdminRadius.base),
              border: izabran
                  ? null
                  : Border.all(
                      color: context.adminColors.border,
                      width: AdminSize.hairline,
                    ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _kratkiDan(dan),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: izabran
                        ? context.adminColors.onAccent
                        : context.adminColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${dan.day}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: izabran ? context.adminColors.onAccent : null,
                    fontWeight: FontWeight.w700,
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

/// `PON`, `UTO` … — tri slova iz punog imena dana, bez druge tabele.
String _kratkiDan(DateTime dan) =>
    kDaniSedmice[dan.weekday - 1].substring(0, 3).toUpperCase();

/// Chip traka: „Svi" i jedan chip po radniku.
class _TrakaRadnika extends ConsumerWidget {
  const _TrakaRadnika({required this.dan});

  final KalendarDan dan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izabran = ref.watch(izabraniRadnikProvider);
    // Salon sa jednim radnikom ne treba filter — „Svi" i „Emir" bi bila ista lista.
    if (dan.kolone.length < 2) return const SizedBox.shrink();

    return Container(
      color: context.adminColors.surface,
      padding: const EdgeInsets.only(bottom: AdminSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.gutterMobile,
        ),
        child: Row(
          children: [
            _ChipRadnika(
              tekst: 'Svi',
              izabran: izabran == null,
              onTap: () =>
                  ref.read(izabraniRadnikProvider.notifier).postavi(null),
            ),
            for (final kolona in dan.kolone)
              _ChipRadnika(
                tekst: kolona.ime,
                izabran: izabran == _kljucKolone(kolona),
                onTap: () => ref
                    .read(izabraniRadnikProvider.notifier)
                    .postavi(_kljucKolone(kolona)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ključ kolone u chip traci.
///
/// Kolona „Bez radnika" nema `id`, pa je ime jedino što je razlikuje. `id` je inače
/// stabilniji, ali ovdje je izbor kratkotrajan i ne preživljava promjenu dana.
String _kljucKolone(KolonaRadnika kolona) => kolona.radnikId ?? kolona.ime;

class _ChipRadnika extends StatelessWidget {
  const _ChipRadnika({
    required this.tekst,
    required this.izabran,
    required this.onTap,
  });

  final String tekst;
  final bool izabran;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AdminSpacing.sm),
      child: ChoiceChip(
        label: Text(tekst),
        selected: izabran,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// Lista po vremenu — `3l`.
///
/// **Isprekidani redovi „Slobodno 80 min · Dodirni za novi termin" iz canvasa ovdje ne
/// postoje.** Slobodno vrijeme nije rupa u rasporedu: `buffer_minutes` produžava zauzeti
/// interval, `slot_step_minutes` bira dozvoljene početke, `min_advance_booking_hours`
/// odsijeca ono što je preblizu. Računanje u Dartu bi vlasniku nudilo termine koje
/// `book_appointment` odbija — a availability logika u aplikaciji je bug koji se ne može
/// hotfixati (`.claude/docs/architecture.md`). Izvor bi bio `get_available_slots`, ali on
/// traži uslugu i trajanje, kojih kalendar dana nema.
class _MobilnaLista extends ConsumerWidget {
  const _MobilnaLista({required this.dan});

  final KalendarDan dan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izabran = ref.watch(izabraniRadnikProvider);
    final kolona = izabran == null
        ? null
        : dan.kolone.where((k) => _kljucKolone(k) == izabran).firstOrNull;

    final redovi = kolona == null
        ? redoviDana(dan)
        : [for (final s in redoviKolone(kolona)) RedListe(stavka: s)];

    if (redovi.isEmpty) return _PrazanDan(dan: dan, kolona: kolona);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.gutterMobile,
        AdminSpacing.lg,
        AdminSpacing.gutterMobile,
        AdminSpacing.xl,
      ),
      itemCount: redovi.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _MobilniRed(red: redovi[i]),
    );
  }
}

/// Jedan red: vrijeme lijevo (62 px, mono), sadržaj desno.
class _MobilniRed extends ConsumerWidget {
  const _MobilniRed({required this.red});

  final RedListe red;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sada = ref.watch(sadaProvider).valueOrNull;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Canvas daje 62 px, ali kao **minimum**: na uvećanom sistemskom fontu `11:00` u
        // toj širini ne stane, a odsječeno vrijeme u kalendaru je gore od šireg reda.
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 62),
          child: Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Text(
              vrijemeOse(red.stavka.odMinuta),
              style: AdminText.time.copyWith(
                color: context.adminColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: _SadrzajReda(red: red, sada: sada),
        ),
      ],
    );
  }
}

class _SadrzajReda extends ConsumerWidget {
  const _SadrzajReda({required this.red, required this.sada});

  final RedListe red;
  final DateTime? sada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stavka = red.stavka;

    if (stavka.termin == null) return _PojasRed(red: red);

    final termin = stavka.termin!;
    final usluge = ref.watch(uslugePoIdProvider);
    final radnici = ref.watch(radniciPoIdProvider);
    final uToku = sada != null && terminUToku(termin, sada!);
    final ton = _tonTermina(context, termin.status, uToku: uToku);
    final opis = opisTermina(termin, usluge: usluge, radnici: radnici);
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: oznakaTermina(
        termin,
        status: uToku ? kOznakaUToku : statusOznaka(termin.status),
        usluga: opis.usluga,
        radnik: opis.majstor ?? red.radnik,
      ),
      child: ExcludeSemantics(
        child: Material(
          color: ton.pozadina,
          borderRadius: BorderRadius.circular(AdminRadius.base),
          child: InkWell(
            // `push`, ne `go`: `go` zamijeni cijeli stek, pa „Nazad" iz detalja vodi na
            // `/appointments` umjesto natrag u kalendar (`canPop()` u detalju bude `false`).
            onTap: () => context.push('/appointments/${termin.id}'),
            borderRadius: BorderRadius.circular(AdminRadius.base),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AdminRadius.base),
                border: Border(left: BorderSide(color: ton.rub, width: 3)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    termin.customerName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ton.tekst,
                      fontWeight: FontWeight.w600,
                      decoration: _precrtan(termin.status)
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      // **Status je prvi i uvijek prisutan.** `SPEC.md` („Raspored i
                      // komponente") traži da boja nije jedini nosač značenja, a legenda koja
                      // to objašnjava živi u bočnoj traci — koje na 402 px nema. Bez ove riječi
                      // je telefonski raspored nečitljiv svakome ko ne razlikuje nijanse.
                      uToku ? kOznakaUToku : statusOznaka(termin.status),
                      if (opis.red.isNotEmpty) opis.red,
                      '${stavka.trajanjeMinuta} min',
                      // Ime radnika samo u listi „Svi": u listi jednog radnika bi ga svaki red
                      // ponavljao, a chip iznad ga već kaže.
                      if (red.radnik case final ime? when opis.majstor == null)
                        ime,
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: ton.tekstTih,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pauza ili blokada u mobilnoj listi.
class _PojasRed extends StatelessWidget {
  const _PojasRed({required this.red});

  final RedListe red;

  @override
  Widget build(BuildContext context) {
    final stavka = red.stavka;
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AdminRadius.base),
      child: CustomPaint(
        painter: _Srafura(
          podloga: context.adminColors.ground,
          crta: context.adminColors.separator,
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stavka.tekst ?? 'Blokirano',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.adminColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  '${vrijemeOse(stavka.odMinuta)}–${vrijemeOse(stavka.doMinuta)}',
                  ?red.radnik,
                ].join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.adminColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Traka u dnu `3l`: novi termin i blokada.
class _MobilnaTraka extends StatelessWidget {
  const _MobilnaTraka();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.gutterMobile,
        vertical: AdminSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.adminColors.surface,
        border: Border(
          top: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => context.go(AdminRoute.appointmentNew.path),
                child: const Text('+ Novi termin'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            height: 52,
            child: OutlinedButton(
              onPressed: () => context.go(AdminRoute.calendarBlock.path),
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: const Icon(Icons.block_outlined, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Prazna stanja i greška
// ---------------------------------------------------------------------------

/// Prazan dan — **skrolabilan, iako stane na ekran.**
///
/// `RefreshIndicator` hvata gest samo nad `Scrollable`-om. Sa golim `Center`-om bi
/// pull-to-refresh nestao tačno na danu na kojem vlasnik najviše želi povući da provjeri je
/// li raspored stvarno prazan.
class _PrazanDan extends StatelessWidget {
  const _PrazanDan({required this.dan, this.kolona});

  final KalendarDan dan;
  final KolonaRadnika? kolona;

  @override
  Widget build(BuildContext context) {
    // „Nema termina" i „danas se ne radi" nisu isto: prvo je prazan raspored, drugo je
    // zatvoren salon. Vlasnik po toj razlici odlučuje hoće li nekog zvati.
    final nerada = kolona != null
        ? !kolona!.radi
        : dan.kolone.isNotEmpty && dan.kolone.every((k) => !k.radi);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AdminSpacing.xxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    nerada
                        ? Icons.event_busy_outlined
                        : Icons.event_available_outlined,
                    size: 48,
                    color: context.adminColors.textMuted,
                  ),
                  const SizedBox(height: AdminSpacing.lg),
                  Text(
                    nerada
                        ? 'Ovaj dan se ne radi.'
                        : 'Nema zakazanih termina za ovaj dan.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NemaRadnika extends StatelessWidget {
  const _NemaRadnika();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: context.adminColors.textMuted,
            ),
            const SizedBox(height: AdminSpacing.lg),
            // Kalendar bez radnika nema nijednu kolonu. Poruka vodi tamo gdje se radnik
            // dodaje, umjesto da ostavi prazan ekran bez objašnjenja.
            const Text(
              'Salon još nema nijednog radnika, pa kalendar nema kolone.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AdminSpacing.lg),
            OutlinedButton(
              onPressed: () => context.go(AdminRoute.employees.path),
              child: const Text('Osoblje'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greska extends StatelessWidget {
  const _Greska({required this.onPonovi});

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
            const Text(
              'Kalendar se ne može učitati.',
              textAlign: TextAlign.center,
            ),
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

// ---------------------------------------------------------------------------
// Boje i crtanje
// ---------------------------------------------------------------------------

/// Tri boje jednog bloka.
class _TonBloka {
  const _TonBloka({
    required this.pozadina,
    required this.rub,
    required this.tekst,
    required this.tekstTih,
  });

  final Color pozadina;
  final Color rub;
  final Color tekst;
  final Color tekstTih;
}

/// Boje bloka po statusu — isti parovi koje nosi statusna pilula.
///
/// Ne bira se nova nijansa za kalendar: „potvrđeno" mora biti ista zelena u piluli, u
/// listi i u mreži, inače vlasnik uči dvije legende.
_TonBloka _tonTermina(
  BuildContext context,
  AppointmentStatus status, {
  required bool uToku,
}) {
  final statusi = context.statusColors;
  final boje = context.adminColors;

  // Termin koji upravo traje je pun akcent, kako ga canvas crta — jedini blok koji se vidi
  // preko cijele mreže.
  if (uToku) {
    return _TonBloka(
      pozadina: boje.accent,
      rub: boje.accentInk,
      tekst: boje.onAccent,
      tekstTih: boje.onAccent,
    );
  }

  final ton = statusTon(statusi, status);

  return _TonBloka(
    pozadina: ton.background,
    rub: ton.foreground,
    tekst: ton.foreground,
    tekstTih: ton.foreground,
  );
}

bool _precrtan(AppointmentStatus status) =>
    status == AppointmentStatus.cancelled || status == AppointmentStatus.noShow;

bool _istiDan(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Satne linije unutar kolone. Canvas ih crta `repeating-linear-gradient`-om na 80 px.
class _SatneLinije extends CustomPainter {
  const _SatneLinije({required this.broj, required this.boja});

  final int broj;
  final Color boja;

  @override
  void paint(Canvas canvas, Size size) {
    final olovka = Paint()
      ..color = boja
      ..strokeWidth = AdminSize.hairline;

    for (var i = 1; i < broj; i++) {
      final y = i * kVisinaSata;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), olovka);
    }
  }

  @override
  bool shouldRepaint(_SatneLinije old) => old.broj != broj || old.boja != boja;
}

/// Kosa šrafura pozadinskog pojasa. Canvas: `repeating-linear-gradient(135deg, …)`.
class _Srafura extends CustomPainter {
  const _Srafura({required this.podloga, required this.crta, this.korak = 16});

  final Color podloga;
  final Color crta;

  /// Razmak između crta. Canvas crta par 8/16 px, dakle korak 16 za pauzu i blokadu;
  /// neradno vrijeme ide gušće, da se razlikuje i bez boje.
  final double korak;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = podloga);

    final olovka = Paint()
      ..color = crta
      ..strokeWidth = korak / 2;

    // 135° ide gore-desno; crte se pomjeraju od `-size.height` da pokriju i gornji lijevi
    // ugao, koji bi inače ostao prazan.
    for (var x = -size.height; x < size.width + size.height; x += korak) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        olovka,
      );
    }
  }

  @override
  bool shouldRepaint(_Srafura old) =>
      old.podloga != podloga || old.crta != crta || old.korak != korak;
}
