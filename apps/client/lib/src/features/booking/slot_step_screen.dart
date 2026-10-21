import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import 'booking_flow_provider.dart';
import 'booking_flow_state.dart';
import 'date_labels.dart';
import 'widgets/booking_step_scaffold.dart';
import '../waitlist/waitlist_day_panel.dart';
import '../waitlist/waitlist_providers.dart';

/// Korak 3 — kada (`prototype/ui/screenshots/05-korak3-vrijeme.png`).
///
/// ## Ovdje se ne računa ništa
///
/// Kalendar prikazuje mjesec, a **koji su dani slobodni kaže `get_available_dates`**.
/// Mreža vremena je ono što je vratio `get_available_slots`, bez ijednog filtera iznad
/// toga: nema oduzimanja buffera, nema izbacivanja prošlih vremena, nema
/// `minAdvanceBookingHours` provjere. Sve je to već primijenjeno u funkciji (task 05), i
/// kad bi se ponovilo ovdje, ponovilo bi se pogrešno prvi put kad se pravilo promijeni u
/// migraciji.
///
/// Podjela na "Prijepodne" i "Poslijepodne" je **prikaz, ne pravilo** — granica je podne i
/// služi da mreža od dvadeset chipova ima dvije tačke oslonca.
///
/// ## Dva moda
///
/// `exact_slot` traži dan **i** vrijeme. `date_only` (`docs/05 §4.1`) traži samo dan —
/// vrijeme dodjeljuje salon, pa mreža vremena ne postoji i korak se završava izborom dana.
/// Razlika dolazi iz vertikale kroz `bookingDateOnlyProvider`, ne iz konstante: isti build
/// služi i frizera i ordinaciju.
class SlotStepScreen extends ConsumerStatefulWidget {
  const SlotStepScreen({super.key});

  @override
  ConsumerState<SlotStepScreen> createState() => _SlotStepScreenState();
}

class _SlotStepScreenState extends ConsumerState<SlotStepScreen> {
  /// Koji je mjesec prikazan. Pomjera ga korisnik strelicama; nije dio stanja flowa, jer
  /// listanje mjeseca nije izbor — izbor je dan.
  int _pomakMjeseci = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final flow = ref.watch(bookingFlowProvider);
    final dateOnly = ref.watch(bookingDateOnlyProvider);
    final danas = ref.watch(bookingTodayProvider);

    final serviceId = flow.serviceId;
    // `BookingStepScaffold` već pokriva dolazak bez usluge praznim stanjem; ovdje samo
    // ne smije pući prije nego što ga prikaže.
    if (serviceId == null) {
      return BookingStepScaffold(
        step: BookingStep.slot,
        title: dateOnly ? l10n.bookingPickDate : l10n.bookingPickTime,
        child: const SizedBox.shrink(),
      );
    }

    final spreman = flow.isStepComplete(BookingStep.slot, dateOnly: dateOnly);
    final mjesec = monthOffsetFrom(danas, _pomakMjeseci);
    // Prozor je danas..danas+N, oba kraja uključena, kao u bazi (`get_available_slots`,
    // `join_waitlist`): N dana unaprijed **od** danas je N+1 dan. Sa N dana bi kalendar
    // prešutio zadnji dan, a lista čekanja rekla „do 19.11." gdje baza kaže „do 20.11."
    final raspon = daysFrom(
      danas,
      ref.watch(bookingMaxAdvanceDaysProvider) + 1,
    );

    final upitRaspona = DateRangeQuery(
      serviceId: serviceId,
      from: raspon.first,
      to: raspon.last,
      employeeId: flow.employeeId,
    );
    final dostupniDani = ref.watch(availableDatesProvider(upitRaspona));
    // Puni dani se tapaju i nude listu čekanja (task 68 i 91). Samo u `exact_slot`: u
    // `date_only` korak završava izbor dana, pa pun dan nema gdje ponuditi upis. Greška
    // ovog upita ne ruši kalendar — bez nje su puni dani samo nedostupni, kao prije.
    final puniDani = dateOnly
        ? const <LocalDate>{}
        : ref.watch(waitlistFullDatesProvider(upitRaspona)).valueOrNull ??
              const <LocalDate>{};

    return BookingStepScaffold(
      step: BookingStep.slot,
      title: dateOnly ? l10n.bookingPickDate : l10n.bookingPickTime,
      subtitle: dateOnly ? l10n.bookingDateOnlyNote : l10n.bookingPickTimeHint,
      cta: AppButton(
        label: spreman
            ? l10n.bookingNext
            : dateOnly
            ? l10n.bookingPickDate
            : l10n.bookingPickTime,
        onPressed: spreman
            ? () => context.push(BookingStep.details.path)
            : null,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          _Kalendar(
            mjesec: mjesec,
            dostupni: dostupniDani,
            puni: puniDani,
            izabran: flow.date,
            // Unazad se ne ide ispod tekućeg mjeseca — prošli dani ionako nisu
            // dostupni, a prazan mjesec izgleda kao kvar.
            onPrethodni: _pomakMjeseci > 0
                ? () => setState(() => _pomakMjeseci--)
                : null,
            onSljedeci: () => setState(() => _pomakMjeseci++),
            onIzbor: (datum) =>
                ref.read(bookingFlowProvider.notifier).chooseDate(datum),
          ),
          if (!dateOnly) ...[
            const SizedBox(height: AppSpacing.xxl),
            _Vremena(
              serviceId: serviceId,
              flow: flow,
              pun: flow.date != null && puniDani.contains(flow.date),
              // Prvi slobodan dan poslije izabranog: iz iste liste kao kalendar, ne
              // izračunat ovdje. Lista je sortirana (`order by 1` u bazi).
              prviSlobodan: flow.date == null
                  ? null
                  : (dostupniDani.valueOrNull ?? const <LocalDate>[])
                        .where((d) => d.compareTo(flow.date!) > 0)
                        .fold<LocalDate?>(
                          null,
                          (min, d) =>
                              min == null || d.compareTo(min) < 0 ? d : min,
                        ),
              prviSlobodanPoznat: dostupniDani.hasValue,
              krajProzora: raspon.last,
            ),
          ],
        ],
      ),
    );
  }
}

/// Mjesečna mreža dana. Dani bez slobodnog termina ostaju vidljivi, ali se ne tapaju.
class _Kalendar extends ConsumerWidget {
  const _Kalendar({
    required this.mjesec,
    required this.dostupni,
    required this.puni,
    required this.izabran,
    required this.onIzbor,
    required this.onPrethodni,
    required this.onSljedeci,
  });

  final LocalDate mjesec;
  final AsyncValue<List<LocalDate>> dostupni;

  /// Dani koji rade, a popunjeni su — tapaju se, precrtani (task 68).
  final Set<LocalDate> puni;
  final LocalDate? izabran;
  final ValueChanged<LocalDate> onIzbor;
  final VoidCallback? onPrethodni;
  final VoidCallback onSljedeci;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (dostupni.isLoading) {
      return const SkeletonLoader(height: 320);
    }

    if (dostupni.hasError) {
      return EmptyState(
        message: l10n.bookingServicesUnavailable,
        icon: LucideIcons.cloudOff,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(availableDatesProvider),
      );
    }

    final slobodni = (dostupni.valueOrNull ?? const <LocalDate>[]).toSet();
    if (slobodni.isEmpty && puni.isEmpty) {
      return EmptyState(
        message: l10n.bookingNoDates,
        icon: LucideIcons.calendarX,
      );
    }

    final daniMjeseca = daysOfMonth(mjesec);

    return CalendarMonth(
      monthLabel: formatMonth(l10n, mjesec),
      weekdayLabels: weekdayInitials(l10n),
      // Prvi u mjesecu mora pasti na svoj dan u sedmici, inače mreža laže o datumu.
      leadingEmptyCells: daniMjeseca.first.weekday - DateTime.monday,
      selectedId: izabran?.format(),
      onSelect: (id) => onIzbor(LocalDate.parse(id)),
      onPreviousMonth: onPrethodni,
      onNextMonth: onSljedeci,
      days: [
        for (final dan in daniMjeseca)
          CalendarDay(
            id: dan.format(),
            label: dan.day.toString(),
            available: slobodni.contains(dan),
            full: puni.contains(dan),
            semanticLabel: puni.contains(dan)
                ? l10n.calendarDayFull(dan.day.toString())
                : null,
          ),
      ],
    );
  }
}

/// Slobodna vremena za izabrani dan, u dvije grupe.
class _Vremena extends ConsumerWidget {
  const _Vremena({
    required this.serviceId,
    required this.flow,
    required this.pun,
    required this.prviSlobodan,
    required this.prviSlobodanPoznat,
    required this.krajProzora,
  });

  final String serviceId;
  final BookingFlowState flow;

  /// Izabran dan radi, a nema slobodnog vremena — mjesto mreže zauzima lista čekanja.
  final bool pun;

  /// Prvi dan poslije izabranog koji ima slobodnog vremena (task 91); `null` kad ga nema.
  final LocalDate? prviSlobodan;

  /// Je li lista slobodnih dana stigla (v. [WaitlistDayPanel.firstFreeKnown]).
  final bool prviSlobodanPoznat;

  /// Zadnji dan prozora rezervacije.
  final LocalDate krajProzora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final datum = flow.date;

    if (datum == null) {
      return EmptyState(
        message: l10n.bookingPickDate,
        icon: LucideIcons.calendar,
      );
    }

    final upit = SlotQuery(
      serviceId: serviceId,
      date: datum,
      employeeId: flow.employeeId,
    );
    final slotovi = ref.watch(availableSlotsProvider(upit));

    return switch (slotovi) {
      AsyncData(:final value) when value.isEmpty && pun => WaitlistDayPanel(
        serviceId: serviceId,
        date: datum,
        employeeId: flow.employeeId,
        firstFree: prviSlobodan,
        firstFreeKnown: prviSlobodanPoznat,
        windowEnd: krajProzora,
      ),
      AsyncData(:final value) when value.isEmpty => EmptyState(
        message: l10n.bookingDayFull,
        icon: LucideIcons.calendarX,
      ),
      // `distinctTimes` svodi redove na vremena: kad radnik nije izabran, funkcija
      // vrati isto vrijeme po svakom slobodnom radniku, pa bi korisnik bez ovoga
      // vidio "09:00" tri puta.
      AsyncData(:final value) => _Grupe(
        vremena: value.distinctTimes,
        izabrano: flow.startTime,
        onIzbor: (vrijeme) => ref
            .read(bookingFlowProvider.notifier)
            .chooseSlot(date: datum, startTime: vrijeme),
      ),
      AsyncError() => EmptyState(
        message: l10n.bookingServicesUnavailable,
        icon: LucideIcons.cloudOff,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(availableSlotsProvider(upit)),
      ),
      _ => const SkeletonLoader(height: 200),
    };
  }
}

/// "Prijepodne" i "Poslijepodne", svaka sa svojom mrežom chipova.
class _Grupe extends StatelessWidget {
  const _Grupe({
    required this.vremena,
    required this.izabrano,
    required this.onIzbor,
  });

  final List<LocalTime> vremena;
  final LocalTime? izabrano;
  final ValueChanged<LocalTime> onIzbor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prije = [
      for (final v in vremena)
        if (v.hour < 12) v,
    ];
    final poslije = [
      for (final v in vremena)
        if (v.hour >= 12) v,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prije.isNotEmpty)
          _Grupa(
            naslov: l10n.bookingMorning,
            vremena: prije,
            izabrano: izabrano,
            onIzbor: onIzbor,
          ),
        if (prije.isNotEmpty && poslije.isNotEmpty)
          const SizedBox(height: AppSpacing.xxl),
        if (poslije.isNotEmpty)
          _Grupa(
            naslov: l10n.bookingAfternoon,
            vremena: poslije,
            izabrano: izabrano,
            onIzbor: onIzbor,
          ),
      ],
    );
  }
}

class _Grupa extends StatelessWidget {
  const _Grupa({
    required this.naslov,
    required this.vremena,
    required this.izabrano,
    required this.onIzbor,
  });

  final String naslov;
  final List<LocalTime> vremena;
  final LocalTime? izabrano;
  final ValueChanged<LocalTime> onIzbor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(naslov, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            // Tri po redu na 402 px (`prototype/ui` 5e), a na širem ekranu više — bez
            // fiksnog broja kolona, koji na tabletu razvuče chip preko pola ekrana.
            maxCrossAxisExtent: 130,
            mainAxisExtent: AppSize.timeSlot,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemCount: vremena.length,
          itemBuilder: (context, index) {
            final vrijeme = vremena[index];
            return TimeSlotChip(
              label: vrijeme.format(),
              selected: vrijeme == izabrano,
              onTap: () => onIzbor(vrijeme),
            );
          },
        ),
      ],
    );
  }
}
