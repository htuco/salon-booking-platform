/// Dva dijaloga koja radno vrijeme dijeli sa blokadama: upozorenje o terminima koji
/// ispadaju, i uređivač nove blokade.
///
/// Stoje odvojeno od ekrana jer ih zove i `3h` i, kasnije, „Blokiraj vrijeme" iz
/// kalendara (`3c`) — isti ugovor, dva ulaza.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/poruka_greske.dart';
import '../../core/format/datum.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/admin_verzal.dart';
import 'working_hours_providers.dart';

/// Termini koji ispadaju van novog rasporeda — vlasnik ih vidi **prije** nego što snimi.
///
/// Vraća `true` ako je potvrdio. Aplikacija ih ni tada ne briše i ne pomjera: ostaju
/// zakazani, a vlasnik ih rješava sa ekrana termina. Ovaj dijalog postoji da odluka ne
/// bude nevidljiva, ne da je izvrši.
Future<bool?> prikaziKonflikte(
  BuildContext context,
  List<ScheduleConflict> konflikti,
) => showDialog<bool>(
  context: context,
  builder: (context) {
    final boje = context.adminColors;
    return AlertDialog(
      title: const Text('Termini ostaju van radnog vremena'),
      // `maxWidth`, ne fiksnih `460`: na telefonu je dostupno ~322 px, pa fiksna širina
      // opisuje namjeru pogrešno („uvijek 460") iako je `AlertDialog` ionako stisne.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              konflikti.length == 1
                  ? 'Jedan zakazan termin ispada van novog radnog vremena. '
                        'Ostaje zakazan — ne briše se i ne pomjera.'
                  : '${konflikti.length} zakazanih termina ispada van novog '
                        'radnog vremena. Ostaju zakazani — ne brišu se i ne '
                        'pomjeraju.',
              style: TextStyle(color: boje.textSecondary),
            ),
            const SizedBox(height: AdminSpacing.lg),
            // `SingleChildScrollView`, ne `ListView`: `AlertDialog` mjeri sadržaj kroz
            // `IntrinsicWidth`, a `RenderShrinkWrappingViewport` intrinsične dimenzije
            // **ne podržava** — assertion je padao u `performLayout()`, izvan svakog
            // `try/catch` oko poziva, jer nije greška poziva nego crtanja (task 38).
            // Lijenost se ne gubi: `shrinkWrap: true` ju je ionako već isključio, a lista
            // je ograničena brojem termina koji ispadaju iz jedne sedmice.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, k) in konflikti.indexed) ...[
                      if (i > 0) const SizedBox(height: AdminSpacing.sm),
                      Builder(
                        builder: (context) {
                          final datum = DateTime(
                            k.date.year,
                            k.date.month,
                            k.date.day,
                          );
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${datumSaGodinom(datum)} · '
                                      '${k.startTime.format()}–${k.endTime.format()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    Text(
                                      [
                                        k.customerName,
                                        if (k.employeeName != null)
                                          k.employeeName!,
                                        if (k.reason != null) k.reason!,
                                      ].join(' · '),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: boje.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(textStyle: AdminText.actionLabel),
          child: const AdminVerzal('Sačuvaj ipak'),
        ),
      ],
    );
  },
);

/// Nova blokada — „Dodaj neradni dan" iz `3h`, „Blokiraj vrijeme" iz `3c`.
Future<void> prikaziUredjivacBlokade(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _UredjivacBlokade(),
    );

class _UredjivacBlokade extends ConsumerStatefulWidget {
  const _UredjivacBlokade();

  @override
  ConsumerState<_UredjivacBlokade> createState() => _UredjivacBlokadeState();
}

class _UredjivacBlokadeState extends ConsumerState<_UredjivacBlokade> {
  final _razlog = TextEditingController();
  DateTime _datum = DateTime.now();
  LocalTime _od = const LocalTime(9, 0);
  LocalTime _do = const LocalTime(17, 0);

  /// `null` = cijeli salon. Isto pravilo kao `blocked_slots.employee_id`.
  String? _radnikId;
  bool _snimam = false;
  String? _greska;

  @override
  void dispose() {
    _razlog.dispose();
    super.dispose();
  }

  Future<void> _sacuvaj() async {
    if (_do.minutesFromMidnight <= _od.minutesFromMidnight) {
      setState(() => _greska = 'Kraj mora biti poslije početka.');
      return;
    }
    setState(() {
      _snimam = true;
      _greska = null;
    });

    final actions = ref.read(workingHoursActionsProvider);
    final datum = LocalDate(_datum.year, _datum.month, _datum.day);
    try {
      // Isti redoslijed kao kod radnog vremena: prvo posljedica, pa potvrda, pa upis.
      final konflikti = await actions.konfliktiBlokade(
        datum: datum,
        od: _od,
        do_: _do,
        employeeId: _radnikId,
      );
      if (!mounted) return;
      if (konflikti.isNotEmpty) {
        final nastavi = await prikaziKonflikte(context, konflikti);
        if (!mounted) return;
        if (nastavi != true) {
          setState(() => _snimam = false);
          return;
        }
      }
      await actions.dodajBlokadu(
        datum: datum,
        od: _od,
        do_: _do,
        razlog: _razlog.text.trim(),
        employeeId: _radnikId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _greska = porukaGreske(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _greska = 'Blokada se ne može sačuvati.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sirina = MediaQuery.sizeOf(context).width;
    // `isLoading` se prati odvojeno: sa `valueOrNull ?? []` dropdown dok učitava izgleda
    // identično salonu koji stvarno nema nijednog radnika, a to su različita stanja.
    final osobljeStanje = ref.watch(osobljeZaBlokadeProvider);
    final osoblje = osobljeStanje.valueOrNull ?? const <Employee>[];
    final osobljeSeUcitava = osobljeStanje.isLoading;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        width: sirina >= AdminBreakpoint.desktop ? 520 : double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AdminSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Neradni dan ili blokada',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AdminSpacing.xl),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Datum'),
                subtitle: Text(datumSaGodinom(_datum)),
                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                onTap: () async {
                  final izabrano = await showDatePicker(
                    context: context,
                    initialDate: _datum,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (izabrano != null) setState(() => _datum = izabrano);
                },
              ),
              const SizedBox(height: AdminSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _Polje(
                      naslov: 'Od',
                      vrijeme: _od,
                      onChanged: (v) => setState(() => _od = v),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: _Polje(
                      naslov: 'Do',
                      vrijeme: _do,
                      onChanged: (v) => setState(() => _do = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AdminSpacing.lg),
              DropdownButtonFormField<String?>(
                initialValue: _radnikId,
                decoration: InputDecoration(
                  labelText: 'Odnosi se na',
                  helperText: osobljeSeUcitava
                      ? 'Učitavanje osoblja…'
                      : (osoblje.isEmpty
                            ? 'Salon nema aktivnih radnika.'
                            : null),
                ),
                // `isExpanded` i `ellipsis` idu zajedno: bez `isExpanded` dropdown traži
                // prirodnu širinu stavke, pa se skraćivanje nikad ne aktivira i dugo ime
                // („Amar Hadžiabdić-Mehmedagić iz Travnika") prelije telefon za ~300 px.
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(child: Text('Cijeli salon')),
                  for (final radnik in osoblje)
                    DropdownMenuItem<String?>(
                      value: radnik.id,
                      child: Text(
                        radnik.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _radnikId = v),
              ),
              const SizedBox(height: AdminSpacing.lg),
              TextFormField(
                controller: _razlog,
                decoration: const InputDecoration(
                  labelText: 'Razlog (nije obavezan)',
                  hintText: 'Kurban-bajram, inventura…',
                ),
              ),
              if (_greska != null) ...[
                const SizedBox(height: AdminSpacing.md),
                Text(
                  _greska!,
                  style: TextStyle(color: context.adminColors.destructive),
                ),
              ],
              const SizedBox(height: AdminSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _snimam
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Odustani'),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  FilledButton(
                    onPressed: _snimam ? null : _sacuvaj,
                    style: FilledButton.styleFrom(
                      textStyle: AdminText.actionLabel,
                    ),
                    child: _snimam
                        ? const AdminButtonBusy()
                        : const AdminVerzal('Sačuvaj'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Polje extends StatelessWidget {
  const _Polje({
    required this.naslov,
    required this.vrijeme,
    required this.onChanged,
  });

  final String naslov;
  final LocalTime vrijeme;
  final ValueChanged<LocalTime> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(naslov, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: AdminSpacing.xs),
      // Vidljivi naslov „Od"/„Do" stoji van dugmeta, pa ga čitač ekrana ne veže uz njega —
      // isti razlog za `container`/`excludeSemantics` kao kod `_Sat` u ekranu.
      Semantics(
        container: true,
        button: true,
        label: '$naslov, ${vrijeme.format()}',
        excludeSemantics: true,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              final izabrano = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: vrijeme.hour,
                  minute: vrijeme.minute,
                ),
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
      ),
    ],
  );
}

/// `pon` … `ned` — dani u opisu pauze i na čipovima izbora.
const List<String> kDaniKratko = [
  'pon',
  'uto',
  'sri',
  'čet',
  'pet',
  'sub',
  'ned',
];

/// Šta je vlasnik izabrao u uređivaču pauze.
class IzmjenaPauze {
  const IzmjenaPauze({required this.od, required this.do_, required this.dani})
    : ukloni = false;

  const IzmjenaPauze.ukloni()
    : od = const LocalTime(0, 0),
      do_ = const LocalTime(0, 0),
      dani = const {},
      ukloni = true;

  final LocalTime od;
  final LocalTime do_;

  /// ISO dani (1 = ponedjeljak) koji nose ovu pauzu.
  final Set<int> dani;
  final bool ukloni;
}

/// Dnevna pauza salona — „+ Dodaj pauzu" i „Uredi" iz `3h`.
///
/// **Ne snima.** Vraća izbor ekranu, koji ga upiše u lokalnu sedmicu; u bazu ide sa
/// „Sačuvaj izmjene", kroz istu provjeru konflikata kao i sati. Pauza je kolona dana, pa
/// je izbor dana ovdje isto što i „kojim danima ova kolona dobija ovo vrijeme".
///
/// [dani] `null` znači novu pauzu.
Future<IzmjenaPauze?> prikaziUrediPauzu(
  BuildContext context, {
  required List<WorkingHoursInput> sedmica,
  LocalTime? od,
  LocalTime? do_,
  Set<int>? dani,
}) => showDialog<IzmjenaPauze>(
  context: context,
  builder: (_) =>
      _UredjivacPauze(sedmica: sedmica, od: od, do_: do_, dani: dani),
);

class _UredjivacPauze extends StatefulWidget {
  const _UredjivacPauze({required this.sedmica, this.od, this.do_, this.dani});

  final List<WorkingHoursInput> sedmica;
  final LocalTime? od;
  final LocalTime? do_;
  final Set<int>? dani;

  @override
  State<_UredjivacPauze> createState() => _UredjivacPauzeState();
}

class _UredjivacPauzeState extends State<_UredjivacPauze> {
  late LocalTime _od = widget.od ?? const LocalTime(13, 0);
  late LocalTime _do = widget.do_ ?? const LocalTime(14, 0);

  /// Nova pauza unaprijed bira otvorene dane **bez** pauze — da „Dodaj" ne pregazi tiho
  /// pauzu koju dan već ima.
  late final Set<int> _dani =
      widget.dani ??
      {
        for (final d in widget.sedmica)
          if (!d.isClosed && !d.hasBreak) d.dayOfWeek,
      };
  String? _greska;

  bool get _nova => widget.dani == null;

  void _primijeni() {
    if (_do.minutesFromMidnight <= _od.minutesFromMidnight) {
      setState(() => _greska = 'Kraj pauze mora biti poslije početka.');
      return;
    }
    if (_dani.isEmpty) {
      setState(() => _greska = 'Izaberi bar jedan dan.');
      return;
    }
    Navigator.of(context)
        .pop(IzmjenaPauze(od: _od, do_: _do, dani: Set.of(_dani)));
  }

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(_nova ? 'Nova pauza' : 'Pauza'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Polje(
                      naslov: 'Od',
                      vrijeme: _od,
                      onChanged: (v) => setState(() => _od = v),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: _Polje(
                      naslov: 'Do',
                      vrijeme: _do,
                      onChanged: (v) => setState(() => _do = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AdminSpacing.lg),
              Text('Dani', style: tema.labelLarge),
              const SizedBox(height: AdminSpacing.sm),
              Wrap(
                spacing: AdminSpacing.sm,
                runSpacing: AdminSpacing.sm,
                children: [
                  for (final d in widget.sedmica)
                    FilterChip(
                      label: Text(kDaniKratko[d.dayOfWeek - 1]),
                      tooltip: kDaniSedmice[d.dayOfWeek - 1],
                      selected: _dani.contains(d.dayOfWeek),
                      // Zatvoren dan nema smjenu, pa ni pauzu u njoj.
                      onSelected: d.isClosed
                          ? null
                          : (izabran) => setState(
                              () => izabran
                                  ? _dani.add(d.dayOfWeek)
                                  : _dani.remove(d.dayOfWeek),
                            ),
                    ),
                ],
              ),
              const SizedBox(height: AdminSpacing.sm),
              Text(
                'Dan koji već ima drugu pauzu dobija ovu umjesto nje. Promjena se '
                'snima tek sa „Sačuvaj izmjene".',
                style: tema.bodySmall?.copyWith(color: boje.textSecondary),
              ),
              if (_greska != null) ...[
                const SizedBox(height: AdminSpacing.md),
                Text(_greska!, style: TextStyle(color: boje.destructive)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_nova)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const IzmjenaPauze.ukloni()),
            style: TextButton.styleFrom(foregroundColor: boje.destructive),
            child: const Text('Ukloni pauzu'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _primijeni,
          style: FilledButton.styleFrom(textStyle: AdminText.actionLabel),
          child: const AdminVerzal('Primijeni'),
        ),
      ],
    );
  }
}

/// Sati jednog dana na telefonu — `3s` red ne nosi polja, samo `09:00 – 20:00`, pa se
/// vrijeme mijenja ovdje. Kao i pauza, ne snima: vraća izbor ekranu.
Future<(LocalTime, LocalTime)?> prikaziUrediDan(
  BuildContext context, {
  required String ime,
  required LocalTime od,
  required LocalTime do_,
}) => showDialog<(LocalTime, LocalTime)>(
  context: context,
  builder: (_) => _UredjivacDana(ime: ime, od: od, do_: do_),
);

class _UredjivacDana extends StatefulWidget {
  const _UredjivacDana({
    required this.ime,
    required this.od,
    required this.do_,
  });

  final String ime;
  final LocalTime od;
  final LocalTime do_;

  @override
  State<_UredjivacDana> createState() => _UredjivacDanaState();
}

class _UredjivacDanaState extends State<_UredjivacDana> {
  late LocalTime _od = widget.od;
  late LocalTime _do = widget.do_;
  String? _greska;

  void _primijeni() {
    if (_do.minutesFromMidnight <= _od.minutesFromMidnight) {
      setState(
        () => _greska = 'Kraj radnog vremena mora biti poslije početka.',
      );
      return;
    }
    Navigator.of(context).pop((_od, _do));
  }

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return AlertDialog(
      title: Text(widget.ime),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Polje(
                    naslov: 'Od',
                    vrijeme: _od,
                    onChanged: (v) => setState(() => _od = v),
                  ),
                ),
                const SizedBox(width: AdminSpacing.md),
                Expanded(
                  child: _Polje(
                    naslov: 'Do',
                    vrijeme: _do,
                    onChanged: (v) => setState(() => _do = v),
                  ),
                ),
              ],
            ),
            if (_greska != null) ...[
              const SizedBox(height: AdminSpacing.md),
              Text(_greska!, style: TextStyle(color: boje.destructive)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _primijeni,
          style: FilledButton.styleFrom(textStyle: AdminText.actionLabel),
          child: const AdminVerzal('Primijeni'),
        ),
      ],
    );
  }
}
