import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/admin_router.dart';
import '../../core/widgets/admin_scaffold.dart';
import 'appointment_actions_bar.dart';
import 'appointment_tile.dart';
import 'appointments_providers.dart';

/// Lista termina sa filterom po danu i statusu (`01 §12`).
///
/// **Piše se prije dashboarda**, kako task 23 nalaže: dashboard je sažetak ove liste. Da je
/// išao prvi, upit za „današnje termine" bi se napisao dvaput — jednom sam svoj, pa opet kad
/// lista donese filtere.
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
    final termini = ref.watch(filtriraniTerminiProvider);

    return AdminScaffold(
      // Naslov prati filter, jer ista ruta nosi dvije ćelije navigacije: „Zahtjevi" vode
      // ovdje sa `?status=pending`. Ekran naslovljen „Termini" poslije tapa na „Zahtjeve"
      // izgleda kao da je ćelija promašila.
      title: filter.status == AppointmentStatus.pending
          ? 'Zahtjevi'
          : 'Termini',
      aktivna: AdminRoute.appointments,
      // Ručni unos je jedini ulaz u `/appointments/new` — bez njega ekran postoji ali se do
      // njega ne može doći iz aplikacije, što je rupa koju je task 17 već jednom našao sa
      // `/account`.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AdminRoute.appointmentNew.path),
        icon: const Icon(Icons.add),
        label: const Text('Novi termin'),
      ),
      body: Column(
        children: [
          _FilterTraka(filter: filter),
          const Divider(height: 1),
          Expanded(
            child: termini.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              // Greska nosi dugme, ne samo tekst: admin koji izgubi vezu usred smjene mora
              // moci ponoviti bez zatvaranja app-e.
              error: (greska, _) => _Greska(
                poruka: greska is ApiError
                    ? 'Termini se ne mogu učitati.'
                    : 'Došlo je do greške.',
                onPonovi: () => ref.invalidate(filtriraniTerminiProvider),
              ),
              data: (lista) => lista.isEmpty
                  ? _PrazanDan(filter: filter)
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(filtriraniTerminiProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: lista.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        // Termin i njegove akcije su jedna stavka liste, ne dvije:
                        // `separatorBuilder` crta liniju između termina, a ne između
                        // termina i njegovih dugmadi.
                        itemBuilder: (context, i) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppointmentTile(termin: lista[i]),
                            AppointmentActionsBar(termin: lista[i]),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Izbor dana i statusa.
class _FilterTraka extends ConsumerWidget {
  const _FilterTraka({required this.filter});

  final AppointmentsFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(appointmentsFilterProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => notifier.pomjeriDan(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Prethodni dan',
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final izabran = await showDatePicker(
                      context: context,
                      initialDate: filter.dan,
                      // Prosli termini se gledaju (ko se nije pojavio, sta je odradjeno),
                      // pa raspon ide i unazad — ne samo naprijed.
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030, 12, 31),
                    );
                    if (izabran != null) notifier.postaviDan(izabran);
                  },
                  child: Column(
                    children: [
                      Text(
                        _naslovDana(filter.dan),
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _datumTekst(filter.dan),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () => notifier.pomjeriDan(1),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Sljedeći dan',
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusCip(
                  labela: 'Svi',
                  izabran: filter.status == null,
                  onTap: () => notifier.postaviStatus(null),
                ),
                // `unknown` se ne nudi kao filter: to je status koji ova verzija app-e ne
                // poznaje, a ne nesto sto vlasnik bira.
                for (final status in AppointmentStatus.values)
                  if (status != AppointmentStatus.unknown)
                    _StatusCip(
                      labela: statusLabela(status),
                      izabran: filter.status == status,
                      onTap: () => notifier.postaviStatus(status),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// „Danas" i „Sutra" su korisniji od datuma kad je dan blizu — vlasnik gleda raspored,
  /// ne kalendar.
  static String _naslovDana(DateTime dan) {
    final danas = DateTime.now();
    final razlika = DateTime(
      dan.year,
      dan.month,
      dan.day,
    ).difference(DateTime(danas.year, danas.month, danas.day)).inDays;
    return switch (razlika) {
      0 => 'Danas',
      1 => 'Sutra',
      -1 => 'Jučer',
      _ => _daniSedmice[dan.weekday - 1],
    };
  }

  static String _datumTekst(DateTime dan) =>
      '${dan.day}. ${_mjeseci[dan.month - 1]} ${dan.year}.';

  static const _daniSedmice = [
    'Ponedjeljak',
    'Utorak',
    'Srijeda',
    'Četvrtak',
    'Petak',
    'Subota',
    'Nedjelja',
  ];

  static const _mjeseci = [
    'januar',
    'februar',
    'mart',
    'april',
    'maj',
    'juni',
    'juli',
    'august',
    'septembar',
    'oktobar',
    'novembar',
    'decembar',
  ];
}

class _StatusCip extends StatelessWidget {
  const _StatusCip({
    required this.labela,
    required this.izabran,
    required this.onTap,
  });

  final String labela;
  final bool izabran;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(labela),
        selected: izabran,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _PrazanDan extends StatelessWidget {
  const _PrazanDan({required this.filter});

  final AppointmentsFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Prazan dan i prazan filter nisu ista stvar, i poruka to mora reci: inace vlasnik
    // koji je ostavio filter na „Otkazani" misli da mu je dan prazan.
    final poruka = filter.status == null
        ? 'Nema zakazanih termina za ovaj dan.'
        : 'Nema termina sa statusom „${statusLabela(filter.status!)}" za ovaj dan.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              poruka,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(poruka, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onPonovi,
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      ),
    );
  }
}
