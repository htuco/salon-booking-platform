import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../booking/date_labels.dart';
import 'waitlist_providers.dart';

/// Pun dan u koraku 3 (task 68 i 91): umjesto mreže vremena, upis na listu čekanja.
///
/// Panel kaže **prvi slobodan termin** poslije izabranog dana i nudi „Obavijesti me ako se
/// oslobodi ranije". Upis je za uslugu i radnika **iz flowa** — „Bilo ko" je upis bez radnika —
/// od izabranog dana do dana prije prvog slobodnog termina. Taj raspon računa baza
/// (`join_waitlist`), a ekran ga samo prikazuje iz liste upisa; [firstFree] je prvi dan iz
/// `get_available_dates` poslije izabranog, isto pravilo slotova kojim baza računa granicu.
/// Upis ne drži mjesto (ADR-0031), pa tekst to kaže, umjesto da obeća termin.
///
/// Upis je jedan po usluzi i radniku: pun dan u rasponu pokazuje upis i njegovu granicu, a pun
/// dan van raspona kaže da klijent već čeka u drugom rasponu i nudi odjavu — baza postojeći
/// upis ne proširuje.
///
/// Neprijavljen korisnik ide na prijavu i vraća se ovdje (`?from=`); flow ostaje živ jer je
/// ovaj ekran i dalje na steku ispod prijave.
///
/// Upisan klijent bez dozvole za notifikacije ne dobija „Javićemo vam", nego rečenicu da
/// obavijesti nisu uključene: ponuda ide samo uređaju sa push tokenom.
class WaitlistDayPanel extends ConsumerStatefulWidget {
  const WaitlistDayPanel({
    required this.serviceId,
    required this.date,
    required this.windowEnd,
    required this.firstFreeKnown,
    this.employeeId,
    this.firstFree,
    super.key,
  });

  final String serviceId;
  final LocalDate date;
  final String? employeeId;

  /// Prvi dan poslije [date] sa slobodnim vremenom; `null` kad ga u prozoru nema.
  final LocalDate? firstFree;

  /// Je li lista slobodnih dana stigla. Dok nije (ili je pala), panel o prvom slobodnom
  /// terminu ne kaže ništa: „nema slobodnog" izvedeno iz greške bi bila neistina.
  final bool firstFreeKnown;

  /// Zadnji dan prozora rezervacije — do njega upis čeka kad slobodnog dana nema.
  final LocalDate windowEnd;

  @override
  ConsumerState<WaitlistDayPanel> createState() => _WaitlistDayPanelState();
}

class _WaitlistDayPanelState extends ConsumerState<WaitlistDayPanel> {
  // Dozvola za notifikacije se mijenja van aplikacije. Korisnik kojem panel kaže „uključite
  // ih u postavkama" vraća se ovdje, pa se dozvola tada čita ponovo.
  late final AppLifecycleListener _zivot;

  @override
  void initState() {
    super.initState();
    _zivot = AppLifecycleListener(
      onResume: () => ref.invalidate(pushPermissionProvider),
    );
  }

  @override
  void dispose() {
    _zivot.dispose();
    super.dispose();
  }

  String get _kljuc => waitlistDayKey(
    serviceId: widget.serviceId,
    employeeId: widget.employeeId,
  );

  WaitlistEntry? _moj(List<WaitlistEntry> upisi) => upisi
      .where(
        (u) =>
            u.serviceId == widget.serviceId &&
            u.employeeId == widget.employeeId,
      )
      .firstOrNull;

  Future<void> _upisi() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final uspjeh = await ref
        .read(waitlistActionProvider(_kljuc).notifier)
        .join(
          serviceId: widget.serviceId,
          from: widget.date,
          employeeId: widget.employeeId,
        );
    if (!uspjeh) _greska(messenger, l10n.waitlistFailed);
  }

  Future<void> _odjavi(WaitlistEntry upis) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final uspjeh = await ref
        .read(waitlistActionProvider(_kljuc).notifier)
        .leave(upis.id);
    if (!uspjeh) _greska(messenger, l10n.waitlistLeaveFailed);
  }

  /// Rečenica baze (`PT400` slobodan dan ili raspon bez punog dana, `PT429` tri upisa) ide na
  /// ekran; ostalo dobija [rezerva], posebnu za upis i za odjavu.
  void _greska(ScaffoldMessengerState messenger, String rezerva) {
    final greska = ref.read(waitlistActionProvider(_kljuc)).error;
    final poruka = greska is ApiError ? greska.displayMessage : null;
    messenger.showSnackBar(SnackBar(content: Text(poruka ?? rezerva)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final prijavljen = ref.watch(isSignedInProvider);
    final upisi = ref.watch(myWaitlistProvider);
    final moj = _moj(upisi.valueOrNull ?? const []);
    final radi = ref.watch(waitlistActionProvider(_kljuc)).isLoading;
    // Ponuda ide samo uređaju sa push tokenom (ADR-0031). Dok se dozvola čita, panel ne
    // tvrdi da je isključena.
    final bezObavijesti =
        moj != null && ref.watch(pushPermissionProvider).valueOrNull == false;

    final appointment = verticalOf(ref).terms.appointmentSingular.toLowerCase();
    // Upis je jedan po usluzi i radniku, a baza ga ne proširuje: pun dan van njegovog raspona
    // ne smije reći „na listi ste", jer ponuda za taj dan ne stiže.
    final pokriva = moj != null && moj.covers(widget.date);
    // „Ranije" ima smisla samo kad postoji prvi slobodan termin od kojeg je nešto ranije.
    final ranije = widget.firstFree != null;
    final prvi = widget.firstFree;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            !pokriva
                ? LucideIcons.calendarX
                : bezObavijesti
                ? LucideIcons.bellOff
                : LucideIcons.bellRing,
            size: AppSize.iconEmptyState,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (moj == null && widget.firstFreeKnown) ...[
            Text(
              prvi == null
                  ? l10n.waitlistNoFreeUntil(formatDayMonth(widget.windowEnd))
                  : l10n.waitlistFirstFree(
                      appointment,
                      '${weekdayLong(l10n, prvi.weekday).toLowerCase()}, '
                      '${formatDate(prvi)}',
                    ),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            moj == null
                ? (ranije ? l10n.waitlistDayFull : l10n.waitlistDayFullNoFree)
                : !pokriva
                ? l10n.waitlistOtherRange(
                    formatDayMonth(moj.dateFrom),
                    formatDayMonth(moj.dateTo),
                  )
                : bezObavijesti
                ? l10n.waitlistJoinedNoPush(formatDayMonth(moj.dateTo))
                : l10n.waitlistJoined(formatDayMonth(moj.dateTo)),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (moj == null)
            AppButton(
              label: ranije ? l10n.waitlistJoin : l10n.waitlistJoinNoFree,
              variant: AppButtonVariant.secondary,
              icon: LucideIcons.bell,
              loading: radi || (prijavljen && upisi.isLoading),
              onPressed: !prijavljen
                  ? () => context.push(
                      Uri(
                        path: ClientRoute.login.path,
                        queryParameters: {'from': ClientRoute.bookSlot.path},
                      ).toString(),
                    )
                  : _upisi,
            )
          else
            AppButton(
              label: l10n.waitlistLeave,
              variant: AppButtonVariant.outline,
              loading: radi,
              onPressed: () => _odjavi(moj),
            ),
        ],
      ),
    );
  }
}
