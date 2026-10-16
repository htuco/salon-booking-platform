part of 'calendar_screen.dart';

// Sedmica na ekranu (task 69, skica `prototype/adminv2/sedmica/`: `7a` 1440, `7c` 1024,
// `7b` 402).
//
// **`part` ekrana, iz istog razloga kao `calendar_week.dart` uz model dana.** Sedmica crta
// iste stvari kao dan: isti ton bloka po statusu, isti isprekidan rub zahtjeva, istu
// šrafuru neradnog, iste satne linije i istu legendu. Kao zaseban library bi ili otvorila
// te privatne widgete kao API koji niko drugi ne smije zvati, ili ih prepisala — a dva
// prepisana tona „potvrđeno" su dvije legende.

/// Razmak bloka od ivice kolone dana. Uži od `_uvlakaBloka` (8): kolona dana je na 1024
/// široka ~108 px, pa svaki piksel uvlake ide od sadržaja bloka.
const double _uvlakaSedmice = 4;

/// Od ove širine **sadržaja** legenda stoji desno od čipova, ispod nje u svom redu (`7a`
/// naspram `7c`). Sadržaj, ne prozor: na 1440 sidebar uzme ~236, pa traka ima ~1200 px.
/// Prvi prag od 1280 je zato legendu slao u drugi red i na 1440 — vidio snimak, ne test.
const double _sirinaLegendeURedu = 1000;

/// Prag širine kolone ispod kojeg podnaslov zaglavlja ide u dva reda (`7c`).
///
/// `09:00–20:00 · 11 termina` traži ~165 px uz padding. Sa 150 je na 1440 (kolona ~161)
/// broj termina išao pod „…", a on je razlog zbog kojeg se u zaglavlje gleda.
const double _sirinaJednogPodnaslova = 180;

/// Statusi u legendi — isti redoslijed kao bočna legenda dana.
const _statusiLegende = [
  AppointmentStatus.confirmed,
  AppointmentStatus.pending,
  AppointmentStatus.completed,
  AppointmentStatus.cancelled,
];

/// Prelaz iz sedmice na jedan dan — tap na zaglavlje dana, na obje širine.
void _otvoriDan(WidgetRef ref, DateTime dan) {
  ref.read(kalendarDatumProvider.notifier).postavi(dan);
  ref.read(kalendarPrikazProvider.notifier).postavi(KalendarPrikaz.dan);
}

/// `18. – 24. maj 2026`, ili `28. sep – 4. okt 2026` preko granice mjeseca.
String naslovSedmice(DateTime ponedjeljak) {
  final nedjelja = DateTime(
    ponedjeljak.year,
    ponedjeljak.month,
    ponedjeljak.day + 6,
  );
  if (ponedjeljak.month == nedjelja.month) {
    return '${ponedjeljak.day}. – ${nedjelja.day}. '
        '${kMjeseci[nedjelja.month - 1]} ${nedjelja.year}';
  }
  String kratko(DateTime d) => kMjeseci[d.month - 1].substring(0, 3);
  return '${ponedjeljak.day}. ${kratko(ponedjeljak)} – '
      '${nedjelja.day}. ${kratko(nedjelja)} ${nedjelja.year}';
}

/// Početak ručnog termina za dodir na [y] piksela od vrha ose — zaokružen **dolje** na
/// 30 minuta, kako skica traži. Dolje, a ne na najbliže: dodir u gornju polovinu sata
/// 10:00–11:00 je dodir „u deset", ne „u pola jedanaest".
///
/// Unutar ose, sa mjestom za bar pola sata do njenog kraja.
int pocetakZaDodir(KalendarOsa osa, double y) {
  final minuta = osa.pocetakMinuta + (y / kVisinaSata * 60).floor();
  final zaokruzeno = (minuta ~/ 30) * 30;
  return zaokruzeno.clamp(osa.pocetakMinuta, osa.krajMinuta - 30);
}

/// Avatar radnika: profilna slika, a bez nje inicijali na boji radnika (odluka 2026-10-16).
///
/// Bez semantike: blok, čip i red već kažu ime radnika riječima, a „Profilna slika"
/// pročitana uz svaki termin je šum.
class _AvatarRadnika extends StatelessWidget {
  const _AvatarRadnika({
    required this.radnik,
    required this.boja,
    required this.velicina,
    this.prigusen = false,
  });

  /// `null` za termin bez radnika ili obrisanog radnika — tada prazan neutralan krug.
  final Employee? radnik;

  /// Indeks iz `KalendarSedmica.boje`.
  final int? boja;
  final double velicina;

  /// Odsutan radnik u zaglavlju dana — prigušen, kako ga skica crta.
  final bool prigusen;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final indeks = boja;
    final avatar = ProfilAvatar(
      url: radnik?.imageUrl,
      ime: radnik?.name ?? '',
      velicina: velicina,
      boja: indeks == null ? null : boje.bojaRadnika(indeks),
      bojaInicijala: indeks == null ? null : boje.onRadnik,
    );

    return ExcludeSemantics(
      child: prigusen ? Opacity(opacity: 0.5, child: avatar) : avatar,
    );
  }
}

/// Legenda u jednom redu — sedmica nema bočnu traku, pa legenda ide uz čipove (`7a`).
class _LegendaSedmice extends StatelessWidget {
  const _LegendaSedmice();

  @override
  Widget build(BuildContext context) {
    final statusi = context.statusColors;

    return Wrap(
      spacing: AdminSpacing.lg,
      children: [
        for (final status in _statusiLegende)
          _RedLegende(
            ton: statusTon(statusi, status),
            tekst: statusOznaka(status),
            isprekidan: status == AppointmentStatus.pending,
          ),
        _RedLegende(
          ton: AdminStatusTone(
            background: context.adminColors.accent,
            foreground: context.adminColors.onAccent,
          ),
          tekst: kOznakaUToku,
        ),
      ],
    );
  }
}

/// Čipovi `Svi · Emir · …` sa avatarom — filter sedmice na obje širine.
///
/// Radniku se ne crtaju (vidi samo svoje), ni salonu sa jednim radnikom — „Svi" i „Emir"
/// bi bila ista sedmica.
class _CipoviSedmice extends ConsumerWidget {
  const _CipoviSedmice({required this.sedmica, required this.padding});

  final KalendarSedmica sedmica;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(adminRadnikIdProvider) != null ||
        sedmica.radnici.length < 2) {
      return const SizedBox.shrink();
    }
    final izabran = ref.watch(izabraniRadnikProvider);
    final notifier = ref.read(izabraniRadnikProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          _ChipRadnika(
            tekst: 'Svi',
            izabran: izabran == null,
            onTap: () => notifier.postavi(null),
          ),
          for (final r in sedmica.radnici)
            _ChipRadnika(
              tekst: r.name,
              izabran: izabran == r.id,
              onTap: () => notifier.postavi(r.id),
              avatar: _AvatarRadnika(
                radnik: r,
                boja: sedmica.boje[r.id],
                velicina: 22,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop i tablet `7a` / `7c`
// ---------------------------------------------------------------------------

class _DesktopSedmica extends ConsumerWidget {
  const _DesktopSedmica();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sedmica = ref.watch(kalendarSedmicaProvider);

    return Column(
      children: [
        const _ZaglavljeSedmice(),
        _TrakaSedmice(sedmica: sedmica.valueOrNull),
        Expanded(
          child: ColoredBox(
            color: context.adminColors.surface,
            child: sedmica.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AdminSpacing.xxl),
                child: AdminSkeletonList(),
              ),
              error: (_, _) => _Greska(onPonovi: () => osvjeziKalendar(ref)),
              data: (sedmica) => _MrezaSedmice(sedmica: sedmica),
            ),
          ),
        ),
      ],
    );
  }
}

/// `‹ › 18. – 24. maj 2026 · Ova sedmica` — isto mjesto i iste strelice kao naslov dana.
class _ZaglavljeSedmice extends ConsumerWidget {
  const _ZaglavljeSedmice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ponedjeljak = pocetakSedmice(ref.watch(kalendarDatumProvider));
    final sada = ref.watch(sadaProvider).valueOrNull ?? DateTime.now();
    final notifier = ref.read(kalendarDatumProvider.notifier);

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
            opis: 'Prethodna sedmica',
            onTap: () => notifier.pomjeri(-7),
          ),
          const SizedBox(width: AdminSpacing.sm),
          _StrelicaDana(
            ikona: Icons.chevron_right,
            opis: 'Sljedeća sedmica',
            onTap: () => notifier.pomjeri(7),
          ),
          const SizedBox(width: AdminSpacing.md),
          Flexible(
            child: Text(
              naslovSedmice(ponedjeljak),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          // Kao „Danas" u danu: nestaje kad se već gleda tekuća sedmica.
          if (pocetakSedmice(sada) != ponedjeljak)
            TextButton(
              onPressed: notifier.danas,
              child: const Text('Ova sedmica'),
            ),
        ],
      ),
    );
  }
}

/// Čipovi i legenda — u jednom redu na širokom ekranu, u dva na tabletu (`7c`).
class _TrakaSedmice extends StatelessWidget {
  const _TrakaSedmice({required this.sedmica});

  /// `null` dok se sedmica učitava — legenda se vidi odmah, čipovi tek sa radnicima.
  final KalendarSedmica? sedmica;

  @override
  Widget build(BuildContext context) {
    final sedmica = this.sedmica;
    final cipovi = sedmica == null
        ? const SizedBox.shrink()
        : _CipoviSedmice(sedmica: sedmica, padding: EdgeInsets.zero);

    return Container(
      // Puna širina: `Column` iznad centrira uže dijete, pa je traka stajala kao ostrvo
      // na podlozi, sa rubom samo ispod sebe.
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.gutterDesktop,
        vertical: AdminSpacing.sm,
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
      child: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth >= _sirinaLegendeURedu
            ? Row(
                children: [
                  Expanded(child: cipovi),
                  const SizedBox(width: AdminSpacing.lg),
                  const _LegendaSedmice(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cipovi,
                  const SizedBox(height: AdminSpacing.xs),
                  const _LegendaSedmice(),
                ],
              ),
      ),
    );
  }
}

/// Sedam kolona nad jednom osom. **Bez vodoravnog skrola** (`7c`): kolona se sužava, a
/// blok bira sadržaj po širini — v. [_BlokSedmice].
class _MrezaSedmice extends StatelessWidget {
  const _MrezaSedmice({required this.sedmica});

  final KalendarSedmica sedmica;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sirinaKolone = (constraints.maxWidth - _sirinaOse) / 7;

        return Column(
          children: [
            _ZaglavljaSedmice(sedmica: sedmica, sirinaKolone: sirinaKolone),
            Expanded(
              child: SingleChildScrollView(
                child: _OsaSedmice(
                  sedmica: sedmica,
                  sirinaKolone: sirinaKolone,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ZaglavljaSedmice extends ConsumerWidget {
  const _ZaglavljaSedmice({required this.sedmica, required this.sirinaKolone});

  final KalendarSedmica sedmica;
  final double sirinaKolone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sada = ref.watch(sadaProvider).valueOrNull;
    final danas = sada == null ? null : sedmica.indeksDana(sada);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      // Sva zaglavlja iste visine: dan sa redom odsutnih je viši, a rub kolone mora ići
      // do dna reda i kod susjeda bez njega.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: _sirinaOse),
            for (var i = 0; i < sedmica.dani.length; i++)
              SizedBox(
                width: sirinaKolone,
                child: _ZaglavljeDanaSedmice(
                  dan: sedmica.dani[i],
                  boje: sedmica.boje,
                  danas: i == danas,
                  dvaReda: sirinaKolone < _sirinaJednogPodnaslova,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `PON 18 · 09:00–20:00 · 9 termina`, pa red odsutnih. Tap otvara taj dan.
class _ZaglavljeDanaSedmice extends ConsumerWidget {
  const _ZaglavljeDanaSedmice({
    required this.dan,
    required this.boje,
    required this.danas,
    required this.dvaReda,
  });

  final DanSedmice dan;
  final Map<String, int> boje;
  final bool danas;

  /// Tablet: smjena i broj termina u dva reda, jer `09:00–20:00 · 9 termina` u ~100 px
  /// ne stane, a broj termina bi se odsjekao prvi.
  final bool dvaReda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paleta = context.adminColors;
    final tekst = Theme.of(context).textTheme;
    // `podnaslov` je `smjena · N termina` ili `Ne radi` — isti tekst kao kolona dana, pa
    // se dijeli, a ne slaže iznova.
    final podnaslov = dvaReda ? dan.podnaslov.split(' · ') : [dan.podnaslov];
    final tih = dan.radi ? null : paleta.textMuted;

    return Semantics(
      button: true,
      label: [
        datumDugo(dan.dan),
        dan.podnaslov,
        for (final o in dan.odsutni) o.tekst,
        'otvori dan',
      ].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => _otvoriDan(ref, dan.dan),
          child: Container(
            // Na tabletu uži: `09:00–20:00` u koloni od ~100 px staje tek sa 8 + 4.
            padding: dvaReda
                ? const EdgeInsets.fromLTRB(8, 10, 4, 10)
                : const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: paleta.separator,
                  width: AdminSize.hairline,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kratkiDan(dan.dan),
                  style: AdminText.eyebrow.copyWith(
                    color: paleta.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                // Danas je broj na punom akcentu, kako ga skica crta.
                Container(
                  padding: danas
                      ? const EdgeInsets.symmetric(horizontal: 5)
                      : EdgeInsets.zero,
                  color: danas ? paleta.accent : null,
                  child: Text(
                    '${dan.dan.day}',
                    style: AdminText.timeLarge.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: danas ? paleta.onAccent : (tih ?? paleta.ink),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                for (final red in podnaslov)
                  Text(
                    red,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tekst.bodySmall?.copyWith(color: tih),
                  ),
                for (final o in dan.odsutni)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Tooltip(
                      message: o.tekst,
                      child: Row(
                        children: [
                          _AvatarRadnika(
                            radnik: o.radnik,
                            boja: boje[o.radnik.id],
                            velicina: 14,
                            prigusen: true,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              o.tekst,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tekst.bodySmall?.copyWith(
                                color: paleta.textSecondary,
                              ),
                            ),
                          ),
                        ],
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

/// Osa sati i sedam kolona, sa linijom „sada" samo u današnjoj.
class _OsaSedmice extends ConsumerWidget {
  const _OsaSedmice({required this.sedmica, required this.sirinaKolone});

  final KalendarSedmica sedmica;
  final double sirinaKolone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sada = ref.watch(sadaProvider).valueOrNull;
    final danas = sada == null ? null : sedmica.indeksDana(sada);
    final yLinije = sada == null ? null : sedmica.yLinijeSada(sada);
    // Ručno zakazivanje traži `is_admin` u bazi — radniku prazno mjesto ne nudi ništa.
    final mozeZakazati = ref.watch(adminRadnikIdProvider) == null;

    return SizedBox(
      height: sedmica.osa.visina,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _sirinaOse,
                child: _SatiOse(osa: sedmica.osa),
              ),
              for (final dan in sedmica.dani)
                SizedBox(
                  width: sirinaKolone,
                  child: _KolonaSedmice(
                    dan: dan,
                    sedmica: sedmica,
                    sada: sada,
                    sirina: sirinaKolone,
                    mozeZakazati: mozeZakazati,
                  ),
                ),
            ],
          ),
          if (yLinije != null && danas != null)
            Positioned(
              top: yLinije - 1,
              left: _sirinaOse + sirinaKolone * danas,
              width: sirinaKolone,
              height: 2,
              child: IgnorePointer(
                child: ColoredBox(color: context.adminColors.destructive),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kolona jednog dana: satne linije, prazno mjesto za novi termin, pojasevi, pa termini.
class _KolonaSedmice extends StatelessWidget {
  const _KolonaSedmice({
    required this.dan,
    required this.sedmica,
    required this.sada,
    required this.sirina,
    required this.mozeZakazati,
  });

  final DanSedmice dan;
  final KalendarSedmica sedmica;
  final DateTime? sada;

  /// Odozgo, ne iz `LayoutBuilder`-a — isti razlog kao `_Kolona.sirina`.
  final double sirina;
  final bool mozeZakazati;

  @override
  Widget build(BuildContext context) {
    final osa = sedmica.osa;
    final kolona = dan.kolona;

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
          Positioned.fill(
            child: CustomPaint(
              painter: _SatneLinije(
                broj: osa.sati.length,
                boja: context.adminColors.separator,
              ),
            ),
          ),
          // Ispod pojaseva i termina: dodir u šrafuru „Ne radi" ne nudi termin, a dodir
          // u blok otvara taj termin.
          if (mozeZakazati)
            Positioned.fill(
              child: _PraznoMjesto(dan: dan.dan, osa: osa),
            ),
          for (final stavka in kolona.pozadina)
            Positioned(
              top: osa.yZa(stavka.odMinuta),
              left: _uvlakaSedmice,
              right: _uvlakaSedmice,
              height: osa.visinaZa(stavka.odMinuta, stavka.doMinuta),
              child: _Pojas(stavka: stavka),
            ),
          for (final stavka in kolona.termini)
            Positioned(
              top: osa.yZa(stavka.odMinuta),
              left: _uvlakaSedmice + _sirinaTrake(stavka) * stavka.traka,
              width: _sirinaTrake(stavka),
              height: osa.visinaZa(stavka.odMinuta, stavka.doMinuta) - 2,
              child: _BlokSedmice(
                stavka: stavka,
                sedmica: sedmica,
                sada: sada,
                sirina: _sirinaTrake(stavka),
                visina: osa.visinaZa(stavka.odMinuta, stavka.doMinuta) - 2,
              ),
            ),
        ],
      ),
    );
  }

  double _sirinaTrake(StavkaKalendara stavka) =>
      (sirina - 2 * _uvlakaSedmice) / stavka.brojTraka;
}

/// Prazno mjesto u koloni — dodir otvara ručno zakazivanje za taj dan i vrijeme.
///
/// **Bez semantike, i to je namjerno.** Čitač ekrana bi dobio jedno dugme preko cijele
/// kolone, čije bi vrijeme zavisilo od mjesta dodira koje on ne bira. `+ Novi termin` u
/// top baru radi isti posao i ima labelu.
class _PraznoMjesto extends StatelessWidget {
  const _PraznoMjesto({required this.dan, required this.osa});

  final DateTime dan;
  final KalendarOsa osa;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (detalji) => context.push(
            Uri(
              path: AdminRoute.appointmentNew.path,
              queryParameters: {
                'date': _iso(dan),
                'time': vrijemeOse(
                  pocetakZaDodir(osa, detalji.localPosition.dy),
                ),
              },
            ).toString(),
          ),
        ),
      ),
    );
  }
}

/// Termin u koloni dana: avatar, vrijeme, ime — onoliko koliko širina pusti.
///
/// **Sadržaj bira širina bloka, ne broj traka** (skica, Pravila): ista dva termina u
/// preklapanju su na 1440 široka ~75 px, a na 1024 ~45, pa pravilo po broju traka ne bi
/// važilo na obje širine. Ime je uvijek u tooltipu i u detalju.
class _BlokSedmice extends ConsumerWidget {
  const _BlokSedmice({
    required this.stavka,
    required this.sedmica,
    required this.sada,
    required this.sirina,
    required this.visina,
  });

  final StavkaKalendara stavka;
  final KalendarSedmica sedmica;
  final DateTime? sada;
  final double sirina;
  final double visina;

  /// ≥ 70 px: avatar + vrijeme + ime.
  static const double _zaIme = 70;

  /// ≥ 40 px: avatar + vrijeme. Ispod: samo avatar.
  static const double _zaVrijeme = 40;

  /// Ispod ove visine sve staje u jedan red (termin kraći od ~30 min).
  static const double _zaDvaReda = 40;

  static const double _avatar = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skala = MediaQuery.textScalerOf(context).scale(1);
    final termin = stavka.termin!;
    final uToku = sada != null && terminUToku(termin, sada!);
    final ton = _tonTermina(context, termin.status, uToku: uToku);
    final oznaka = uToku ? kOznakaUToku : statusOznakaTermina(termin);
    final radnik = ref.watch(radniciPoIdProvider)[termin.employeeId];
    final avatar = _AvatarRadnika(
      radnik: radnik,
      boja: sedmica.boje[termin.employeeId],
      velicina: _avatar,
    );
    final vrijeme = Text(
      vrijemeOse(stavka.odMinuta),
      maxLines: 1,
      overflow: TextOverflow.clip,
      softWrap: false,
      style: AdminText.dataInline.copyWith(color: ton.tekst),
    );
    final ime = Text(
      termin.customerName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: ton.tekst,
        fontWeight: FontWeight.w600,
        decoration: _precrtan(termin.status)
            ? TextDecoration.lineThrough
            : null,
      ),
    );
    final jedanRed = visina < _zaDvaReda * skala;

    final Widget sadrzaj;
    if (sirina < _zaVrijeme) {
      sadrzaj = Align(alignment: Alignment.topLeft, child: avatar);
    } else if (sirina < _zaIme) {
      sadrzaj = jedanRed
          ? Row(
              children: [
                avatar,
                const SizedBox(width: 3),
                Flexible(child: vrijeme),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(height: 2),
                Flexible(child: vrijeme),
              ],
            );
    } else {
      final glava = Row(
        children: [
          avatar,
          const SizedBox(width: 4),
          vrijeme,
          if (jedanRed) ...[const SizedBox(width: 5), Expanded(child: ime)],
        ],
      );
      sadrzaj = jedanRed
          ? glava
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                glava,
                const SizedBox(height: 2),
                Flexible(child: ime),
              ],
            );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Tooltip(
        message: '${termin.customerName} · $oznaka',
        excludeFromSemantics: true,
        waitDuration: const Duration(milliseconds: 400),
        child: Semantics(
          button: true,
          label: oznakaTermina(
            termin,
            status: oznaka,
            usluga: ref.watch(uslugePoIdProvider)[termin.serviceId]?.name,
            radnik: radnik?.name,
          ),
          child: ExcludeSemantics(
            child: RubZahtjeva(
              ceka: _cekaPotvrdu(termin.status, uToku: uToku),
              boja: ton.rub,
              child: Material(
                color: ton.pozadina,
                borderRadius: BorderRadius.circular(AdminRadius.base),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: () => otvoriDetaljTermina(context, termin.id),
                  borderRadius: BorderRadius.circular(AdminRadius.base),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AdminRadius.base),
                      border: Border(
                        left: BorderSide(color: ton.rub, width: 3),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      sirina < _zaVrijeme ? 2 : 5,
                      jedanRed ? 2 : 4,
                      2,
                      2,
                    ),
                    child: sadrzaj,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Telefon `7b`
// ---------------------------------------------------------------------------

/// Sedmica na telefonu — **lista po danima**, ne stisnuta mreža (`SPEC.md`).
class _TelefonSedmica extends ConsumerWidget {
  const _TelefonSedmica();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sedmica = ref.watch(kalendarSedmicaProvider);

    return Column(
      children: [
        const _MobilnoZaglavlje(),
        if (sedmica.valueOrNull case final ucitana?)
          Padding(
            padding: const EdgeInsets.only(top: AdminSpacing.md),
            child: _CipoviSedmice(
              sedmica: ucitana,
              padding: const EdgeInsets.symmetric(
                horizontal: AdminSpacing.gutterMobile,
              ),
            ),
          ),
        Expanded(
          child: sedmica.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AdminSpacing.xxl),
              child: AdminSkeletonList(),
            ),
            error: (_, _) => _Greska(onPonovi: () => osvjeziKalendar(ref)),
            // `await` na `future` — v. isti komentar u `_Telefon`.
            data: (sedmica) => AdminRefresh(
              onRefresh: () async {
                osvjeziKalendar(ref);
                await ref.read(kalendarSedmicaProvider.future);
              },
              child: _ListaSedmice(sedmica: sedmica),
            ),
          ),
        ),
      ],
    );
  }
}

class _ListaSedmice extends ConsumerWidget {
  const _ListaSedmice({required this.sedmica});

  final KalendarSedmica sedmica;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dani = redoviSedmice(sedmica);
    if (dani.every((d) => d.$2.isEmpty)) return const _PraznaSedmica();

    final sada = ref.watch(sadaProvider).valueOrNull;
    final danas = sada == null ? null : sedmica.indeksDana(sada);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.gutterMobile,
        AdminSpacing.sm,
        AdminSpacing.gutterMobile,
        AdminSpacing.xl,
      ),
      children: [
        for (var i = 0; i < dani.length; i++)
          _SekcijaDana(
            dan: dani[i].$1,
            redovi: dani[i].$2,
            boje: sedmica.boje,
            danas: i == danas,
            prva: i == 0,
          ),
      ],
    );
  }
}

/// Jedan dan liste: zaglavlje (tap otvara dan), odsutni, pa termini i blokade po vremenu.
/// Neradni dan je samo zaglavlje sa „Ne radi".
class _SekcijaDana extends ConsumerWidget {
  const _SekcijaDana({
    required this.dan,
    required this.redovi,
    required this.boje,
    required this.danas,
    required this.prva,
  });

  final DanSedmice dan;
  final List<StavkaKalendara> redovi;
  final Map<String, int> boje;
  final bool danas;
  final bool prva;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paleta = context.adminColors;
    final tekst = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.only(top: prva ? 0 : AdminSpacing.md),
      decoration: prva
          ? null
          : BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: paleta.separator,
                  width: AdminSize.hairline,
                ),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: '${datumDugo(dan.dan)}, ${dan.podnaslov}, otvori dan',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: () => _otvoriDan(ref, dan.dan),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AdminSize.touchTarget,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_kratkiDan(dan.dan)} ${dan.dan.day}.',
                        style: tekst.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: danas ? paleta.accentInk : null,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dan.radi ? terminaTekst(dan.brojTermina) : 'Ne radi',
                        style: tekst.bodySmall?.copyWith(
                          color: paleta.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          for (final o in dan.odsutni)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  _AvatarRadnika(
                    radnik: o.radnik,
                    boja: boje[o.radnik.id],
                    velicina: 16,
                    prigusen: true,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      o.tekst,
                      style: tekst.bodySmall?.copyWith(
                        color: paleta.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final stavka in redovi)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: stavka.termin == null
                  ? _PojasSedmice(stavka: stavka)
                  : _RedTerminaSedmice(stavka: stavka, boje: boje),
            ),
        ],
      ),
    );
  }
}

/// Termin u listi: vrijeme lijevo, kartica sa imenom i rasponom, avatar radnika desno.
class _RedTerminaSedmice extends ConsumerWidget {
  const _RedTerminaSedmice({required this.stavka, required this.boje});

  final StavkaKalendara stavka;
  final Map<String, int> boje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sada = ref.watch(sadaProvider).valueOrNull;
    final termin = stavka.termin!;
    final uToku = sada != null && terminUToku(termin, sada);
    final ton = _tonTermina(context, termin.status, uToku: uToku);
    final radnik = ref.watch(radniciPoIdProvider)[termin.employeeId];
    final theme = Theme.of(context);
    final raspon =
        '${vrijemeOse(stavka.odMinuta)}–${vrijemeOse(stavka.doMinuta)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Minimum, ne fiksna širina — v. `_MobilniRed`.
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 62),
          child: Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Text(
              vrijemeOse(stavka.odMinuta),
              style: AdminText.time.copyWith(
                color: context.adminColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Semantics(
            button: true,
            label: oznakaTermina(
              termin,
              status: uToku ? kOznakaUToku : statusOznakaTermina(termin),
              usluga: ref.watch(uslugePoIdProvider)[termin.serviceId]?.name,
              radnik: radnik?.name,
            ),
            child: ExcludeSemantics(
              child: RubZahtjeva(
                ceka: _cekaPotvrdu(termin.status, uToku: uToku),
                boja: ton.rub,
                child: Material(
                  color: ton.pozadina,
                  borderRadius: BorderRadius.circular(AdminRadius.base),
                  child: InkWell(
                    onTap: () => otvoriDetaljTermina(context, termin.id),
                    borderRadius: BorderRadius.circular(AdminRadius.base),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AdminRadius.base),
                        border: Border(
                          left: BorderSide(color: ton.rub, width: 3),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
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
                                Text(
                                  raspon,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: ton.tekstTih,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AvatarRadnika(
                            radnik: radnik,
                            boja: boje[termin.employeeId],
                            velicina: 24,
                          ),
                        ],
                      ),
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

/// Pauza ili blokada u listi — jedan red teksta, kako ga `7b` piše
/// („12:00–13:00 · Salon zatvoren · sastanak").
class _PojasSedmice extends StatelessWidget {
  const _PojasSedmice({required this.stavka});

  final StavkaKalendara stavka;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${vrijemeOse(stavka.odMinuta)}–${vrijemeOse(stavka.doMinuta)} · '
      '${stavka.tekst ?? 'Blokirano'}',
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: context.adminColors.textSecondary),
    );
  }
}

class _PraznaSedmica extends StatelessWidget {
  const _PraznaSedmica();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        // Pull-to-refresh mora raditi i na praznoj sedmici.
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
                    Icons.event_available_outlined,
                    size: 48,
                    color: context.adminColors.textMuted,
                  ),
                  const SizedBox(height: AdminSpacing.lg),
                  Text(
                    'Nema termina ove sedmice.',
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
