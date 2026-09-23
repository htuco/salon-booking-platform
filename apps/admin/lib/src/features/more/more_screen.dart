import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/admin_destinations.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../appointments/appointments_providers.dart';
import '../clients/clients_providers.dart';
import '../settings/settings_providers.dart';
import '../working_hours/working_hours_providers.dart';

/// `3t` — „Još": kartica salona, pa grupe redova sa vrijednošću i strelicom.
///
/// **„Upravljanje" nije prepisana lista nego rep navigacije** ([adminSporedne]). Modul
/// dodan u `kAdminDestinations` se ovdje pojavi sam; da je ovdje druga lista, novi modul bi
/// na telefonu ostao nedostupan, a na desktopu radio. Jedini izuzetak su Postavke — do
/// njih vodi kartica salona na vrhu, kako `3t` crta.
///
/// **Vrijednosti su stvarne ili ih nema.** Broj uz red dolazi iz providera koje moduli već
/// imaju; ono što `3t` crta, a baza ne zna (lista čekanja, podsjetnici, uloge), piše
/// „uskoro" ili stanje koje zaista vrijedi, i na dodir to kaže.
class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postavke = ref.watch(postavkeBookingProvider).valueOrNull;
    void uPostavke() => context.go(AdminRoute.settings.path);

    return AdminScaffold(
      title: 'Još',
      aktivna: AdminRoute.more,
      // `3t` crta veliki naslov u bijeloj traci, bez sitnog `AppBar`-a iznad.
      sopstvenoZaglavlje: true,
      body: Column(
        children: [
          const _Zaglavlje(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AdminSpacing.gutterMobile,
                14,
                AdminSpacing.gutterMobile,
                AdminSpacing.xxxl,
              ),
              children: [
                const _SalonKartica(),
                const _Grupa(naslov: 'Upravljanje', child: _Upravljanje()),
                _Grupa(
                  naslov: 'Zakazivanje',
                  child: _Redovi(
                    children: [
                      _Red(
                        naslov: 'Ručna potvrda termina',
                        vrijednost: postavke == null
                            ? null
                            : postavke.bookingMode == 'manual'
                            ? 'uključeno'
                            : 'isključeno',
                        onTap: uPostavke,
                      ),
                      _Red(
                        naslov: 'Izbor majstora',
                        vrijednost: postavke == null
                            ? null
                            : postavke.requireStaffChoice
                            ? 'dozvoljeno'
                            : 'isključeno',
                        onTap: uPostavke,
                      ),
                      // Kolona ne postoji; „isključeno" je stanje koje stvarno vrijedi.
                      _Red(
                        naslov: 'Lista čekanja',
                        vrijednost: 'isključeno',
                        onTap: () =>
                            _uskoro(context, 'Lista čekanja stiže uskoro.'),
                      ),
                      _Red(
                        naslov: 'Pravila otkazivanja',
                        vrijednost: postavke == null
                            ? null
                            : '${postavke.minCancelHours} h prije',
                        onTap: uPostavke,
                      ),
                    ],
                  ),
                ),
                // Potvrdu `send-push` šalje uvijek; podsjetnike (`send-reminders`) još niko.
                _Grupa(
                  naslov: 'Obavijesti',
                  child: _Redovi(
                    children: [
                      _Red(
                        naslov: 'Potvrda termina',
                        vrijednost: 'uvijek',
                        onTap: () => _uskoro(
                          context,
                          'Potvrda termina se šalje uvijek i ne može se isključiti.',
                        ),
                      ),
                      _Red(
                        naslov: 'Podsjetnik dan prije',
                        vrijednost: 'uskoro',
                        onTap: () =>
                            _uskoro(context, 'Podsjetnici stižu uskoro.'),
                      ),
                      _Red(
                        naslov: 'Podsjetnik sat prije',
                        vrijednost: 'uskoro',
                        onTap: () =>
                            _uskoro(context, 'Podsjetnici stižu uskoro.'),
                      ),
                    ],
                  ),
                ),
                _Grupa(
                  naslov: 'Račun',
                  child: _Redovi(
                    children: [
                      _Red(
                        naslov: 'Pristup i uloge',
                        vrijednost: 'uskoro',
                        onTap: () => _uskoro(
                          context,
                          'Upravljanje pristupom stiže uskoro.',
                        ),
                      ),
                      _Red(
                        naslov: 'Odjavi se',
                        opasno: true,
                        onTap: () => odjavi(context, ref),
                      ),
                    ],
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

void _uskoro(BuildContext context, String poruka) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(poruka)));
}

/// Bijela traka sa „Još" — isti oblik kao zaglavlje `3k`, bez podnaslova.
class _Zaglavlje extends StatelessWidget {
  const _Zaglavlje();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(
      AdminSpacing.gutterMobile,
      AdminSpacing.md,
      AdminSpacing.gutterMobile,
      AdminSpacing.lg,
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
    child: SafeArea(
      bottom: false,
      child: Text('Još', style: Theme.of(context).textTheme.displaySmall),
    ),
  );
}

/// Slika salona, naziv i „adresa · telefon" — ulaz u Postavke.
class _SalonKartica extends ConsumerWidget {
  const _SalonKartica();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final salon = ref.watch(adminSalonProvider).valueOrNull;
    if (salon == null) return const SizedBox.shrink();

    final opis = [
      salon.address.trim(),
      (salon.phone ?? '').trim(),
    ].where((d) => d.isNotEmpty).join(' · ');

    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [boje.sidebarMuted, boje.sidebarSelected],
        ),
      ),
    );
    final url = salon.logoUrl ?? salon.coverImageUrl;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AdminRoute.settings.path),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AdminRadius.small),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: url == null || url.isEmpty
                      ? placeholder
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => placeholder,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salon.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                      ),
                    ),
                    if (opis.isNotEmpty)
                      Text(
                        opis,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdminText.dataInline.copyWith(
                          color: boje.textSecondary,
                          fontWeight: FontWeight.w400,
                          height: 1.45,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AdminSpacing.sm),
              Icon(Icons.chevron_right, size: 16, color: boje.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Verzalna labela i kartica sa redovima ispod nje.
class _Grupa extends StatelessWidget {
  const _Grupa({required this.naslov, required this.child});

  final String naslov;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AdminSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            // Verzal je stil, ne podatak — čitač ekrana dobija riječ, ne slova.
            naslov.toUpperCase(),
            semanticsLabel: naslov,
            style: AdminText.eyebrow.copyWith(
              color: context.adminColors.textSecondary,
            ),
          ),
          const SizedBox(height: AdminSpacing.sm),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Separator ide između redova, ne ispod zadnjeg: linija na dnu kartice udvaja obrub.
class _Redovi extends StatelessWidget {
  const _Redovi({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0)
          Divider(
            height: AdminSize.hairline,
            thickness: AdminSize.hairline,
            color: context.adminColors.separator,
          ),
        children[i],
      ],
    ],
  );
}

/// Moduli iza „Još", sa brojem koji modul već zna.
class _Upravljanje extends ConsumerWidget {
  const _Upravljanje();

  /// `StaffCustomerRepository.list` vraća najviše ovoliko redova; više od toga se ne
  /// broji ovdje, nego piše „200+".
  static const _granicaAdresara = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moduli = adminSporedne
        .where((c) => c.route != AdminRoute.settings)
        .toList(growable: false);

    return _Redovi(
      children: [
        for (final cilj in moduli)
          _Red(
            naslov: cilj.label,
            vrijednost: _vrijednost(ref, cilj.route),
            onTap: () => context.go(cilj.putanja),
          ),
      ],
    );
  }

  String? _vrijednost(WidgetRef ref, AdminRoute ruta) {
    switch (ruta) {
      case AdminRoute.clients:
        // Adresar je filtriran izborom sa ekrana Klijenti; broj bi tada lagao.
        final filter = ref.watch(clientsFilterProvider);
        final pretraga = ref.watch(clientsPretragaProvider);
        final klijenti = ref.watch(adminKlijentiProvider).valueOrNull;
        if (klijenti == null ||
            filter != ClientsFilter.svi ||
            pretraga.isNotEmpty) {
          return null;
        }
        return klijenti.length >= _granicaAdresara
            ? '$_granicaAdresara+'
            : '${klijenti.length}';
      case AdminRoute.services:
        final usluge = ref.watch(adminServicesProvider).valueOrNull;
        return usluge == null ? null : '${usluge.length}';
      case AdminRoute.employees:
        final radnici = ref.watch(adminEmployeesProvider).valueOrNull;
        if (radnici == null) return null;
        final aktivni = radnici.where((r) => r.isActive).length;
        return '$aktivni ${_aktivnih(aktivni)}';
      case AdminRoute.workingHours:
        final raspored = ref.watch(radnoVrijemeProvider).valueOrNull;
        return raspored == null ? null : _radniDani(raspored);
      default:
        return null;
    }
  }
}

/// „1 aktivan", „3 aktivna", „5 aktivnih" — bez riječi „majstor", koja je barber
/// terminologija (`vertical.terms`), a jednina iz vertikale se ne da sklanjati.
String _aktivnih(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return 'aktivnih';
  if (zadnja == 1) return 'aktivan';
  if (zadnja >= 2 && zadnja <= 4) return 'aktivna';
  return 'aktivnih';
}

const _dani = ['pon', 'uto', 'sri', 'čet', 'pet', 'sub', 'ned'];

/// Radni dani salona — „pon–sub" kad su uzastopni, inače nabrojani.
String _radniDani(List<WorkingHour> raspored) {
  final dani =
      raspored
          .where((r) => r.isSalonWide && !r.isClosed)
          .map((r) => r.dayOfWeek)
          .where((d) => d >= 1 && d <= 7)
          .toSet()
          .toList()
        ..sort();
  if (dani.isEmpty) return 'nije uneseno';
  if (dani.length == 1) return _dani[dani.first - 1];
  final uzastopni = dani.last - dani.first + 1 == dani.length;
  return uzastopni
      ? '${_dani[dani.first - 1]}–${_dani[dani.last - 1]}'
      : dani.map((d) => _dani[d - 1]).join(', ');
}

/// Red iz `3t`: naslov lijevo, siva vrijednost i strelica desno, 57 px.
class _Red extends StatelessWidget {
  const _Red({
    required this.naslov,
    required this.onTap,
    this.vrijednost,
    this.opasno = false,
  });

  final String naslov;
  final String? vrijednost;
  final VoidCallback onTap;

  /// Odjava: crvena, bez strelice — ne vodi nigdje nego završava sesiju.
  final bool opasno;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boje = context.adminColors;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 57),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  naslov,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: opasno ? boje.destructive : null,
                  ),
                ),
              ),
              if (vrijednost case final v?) ...[
                const SizedBox(width: AdminSpacing.md),
                Text(
                  v,
                  style: AdminText.dataInline.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: boje.textSecondary,
                  ),
                ),
              ],
              if (!opasno) ...[
                const SizedBox(width: 7),
                Icon(Icons.chevron_right, size: 14, color: boje.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
