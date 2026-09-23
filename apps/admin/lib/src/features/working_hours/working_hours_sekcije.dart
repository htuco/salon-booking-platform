/// Desna kolona `3h` (na `3s` ispod sedmice): dnevne pauze, neradni dani, pravila.
///
/// Stoji odvojeno od ekrana jer nijedna od tri sekcije ne drži stanje sedmice — pauze ga
/// samo čitaju i vraćaju izmjenu ekranu, a neradni dani i pravila imaju svoj izvor.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/poruka_greske.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/admin_verzal.dart';
import '../settings/settings_providers.dart';
import 'working_hours_dialogs.dart';
import 'working_hours_providers.dart';

/// Naslov blokade — razlog, ili „Blokirano" kad ga nema (`reason` je nullable).
String naslovBlokade(BlockedSlot blokada) =>
    (blokada.reason?.isNotEmpty ?? false) ? blokada.reason! : 'Blokirano';

/// `27.05.` — kratko, kako ga `3h` piše. Godina se dopisuje tek kad nije tekuća, jer
/// blokada smije biti i do dvije godine unaprijed.
String kratkiDatum(LocalDate dan, {DateTime? danas}) {
  final d = dan.day.toString().padLeft(2, '0');
  final m = dan.month.toString().padLeft(2, '0');
  final godina = (danas ?? DateTime.now()).year;
  return dan.year == godina ? '$d.$m.' : '$d.$m.${dan.year}.';
}

/// `pon–pet`, `pon, sri, pet`, ili `radni dani` kad pauza pokriva sve otvorene dane.
String opisDana(Iterable<int> dani, Iterable<int> otvoreni) {
  final s = [...dani]..sort();
  final o = [...otvoreni]..sort();
  if (s.length > 1 && s.length == o.length && s.every(o.contains)) {
    return 'radni dani';
  }
  final dijelovi = <String>[];
  var i = 0;
  while (i < s.length) {
    var j = i;
    while (j + 1 < s.length && s[j + 1] == s[j] + 1) {
      j++;
    }
    // Raspon tek od tri dana: `pon–uto` se čita sporije od `pon, uto`.
    if (j - i >= 2) {
      dijelovi.add('${kDaniKratko[s[i] - 1]}–${kDaniKratko[s[j] - 1]}');
    } else {
      for (var k = i; k <= j; k++) {
        dijelovi.add(kDaniKratko[s[k] - 1]);
      }
    }
    i = j + 1;
  }
  return dijelovi.join(', ');
}

/// Pauza salona kako je `3h` crta: jedno vrijeme, više dana.
///
/// U bazi je pauza kolona **dana** (`working_hours.break_start_time`), ne zaseban red —
/// ovo je samo grupisanje dana sa istim vremenom, da se sedam istih pauza ne crta sedam puta.
typedef PauzaSalona = ({LocalTime od, LocalTime do_, List<int> dani});

List<PauzaSalona> pauzeSalona(List<WorkingHoursInput> sedmica) {
  final grupe = <(LocalTime, LocalTime), List<int>>{};
  for (final dan in sedmica) {
    // Pauza zatvorenog dana ne znači ništa za zakazivanje, pa se ne prikazuje.
    if (dan.isClosed || !dan.hasBreak) continue;
    grupe
        .putIfAbsent((dan.breakStartTime!, dan.breakEndTime!), () => [])
        .add(dan.dayOfWeek);
  }
  final lista = [
    for (final MapEntry(key: (od, do_), value: dani) in grupe.entries)
      (od: od, do_: do_, dani: dani),
  ]..sort((a, b) => a.od.compareTo(b.od));
  return lista;
}

/// Okvir sekcije. Na desktopu naslov stoji **u** kartici (`3h`), na telefonu iznad nje
/// (`3s` — „Pauze" je van bijele plohe).
class SekcijaKartica extends StatelessWidget {
  const SekcijaKartica({
    required this.naslov,
    required this.naslovUKartici,
    required this.children,
    super.key,
  });

  final String naslov;
  final bool naslovUKartici;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final naslovW = Text(
      naslov,
      style: naslovUKartici
          ? Theme.of(context).textTheme.headlineSmall
          : Theme.of(context).textTheme.headlineMedium,
    );
    final kartica = Card(
      child: Padding(
        // 22 izmjereno iz `3h`; telefon ima uži gutter pa i uži okvir.
        padding: EdgeInsets.all(naslovUKartici ? 22 : AdminSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (naslovUKartici) ...[
              naslovW,
              const SizedBox(height: AdminSpacing.lg),
            ],
            ...children,
          ],
        ),
      ),
    );
    if (naslovUKartici) return kartica;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        naslovW,
        const SizedBox(height: AdminSpacing.md),
        kartica,
      ],
    );
  }
}

/// Pločica unutar sekcije: naslov, opis, radnja desno.
class _Plocica extends StatelessWidget {
  const _Plocica({
    required this.naslov,
    required this.opis,
    required this.podloga,
    this.bojaOpisa,
    this.kraj,
  });

  final String naslov;
  final String opis;
  final Color podloga;
  final Color? bojaOpisa;
  final Widget? kraj;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: podloga,
        borderRadius: BorderRadius.circular(AdminRadius.small),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(naslov, style: tema.titleSmall),
                const SizedBox(height: 2),
                Text(
                  opis,
                  style: tema.bodySmall?.copyWith(
                    color: bojaOpisa ?? boje.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          ?kraj,
        ],
      ),
    );
  }
}

/// `+ Dodaj pauzu` / `+ Dodaj neradni dan` — puna širina, sekundarno dugme u rečenici.
class _DugmeDodaj extends StatelessWidget {
  const _DugmeDodaj({required this.tekst, required this.onPressed});

  final String tekst;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
    child: Text(tekst),
  );
}

// ---------------------------------------------------------------------------
// Dnevne pauze
// ---------------------------------------------------------------------------

/// „Dnevne pauze" iz `3h`.
///
/// Pauze salona se uređuju ovdje, ali **ne snimaju** — izmjena ide u lokalnu sedmicu
/// ekrana preko [onIzmjena] i u bazu stiže sa „Sačuvaj izmjene", zajedno sa satima. Pauze
/// radnika se samo prikazuju: njihov raspored ovaj ekran ne piše.
class RadnoVrijemePauze extends ConsumerWidget {
  const RadnoVrijemePauze({
    required this.sedmica,
    required this.sve,
    required this.naslovUKartici,
    required this.onIzmjena,
    super.key,
  });

  /// Lokalna (još nesnimljena) sedmica salona.
  final List<WorkingHoursInput> sedmica;

  /// Sav raspored iz baze — odavde dolaze pauze radnika.
  final List<WorkingHour> sve;
  final bool naslovUKartici;

  /// Stari dani grupe (prazno za novu pauzu) i šta je vlasnik izabrao.
  final void Function(Set<int> stariDani, IzmjenaPauze izmjena) onIzmjena;

  Future<void> _uredi(BuildContext context, PauzaSalona? pauza) async {
    final izmjena = await prikaziUrediPauzu(
      context,
      sedmica: sedmica,
      od: pauza?.od,
      do_: pauza?.do_,
      dani: pauza?.dani.toSet(),
    );
    if (izmjena != null) onIzmjena(pauza?.dani.toSet() ?? const {}, izmjena);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;
    final salonske = pauzeSalona(sedmica);
    final otvoreni = [
      for (final d in sedmica)
        if (!d.isClosed) d.dayOfWeek,
    ];

    // Ime radnika dolazi iz liste aktivnih; dok se ona učitava, pauze radnika se ne
    // crtaju umjesto da na trenutak stoje bez imena.
    final osoblje = ref.watch(osobljeZaBlokadeProvider).valueOrNull;
    final radnika = <(String, LocalTime, LocalTime), List<int>>{};
    if (osoblje != null) {
      for (final red in sve) {
        if (red.employeeId == null || red.isClosed || !red.hasBreak) continue;
        radnika
            .putIfAbsent((
              red.employeeId!,
              red.breakStartTime!,
              red.breakEndTime!,
            ), () => [])
            .add(red.dayOfWeek);
      }
    }
    String? ime(String id) {
      for (final e in osoblje ?? const <Employee>[]) {
        if (e.id == id) return e.name;
      }
      return null;
    }

    // Podloga pauze je `cardEdge`: `3h` je crta tek za nijansu tamnije od bijele kartice,
    // a `ground` se na bijeloj ne vidi.
    final stavke = <Widget>[
      for (final p in salonske)
        _Plocica(
          naslov: 'Pauza',
          opis:
              '${p.od.format()}–${p.do_.format()} · cijeli salon · '
              '${opisDana(p.dani, otvoreni)}',
          podloga: boje.cardEdge,
          kraj: TextButton(
            onPressed: () => _uredi(context, p),
            child: const Text('Uredi'),
          ),
        ),
      for (final MapEntry(key: (id, od, do_), value: dani) in radnika.entries)
        if (ime(id) case final imeRadnika?)
          _Plocica(
            naslov: '$imeRadnika — pauza',
            opis:
                '${od.format()}–${do_.format()} · ${opisDana(dani, const [])}',
            podloga: boje.cardEdge,
            // Raspored radnika ovaj ekran ne piše; dugme ostaje da oblik prati `3h`,
            // ali kaže istinu umjesto da otvori formu koja ništa ne snima.
            kraj: TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Uskoro — pauza radnika se uređuje uz njegov raspored.',
                  ),
                ),
              ),
              child: const Text('Uredi'),
            ),
          ),
    ];

    return SekcijaKartica(
      naslov: naslovUKartici ? 'Dnevne pauze' : 'Pauze',
      naslovUKartici: naslovUKartici,
      children: [
        if (stavke.isEmpty)
          Text('Nema dnevnih pauza.', style: TextStyle(color: boje.textMuted))
        else
          for (final (i, s) in stavke.indexed) ...[
            if (i > 0) const SizedBox(height: AdminSpacing.md),
            s,
          ],
        const SizedBox(height: AdminSpacing.lg),
        _DugmeDodaj(
          tekst: '+ Dodaj pauzu',
          onPressed: () => _uredi(context, null),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Neradni dani
// ---------------------------------------------------------------------------

/// „Neradni dani" iz `3h` — blokade od danas unaprijed. Ovdje stiže i „Zatvori dan" iz
/// kalendara.
class RadnoVrijemeNeradniDani extends ConsumerWidget {
  const RadnoVrijemeNeradniDani({required this.naslovUKartici, super.key});

  final bool naslovUKartici;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;
    final blokade = ref.watch(buduceBlokadeProvider);

    return SekcijaKartica(
      naslov: 'Neradni dani',
      naslovUKartici: naslovUKartici,
      children: [
        ...blokade.when(
          loading: () => const [AdminSkeletonList(redova: 2)],
          // Bez ovoga je jedini način da se blokade ponovo učitaju napustiti ekran.
          error: (_, _) => [
            Text(
              'Blokade se ne mogu učitati.',
              style: TextStyle(color: boje.textMuted),
            ),
            const SizedBox(height: AdminSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => ref.invalidate(buduceBlokadeProvider),
                child: const Text('Pokušaj ponovo'),
              ),
            ),
          ],
          data: (lista) => [
            if (lista.isEmpty)
              Text(
                'Nema zakazanih neradnih dana.',
                style: TextStyle(color: boje.textMuted),
              )
            else
              for (final (i, blokada) in lista.indexed) ...[
                if (i > 0) const SizedBox(height: AdminSpacing.md),
                _RedBlokade(blokada: blokada),
              ],
          ],
        ),
        const SizedBox(height: AdminSpacing.lg),
        _DugmeDodaj(
          tekst: '+ Dodaj neradni dan',
          onPressed: () => prikaziUredjivacBlokade(context, ref),
        ),
      ],
    );
  }
}

class _RedBlokade extends ConsumerStatefulWidget {
  const _RedBlokade({required this.blokada});

  final BlockedSlot blokada;

  @override
  ConsumerState<_RedBlokade> createState() => _RedBlokadeState();
}

class _RedBlokadeState extends ConsumerState<_RedBlokade> {
  bool _brisem = false;

  /// Potvrda, i dugme koje se gasi dok poziv traje.
  ///
  /// Brisanje je jedina nepovratna radnja na ovom ekranu — promašen tap ne smije obrisati
  /// „Kurban-bajram" bez pitanja.
  Future<void> _obrisi() async {
    final blokada = widget.blokada;
    final messenger = ScaffoldMessenger.of(context);
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ukloniti blokadu?'),
        content: Text(
          '${naslovBlokade(blokada)} — vrijeme ponovo postaje dostupno za '
          'zakazivanje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(textStyle: AdminText.actionLabel),
            child: const AdminVerzal('Ukloni'),
          ),
        ],
      ),
    );
    if (potvrda != true || !mounted) return;
    setState(() => _brisem = true);
    try {
      await ref.read(workingHoursActionsProvider).obrisiBlokadu(blokada.id);
    } on ApiError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(porukaGreske(error))));
      if (mounted) setState(() => _brisem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blokada = widget.blokada;
    final boje = context.adminColors;
    final osoblje = ref.watch(osobljeZaBlokadeProvider).valueOrNull;
    String? radnik;
    for (final e in osoblje ?? const <Employee>[]) {
      if (e.id == blokada.employeeId) radnik = e.name;
    }
    final kome = blokada.isSalonWide ? 'salon zatvoren' : (radnik ?? 'radnik');

    return _Plocica(
      naslov: naslovBlokade(blokada),
      opis:
          '${kratkiDatum(blokada.date)} · '
          '${blokada.startTime.format()}–${blokada.endTime.format()} · $kome',
      // Blijeda crvena iz `3h`: neradni dan je izuzetak od rasporeda i mora se razlikovati
      // od pauze, koja je pravilo.
      podloga: boje.destructive.withValues(alpha: 0.1),
      bojaOpisa: boje.destructive,
      kraj: IconButton(
        tooltip: 'Ukloni blokadu',
        onPressed: _brisem ? null : _obrisi,
        color: boje.destructive,
        icon: const Icon(Icons.close, size: 18),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pravila zakazivanja
// ---------------------------------------------------------------------------

/// „Pravila zakazivanja" iz `3h` — **samo prikaz**.
///
/// Vrijednosti su stvarne (`salon_settings`, isti provider kao Postavke), ali se mijenjaju
/// u Postavkama, gdje forma i provjera već postoje. Druga forma ovdje bi bila drugi upis
/// istog reda sa svojim pravilima.
class RadnoVrijemePravila extends ConsumerWidget {
  const RadnoVrijemePravila({required this.naslovUKartici, super.key});

  final bool naslovUKartici;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postavke = ref.watch(postavkeBookingProvider);
    final s = postavke.valueOrNull;
    String vrijednost(String Function(SalonSettings) f) =>
        s != null ? f(s) : (postavke.isLoading ? '…' : '—');

    return SekcijaKartica(
      naslov: 'Pravila zakazivanja',
      naslovUKartici: naslovUKartici,
      children: [
        _RedPravila(
          labela: 'Razmak termina',
          vrijednost: vrijednost((s) => '${s.slotStepMinutes} min'),
        ),
        const SizedBox(height: 13),
        _RedPravila(
          labela: 'Najranije zakazivanje',
          vrijednost: vrijednost(
            (s) => '${s.minAdvanceBookingHours} h unaprijed',
          ),
        ),
        const SizedBox(height: 13),
        _RedPravila(
          labela: 'Otkazivanje najkasnije',
          vrijednost: vrijednost((s) => '${s.minCancelHours} h prije'),
        ),
      ],
    );
  }
}

class _RedPravila extends StatelessWidget {
  const _RedPravila({required this.labela, required this.vrijednost});

  final String labela;
  final String vrijednost;

  /// Ne vodi odmah u Postavke: odlazak sa ekrana bi bacio nesnimljene sate.
  void _objasni(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pravila zakazivanja se mijenjaju u Postavkama.'),
        // Sa akcijom Flutter po defaultu drži poruku dok se ne klikne; ova je samo
        // napomena i mora se sama skloniti.
        persist: false,
        action: SnackBarAction(
          label: 'Postavke',
          onPressed: () => context.go(AdminRoute.settings.path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(labela, style: tema.bodyLarge)),
        const SizedBox(width: AdminSpacing.md),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              // 206 iz `3h`; na uskoj kartici polje dijeli red sa labelom pola-pola.
              constraints: const BoxConstraints(maxWidth: 206),
              child: Semantics(
                button: true,
                label: '$labela, $vrijednost, mijenja se u Postavkama',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => _objasni(context),
                  borderRadius: BorderRadius.circular(AdminRadius.base),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: boje.border),
                      borderRadius: BorderRadius.circular(AdminRadius.base),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            vrijednost,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tema.bodyLarge?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: boje.textSecondary,
                        ),
                      ],
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
