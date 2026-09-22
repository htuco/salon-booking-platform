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

import '../../core/format/datum.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_skeleton.dart';
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
          child: const Text('Sačuvaj ipak'),
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
        _greska = error.message;
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
                    child: _snimam
                        ? const AdminButtonBusy()
                        : const Text('Sačuvaj'),
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
