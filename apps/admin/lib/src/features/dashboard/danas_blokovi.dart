/// Blokovi Danas ekrana — zahtjevi, „je li došao?", „Sljedeći", brojke i zauzetost.
///
/// Svaki blok čita svoj provider i **sam crta svoje učitavanje i grešku** (`6f`, `6k`):
/// zahtjevi koji se nisu učitali ne smiju sakriti raspored koji jeste.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/datum.dart';
import '../../core/format/tekst.dart';
import '../../core/navigation/admin_destinations.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/admin_verzal.dart';
import '../../core/widgets/rub_zahtjeva.dart';
import '../appointments/appointment_card.dart';
import '../appointments/appointments_providers.dart';
import '../appointments/appointments_screen.dart' show PotvrdiSveDugme;
import 'danas.dart';
import 'danas_akcije.dart';
import 'danas_providers.dart';
import 'dashboard_summary.dart';
import 'kontekst_panel.dart';

/// Koliko zahtjeva blok pokazuje prije „Još N zahtjeva". Telefon jedan, da „Sljedeći"
/// stane na prvi ekran (prijedlog uz `6c`).
const int kZahtjevaDesktop = 3;
const int kZahtjevaTelefon = 1;

DateTime sadaEkrana(WidgetRef ref) =>
    ref.watch(sadaProvider).valueOrNull ?? DateTime.now();

// ---------------------------------------------------------------------------
// Zajedničko
// ---------------------------------------------------------------------------

/// Bijela kartica sa hairline rubom — osnova svakog bloka.
class DanasKartica extends StatelessWidget {
  const DanasKartica({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: boje.surface,
        borderRadius: BorderRadius.circular(AdminRadius.base),
        border: Border.all(color: boje.separator, width: AdminSize.hairline),
      ),
      child: child,
    );
  }
}

/// Greška jednog bloka — `6k`. Ostali blokovi rade dalje.
class GreskaSekcije extends StatelessWidget {
  const GreskaSekcije({required this.sta, required this.onRetry, super.key});

  /// „Raspored" → „Raspored se nije učitao".
  final String sta;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    return DanasKartica(
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: boje.destructive),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: Text(
              '$sta se nije učitao.',
              style: theme.textTheme.bodyLarge,
            ),
          ),
          SizedBox(
            height: AdminSize.touchTarget,
            child: OutlinedButton(
              onPressed: onRetry,
              child: const Text('Pokušaj ponovo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton bloka iste geometrije kao blok koji dolazi — `6f`.
class SkeletonBloka extends StatelessWidget {
  const SkeletonBloka({this.redova = 3, this.visina = 68, super.key});

  final int redova;
  final double visina;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < redova; i++) ...[
        if (i > 0) const SizedBox(height: AdminSpacing.sm),
        AdminSkeleton.card(height: visina),
      ],
    ],
  );
}

/// Naslov bloka — „Zahtjevi na odobrenju", „Ostatak dana".
class NaslovBloka extends StatelessWidget {
  const NaslovBloka(this.tekst, {this.dodatak, this.desno, super.key});

  final String tekst;
  final Widget? dodatak;
  final Widget? desno;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: AdminSize.touchTarget),
    // Naslov uzima sav slobodan prostor, pa `desno` stoji uz desnu ivicu. `Flexible` uz
    // `Spacer` bi taj prostor dijelio napola i gurnuo filter na sredinu bloka.
    child: Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  tekst,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (dodatak != null) ...[const SizedBox(width: 10), dodatak!],
            ],
          ),
        ),
        if (desno != null) ...[const SizedBox(width: AdminSpacing.md), desno!],
      ],
    ),
  );
}

/// Koralna pilula sa brojem zahtjeva — `6a`.
class BrojZahtjeva extends StatelessWidget {
  const BrojZahtjeva(this.broj, {super.key});

  final int broj;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: boje.action,
        borderRadius: BorderRadius.circular(AdminRadius.pill),
      ),
      child: Text(
        '$broj',
        style: AdminText.statusLabel.copyWith(color: boje.onAction),
      ),
    );
  }
}

/// Link u akcentu, sa dodirnom metom od 44 px.
class DanasLink extends StatelessWidget {
  const DanasLink(this.tekst, {required this.onTap, super.key});

  final String tekst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: context.adminColors.accentInk,
      minimumSize: const Size(0, AdminSize.touchTarget),
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.sm),
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
    child: Text(tekst),
  );
}

/// Dugme niže od dodirne mete — vizual iz handoffa, meta i dalje ≥ 44 px (FE-502).
///
/// `6a` crta dugmad top bara 40 px, a filter čipove 34 px. Tema svako dugme drži na 44,
/// pa su na ekranu izgledala krupnije od handoffa. `padded` ostavlja nevidljiv pojas oko
/// dugmeta do 48 px, pa se dugme crta manje, a pogađa jednako lako.
ButtonStyle kompaktnoDugme({
  required double visina,
  required double padding,
  TextStyle? tekst,
}) => ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(0, visina)),
  maximumSize: WidgetStatePropertyAll(Size(double.infinity, visina)),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: padding)),
  tapTargetSize: MaterialTapTargetSize.padded,
  textStyle: tekst == null ? null : WidgetStatePropertyAll(tekst),
);

String _opisReda(TerminOpis opis, {bool saRadnikom = true}) => [
  ?opis.usluga,
  if (saRadnikom)
    if (opis.majstor case final m?) prvoIme(m),
  if (opis.cijena case final c?) iznosKm(c),
].join(' · ');

// ---------------------------------------------------------------------------
// Zahtjevi na odobrenju
// ---------------------------------------------------------------------------

class ZahtjeviBlok extends ConsumerWidget {
  const ZahtjeviBlok({this.telefon = false, super.key});

  final bool telefon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final sada = sadaEkrana(ref);
    final stanje = ref.watch(zahtjeviPrikazProvider);
    final lista = stanje.valueOrNull ?? const <Appointment>[];
    final najstariji = najstarijiZahtjev(lista);
    final koliko = telefon ? kZahtjevaTelefon : kZahtjevaDesktop;

    final naslov = telefon
        ? NaslovBloka(
            lista.isEmpty ? 'Zahtjevi' : 'Zahtjevi · ${lista.length}',
            desno: lista.isEmpty
                ? null
                : DanasLink(
                    'Vidi sve ›',
                    onTap: () => context.go(kZahtjeviPutanja),
                  ),
          )
        : NaslovBloka(
            'Zahtjevi na odobrenju',
            dodatak: lista.isEmpty ? null : BrojZahtjeva(lista.length),
            desno: najstariji == null
                ? null
                : Text(
                    'najstariji prije ${trajanjeCekanja(sada.difference(najstariji.toLocal()))}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: boje.textSecondary,
                    ),
                  ),
          );

    final tijelo = stanje.when(
      skipLoadingOnReload: true,
      loading: () => SkeletonBloka(redova: koliko),
      error: (_, _) => GreskaSekcije(
        sta: 'Blok zahtjeva',
        onRetry: () => ref.invalidate(zahtjeviProvider),
      ),
      data: (lista) {
        if (lista.isEmpty) return const _NemaZahtjeva();
        final vidljivi = lista.take(koliko).toList();
        final skriveno = lista.length - vidljivi.length;
        final najstarijiId = _najstarijiId(lista);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, zahtjev) in vidljivi.indexed) ...[
              if (i > 0) SizedBox(height: telefon ? 10 : AdminSpacing.sm),
              telefon
                  ? _ZahtjevKartica(termin: zahtjev, sada: sada)
                  : _ZahtjevRed(
                      termin: zahtjev,
                      sada: sada,
                      najstariji: zahtjev.id == najstarijiId,
                    ),
            ],
            if (skriveno > 0)
              telefon
                  ? Center(
                      child: DanasLink(
                        'Još ${zahtjevaTekst(skriveno)}',
                        onTap: () => context.go(kZahtjeviPutanja),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Još ${zahtjevaTekst(skriveno)}',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // `6j`: masovna potvrda ima smisla tek kad je skrivenih više nego
                          // što stane na ekran — tri zahtjeva se potvrde rukom.
                          if (skriveno > kZahtjevaDesktop) ...[
                            const PotvrdiSveDugme(),
                            const SizedBox(width: AdminSpacing.sm),
                          ],
                          DanasLink(
                            'Vidi sve ›',
                            onTap: () => context.go(kZahtjeviPutanja),
                          ),
                        ],
                      ),
                    ),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        naslov,
        const SizedBox(height: AdminSpacing.sm),
        tijelo,
      ],
    );
  }

  static String? _najstarijiId(List<Appointment> lista) {
    Appointment? najstariji;
    for (final z in lista) {
      final poslan = z.createdAt;
      if (poslan == null) continue;
      if (najstariji == null || poslan.isBefore(najstariji.createdAt!)) {
        najstariji = z;
      }
    }
    return najstariji?.id;
  }
}

/// `6i` — jedan tihi red od 52 px; raspored ispod se pomjeri gore.
class _NemaZahtjeva extends StatelessWidget {
  const _NemaZahtjeva();

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return DanasKartica(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          Icon(Icons.check, size: 18, color: boje.positiveInk),
          const SizedBox(width: AdminSpacing.md),
          Text(
            'Nema zahtjeva na čekanju',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Isprekidan okvir sa bijelom podlogom — zahtjev se odvaja oblikom, ne bojom.
class _OkvirZahtjeva extends StatelessWidget {
  const _OkvirZahtjeva({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return RubZahtjeva(
      ceka: true,
      boja: boje.textMuted,
      child: Material(
        color: boje.surface,
        borderRadius: BorderRadius.circular(AdminRadius.base),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// Red zahtjeva iz `6a`: vrijeme i dan | klijent | čeka | Odbij · Potvrdi.
class _ZahtjevRed extends ConsumerWidget {
  const _ZahtjevRed({
    required this.termin,
    required this.sada,
    required this.najstariji,
  });

  final Appointment termin;
  final DateTime sada;
  final bool najstariji;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final opis = opisTermina(
      termin,
      usluge: ref.watch(uslugePoIdProvider),
      radnici: ref.watch(radniciPoIdProvider),
    );
    final cekanje = cekaKoliko(termin.createdAt, sada);
    final izabran =
        imaStalniPanel(context) && terminZaPanel(ref, sada)?.id == termin.id;

    return _Izbor(
      izabran: izabran,
      child: _OkvirZahtjeva(
        onTap: () => otvoriTermin(context, ref, termin),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vrijemeHhMm(termin.startTime),
                      style: AdminText.metricNumber.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: AdminSpacing.xs),
                    Text(
                      danZahtjeva(termin.date, sada),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: boje.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              DanasAvatar(ime: termin.customerName),
              const SizedBox(width: AdminSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      termin.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      [
                        ?opis.usluga,
                        '${vrijemeHhMm(termin.startTime)}–${vrijemeHhMm(termin.endTime)}',
                        prvoIme(opis.majstor ?? 'bilo ko'),
                        if (opis.cijena case final c?) iznosKm(c),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: boje.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (cekanje != null) ...[
                const SizedBox(width: AdminSpacing.md),
                Text(
                  cekanje,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: najstariji ? boje.ink : boje.textSecondary,
                  ),
                ),
              ],
              const SizedBox(width: AdminSpacing.lg),
              SizedBox(
                height: AdminSize.touchTarget,
                child: OutlinedButton(
                  onPressed: () => odbijZahtjev(context, ref, termin),
                  child: const Text('Odbij'),
                ),
              ),
              const SizedBox(width: AdminSpacing.sm),
              SizedBox(
                height: AdminSize.touchTarget,
                child: FilledButton(
                  onPressed: () => potvrdiZahtjev(context, ref, termin),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: AdminText.actionLabel,
                  ),
                  child: const AdminVerzal('Potvrdi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartica zahtjeva iz `6c`.
class _ZahtjevKartica extends ConsumerWidget {
  const _ZahtjevKartica({required this.termin, required this.sada});

  final Appointment termin;
  final DateTime sada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final opis = opisTermina(
      termin,
      usluge: ref.watch(uslugePoIdProvider),
      radnici: ref.watch(radniciPoIdProvider),
    );
    final dan = danZahtjeva(termin.date, sada);
    final cekanje = cekaKoliko(termin.createdAt, sada);

    return _OkvirZahtjeva(
      onTap: () => otvoriTermin(context, ref, termin),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DanasAvatar(ime: termin.customerName, velicina: 36),
                const SizedBox(width: AdminSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        termin.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        [
                          ?opis.usluga,
                          prvoIme(opis.majstor ?? 'bilo ko'),
                          if (opis.cijena case final c?) iznosKm(c),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: boje.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      dan == 'danas'
                          ? vrijemeHhMm(termin.startTime)
                          : '$dan ${vrijemeHhMm(termin.startTime)}',
                      style: AdminText.metricNumber.copyWith(fontSize: 17),
                    ),
                    if (cekanje != null)
                      Text(
                        cekanje,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: boje.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AdminSpacing.md),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AdminSize.touchTarget,
                    child: OutlinedButton(
                      onPressed: () => odbijZahtjev(context, ref, termin),
                      child: const Text('Odbij'),
                    ),
                  ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: AdminSize.touchTarget,
                    child: FilledButton(
                      onPressed: () => potvrdiZahtjev(context, ref, termin),
                      style: FilledButton.styleFrom(
                        textStyle: AdminText.actionLabel,
                      ),
                      child: const AdminVerzal('Potvrdi'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Izabran red nosi plavi obris sa razmakom od 2 px (`6b`).
class _Izbor extends StatelessWidget {
  const _Izbor({required this.izabran, required this.child});

  final bool izabran;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AdminRadius.base + 2),
      border: Border.all(
        color: izabran ? context.adminColors.accent : Colors.transparent,
        width: 2,
      ),
    ),
    child: child,
  );
}

// ---------------------------------------------------------------------------
// Je li došao?
// ---------------------------------------------------------------------------

/// Potvrđeni termini kojima je vrijeme prošlo. Skriven kad ih nema.
class BezOznakeBlok extends ConsumerWidget {
  const BezOznakeBlok({this.telefon = false, super.key});

  final bool telefon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sada = sadaEkrana(ref);
    final danas = ref.watch(danasPrikazProvider).valueOrNull ?? const [];
    final lista = bezOznake(danas, sada);
    if (lista.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AdminSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, termin) in lista.indexed) ...[
            if (i > 0) const SizedBox(height: AdminSpacing.sm),
            _BezOznakeRed(termin: termin, telefon: telefon),
          ],
        ],
      ),
    );
  }
}

class _BezOznakeRed extends ConsumerWidget {
  const _BezOznakeRed({required this.termin, required this.telefon});

  final Appointment termin;
  final bool telefon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final opis = opisTermina(
      termin,
      usluge: ref.watch(uslugePoIdProvider),
      radnici: ref.watch(radniciPoIdProvider),
      saCijenom: false,
    );

    final tekst = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${termin.customerName} — je li došao?',
          style: theme.textTheme.titleSmall,
        ),
        Text(
          [
            _opisReda(opis),
            'završilo u ${vrijemeHhMm(termin.endTime)}',
          ].where((d) => d.isNotEmpty).join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(color: boje.textSecondary),
        ),
      ],
    );

    final nijeDosao = SizedBox(
      height: AdminSize.touchTarget,
      child: OutlinedButton(
        onPressed: () => oznaciNijeDosao(context, ref, termin),
        child: const Text('Nije došao'),
      ),
    );
    final zavrseno = SizedBox(
      height: AdminSize.touchTarget,
      child: OutlinedButton(
        onPressed: () => oznaciZavrsen(context, ref, termin),
        child: const Text('✓ Završeno'),
      ),
    );

    return DanasKartica(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: telefon
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tekst,
                const SizedBox(height: AdminSpacing.sm),
                Row(
                  children: [
                    Expanded(child: nijeDosao),
                    const SizedBox(width: AdminSpacing.sm),
                    Expanded(child: zavrseno),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    vrijemeHhMm(termin.startTime),
                    style: AdminText.metricNumber.copyWith(fontSize: 17),
                  ),
                ),
                Expanded(child: tekst),
                nijeDosao,
                const SizedBox(width: AdminSpacing.sm),
                zavrseno,
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sljedeći
// ---------------------------------------------------------------------------

class SljedeciKartica extends ConsumerWidget {
  const SljedeciKartica({this.telefon = false, super.key});

  final bool telefon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final sada = sadaEkrana(ref);
    final stanje = ref.watch(danasPrikazProvider);
    if (stanje.isLoading && !stanje.hasValue) {
      return AdminSkeleton.card(height: telefon ? 76 : 150);
    }
    // Greška termina se pokazuje jednom, u rasporedu; ovdje bi bila ista poruka dvaput.
    if (stanje.hasError && !stanje.hasValue) return const SizedBox.shrink();

    final danas = stanje.valueOrNull ?? const [];
    final sljedeci = sljedeciTermin(danas, sada);
    final uToku = uTokuSada(danas, sada);
    final radnik = ref.watch(adminRadnikIdProvider) != null;
    final opis = sljedeci == null
        ? null
        : opisTermina(
            sljedeci,
            usluge: ref.watch(uslugePoIdProvider),
            radnici: ref.watch(radniciPoIdProvider),
          );

    final eyebrow = AdminText.eyebrow.copyWith(color: boje.textSecondary);
    final za = sljedeci == null ? null : zaKoliko(sljedeci, sada);

    if (telefon) {
      return DanasKartica(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: sljedeci == null
            ? Text(
                'Danas više nema potvrđenih termina.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: boje.textSecondary,
                ),
              )
            : InkWell(
                onTap: () => otvoriTermin(context, ref, sljedeci),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminVerzal(
                            'Sljedeći · ${vrijemeHhMm(sljedeci.startTime)}',
                            style: eyebrow,
                          ),
                          Text(
                            sljedeci.customerName,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            _opisReda(opis!, saRadnikom: !radnik),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: boje.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      za!,
                      style: AdminText.metricNumber.copyWith(
                        fontSize: 22,
                        color: boje.accent,
                      ),
                    ),
                  ],
                ),
              ),
      );
    }

    return DanasKartica(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminVerzal('Sljedeći', style: eyebrow),
          const SizedBox(height: 6),
          if (sljedeci == null)
            Text(
              'Danas više nema potvrđenih termina.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: boje.textSecondary,
              ),
            )
          else
            InkWell(
              onTap: () => otvoriTermin(context, ref, sljedeci),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: za,
                          style: AdminText.metricNumber.copyWith(
                            fontSize: 30,
                            color: boje.accent,
                          ),
                        ),
                        TextSpan(
                          text: '  ${vrijemeHhMm(sljedeci.startTime)}',
                          style: AdminText.metricNumber.copyWith(
                            fontSize: 15,
                            color: boje.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      DanasAvatar(ime: sljedeci.customerName, velicina: 36),
                      const SizedBox(width: AdminSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sljedeci.customerName,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              _opisReda(opis!, saRadnikom: !radnik),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: boje.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (uToku.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: boje.separator),
            const SizedBox(height: 12),
            AdminVerzal('U toku', style: eyebrow),
            const SizedBox(height: AdminSpacing.xs),
            for (final termin in uToku)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        radnik || termin.employeeId == null
                            ? prvoIme(termin.customerName)
                            : '${prvoIme(termin.customerName)} · '
                                  '${prvoIme(ref.watch(radniciPoIdProvider)[termin.employeeId]?.name ?? termin.employeeName ?? '')}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      'do ${vrijemeHhMm(termin.endTime)}',
                      style: AdminText.dataInline.copyWith(
                        color: boje.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brojke
// ---------------------------------------------------------------------------

/// Najveća rupa kao „Amar 17:30–19:20" i „1 h 50 min".
({String vrijednost, String opis})? _rupa(WidgetRef ref, DateTime sada) {
  final smjene = ref.watch(dashboardSmjeneProvider);
  if (smjene.isEmpty) return null;
  final slobodno = slobodnoVrijeme(
    smjene: smjene,
    termini: ref.watch(danasPrikazProvider).valueOrNull ?? const [],
    blokade: ref.watch(dashboardBlokadeProvider).valueOrNull ?? const [],
    sadaMinuta: minutaDana(sada),
  );
  final rupa = slobodno.najvecaRupa;
  if (rupa == null) return (vrijednost: 'nema', opis: 'dan je pun');
  final radnik = ref.watch(adminRadnikIdProvider) != null;
  final ime = prvoIme(
    ref.watch(radniciPoIdProvider)[rupa.radnikId]?.name ?? '',
  );
  final raspon = '${hhmm(rupa.od)}–${hhmm(rupa.doMinute)}';
  return (
    vrijednost: radnik || ime.isEmpty ? raspon : '$ime $raspon',
    opis: trajanjeCekanja(Duration(minutes: rupa.minuta)),
  );
}

BrojkeDana _brojke(WidgetRef ref) => BrojkeDana.izracunaj(
  ref.watch(danasPrikazProvider).valueOrNull ?? const [],
  ref.watch(cijenePoUsluziProvider),
);

String _odustaliOpis(BrojkeDana b) => [
  if (b.nijeDoslo > 0) '${b.nijeDoslo} nije došao',
  if (b.otkazano > 0) '${b.otkazano} otkazan${b.otkazano == 1 ? '' : 'o'}',
].join(' · ');

class BrojkeKartica extends ConsumerWidget {
  const BrojkeKartica({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sada = sadaEkrana(ref);
    final stanje = ref.watch(danasPrikazProvider);
    if (stanje.isLoading && !stanje.hasValue) {
      return AdminSkeleton.card(height: 260);
    }
    final b = _brojke(ref);
    final rupa = _rupa(ref, sada);
    final sedmica = ref.watch(sedmicaProvider).valueOrNull;
    final radnikId = ref.watch(adminRadnikIdProvider);

    final redovi = <(String, String, String?)>[
      if (radnikId == null) ...[
        ('Naplaćeno', iznosKm(b.naplaceno), zavrsenihTekst(b.zavrsenih)),
        (
          'Prognoza dana',
          iznosKm(b.prognoza),
          b.naCekanjuIznos > 0
              ? 'od toga ${iznosKm(b.naCekanjuIznos)} čeka potvrdu'
              : b.termina == 0
              ? 'nema termina'
              : 'sve potvrđeno',
        ),
        ('Termini danas', '${b.termina}', _odustaliOpis(b)),
      ] else ...[
        (
          'Moji termini',
          '${b.termina}',
          [
            if (b.zavrsenih > 0) '${b.zavrsenih} završeno',
            if (_odustaliOpis(b) case final o when o.isNotEmpty) o,
          ].join(' · '),
        ),
        ('Moja zauzetost', _mojaZauzetost(ref) ?? '—', null),
      ],
      if (rupa != null) ('Najveća rupa', rupa.vrijednost, rupa.opis),
      if (sedmica != null) ('Ova sedmica', terminaTekst(sedmica), null),
    ];

    return DanasKartica(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Column(
        children: [
          for (final (i, (labela, vrijednost, opis)) in redovi.indexed)
            _RedBrojke(
              labela: labela,
              vrijednost: vrijednost,
              opis: opis == null || opis.isEmpty ? null : opis,
              zadnji: i == redovi.length - 1,
            ),
        ],
      ),
    );
  }
}

String? _mojaZauzetost(WidgetRef ref) {
  final radnikId = ref.watch(adminRadnikIdProvider);
  final z = zauzetostPoRadniku(
    ref.watch(danasPrikazProvider).valueOrNull ?? const [],
    {
      for (final r in ref.watch(radniciPoIdProvider).entries)
        r.key: prvoIme(r.value.name),
    },
    smjene: ref.watch(dashboardSmjeneProvider),
  ).where((r) => r.radnikId == radnikId).firstOrNull;
  final procenat = z?.procenat;
  return procenat == null ? null : '$procenat %';
}

class _RedBrojke extends StatelessWidget {
  const _RedBrojke({
    required this.labela,
    required this.vrijednost,
    required this.zadnji,
    this.opis,
  });

  final String labela;
  final String vrijednost;
  final String? opis;
  final bool zadnji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    return Container(
      constraints: const BoxConstraints(minHeight: AdminSize.touchTarget),
      padding: const EdgeInsets.symmetric(vertical: 11),
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
          Text(
            labela,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: boje.textSecondary,
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          // Desna strana se lomi, a ne gura red: „od toga 60 KM čeka potvrdu" uz veći
          // tekst sistema ne stane u kolonu od 330 px.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  vrijednost,
                  textAlign: TextAlign.right,
                  style: AdminText.metricNumber.copyWith(fontSize: 16),
                ),
                if (opis != null)
                  Text(
                    opis!,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: boje.textSecondary,
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

/// Tri ćelije iz `6c`/`6e`.
class BrojkeTraka extends ConsumerWidget {
  const BrojkeTraka({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final stanje = ref.watch(danasPrikazProvider);
    if (stanje.isLoading && !stanje.hasValue) {
      return AdminSkeleton.card(height: 64);
    }
    final b = _brojke(ref);
    final radnik = ref.watch(adminRadnikIdProvider) != null;
    final sedmica = ref.watch(sedmicaProvider).valueOrNull;

    final celije = radnik
        ? [
            ('${b.termina}', 'termina'),
            (_mojaZauzetost(ref) ?? '—', 'zauzetost'),
            (sedmica == null ? '—' : '$sedmica', 'ova sedmica'),
          ]
        : [
            (iznosKm(b.naplaceno), 'naplaćeno'),
            (iznosKm(b.prognoza), 'prognoza'),
            ('${b.termina}', 'termina'),
          ];
    final hairline = BorderSide(
      color: boje.separator,
      width: AdminSize.hairline,
    );

    return DanasKartica(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (vrijednost, labela)) in celije.indexed)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    border: i == 0 ? null : Border(left: hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vrijednost,
                        style: AdminText.metricNumber.copyWith(fontSize: 17),
                      ),
                      Text(
                        labela,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: boje.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zauzetost
// ---------------------------------------------------------------------------

class ZauzetostKartica extends ConsumerWidget {
  const ZauzetostKartica({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final danas = ref.watch(danasPrikazProvider).valueOrNull;
    if (danas == null) return const SizedBox.shrink();
    final zauzetost = zauzetostPoRadniku(
      danas,
      {
        for (final r in ref.watch(radniciPoIdProvider).entries)
          r.key: prvoIme(r.value.name),
      },
      smjene: ref.watch(dashboardSmjeneProvider),
    )..sort((a, b) => a.ime.compareTo(b.ime));
    if (zauzetost.isEmpty) return const SizedBox.shrink();
    final najvise = zauzetost.fold<int>(
      0,
      (m, r) => r.minuta > m ? r.minuta : m,
    );

    return DanasKartica(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Zauzetost danas', style: theme.textTheme.titleMedium),
          const SizedBox(height: AdminSpacing.md),
          for (final radnik in zauzetost)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          radnik.ime,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        '${terminaTekst(radnik.termina)} · '
                        '${radnik.procenat == null ? trajanjeKratko(radnik.minuta) : '${radnik.procenat} %'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AdminRadius.small),
                    // Traka podatka, ne indikator učitavanja: `value` je udio smjene.
                    // ignore: FE-205 traka podatka
                    child: LinearProgressIndicator(
                      value: radnik.procenat != null
                          ? radnik.procenat! / 100
                          : najvise == 0
                          ? 0
                          : radnik.minuta / najvise,
                      minHeight: 5,
                      backgroundColor: boje.neutralTint,
                      valueColor: AlwaysStoppedAnimation(boje.accent),
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

// ---------------------------------------------------------------------------
// Neradni dan — `6h`
// ---------------------------------------------------------------------------

class NeradniDanKartica extends StatelessWidget {
  const NeradniDanKartica({required this.sada, super.key});

  final DateTime sada;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DanasKartica(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Danas ne radimo', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            '${kDaniSedmice[sada.weekday - 1]} je neradni dan. '
            'Klijenti ne mogu zakazati za danas.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.adminColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class SljedeciRadniDanKartica extends ConsumerWidget {
  const SljedeciRadniDanKartica({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final sljedeci = ref.watch(sljedeciRadniDanProvider).valueOrNull;
    if (sljedeci == null) return const SizedBox.shrink();

    return DanasKartica(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminVerzal(
                  'Sljedeći radni dan',
                  style: AdminText.eyebrow.copyWith(color: boje.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${naslovDana(sljedeci.dan)} · otvaramo u '
                  '${vrijemeHhMm(sljedeci.otvara)}',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          Text(
            terminaTekst(sljedeci.termina),
            style: AdminText.metricNumber.copyWith(fontSize: 17),
          ),
        ],
      ),
    );
  }
}
