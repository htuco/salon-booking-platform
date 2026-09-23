/// Radno vrijeme, pauze i neradni dani — `3h` na desktopu, `3s` na telefonu.
///
/// ## Sedmica je jedan podatak, ne sedam
///
/// Ekran drži cijelu sedmicu u lokalnom stanju i šalje je **u cjelini** na „Sačuvaj
/// izmjene". To nije izbor izgleda nego posljedica toga kako je baza čita:
/// `get_available_slots` tretira **odsustvo reda kao zatvoreno**, a ne kao „nije
/// podešeno". Slanje samo izmijenjenih dana bi tiho zatvorilo ostale. Pauze (`3h` ih crta
/// kao zasebnu karticu) su kolone istih redova, pa idu istim snimanjem.
///
/// ## Availability ostaje na backendu
///
/// Ovaj ekran mijenja **ulaz** u `get_available_slots`, nikad njegova pravila. Ovdje se
/// ne računa nijedan slobodan termin; jedino što ekran provjerava sam (`_provjeri`) je
/// staje li pauza u smjenu i je li kraj poslije početka, i to samo da greška stigne kao
/// rečenica uz dan koji je kriv umjesto kao sirovi `PT400`. Baza istu provjeru ponavlja i
/// ostaje jedina koja obavezuje (`docs/01 §8.1`).
///
/// ## Termin se ne briše tiho
///
/// Prije snimanja se zove `working_hours_conflicts` i, ako nešto ispada van novog
/// vremena, vlasnik to **vidi i potvrđuje**. Aplikacija ne pomjera i ne otkazuje tuđe
/// termine umjesto njega.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/datum.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/admin_verzal.dart';
import 'working_hours_dialogs.dart';
import 'working_hours_providers.dart';
import 'working_hours_sekcije.dart';

export 'working_hours_sekcije.dart' show naslovBlokade;

const _podnaslov =
    'Aplikacija nudi termine samo unutar ovog vremena, umanjeno za pauze.';

/// Stanje sedmice živi **ovdje**, iznad ljuske, a ne u tijelu.
///
/// `3h` crta „Sačuvaj izmjene" u top baru, koji crta [AdminScaffold] — dugme mora znati
/// za izmjene, a ljuska prima `actions` prije tijela. Stanje u tijelu bi značilo dugme
/// koje ne zna šta snima.
class AdminWorkingHoursScreen extends ConsumerStatefulWidget {
  const AdminWorkingHoursScreen({super.key});

  @override
  ConsumerState<AdminWorkingHoursScreen> createState() =>
      _AdminWorkingHoursScreenState();
}

class _AdminWorkingHoursScreenState
    extends ConsumerState<AdminWorkingHoursScreen> {
  List<WorkingHour>? _izvor;
  List<WorkingHoursInput> _pocetna = const [];
  List<WorkingHoursInput> _dani = const [];
  bool _snimam = false;
  String? _greska;

  /// Svježa sedmica iz baze preuzima lokalno stanje — **samo kad stigne novi odgovor**.
  ///
  /// Poredi se identitet liste iz providera, ne sadržaj: poslije uspješnog upisa baza vrati
  /// upravo ono što je poslano, pa bi poređenje sadržaja propustilo trenutak u kojem lokalne
  /// izmjene postaju zapisano stanje, i „Sačuvaj izmjene" bi ostalo aktivno. A rebuild bez
  /// novog odgovora (promjena širine prozora) ne smije baciti nesnimljene izmjene.
  void _preuzmi(List<WorkingHour> sve) {
    if (identical(sve, _izvor)) return;
    _izvor = sve;
    _pocetna = weekFromWorkingHours(sve);
    _dani = List.of(_pocetna);
  }

  /// `listEquals`, ne petlja po indeksu: dužine su danas uvijek sedam, ali poređenje
  /// koje to pretpostavlja postaje `RangeError` čim se pojavi raspored po radniku.
  bool get _izmijenjeno => _izvor != null && !listEquals(_dani, _pocetna);

  void _zamijeni(int index, WorkingHoursInput dan) =>
      setState(() => _dani[index] = dan);

  /// Pauza je kolona dana: dani iz nove grupe dobijaju vrijeme, dani koji su ispali iz
  /// stare ga gube.
  void _primijeniPauzu(Set<int> stariDani, IzmjenaPauze izmjena) {
    setState(() {
      for (var i = 0; i < _dani.length; i++) {
        final dan = _dani[i];
        final uNovoj = !izmjena.ukloni && izmjena.dani.contains(dan.dayOfWeek);
        if (uNovoj) {
          _dani[i] = dan.copyWith(
            breakStartTime: izmjena.od,
            breakEndTime: izmjena.do_,
          );
        } else if (stariDani.contains(dan.dayOfWeek)) {
          _dani[i] = dan.copyWith(clearBreak: true);
        }
      }
    });
  }

  Future<void> _urediDan(int index) async {
    final dan = _dani[index];
    final izbor = await prikaziUrediDan(
      context,
      ime: kDaniSedmice[dan.dayOfWeek - 1],
      od: dan.startTime,
      do_: dan.endTime,
    );
    if (izbor == null || !mounted) return;
    _zamijeni(index, dan.copyWith(startTime: izbor.$1, endTime: izbor.$2));
  }

  /// Ono malo što ekran smije izračunati sam: staje li pauza u smjenu.
  ///
  /// Ovo **nije** availability logika — to ostaje u bazi. Ovdje je samo da greška stigne
  /// kao rečenica uz dan koji je kriv, umjesto kao sirovi `PT400` iz backenda. Baza istu
  /// provjeru ponavlja i ostaje jedina koja obavezuje.
  String? _provjeri() {
    for (final dan in _dani) {
      if (dan.isClosed) continue;
      final ime = kDaniSedmice[dan.dayOfWeek - 1];
      if (dan.endTime <= dan.startTime) {
        return '$ime: kraj radnog vremena mora biti poslije početka.';
      }
      if (dan.hasBreak &&
          (dan.breakStartTime! < dan.startTime ||
              dan.breakEndTime! > dan.endTime ||
              dan.breakEndTime! <= dan.breakStartTime!)) {
        return '$ime: pauza mora biti unutar radnog vremena.';
      }
    }
    return null;
  }

  /// Greška ide i u `_greska` i u snackbar — dugme za snimanje je u top baru ili na dnu,
  /// daleko od poruke iznad sedmice.
  void _prijaviGresku(String poruka) {
    setState(() {
      _snimam = false;
      _greska = poruka;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(poruka)));
  }

  /// Snima tek kad vlasnik vidi šta ispada van novog vremena.
  ///
  /// Redoslijed je namjeran: prvo pitanje bazi šta bi ispalo, pa dijalog, pa upis. Obrnut
  /// redoslijed bi značio da vlasnik saznaje za posljedicu kad je već nastala.
  Future<void> _sacuvaj() async {
    final problem = _provjeri();
    if (problem != null) {
      _prijaviGresku(problem);
      return;
    }
    setState(() {
      _snimam = true;
      _greska = null;
    });
    final actions = ref.read(workingHoursActionsProvider);
    try {
      final konflikti = await actions.konflikti(_dani);
      if (!mounted) return;
      if (konflikti.isNotEmpty) {
        final nastavi = await prikaziKonflikte(context, konflikti);
        if (!mounted) return;
        if (nastavi != true) {
          setState(() => _snimam = false);
          return;
        }
      }
      await actions.sacuvaj(_dani);
      if (!mounted) return;
      setState(() => _snimam = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radno vrijeme je sačuvano.')),
      );
    } on ApiError catch (error) {
      if (!mounted) return;
      _prijaviGresku(error.message);
    } catch (_) {
      if (!mounted) return;
      _prijaviGresku('Radno vrijeme se ne može sačuvati.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = AdminShell.jeDesktop(context);
    final raspored = ref.watch(radnoVrijemeProvider);
    final sve = raspored.valueOrNull;
    if (sve != null) _preuzmi(sve);
    final onSacuvaj = _izmijenjeno && !_snimam ? _sacuvaj : null;

    final sadrzaj = raspored.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AdminSpacing.xxl),
        child: AdminSkeletonList(),
      ),
      error: (error, _) =>
          _Greska(onRetry: () => ref.invalidate(radnoVrijemeProvider)),
      data: (sve) => _sadrzaj(context, desktop, sve),
    );

    return AdminScaffold(
      title: 'Radno vrijeme',
      aktivna: AdminRoute.workingHours,
      // `3s` crta svoje zaglavlje („‹ Još", veliki naslov); desktop top bar ostaje ljusci.
      sopstvenoZaglavlje: true,
      podstranica: true,
      actions: desktop
          ? [
              SizedBox(
                height: 42,
                child: _DugmeSacuvaj(onPressed: onSacuvaj, snimam: _snimam),
              ),
            ]
          : null,
      body: desktop
          ? sadrzaj
          : Column(
              children: [
                const _ZaglavljeTelefona(),
                Expanded(child: sadrzaj),
                if (sve != null)
                  _TrakaSacuvaj(onPressed: onSacuvaj, snimam: _snimam),
              ],
            ),
    );
  }

  Widget _sadrzaj(BuildContext context, bool desktop, List<WorkingHour> sve) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // `bandZa` nad stvarnom širinom radne površine, ne prozora: sidebar uzima 236.
        final dvijeKolone =
            desktop && !AdminShell.bandZa(constraints.maxWidth).jeCompact;

        final lijevo = <Widget>[
          if (desktop) ...[
            Text('Kad je salon otvoren', style: AdminText.display),
            const SizedBox(height: 6),
          ],
          Text(
            _podnaslov,
            style: tema.bodyLarge?.copyWith(
              color: desktop ? boje.ink : boje.textSecondary,
            ),
          ),
          SizedBox(height: desktop ? AdminSpacing.xl : AdminSpacing.lg),
          if (_greska != null) ...[
            _Poruka(tekst: _greska!),
            const SizedBox(height: AdminSpacing.md),
          ],
          _Sedmica(
            dani: _dani,
            desktop: desktop,
            onChanged: _zamijeni,
            onUrediDan: _urediDan,
          ),
        ];

        final razmakSekcija = desktop ? AdminSpacing.xl : AdminSpacing.xxl;
        final desno = <Widget>[
          RadnoVrijemePauze(
            sedmica: _dani,
            sve: sve,
            naslovUKartici: desktop,
            onIzmjena: _primijeniPauzu,
          ),
          SizedBox(height: razmakSekcija),
          RadnoVrijemeNeradniDani(naslovUKartici: desktop),
          SizedBox(height: razmakSekcija),
          RadnoVrijemePravila(naslovUKartici: desktop),
        ];

        final tijelo = dvijeKolone
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 614 : 512 — odnos kolona izmjeren iz `3h` na 1440.
                  Expanded(
                    flex: 614,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: lijevo,
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.xl),
                  Expanded(
                    flex: 512,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: desno,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...lijevo,
                  const SizedBox(height: AdminSpacing.xxl),
                  ...desno,
                ],
              );

        final gutter = desktop
            ? AdminSpacing.gutterDesktop
            : AdminSpacing.gutterMobile;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(gutter),
          children: [
            // Preko cijele radne površine, kao „Danas" — bez gornje granice širine.
            tijelo,
          ],
        );
      },
    );
  }
}

class _Greska extends StatelessWidget {
  const _Greska({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AdminSpacing.gutterMobile),
    children: [
      const SizedBox(height: 160),
      Icon(
        Icons.cloud_off_outlined,
        size: 42,
        color: context.adminColors.textMuted,
      ),
      const SizedBox(height: AdminSpacing.md),
      const Center(child: Text('Radno vrijeme se ne može učitati.')),
      const SizedBox(height: AdminSpacing.md),
      Center(
        child: OutlinedButton(
          onPressed: onRetry,
          child: const Text('Pokušaj ponovo'),
        ),
      ),
    ],
  );
}

/// Zaglavlje `3s`: „‹ Još" i veliki naslov na bijeloj traci.
///
/// Radno vrijeme na telefonu nije u donjoj navigaciji nego ispod „Još", pa povratak ide
/// tamo, a ne na prethodni ekran iz historije.
class _ZaglavljeTelefona extends StatelessWidget {
  const _ZaglavljeTelefona();

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: boje.surface,
        border: Border(
          bottom: BorderSide(color: boje.separator, width: AdminSize.hairline),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            // Chevron ima svoj unutrašnji razmak; bez -6 „‹" ne stoji na gutteru.
            AdminSpacing.gutterMobile - 6,
            AdminSpacing.xs,
            AdminSpacing.gutterMobile,
            AdminSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: 'Nazad na Još',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => context.go(AdminRoute.more.path),
                  borderRadius: BorderRadius.circular(AdminRadius.base),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AdminSize.touchTarget,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left, size: 22, color: boje.accent),
                        Text(
                          'Još',
                          style: tema.bodyLarge?.copyWith(color: boje.accent),
                        ),
                        const SizedBox(width: AdminSpacing.sm),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AdminSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('Radno vrijeme', style: tema.displaySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Donja traka `3s` sa „Sačuvaj izmjene" — stoji van liste, da se snima bez skrolanja
/// do dna ispod blokada i pravila.
class _TrakaSacuvaj extends StatelessWidget {
  const _TrakaSacuvaj({required this.onPressed, required this.snimam});

  final VoidCallback? onPressed;
  final bool snimam;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: boje.surface,
        border: Border(
          top: BorderSide(color: boje.separator, width: AdminSize.hairline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AdminSpacing.gutterMobile,
          AdminSpacing.md,
          AdminSpacing.gutterMobile,
          AdminSpacing.md,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: _DugmeSacuvaj(onPressed: onPressed, snimam: snimam),
        ),
      ),
    );
  }
}

class _DugmeSacuvaj extends StatelessWidget {
  const _DugmeSacuvaj({required this.onPressed, required this.snimam});

  final VoidCallback? onPressed;
  final bool snimam;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      textStyle: AdminText.actionLabel,
      padding: const EdgeInsets.symmetric(horizontal: 17),
    ),
    child: snimam
        ? const AdminButtonBusy()
        : const AdminVerzal('Sačuvaj izmjene'),
  );
}

class _Poruka extends StatelessWidget {
  const _Poruka({required this.tekst});

  final String tekst;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: boje.destructive.withValues(alpha: 0.08),
        border: Border.all(color: boje.destructive),
        borderRadius: BorderRadius.circular(AdminRadius.base),
      ),
      child: Text(tekst, style: TextStyle(color: boje.destructive)),
    );
  }
}

/// Sedam dana u jednoj kartici, odvojenih hairline linijom — `3h` i `3s`.
class _Sedmica extends StatelessWidget {
  const _Sedmica({
    required this.dani,
    required this.desktop,
    required this.onChanged,
    required this.onUrediDan,
  });

  final List<WorkingHoursInput> dani;
  final bool desktop;
  final void Function(int index, WorkingHoursInput dan) onChanged;
  final void Function(int index) onUrediDan;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < dani.length; i++) ...[
          if (i > 0) const Divider(),
          if (desktop)
            _RedDanaDesktop(dan: dani[i], onChanged: (d) => onChanged(i, d))
          else
            _RedDanaTelefon(
              dan: dani[i],
              onChanged: (d) => onChanged(i, d),
              onUredi: () => onUrediDan(i),
            ),
        ],
      ],
    ),
  );
}

/// `3h`: ime, dva polja sa vremenom, prekidač desno.
class _RedDanaDesktop extends StatelessWidget {
  const _RedDanaDesktop({required this.dan, required this.onChanged});

  final WorkingHoursInput dan;
  final ValueChanged<WorkingHoursInput> onChanged;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    final ime = kDaniSedmice[dan.dayOfWeek - 1];
    final zatvoren = dan.isClosed;

    // Polja se sužavaju do 163 (mjera iz `3h`), a ne preko nje: uska kolona na 1100 px
    // prozora bi inače prelila red, a široka na 2560 razvukla sat u traku.
    Widget polje(Widget sat) => Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 163),
        child: sat,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
      child: Row(
        children: [
          SizedBox(
            width: 152,
            child: Text(
              ime,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.titleMedium?.copyWith(
                color: zatvoren ? boje.textMuted : null,
              ),
            ),
          ),
          Expanded(
            child: zatvoren
                ? Text(
                    'Zatvoreno',
                    style: tema.bodyLarge?.copyWith(color: boje.textMuted),
                  )
                : Row(
                    children: [
                      polje(
                        _Sat(
                          vrijeme: dan.startTime,
                          semantika: '$ime, početak radnog vremena',
                          onChanged: (v) =>
                              onChanged(dan.copyWith(startTime: v)),
                        ),
                      ),
                      const SizedBox(width: AdminSpacing.md),
                      polje(
                        _Sat(
                          vrijeme: dan.endTime,
                          semantika: '$ime, kraj radnog vremena',
                          onChanged: (v) => onChanged(dan.copyWith(endTime: v)),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: AdminSpacing.md),
          _Prekidac(
            otvoren: !zatvoren,
            semantika: '$ime, salon otvoren',
            velik: false,
            onChanged: (otvoren) => onChanged(dan.copyWith(isClosed: !otvoren)),
          ),
        ],
      ),
    );
  }
}

/// `3s`: ime i `09:00 – 20:00` jedno ispod drugog, prekidač desno.
///
/// Na 402 px dva polja ne stanu uz ime i prekidač, pa red nosi samo tekst, a vrijeme se
/// mijenja tapom na njega ([prikaziUrediDan]).
class _RedDanaTelefon extends StatelessWidget {
  const _RedDanaTelefon({
    required this.dan,
    required this.onChanged,
    required this.onUredi,
  });

  final WorkingHoursInput dan;
  final ValueChanged<WorkingHoursInput> onChanged;
  final VoidCallback onUredi;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    final ime = kDaniSedmice[dan.dayOfWeek - 1];
    final zatvoren = dan.isClosed;
    final vrijeme = zatvoren
        ? 'Zatvoreno'
        : '${dan.startTime.format()} – ${dan.endTime.format()}';

    final tekst = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ime,
          style: tema.titleMedium?.copyWith(
            color: zatvoren ? boje.textMuted : null,
          ),
        ),
        Text(
          vrijeme,
          style: tema.bodyLarge?.copyWith(
            color: boje.textMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.lg,
        vertical: 13,
      ),
      child: Row(
        children: [
          Expanded(
            child: zatvoren
                ? tekst
                : Semantics(
                    button: true,
                    label: '$ime, $vrijeme, promijeni vrijeme',
                    excludeSemantics: true,
                    child: InkWell(onTap: onUredi, child: tekst),
                  ),
          ),
          const SizedBox(width: AdminSpacing.md),
          _Prekidac(
            otvoren: !zatvoren,
            semantika: '$ime, salon otvoren',
            velik: true,
            onChanged: (otvoren) => onChanged(dan.copyWith(isClosed: !otvoren)),
          ),
        ],
      ),
    );
  }
}

/// Prekidač iz `3h`/`3s`: plava staza, bijeli palac iste veličine u oba stanja.
///
/// Material `Switch` ostaje (semantika „uključeno", tastatura, prevlačenje), samo se crta
/// manji: `3h` ga crta 42×24, `3s` 50×28, a M3 zadano 52×32 sa sitnim palcem kad je
/// isključen.
class _Prekidac extends StatelessWidget {
  const _Prekidac({
    required this.otvoren,
    required this.semantika,
    required this.velik,
    required this.onChanged,
  });

  final bool otvoren;
  final String semantika;
  final bool velik;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final (sirina, visina) = velik ? (50.0, 28.0) : (42.0, 24.0);

    final prekidac = SizedBox(
      width: sirina,
      height: visina,
      child: FittedBox(
        child: Switch(
          value: otvoren,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          thumbColor: WidgetStatePropertyAll(boje.surface),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? boje.accent
                : boje.neutralTint,
          ),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          // Prazna ikona tjera M3 da i isključenom palcu da punu veličinu, kako ga
          // `3h` crta.
          thumbIcon: const WidgetStatePropertyAll(Icon(null)),
        ),
      ),
    );

    // Sedam prekidača u nizu bez labele čitač ekrana javlja kao sedam puta „uključeno,
    // prekidač" — ime dana stoji u zasebnom `Text`-u i ne veže se.
    return Semantics(
      label: semantika,
      // Na telefonu je vidljivi prekidač niži od 44 px, pa tap oko njega mora raditi isto.
      child: velik
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!otvoren),
              child: SizedBox(
                width: sirina + AdminSpacing.sm,
                height: AdminSize.touchTarget,
                child: Center(child: prekidac),
              ),
            )
          : prekidac,
    );
  }
}

/// Polje sa vremenom iz `3h` — otvara `showTimePicker` i vraća [LocalTime].
///
/// [TimeOfDay] se koristi **samo** unutar ovog widgeta, jer ga Flutterov birač traži.
/// Dalje ide [LocalTime]: zidno vrijeme salona bez zone, v. njegovu dokumentaciju.
class _Sat extends StatelessWidget {
  const _Sat({
    required this.vrijeme,
    required this.semantika,
    required this.onChanged,
  });

  final LocalTime vrijeme;
  final String semantika;
  final ValueChanged<LocalTime> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    // `container: true` + `excludeSemantics: true` je jedino što spoji labelu sa dugmetom.
    //
    // Bez njih `Semantics` pravi **susjedni** čvor: čitač ekrana pročita labelu kao stavku
    // koja ništa ne radi, pa odmah zatim „09:00, dugme" — i korisnik ne može razlikovati
    // početak od kraja. `MergeSemantics` ovdje ne pomaže.
    container: true,
    button: true,
    label: '$semantika, ${vrijeme.format()}',
    excludeSemantics: true,
    child: SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          textStyle: AdminText.timeLarge,
        ),
        onPressed: () async {
          final izabrano = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: vrijeme.hour, minute: vrijeme.minute),
            // 24-satni prikaz bez obzira na postavku uređaja: raspored salona se piše
            // `09:00–20:00` i u izvozu i u bazi.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
          );
          if (izabrano != null) {
            onChanged(LocalTime(izabrano.hour, izabrano.minute));
          }
        },
        child: Text(vrijeme.format()),
      ),
    ),
  );
}
