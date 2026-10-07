/// Kartica zahtjeva — desktop red iz `3d` i telefonska kartica iz `3m`.
///
/// Dva oblika, jedne radnje: potvrda i odbijanje idu kroz isti [_ZahtjevAkcije], pa se
/// dijalog za obrazloženje i poruka o grešci ne mogu razići između širina.
///
/// ## Šta je nacrtano, a nema podatka iza sebe
///
/// - **„Ponudi drugo vrijeme" / „Promijeni majstora"** — pomjeranje termina i promjena
///   radnika nemaju RPC putanju. Dugme stoji (raspored je iz `3d`), tap kaže „uskoro".
/// - **Koralna traka upozorenja** crta se samo iz podatka koji postoji: rok isteka zahtjeva
///   (`pending_expires_at`). „Preklapa se s pauzom" iz handoffa traži pauze (task 34), a
///   „tri nedolaska" istoriju klijenta (task 35) — traka koja se ne računa iz podataka bi
///   tvrdila da je provjera urađena.
/// - **„12 dolazaka · bez nedolazaka"** uz telefon — isto, istorija klijenta.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/datum.dart';
import '../../core/format/tekst.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_verzal.dart';
import '../dashboard/dashboard_summary.dart' show prijeKoliko;
import '../dashboard/danas.dart' show cekaKoliko;
import '../../core/widgets/admin_skeleton.dart';
import 'appointment_actions_bar.dart';
import 'appointment_card.dart';
import 'appointments_providers.dart';
import '../../core/widgets/admin_toast.dart';

/// Koliko prije isteka zahtjev dobija koralnu traku. Da je svaki zahtjev „hitan", traka
/// ne bi značila ništa.
const Duration _prozorIsteka = Duration(hours: 1);

/// Mjere desktop reda iz `3d` (1440 px): lijeva kolona 160, desna 280, padding 22.
const double _sirinaVremena = 160;
const double _sirinaRadnji = 280;
const double _paddingReda = 22;

/// `3m`: dugmad u kartici su 50 px, unutrašnji padding 18.

/// `danas` / `utorak` — kako `3d` i `3m` imenuju dan zahtjeva.
///
/// Handoff za sutrašnji dan piše ime dana, ne „sutra": uz datum pored, „sutra, 19.05."
/// bi rekao isto dvaput.
String _imeDana(LocalDate dan, DateTime sada) {
  final datum = DateTime(dan.year, dan.month, dan.day);
  if (datum == DateTime(sada.year, sada.month, sada.day)) return 'danas';
  return kDaniSedmice[datum.weekday - 1].toLowerCase();
}

/// `18.05.`
String _datumKratko(LocalDate dan) =>
    '${dan.day.toString().padLeft(2, '0')}.${dan.month.toString().padLeft(2, '0')}.';

/// Minute do isteka zahtjeva, ili `null` kad roka nema ili je daleko.
int? _minutaDoIsteka(Appointment termin, DateTime sada) {
  final rok = termin.pendingExpiresAt;
  if (rok == null) return null;
  final ostalo = rok.toLocal().difference(sada);
  if (ostalo.isNegative || ostalo > _prozorIsteka) return null;
  return ostalo.inMinutes < 1 ? 1 : ostalo.inMinutes;
}

/// Potvrda i odbijanje, isti tok za obje kartice.
mixin _ZahtjevAkcije<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool uToku = false;

  Appointment get termin;

  Future<void> potvrdi() => _izvrsi(
    () => ref.read(appointmentActionsProvider).potvrdi(termin.id),
    uspjeh: 'Termin je potvrđen.',
  );

  /// Odbijanje pita za obrazloženje jer ga klijent vidi — isti dijalog kao u traci akcija.
  Future<void> odbij() async {
    final razlog = await pitajZaRazlog(
      context,
      naslov: 'Odbij zahtjev',
      opis:
          'Klijent ${termin.customerName} će dobiti obavijest da termin nije prihvaćen.',
      potvrda: 'Odbij',
    );
    if (razlog == null || !mounted) return;

    await _izvrsi(
      () =>
          ref.read(appointmentActionsProvider).odbij(termin.id, razlog: razlog),
      uspjeh: 'Zahtjev je odbijen.',
    );
  }

  Future<void> _izvrsi(
    Future<Appointment?> Function() poziv, {
    required String uspjeh,
  }) async {
    setState(() => uToku = true);
    try {
      await poziv();
      if (!mounted) return;
      AdminToast.uspjeh(context, uspjeh);
    } on ApiError catch (greska) {
      if (!mounted) return;
      AdminToast.greska(context, tekstGreskeAkcije(greska));
    } finally {
      if (mounted) setState(() => uToku = false);
    }
  }
}

/// Obrub kartice: koralni kad nosi upozorenje (`3d`, `3m`), inače tihi rub.
ShapeBorder _oblik(BuildContext context, {required bool upozorenje}) =>
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AdminRadius.base),
      side: BorderSide(
        color: upozorenje
            ? context.adminColors.action
            : context.adminColors.cardEdge,
        width: AdminSize.hairline,
      ),
    );

/// Koralna traka upozorenja. Tekst je tamni `onAction`, ne bijeli — bijelo na koralnoj
/// pada AA (v. `admin_colors.dart`).
class _Traka extends StatelessWidget {
  const _Traka({required this.tekst, required this.stil});

  final String tekst;
  final TextStyle? stil;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: context.adminColors.action,
        borderRadius: BorderRadius.circular(AdminRadius.small),
      ),
      child: Text(
        tekst,
        style: stil?.copyWith(color: context.adminColors.onAction),
      ),
    );
  }
}

/// Red zahtjeva iz `3d`: vrijeme | klijent i podaci | radnje.
class ZahtjevRedDesktop extends ConsumerStatefulWidget {
  const ZahtjevRedDesktop({
    required this.termin,
    required this.opis,
    this.onTap,
    super.key,
  });

  final Appointment termin;
  final TerminOpis opis;
  final VoidCallback? onTap;

  @override
  ConsumerState<ZahtjevRedDesktop> createState() => _ZahtjevRedDesktopState();
}

class _ZahtjevRedDesktopState extends ConsumerState<ZahtjevRedDesktop>
    with _ZahtjevAkcije<ZahtjevRedDesktop> {
  @override
  Appointment get termin => widget.termin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final sada = DateTime.now();
    final istice = _minutaDoIsteka(termin, sada);
    final upozorenje = istice == null
        ? null
        : 'Zahtjev ističe za $istice min — odgovorite prije isteka.';
    final opis = widget.opis;
    final poslano = prijeKoliko(termin.createdAt, sada);
    final telefon = termin.customerPhone;
    final hairline = BorderSide(
      color: boje.separator,
      width: AdminSize.hairline,
    );

    return Card(
      shape: _oblik(context, upozorenje: upozorenje != null),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vrijeme je najkrupnije na kartici: zahtjev se prvo mjeri time kada je.
              Container(
                width: _sirinaVremena,
                padding: const EdgeInsets.all(_paddingReda),
                decoration: BoxDecoration(border: Border(right: hairline)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vrijemeHhMm(termin.startTime),
                      // `3d`: 30 px, 600, tabularne cifre.
                      style: AdminText.metricNumber.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: AdminSpacing.xs),
                    Text(
                      '${_imeDana(termin.date, sada)}, '
                      '${_datumKratko(termin.date)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: boje.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${termin.durationMinutes} minuta',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: boje.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(_paddingReda),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Avatar(ime: termin.customerName),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  termin.customerName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 17,
                                  ),
                                ),
                                if (telefon != null && telefon.isNotEmpty)
                                  Text(
                                    telefon,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: boje.textSecondary,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 30,
                        runSpacing: AdminSpacing.sm,
                        children: [
                          _Podatak(
                            labela: 'Usluga',
                            vrijednost: [
                              opis.usluga ?? '—',
                              if (opis.cijena case final c?) iznosKm(c),
                            ].join(' · '),
                          ),
                          _Podatak(
                            labela: 'Majstor',
                            vrijednost: opis.majstor ?? 'bilo ko',
                          ),
                          if (poslano != null)
                            _Podatak(labela: 'Poslano', vrijednost: poslano),
                        ],
                      ),
                      if (upozorenje != null) ...[
                        const SizedBox(height: 14),
                        _Traka(
                          tekst: upozorenje,
                          stil: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (termin.customerNote case final napomena?
                          when napomena.isNotEmpty) ...[
                        const SizedBox(height: AdminSpacing.lg),
                        Text(
                          'Napomena klijenta: „$napomena"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: boje.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                width: _sirinaRadnji,
                padding: const EdgeInsets.all(_paddingReda),
                decoration: BoxDecoration(border: Border(left: hairline)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: AdminSize.touchTarget,
                      child: FilledButton(
                        onPressed: uToku ? null : potvrdi,
                        style: FilledButton.styleFrom(
                          textStyle: AdminText.actionLabel,
                        ),
                        child: const AdminVerzal('Potvrdi'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: AdminSize.touchTarget,
                      child: OutlinedButton(
                        // Zahtjev „bilo ko" handoff nudi preraspodjelom, ostale novim
                        // vremenom. Nijedno nema RPC — placeholder.
                        onPressed: () => pokaziUskoro(
                          context,
                          termin.employeeId == null
                              ? 'Promjena majstora'
                              : 'Ponuda drugog vremena',
                        ),
                        child: Text(
                          termin.employeeId == null
                              ? 'Promijeni majstora'
                              : 'Ponudi drugo vrijeme',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: AdminSize.touchTarget,
                      child: TextButton(
                        onPressed: uToku ? null : odbij,
                        style: TextButton.styleFrom(
                          foregroundColor: boje.destructive,
                        ),
                        child: const Text('Odbij zahtjev'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartica zahtjeva iz `3m`.
///
/// Bez upozorenja su radnje u jednom redu (`POTVRDI | Odbij`); sa upozorenjem jedna ispod
/// druge preko cijele širine, kako `3m` crta karticu koja traži pažnju.
class ZahtjevKarticaTelefon extends ConsumerStatefulWidget {
  const ZahtjevKarticaTelefon({
    required this.termin,
    required this.opis,
    this.onTap,
    super.key,
  });

  final Appointment termin;
  final TerminOpis opis;
  final VoidCallback? onTap;

  @override
  ConsumerState<ZahtjevKarticaTelefon> createState() =>
      _ZahtjevKarticaTelefonState();
}

class _ZahtjevKarticaTelefonState extends ConsumerState<ZahtjevKarticaTelefon>
    with _ZahtjevAkcije<ZahtjevKarticaTelefon> {
  @override
  Appointment get termin => widget.termin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.adminColors;
    final now = DateTime.now();
    final expires = _minutaDoIsteka(termin, now);
    final waiting = cekaKoliko(termin.createdAt, now);
    final description = widget.opis;
    // `Danas, 18. maj` / `Srijeda, 20. maj` — kako mobile-refresh piše dan zahtjeva.
    final date =
        '${naslovDanaZaDatum(termin.date, danas: now)}, '
        '${termin.date.day}. ${kMjeseci[termin.date.month - 1]}';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.mobileCard),
        side: BorderSide(
          color: expires == null ? colors.border : colors.action,
        ),
      ),
      // Dodir na karticu i dalje otvara detalj termina; dugmad hvataju svoj dodir sama.
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(termin.customerName, style: theme.textTheme.titleMedium),
                  if (waiting != null)
                    Text(
                      waiting,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AdminSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      description.usluga ?? 'Usluga',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  if (description.cijena case final price?) ...[
                    const SizedBox(width: AdminSpacing.sm),
                    Text(iznosKm(price), style: theme.textTheme.titleSmall),
                  ],
                ],
              ),
              const SizedBox(height: AdminSpacing.sm),
              Divider(color: colors.separator),
              const SizedBox(height: AdminSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Text(date, style: theme.textTheme.bodyMedium),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Text(
                    vrijemeHhMm(termin.startTime),
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: AdminSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Text(
                      '${description.majstor ?? 'bilo ko'} · ${termin.durationMinutes} min',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (termin.customerNote case final note?
                  when note.isNotEmpty) ...[
                const SizedBox(height: AdminSpacing.sm),
                Text(note, style: theme.textTheme.bodySmall),
              ],
              if (expires != null) ...[
                const SizedBox(height: AdminSpacing.sm),
                _Traka(
                  tekst: 'Zahtjev ističe za $expires min.',
                  stil: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AdminSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: uToku ? null : odbij,
                      child: const Text('Odbij'),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: uToku ? null : potvrdi,
                      icon: uToku ? null : const Icon(Icons.check, size: 17),
                      label: uToku
                          ? const AdminButtonBusy()
                          : const Text('Prihvati'),
                    ),
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

/// Krug klijenta. Inicijal umjesto fotografije: `customers` nema sliku, a placeholder
/// fotografija iz handoffa ne ulazi u bundle.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.ime});

  final String ime;

  @override
  Widget build(BuildContext context) {
    final ocisceno = ime.trim();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.adminColors.neutralTint,
        shape: BoxShape.circle,
      ),
      child: Text(
        ocisceno.isEmpty ? '?' : ocisceno.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: context.adminColors.textSecondary),
      ),
    );
  }
}

/// Labela iznad vrijednosti — „Usluga / Fade + brada · 30 KM" iz `3d`.
class _Podatak extends StatelessWidget {
  const _Podatak({required this.labela, required this.vrijednost});

  final String labela;
  final String vrijednost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          labela,
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.adminColors.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(vrijednost, style: theme.textTheme.titleSmall),
      ],
    );
  }
}
