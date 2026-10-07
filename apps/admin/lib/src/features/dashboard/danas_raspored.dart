/// „Ostatak dana" (vlasnik) i „Moj dan" (radnik) — vremenska linija iz `6a`/`6d`.
///
/// Jedna kartica po terminu, hronološki, sa linijom „Sad" koja se pomjera svake minute.
/// Prošli termini su stišani na pola, a svi osim zadnja dva se sklope u „Još N ranijih
/// termina". Rupe i pauza se crtaju samo kad je raspored jednog radnika: radnik ih vidi
/// uvijek, vlasnik kad filtrira jednog (na „Svi" bi se rupe tri radnika preklapale).
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/datum.dart';
import '../../core/format/tekst.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/rub_zahtjeva.dart';
import '../appointments/appointment_card.dart';
import '../appointments/appointments_providers.dart';
import '../calendar/calendar_screen.dart' show KalendarMrezaDana;
import 'danas.dart';
import 'danas_akcije.dart';
import 'danas_blokovi.dart';
import 'danas_providers.dart';
import 'kontekst_panel.dart';

class RasporedBlok extends ConsumerStatefulWidget {
  const RasporedBlok({this.telefon = false, super.key});

  final bool telefon;

  @override
  ConsumerState<RasporedBlok> createState() => _RasporedBlokState();
}

class _RasporedBlokState extends ConsumerState<RasporedBlok> {
  bool _prikaziRanije = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final sada = sadaEkrana(ref);
    final radnikId = ref.watch(adminRadnikIdProvider);
    final filter = radnikId ?? ref.watch(filterRadnikaProvider);
    final stanje = ref.watch(danasPrikazProvider);
    final smjene = ref.watch(dashboardSmjeneProvider);
    final smjena = filter == null
        ? null
        : smjene.where((s) => s.radnikId == filter).firstOrNull;

    final prikaz = ref.watch(prikazDanaProvider);
    // Telefon je uvijek lista: i mobilni kalendar (`3l`) je lista po vremenu.
    final kalendar = !widget.telefon && prikaz == PrikazDana.kalendar;

    final naslov = radnikId != null
        ? NaslovBloka(
            'Moj dan',
            desno: widget.telefon ? null : const _PrekidacPrikaza(),
            dodatak: smjena == null || kalendar
                ? null
                : Flexible(
                    child: Text(
                      [
                        'smjena ${hhmm(smjena.od)}–${hhmm(smjena.doMinute)}',
                        if ((smjena.pauzaOd, smjena.pauzaDo) case (
                          final int p,
                          final int k,
                        ))
                          'pauza ${hhmm(p)}–${hhmm(k)}',
                      ].join(' · '),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: boje.textSecondary,
                      ),
                    ),
                  ),
          )
        : NaslovBloka(
            'Ostatak dana',
            desno: widget.telefon
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Kalendar ima kolonu po radniku, pa mu filter ne treba.
                      if (prikaz == PrikazDana.lista) ...[
                        const _FilterRadnika(),
                        const SizedBox(width: AdminSpacing.lg),
                      ],
                      const _PrekidacPrikaza(),
                    ],
                  ),
          );

    if (kalendar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          naslov,
          const SizedBox(height: AdminSpacing.md),
          const _KalendarDana(),
        ],
      );
    }

    final tijelo = stanje.when(
      skipLoadingOnReload: true,
      loading: () => const SkeletonBloka(redova: 4, visina: 52),
      error: (_, _) => GreskaSekcije(
        sta: 'Raspored',
        onRetry: () => ref.invalidate(danasnjiTerminiProvider),
      ),
      data: (svi) {
        final termini = filter == null || radnikId != null
            ? svi
            : svi.where((t) => t.employeeId == filter).toList();
        final blokade = [
          for (final b
              in ref.watch(dashboardBlokadeProvider).valueOrNull ??
                  const <BlockedSlot>[])
            if (filter == null ||
                b.employeeId == null ||
                b.employeeId == filter)
              b,
        ];
        if (termini.isEmpty && blokade.isEmpty) {
          return DanasKartica(
            padding: const EdgeInsets.all(22),
            child: Text(
              'Danas nema termina.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: boje.textSecondary,
              ),
            ),
          );
        }

        final stavke = stavkeDana(
          termini: termini,
          blokade: blokade,
          sada: sada,
          smjena: smjena,
        );

        final prosli = [
          for (final s in stavke)
            if (s is TerminStavka && terminProsao(s.termin, sada)) s,
        ];
        final sakriveno = _prikaziRanije
            ? 0
            : (prosli.length - kVidljivihRanijih).clamp(0, prosli.length);
        final sakrivene = prosli.take(sakriveno).toSet();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (prosli.length > kVidljivihRanijih)
              _Red(
                telefon: widget.telefon,
                vrijeme: null,
                tacka: null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AdminSize.touchTarget,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _prikaziRanije
                              ? 'Raniji termini'
                              : josRanijih(sakriveno),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: boje.textSecondary,
                          ),
                        ),
                      ),
                      DanasLink(
                        _prikaziRanije ? 'Sakrij' : 'Prikaži',
                        onTap: () =>
                            setState(() => _prikaziRanije = !_prikaziRanije),
                      ),
                    ],
                  ),
                ),
              ),
            for (final stavka in stavke)
              if (!sakrivene.contains(stavka))
                _stavka(stavka, sada, prikaziRadnika: radnikId == null),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        naslov,
        if (widget.telefon && radnikId == null) ...[
          const SizedBox(height: AdminSpacing.sm),
          const _FilterRadnika(),
        ],
        const SizedBox(height: AdminSpacing.md),
        tijelo,
      ],
    );
  }

  Widget _stavka(
    StavkaDana stavka,
    DateTime sada, {
    required bool prikaziRadnika,
  }) => switch (stavka) {
    TerminStavka(:final termin) => _TerminRed(
      termin: termin,
      sada: sada,
      telefon: widget.telefon,
      prikaziRadnika: prikaziRadnika,
    ),
    SadStavka(:final od) => _SadRed(minuta: od, telefon: widget.telefon),
    SlobodnoStavka(:final od, :final minuta) => _TihiRed(
      od: od,
      tekst: 'Slobodno · ${trajanjeCekanja(Duration(minutes: minuta))}',
      telefon: widget.telefon,
    ),
    PauzaStavka(:final od, :final minuta) => _TihiRed(
      od: od,
      tekst: 'Pauza · ${trajanjeCekanja(Duration(minutes: minuta))}',
      telefon: widget.telefon,
    ),
    BlokadaStavka(:final blokada) => _TihiRed(
      od: stavka.od,
      tekst: [
        'Blokirano ${vrijemeHhMm(blokada.startTime)}–${vrijemeHhMm(blokada.endTime)}',
        if (blokada.reason case final r? when r.isNotEmpty) r,
      ].join(' · '),
      telefon: widget.telefon,
    ),
  };
}

/// „Lista · Kalendar" — desktop.
class _PrekidacPrikaza extends ConsumerWidget {
  const _PrekidacPrikaza();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prikaz = ref.watch(prikazDanaProvider);
    final boje = context.adminColors;

    Widget segment(String tekst, IconData ikona, PrikazDana vrijednost) {
      final on = prikaz == vrijednost;
      final stil = kompaktnoDugme(
        visina: 34,
        padding: 11,
        tekst: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 13.5,
          fontWeight: on ? FontWeight.w600 : FontWeight.w500,
        ),
      );
      final dijete = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikona, size: 16),
          const SizedBox(width: 6),
          Text(tekst),
        ],
      );
      void izaberi() =>
          ref.read(prikazDanaProvider.notifier).postavi(vrijednost);
      return Semantics(
        selected: on,
        child: on
            ? FilledButton(
                onPressed: izaberi,
                style: stil.merge(
                  FilledButton.styleFrom(
                    backgroundColor: boje.ink,
                    foregroundColor: boje.surface,
                  ),
                ),
                child: dijete,
              )
            : OutlinedButton(onPressed: izaberi, style: stil, child: dijete),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        segment('Lista', Icons.view_agenda_outlined, PrikazDana.lista),
        const SizedBox(width: 6),
        segment(
          'Kalendar',
          Icons.calendar_view_week_outlined,
          PrikazDana.kalendar,
        ),
      ],
    );
  }
}

/// Mreža kalendara za danas — `3c` u bloku „Ostatak dana".
///
/// Visina je ograničena: mreža od 09 do 20 h je 880 px, pa bi pod njom nestale kartice
/// sa strane. Osa se skroluje unutar kartice, kao na ekranu Kalendar.
class _KalendarDana extends ConsumerWidget {
  const _KalendarDana();

  /// Koliko mreže stane u blok prije unutrašnjeg skrola.
  static const double _visina = 620;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;
    final stanje = ref.watch(danasPrikazProvider);
    if (stanje.hasError && !stanje.hasValue) {
      return GreskaSekcije(
        sta: 'Raspored',
        onRetry: () => ref.invalidate(danasnjiTerminiProvider),
      );
    }
    final dan = ref.watch(danasKalendarProvider);
    if (dan == null) return const SkeletonBloka(redova: 1, visina: _visina);

    return Container(
      height: _visina,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: boje.surface,
        borderRadius: BorderRadius.circular(AdminRadius.base),
        border: Border.all(color: boje.separator, width: AdminSize.hairline),
      ),
      child: KalendarMrezaDana(dan: dan),
    );
  }
}

/// „Svi · Emir · Vedad · Amar" — samo vlasnik.
class _FilterRadnika extends ConsumerWidget {
  const _FilterRadnika();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radnici = ref.watch(radniciPoIdProvider);
    final izabran = ref.watch(filterRadnikaProvider);
    final smjene = ref.watch(dashboardSmjeneProvider);
    final danas = ref.watch(danasPrikazProvider).valueOrNull ?? const [];
    // Radnik bez smjene i bez termina danas nema šta pokazati u filteru.
    final aktivni = [
      for (final r in radnici.values)
        if (r.isActive &&
            (smjene.any((s) => s.radnikId == r.id) ||
                danas.any((t) => t.employeeId == r.id)))
          r,
    ]..sort((a, b) => a.name.compareTo(b.name));
    if (aktivni.length < 2) return const SizedBox.shrink();

    // `6a`: 34 px, padding 13, 13,5 px — izabran 600 na akcentu, ostali 500 na bijelom.
    Widget cip(String tekst, String? id) {
      final on = izabran == id;
      final boje = context.adminColors;
      final stil = kompaktnoDugme(
        visina: 34,
        padding: 13,
        tekst: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 13.5,
          fontWeight: on ? FontWeight.w600 : FontWeight.w500,
        ),
      );
      void izaberi() => ref.read(filterRadnikaProvider.notifier).postavi(id);
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: on
            ? FilledButton(
                onPressed: izaberi,
                style: stil.merge(
                  FilledButton.styleFrom(
                    backgroundColor: boje.accent,
                    foregroundColor: boje.onAccent,
                  ),
                ),
                child: Text(tekst),
              )
            : OutlinedButton(
                onPressed: izaberi,
                style: stil,
                child: Text(tekst),
              ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          cip('Svi', null),
          for (final r in aktivni) cip(prvoIme(r.name), r.id),
        ],
      ),
    );
  }
}

/// Kolone reda: vrijeme | linija sa tačkom | sadržaj.
class _Red extends StatelessWidget {
  const _Red({
    required this.telefon,
    required this.vrijeme,
    required this.tacka,
    required this.child,
  });

  final bool telefon;
  final Widget? vrijeme;
  final Widget? tacka;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: telefon ? 48 : 60,
              child: Padding(
                padding: const EdgeInsets.only(top: 9),
                child: vrijeme ?? const SizedBox.shrink(),
              ),
            ),
            SizedBox(
              width: telefon ? 18 : 24,
              child: Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -6,
                    bottom: -6,
                    child: Container(width: 1, color: boje.separator),
                  ),
                  if (tacka != null) Positioned(top: 14, child: tacka!),
                ],
              ),
            ),
            SizedBox(width: telefon ? 6 : 10),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _Tacka extends StatelessWidget {
  const _Tacka({required this.boja, this.puna = false, this.velicina = 9});

  final Color boja;
  final bool puna;
  final double velicina;

  @override
  Widget build(BuildContext context) => Container(
    width: velicina,
    height: velicina,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: puna ? boja : context.adminColors.surface,
      border: Border.all(color: boja, width: 1.5),
    ),
  );
}

class _TerminRed extends ConsumerWidget {
  const _TerminRed({
    required this.termin,
    required this.sada,
    required this.telefon,
    required this.prikaziRadnika,
  });

  final Appointment termin;
  final DateTime sada;
  final bool telefon;
  final bool prikaziRadnika;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final opis = opisTermina(
      termin,
      usluge: ref.watch(uslugePoIdProvider),
      radnici: ref.watch(radniciPoIdProvider),
    );
    final uToku = terminUToku(termin, sada);
    final prosao = terminProsao(termin, sada);
    final ceka = termin.status == AppointmentStatus.pending;
    final otkazan = termin.status == AppointmentStatus.cancelled;
    final sljedeci =
        sljedeciTermin(
          ref.watch(danasPrikazProvider).valueOrNull ?? const [],
          sada,
        )?.id ==
        termin.id;
    final izabran =
        imaStalniPanel(context) && terminZaPanel(ref, sada)?.id == termin.id;

    final tacka = switch ((uToku, prosao, ceka)) {
      (true, _, _) => _Tacka(boja: boje.accent, puna: true, velicina: 10),
      (_, true, _) => _Tacka(boja: boje.separator, puna: true),
      (_, _, true) => _Tacka(boja: boje.textMuted),
      _ => _Tacka(boja: boje.accent),
    };

    final podnaslov = [
      ?opis.usluga,
      if (prikaziRadnika)
        if (opis.majstor case final m?) prvoIme(m),
      if (opis.cijena case final c?) iznosKm(c),
    ].join(' · ');

    final kartica = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: termin.customerName),
                      if (sljedeci)
                        TextSpan(
                          text: '  ${zaKoliko(termin, sada)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: boje.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    decoration: otkazan ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (podnaslov.isNotEmpty)
                  Text(
                    podnaslov,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: boje.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AdminSpacing.sm),
          StatusOznaka(termin: termin, sada: sada),
        ],
      ),
    );

    final oblik = BorderRadius.circular(AdminRadius.base);
    Widget sadrzaj = RubZahtjeva(
      ceka: ceka,
      boja: boje.textMuted,
      child: Material(
        color: uToku ? boje.accentTint : boje.surface,
        shape: RoundedRectangleBorder(
          borderRadius: oblik,
          side: ceka
              ? BorderSide.none
              : BorderSide(
                  color: izabran ? boje.accent : boje.separator,
                  width: izabran ? 2 : AdminSize.hairline,
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => otvoriTermin(context, ref, termin),
          child: kartica,
        ),
      ),
    );
    if (prosao && !uToku) sadrzaj = Opacity(opacity: 0.5, child: sadrzaj);

    return _Red(
      telefon: telefon,
      tacka: tacka,
      vrijeme: Opacity(
        opacity: prosao && !uToku ? 0.5 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vrijemeHhMm(termin.startTime),
              style: AdminText.timeLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: uToku ? boje.accent : boje.ink,
              ),
            ),
            Text(
              vrijemeHhMm(termin.endTime),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: boje.textSecondary,
              ),
            ),
          ],
        ),
      ),
      child: sadrzaj,
    );
  }
}

/// Linija „Sad 13:12".
class _SadRed extends StatelessWidget {
  const _SadRed({required this.minuta, required this.telefon});

  final int minuta;
  final bool telefon;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            SizedBox(
              width: telefon ? 48 : 60,
              child: Text(
                'Sad ${hhmm(minuta)}',
                style: AdminText.time.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: boje.accent,
                ),
              ),
            ),
            SizedBox(
              width: telefon ? 18 : 24,
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: boje.accent,
                    border: Border.all(color: boje.accentTint, width: 2),
                  ),
                ),
              ),
            ),
            SizedBox(width: telefon ? 6 : 10),
            Expanded(child: Container(height: 2, color: boje.accent)),
          ],
        ),
      ),
    );
  }
}

/// Slobodno, pauza ili blokada — šrafiran red bez kartice.
class _TihiRed extends StatelessWidget {
  const _TihiRed({
    required this.od,
    required this.tekst,
    required this.telefon,
  });

  final int od;
  final String tekst;
  final bool telefon;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return _Red(
      telefon: telefon,
      tacka: null,
      vrijeme: Text(
        hhmm(od),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: boje.textSecondary),
      ),
      child: CustomPaint(
        painter: _Srafura(boja: boje.neutralTint),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: Text(
            tekst,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: boje.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kose linije na 135° — isti jezik kao neradno vrijeme u kalendaru.
class _Srafura extends CustomPainter {
  const _Srafura({required this.boja});

  final Color boja;

  @override
  void paint(Canvas canvas, Size size) {
    final olovka = Paint()
      ..color = boja
      ..strokeWidth = 4;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(AdminRadius.base),
      ),
    );
    for (var x = -size.height; x < size.width; x += 12) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        olovka,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Srafura old) => old.boja != boja;
}
