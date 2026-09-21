/// Radno vrijeme, pauze i neradni dani — `3h` na desktopu, `3s` na telefonu.
///
/// ## Sedmica je jedan podatak, ne sedam
///
/// Ekran drži cijelu sedmicu u lokalnom stanju i šalje je **u cjelini** na „Sačuvaj
/// izmjene". To nije izbor izgleda nego posljedica toga kako je baza čita:
/// `get_available_slots` tretira **odsustvo reda kao zatvoreno**, a ne kao „nije
/// podešeno". Slanje samo izmijenjenih dana bi tiho zatvorilo ostale.
///
/// ## Availability ostaje na backendu
///
/// Ovaj ekran mijenja **ulaz** u `get_available_slots`, nikad njegova pravila. Ovdje se
/// ne računa nijedan slobodan termin; jedino što ekran zna izračunati je da li pauza
/// stane u smjenu, i to samo da bi greška stigla prije `PT400` iz baze
/// (`docs/01 §8.1`).
///
/// ## Termin se ne briše tiho
///
/// Prije snimanja se zove `working_hours_conflicts` i, ako nešto ispada van novog
/// vremena, vlasnik to **vidi i potvrđuje**. Aplikacija ne pomjera i ne otkazuje tuđe
/// termine umjesto njega.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/datum.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import 'working_hours_dialogs.dart';
import 'working_hours_providers.dart';

class AdminWorkingHoursScreen extends ConsumerWidget {
  const AdminWorkingHoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = AdminShell.jeDesktop(context);
    final raspored = ref.watch(radnoVrijemeProvider);

    return AdminScaffold(
      title: 'Radno vrijeme',
      aktivna: AdminRoute.workingHours,
      body: raspored.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _Greska(onRetry: () => ref.invalidate(radnoVrijemeProvider)),
        // `key` po dužini učitanog rasporeda: kad se provider poništi nakon snimanja,
        // uređivač se gradi iznova iz svježih redova umjesto da zadrži staro stanje.
        data: (sve) => _Uredjivac(
          key: ValueKey(sve.length),
          pocetna: weekFromWorkingHours(sve),
          desktop: desktop,
        ),
      ),
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

class _Uredjivac extends ConsumerStatefulWidget {
  const _Uredjivac({super.key, required this.pocetna, required this.desktop});

  final List<WorkingHoursInput> pocetna;
  final bool desktop;

  @override
  ConsumerState<_Uredjivac> createState() => _UredjivacState();
}

class _UredjivacState extends ConsumerState<_Uredjivac> {
  late List<WorkingHoursInput> _dani;
  bool _snimam = false;
  String? _greska;

  @override
  void initState() {
    super.initState();
    _dani = List.of(widget.pocetna);
  }

  bool get _izmijenjeno {
    for (var i = 0; i < _dani.length; i++) {
      if (_dani[i] != widget.pocetna[i]) return true;
    }
    return false;
  }

  void _zamijeni(int index, WorkingHoursInput dan) =>
      setState(() => _dani[index] = dan);

  /// Snima tek kad vlasnik vidi šta ispada van novog vremena.
  ///
  /// Redoslijed je namjeran: prvo pitanje bazi šta bi ispalo, pa dijalog, pa upis. Obrnut
  /// redoslijed bi značio da vlasnik saznaje za posljedicu kad je već nastala.
  Future<void> _sacuvaj() async {
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
      setState(() {
        _snimam = false;
        _greska = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _greska = 'Radno vrijeme se ne može sačuvati.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = widget.desktop;
    final boje = context.adminColors;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(
        desktop ? AdminSpacing.gutterDesktop : AdminSpacing.gutterMobile,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kad je salon otvoren',
                    style: desktop
                        ? AdminText.display
                        : Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Aplikacija nudi termine samo unutar ovog vremena, '
                    'umanjeno za pauze.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: boje.textSecondary),
                  ),
                ],
              ),
            ),
            if (desktop) ...[
              const SizedBox(width: AdminSpacing.lg),
              _DugmeSacuvaj(
                onPressed: _izmijenjeno && !_snimam ? _sacuvaj : null,
                snimam: _snimam,
              ),
            ],
          ],
        ),
        const SizedBox(height: AdminSpacing.xl),
        if (_greska != null) ...[
          _Poruka(tekst: _greska!),
          const SizedBox(height: AdminSpacing.md),
        ],
        for (var i = 0; i < _dani.length; i++) ...[
          _RedDana(
            dan: _dani[i],
            desktop: desktop,
            onChanged: (dan) => _zamijeni(i, dan),
          ),
          const SizedBox(height: AdminSpacing.sm),
        ],
        const SizedBox(height: AdminSpacing.xxl),
        const _Blokade(),
        if (!desktop) ...[
          const SizedBox(height: AdminSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: _DugmeSacuvaj(
              onPressed: _izmijenjeno && !_snimam ? _sacuvaj : null,
              snimam: _snimam,
            ),
          ),
        ],
        const SizedBox(height: AdminSpacing.xxl),
      ],
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
    child: snimam
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Sačuvaj izmjene'),
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
      ),
      child: Text(tekst, style: TextStyle(color: boje.destructive)),
    );
  }
}

/// Jedan dan: ime, prekidač „zatvoreno", vremena i pauza.
class _RedDana extends StatelessWidget {
  const _RedDana({
    required this.dan,
    required this.desktop,
    required this.onChanged,
  });

  final WorkingHoursInput dan;
  final bool desktop;
  final ValueChanged<WorkingHoursInput> onChanged;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final ime = kDaniSedmice[dan.dayOfWeek - 1];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.lg,
        vertical: AdminSpacing.md,
      ),
      decoration: BoxDecoration(
        color: boje.surface,
        border: Border.all(color: boje.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Telefon (`3s`) ne stane ime + dva sata + prekidač u jedan red — na 402 px
          // to je prelivanje od stotinjak piksela. Zato su vremena ispod imena, a na
          // desktopu (`3h`) ostaju u istom redu, kako ih canvas i crta.
          Row(
            children: [
              SizedBox(
                width: desktop ? 140 : null,
                child: Text(
                  ime,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (desktop) ...[
                if (dan.isClosed)
                  Expanded(
                    child: Text(
                      'Zatvoreno',
                      style: TextStyle(color: boje.textMuted),
                    ),
                  )
                else ...[
                  _Sat(
                    vrijeme: dan.startTime,
                    semantika: '$ime, početak radnog vremena',
                    onChanged: (v) => onChanged(dan.copyWith(startTime: v)),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Text('–', style: TextStyle(color: boje.textMuted)),
                  const SizedBox(width: AdminSpacing.sm),
                  _Sat(
                    vrijeme: dan.endTime,
                    semantika: '$ime, kraj radnog vremena',
                    onChanged: (v) => onChanged(dan.copyWith(endTime: v)),
                  ),
                  const Spacer(),
                ],
              ] else ...[
                const Spacer(),
                if (dan.isClosed)
                  Text('Zatvoreno', style: TextStyle(color: boje.textMuted)),
              ],
              Switch(
                value: !dan.isClosed,
                onChanged: (otvoren) =>
                    onChanged(dan.copyWith(isClosed: !otvoren)),
              ),
            ],
          ),
          if (!desktop && !dan.isClosed) ...[
            const SizedBox(height: AdminSpacing.sm),
            Row(
              children: [
                _Sat(
                  vrijeme: dan.startTime,
                  semantika: '$ime, početak radnog vremena',
                  onChanged: (v) => onChanged(dan.copyWith(startTime: v)),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Text('–', style: TextStyle(color: boje.textMuted)),
                const SizedBox(width: AdminSpacing.sm),
                _Sat(
                  vrijeme: dan.endTime,
                  semantika: '$ime, kraj radnog vremena',
                  onChanged: (v) => onChanged(dan.copyWith(endTime: v)),
                ),
              ],
            ),
          ],
          if (!dan.isClosed) ...[
            const SizedBox(height: AdminSpacing.sm),
            _RedPauze(dan: dan, desktop: desktop, onChanged: onChanged),
          ],
        ],
      ),
    );
  }
}

/// Pauza unutar smjene — `working_hours.break_start_time`.
///
/// Jedna po danu, jer kolona nosi jednu. Pauza za pojedinog radnika i jednokratno
/// odsustvo su **blokada**, ne drugi red ovdje.
class _RedPauze extends StatelessWidget {
  const _RedPauze({
    required this.dan,
    required this.desktop,
    required this.onChanged,
  });

  final WorkingHoursInput dan;
  final bool desktop;
  final ValueChanged<WorkingHoursInput> onChanged;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;

    if (!dan.hasBreak) {
      return Padding(
        padding: EdgeInsets.only(left: desktop ? 140 : 0),
        child: TextButton(
          onPressed: () => onChanged(
            dan.copyWith(
              breakStartTime: const LocalTime(13, 0),
              breakEndTime: const LocalTime(14, 0),
            ),
          ),
          child: const Text('+ Dodaj pauzu'),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: desktop ? 140 : 0),
      // `Wrap`, ne `Row`: na telefonu „Pauza" + dva sata + dugme za uklanjanje ne stanu
      // u jedan red, pa se dugme prelomi u sljedeći umjesto da preliva.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AdminSpacing.sm,
        runSpacing: AdminSpacing.xs,
        children: [
          Text('Pauza', style: TextStyle(color: boje.textSecondary)),
          _Sat(
            vrijeme: dan.breakStartTime!,
            semantika: 'Početak pauze',
            onChanged: (v) => onChanged(dan.copyWith(breakStartTime: v)),
          ),
          Text('–', style: TextStyle(color: boje.textMuted)),
          _Sat(
            vrijeme: dan.breakEndTime!,
            semantika: 'Kraj pauze',
            onChanged: (v) => onChanged(dan.copyWith(breakEndTime: v)),
          ),
          IconButton(
            tooltip: 'Ukloni pauzu',
            onPressed: () => onChanged(dan.copyWith(clearBreak: true)),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Dugme koje otvara `showTimePicker` i vraća [LocalTime].
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
    label: semantika,
    button: true,
    child: OutlinedButton(
      onPressed: () async {
        final izabrano = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: vrijeme.hour, minute: vrijeme.minute),
          // 24-satni prikaz bez obzira na postavku uređaja: raspored salona se piše
          // `09:00–20:00` i u canvasu i u bazi.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
        if (izabrano != null) {
          onChanged(LocalTime(izabrano.hour, izabrano.minute));
        }
      },
      child: Text(vrijeme.format()),
    ),
  );
}

/// „Neradni dani" iz `3h` — blokade od danas unaprijed.
class _Blokade extends ConsumerWidget {
  const _Blokade();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;
    final blokade = ref.watch(buduceBlokadeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Neradni dani i blokade',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 7),
        Text(
          'Jednokratno zatvaranje ili odsustvo radnika. Ne mijenja sedmični '
          'raspored.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: boje.textSecondary),
        ),
        const SizedBox(height: AdminSpacing.lg),
        blokade.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AdminSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text(
            'Blokade se ne mogu učitati.',
            style: TextStyle(color: boje.textMuted),
          ),
          data: (lista) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lista.isEmpty)
                Text(
                  'Nema zakazanih neradnih dana.',
                  style: TextStyle(color: boje.textMuted),
                )
              else
                for (final blokada in lista) ...[
                  _RedBlokade(blokada: blokada),
                  const SizedBox(height: AdminSpacing.sm),
                ],
              const SizedBox(height: AdminSpacing.sm),
              TextButton(
                onPressed: () => prikaziUredjivacBlokade(context, ref),
                child: const Text('+ Dodaj neradni dan'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RedBlokade extends ConsumerWidget {
  const _RedBlokade({required this.blokada});

  final BlockedSlot blokada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;
    final datum = DateTime(
      blokada.date.year,
      blokada.date.month,
      blokada.date.day,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.lg,
        vertical: AdminSpacing.md,
      ),
      decoration: BoxDecoration(
        color: boje.surface,
        border: Border.all(color: boje.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blokada.reason?.isNotEmpty ?? false
                      ? blokada.reason!
                      : 'Blokirano',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${datumSaGodinom(datum)} · '
                  '${blokada.startTime.format()}–${blokada.endTime.format()}'
                  '${blokada.isSalonWide ? ' · cijeli salon' : ''}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: boje.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ukloni blokadu',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(workingHoursActionsProvider)
                    .obrisiBlokadu(blokada.id);
              } on ApiError catch (error) {
                messenger.showSnackBar(SnackBar(content: Text(error.message)));
              }
            },
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}
