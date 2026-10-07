/// Kontekstni panel — `6b`. Stalna treća kolona od 1920 px, ispod toga drawer sa desne
/// strane koji se otvara klikom na red (Esc i × ga zatvaraju).
///
/// Panel ne uvodi upit za termin: traži ga u listama koje ekran već drži (današnji termini
/// i zahtjevi). Klijent se čita iz `klijentProvider`, istog koji koristi profil u
/// Klijentima — brojke „4 dolaska · 0 nedolazaka" su `visit_count` i `no_show_count`, koje
/// `set_appointment_status` puni.
library;

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/datum.dart';
import '../../core/format/tekst.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_verzal.dart';
import '../../core/widgets/rub_zahtjeva.dart';
import '../appointments/appointment_card.dart';
import '../appointments/appointments_providers.dart';
import '../appointments/status_pill.dart';
import '../clients/clients_providers.dart' show klijentProvider;
import 'danas.dart';
import 'danas_akcije.dart';
import 'danas_providers.dart';
import '../../core/router/admin_router.dart';

/// Širina panela iz `6b`.
const double kSirinaPanela = 560;

/// Od 1920 px prozora panel stoji uvijek — mjeri se **prozor**, kako handoff piše, a ne
/// radna površina (koja je na 1920 za sidebar uža i pala bi u pojas ispod).
bool imaStalniPanel(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AdminBreakpoint.ultraWide;

/// Termin koji panel pokazuje.
///
/// Bez izbora stalni panel pokazuje prvi zahtjev, pa „Sljedeći" — prazna treća kolona na
/// 2560 bi bila mjesto koje ništa ne govori.
Appointment? terminZaPanel(WidgetRef ref, DateTime sada) {
  final id = ref.watch(izabraniTerminProvider);
  final danas = ref.watch(danasPrikazProvider).valueOrNull ?? const [];
  final zahtjevi = ref.watch(zahtjeviPrikazProvider).valueOrNull ?? const [];
  if (id != null) {
    for (final termin in [...zahtjevi, ...danas]) {
      if (termin.id == id) return termin;
    }
  }
  return zahtjevi.firstOrNull ?? sljedeciTermin(danas, sada);
}

class KontekstPanel extends ConsumerWidget {
  const KontekstPanel({this.onZatvori, super.key});

  /// `null` u stalnom panelu — tamo × samo poništi izbor.
  final VoidCallback? onZatvori;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final sada = ref.watch(sadaProvider).valueOrNull ?? DateTime.now();
    final termin = terminZaPanel(ref, sada);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: boje.surface,
        border: Border(
          left: BorderSide(color: boje.separator, width: AdminSize.hairline),
        ),
      ),
      child: termin == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AdminSpacing.xxxl),
                child: Text(
                  'Izaberite zahtjev ili termin da vidite detalje.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: boje.textSecondary,
                  ),
                ),
              ),
            )
          : _Sadrzaj(termin: termin, sada: sada, onZatvori: onZatvori),
    );
  }
}

class _Sadrzaj extends ConsumerWidget {
  const _Sadrzaj({required this.termin, required this.sada, this.onZatvori});

  final Appointment termin;
  final DateTime sada;
  final VoidCallback? onZatvori;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final opis = opisTermina(
      termin,
      usluge: ref.watch(uslugePoIdProvider),
      radnici: ref.watch(radniciPoIdProvider),
    );
    final zahtjev = termin.status == AppointmentStatus.pending;
    final bezOznakeTermin = bezOznake([termin], sada).isNotEmpty;
    final cekanje = cekaKoliko(termin.createdAt, sada);

    final eyebrow = zahtjev
        ? ['Zahtjev', ?cekanje].join(' · ')
        : 'Termin · ${statusOznaka(termin.status)}';

    final hairline = BorderSide(
      color: boje.separator,
      width: AdminSize.hairline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 14, 10, 14),
          decoration: BoxDecoration(border: Border(bottom: hairline)),
          child: Row(
            children: [
              Expanded(
                child: AdminVerzal(
                  eyebrow,
                  style: AdminText.eyebrow.copyWith(color: boje.textSecondary),
                ),
              ),
              IconButton(
                tooltip: 'Zatvori',
                onPressed:
                    onZatvori ??
                    () =>
                        ref.read(izabraniTerminProvider.notifier).izaberi(null),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                children: [
                  DanasAvatar(ime: termin.customerName, velicina: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          termin.customerName,
                          style: theme.textTheme.headlineSmall,
                        ),
                        if (termin.customerPhone case final telefon?
                            when telefon.isNotEmpty)
                          SelectableText(
                            telefon,
                            style: AdminText.dataInline.copyWith(
                              color: boje.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AdminSpacing.xl),
              RubZahtjeva(
                ceka: zahtjev,
                boja: boje.textMuted,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AdminRadius.base),
                    border: zahtjev ? null : Border.fromBorderSide(hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '${vrijemeHhMm(termin.startTime)}–'
                                        '${vrijemeHhMm(termin.endTime)}',
                                    style: AdminText.metricNumber.copyWith(
                                      fontSize: 26,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  ${danZahtjeva(termin.date, sada)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: boje.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          StatusOznaka(termin: termin, sada: sada),
                        ],
                      ),
                      const SizedBox(height: AdminSpacing.sm),
                      Text(
                        [
                          ?opis.usluga,
                          if (opis.majstor case final m?) prvoIme(m),
                          if (opis.cijena case final c?) iznosKm(c),
                        ].join(' · '),
                        style: theme.textTheme.titleSmall,
                      ),
                      if (termin.createdAt case final poslan?) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${termin.source == 'app' ? 'Poslano iz aplikacije' : 'Upisano u salonu'}'
                          ' u ${vrijemeHhMm(LocalTime(poslan.toLocal().hour, poslan.toLocal().minute))}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: boje.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (zahtjev) ...[
                const SizedBox(height: AdminSpacing.lg),
                _Provjera(termin: termin, sada: sada),
              ],
              const SizedBox(height: AdminSpacing.xxl),
              _Klijent(customerId: termin.customerId),
              if (termin.customerNote case final napomena?
                  when napomena.isNotEmpty) ...[
                const SizedBox(height: AdminSpacing.xl),
                Text('Napomena klijenta', style: theme.textTheme.titleSmall),
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  napomena,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: boje.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(border: Border(top: hairline)),
          child: Row(
            children: [
              if (zahtjev || bezOznakeTermin) ...[
                Expanded(
                  child: SizedBox(
                    height: AdminSize.touchTarget,
                    child: OutlinedButton(
                      onPressed: () {
                        onZatvori?.call();
                        zahtjev
                            ? odbijZahtjev(context, ref, termin)
                            : oznaciNijeDosao(context, ref, termin);
                      },
                      child: Text(zahtjev ? 'Odbij' : 'Nije došao'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: AdminSize.touchTarget,
                    child: FilledButton(
                      onPressed: () {
                        onZatvori?.call();
                        zahtjev
                            ? potvrdiZahtjev(context, ref, termin)
                            : oznaciZavrsen(context, ref, termin);
                      },
                      style: FilledButton.styleFrom(
                        textStyle: AdminText.actionLabel,
                      ),
                      child: AdminVerzal(zahtjev ? 'Potvrdi' : '✓ Završeno'),
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: SizedBox(
                    height: AdminSize.touchTarget,
                    child: OutlinedButton(
                      onPressed: () {
                        onZatvori?.call();
                        otvoriDetaljTermina(context, termin.id);
                      },
                      child: const Text('Otvori termin'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// „Termin 15:00–15:40 je slobodan · Amar. Prije: …, poslije: …" — `6b`.
class _Provjera extends ConsumerWidget {
  const _Provjera({required this.termin, required this.sada});

  final Appointment termin;
  final DateTime sada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final danas = ref.watch(danasPrikazProvider).valueOrNull ?? const [];
    final smjena = ref
        .watch(dashboardSmjeneProvider)
        .where((s) => s.radnikId == termin.employeeId)
        .firstOrNull;
    final provjera = provjeriZahtjev(termin, danas, sada, smjena: smjena);
    if (provjera == null) return const SizedBox.shrink();

    final radnik = prvoIme(
      ref.watch(radniciPoIdProvider)[termin.employeeId]?.name ??
          termin.employeeName ??
          '',
    );
    String susjed(Appointment t, String rijec) =>
        '${t.customerName} $rijec ${vrijemeHhMm(rijec == 'do' ? t.endTime : t.startTime)}'
        '${t.status == AppointmentStatus.pending ? ' (na čekanju)' : ''}';

    final (ikona, boja, tekst) = switch (provjera) {
      SlobodanTermin(:final prije, :final poslije) => (
        Icons.check,
        boje.positiveInk,
        [
          'Termin ${vrijemeHhMm(termin.startTime)}–${vrijemeHhMm(termin.endTime)} '
              'je slobodan${radnik.isEmpty ? '' : ' · $radnik'}.',
          [
            if (prije != null) 'Prije: ${susjed(prije, 'do')}',
            if (poslije != null)
              '${prije == null ? 'Poslije' : 'poslije'}: ${susjed(poslije, 'u')}',
          ].join(', '),
        ].where((d) => d.isNotEmpty).join(' '),
      ),
      ZauzetTermin(pauza: true) => (
        Icons.error_outline,
        boje.destructive,
        'Termin pada u pauzu iz smjene.',
      ),
      ZauzetTermin(:final sa) => (
        Icons.error_outline,
        boje.destructive,
        'Preklapa se sa: ${sa == null ? 'drugim terminom' : '${sa.customerName} ${vrijemeHhMm(sa.startTime)}'}.',
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikona, size: 18, color: boja),
        const SizedBox(width: 10),
        Expanded(child: Text(tekst, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// Dolasci, nedolasci i zadnji dolazak — iz reda klijenta.
class _Klijent extends ConsumerWidget {
  const _Klijent({required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final klijent = ref.watch(klijentProvider(customerId)).valueOrNull;
    // Greška i učitavanje ne crtaju ništa: panel je sporedan, a „0 dolazaka" prije nego što
    // podatak stigne bi tvrdilo da je klijent nov.
    if (klijent == null) return const SizedBox.shrink();

    final zadnji = klijent.lastVisitAt?.toLocal();
    final celije = [
      ('${klijent.visitCount}', 'dolazaka'),
      ('${klijent.noShowCount}', 'nedolazaka'),
      (
        zadnji == null
            ? '—'
            : '${zadnji.day.toString().padLeft(2, '0')}.'
                  '${zadnji.month.toString().padLeft(2, '0')}.',
        'zadnji dolazak',
      ),
    ];
    final hairline = BorderSide(
      color: boje.separator,
      width: AdminSize.hairline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Klijent', style: theme.textTheme.titleSmall),
        const SizedBox(height: AdminSpacing.sm),
        Container(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(hairline),
            borderRadius: BorderRadius.circular(AdminRadius.base),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (vrijednost, labela)) in celije.indexed)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: i == 0 ? null : Border(left: hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vrijednost,
                            style: AdminText.metricNumber.copyWith(
                              fontSize: 20,
                            ),
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
        ),
        if (klijent.note case final biljeska? when biljeska.isNotEmpty) ...[
          const SizedBox(height: AdminSpacing.xl),
          Text('Bilješka salona', style: theme.textTheme.titleSmall),
          const SizedBox(height: AdminSpacing.xs),
          Text(
            biljeska,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: boje.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Oznaka stanja termina — ista u rasporedu i u panelu.
///
/// Tri stanja ne stoje u bazi nego u satu: „U toku", „Bez oznake" (potvrđen, a vrijeme mu
/// je prošlo) i zahtjev koji nosi isprekidan rub umjesto pune pilule.
class StatusOznaka extends StatelessWidget {
  const StatusOznaka({required this.termin, required this.sada, super.key});

  final Appointment termin;
  final DateTime sada;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    if (terminUToku(termin, sada)) {
      return AppointmentStatusPill(status: termin.status, uToku: true);
    }

    if (termin.status == AppointmentStatus.pending) {
      return RubZahtjeva(
        ceka: true,
        boja: boje.textMuted,
        radius: AdminRadius.pill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          child: Text(
            statusOznaka(termin.status),
            style: AdminText.statusLabel.copyWith(color: boje.ink),
          ),
        ),
      );
    }

    if (termin.status == AppointmentStatus.confirmed &&
        terminProsao(termin, sada)) {
      final ton = context.statusColors.neutral;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: ton.background,
          borderRadius: BorderRadius.circular(AdminRadius.pill),
        ),
        child: Text(
          'Bez oznake',
          style: AdminText.statusLabel.copyWith(color: ton.foreground),
        ),
      );
    }

    return AppointmentStatusPill(status: termin.status);
  }
}

/// Krug klijenta, dijeljen između blokova Danas ekrana.
class DanasAvatar extends StatelessWidget {
  const DanasAvatar({required this.ime, this.velicina = 38, super.key});

  final String ime;
  final double velicina;

  @override
  Widget build(BuildContext context) {
    final ocisceno = ime.trim();
    return Container(
      width: velicina,
      height: velicina,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.adminColors.neutralTint,
        shape: BoxShape.circle,
      ),
      child: ExcludeSemantics(
        child: Text(
          ocisceno.isEmpty ? '?' : ocisceno.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.adminColors.textSecondary,
            fontSize: velicina * 0.4,
          ),
        ),
      ),
    );
  }
}
