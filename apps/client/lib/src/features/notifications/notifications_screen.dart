import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/load_error.dart';
import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../booking/date_labels.dart';
import 'notifications_provider.dart';

/// `/notifications` — „Obavijesti" (`SPEC.md` 5j, `10-obavijesti.png`).
///
/// Lista push poruka koje je klijent dobio u ovom salonu, najnovije prve (task 70). Izvor je
/// `my_notifications`: jedna stavka po (termin, tip), bez obzira na broj uređaja.
///
/// **Nepročitano** je jača ivica kartice, kao na handoffu, uz oznaku za čitač ekrana.
/// Otvaranje liste ih označava pročitanim u bazi, ali ova lista ostaje kakva je stigla —
/// korisnik u istom pogledu i dalje vidi šta je novo.
///
/// Tap vodi na „Moji termini", isto kao tap na push (`send-push` šalje `route:
/// /appointments`). Detalj termina u klijentu još ne postoji.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  /// Da se `markAllRead` ne zove na svaki rebuild iste liste.
  List<ClientNotification>? _oznaceno;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Push je mogao stići dok je app bila u pozadini.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(myNotificationsProvider);
    }
  }

  void _oznaciProcitano(List<ClientNotification> lista) {
    if (identical(lista, _oznaceno) || lista.every((n) => n.read)) return;
    _oznaceno = lista;
    // Neuspjeh nije greška za korisnika: stavka ostaje „nova" do sljedećeg otvaranja.
    ref
        .read(notificationRepositoryProvider)
        .markAllRead()
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final obavijesti = ref.watch(myNotificationsProvider);

    if (obavijesti case AsyncData(:final value)) _oznaciProcitano(value);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xl,
                AppSpacing.gutter,
                AppSpacing.lg,
              ),
              child: Text(
                l10n.notificationsTitle,
                style: theme.textTheme.displaySmall,
              ),
            ),
            Expanded(
              child: switch (obavijesti) {
                AsyncValue(:final value?) when value.isNotEmpty => _Lista(
                  obavijesti: value,
                ),
                AsyncValue(hasValue: true) => EmptyState(
                  icon: LucideIcons.bell,
                  message: l10n.notificationsEmpty,
                  actionLabel: l10n.notificationsEmptyAction,
                  onAction: () => context.go(ClientRoute.appointments.path),
                ),
                AsyncError(:final error) => LoadError(
                  error: error,
                  onRetry: () => ref.invalidate(myNotificationsProvider),
                ),
                // Skeleton, ne spinner — pravilo koje je postavio prvi ekran (task 10).
                _ => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                  child: Column(
                    children: [
                      SkeletonLoader(height: 110),
                      SizedBox(height: AppSpacing.md),
                      SkeletonLoader(height: 110),
                    ],
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Lista extends ConsumerWidget {
  const _Lista({required this.obavijesti});

  final List<ClientNotification> obavijesti;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sada = ref.watch(notificationsNowProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(myNotificationsProvider.future),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        itemCount: obavijesti.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) =>
            _Kartica(obavijest: obavijesti[i], sada: sada),
      ),
    );
  }
}

class _Kartica extends StatelessWidget {
  const _Kartica({required this.obavijest, required this.sada});

  final ClientNotification obavijest;
  final DateTime sada;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nova = !obavijest.read;
    final kada = notificationWhen(l10n, obavijest.createdAt.toLocal(), sada);
    final naslov = notificationTitle(l10n, obavijest.type);
    final opis = notificationBody(l10n, obavijest);

    return Semantics(
      button: true,
      label: [if (nova) l10n.notificationUnread, kada, naslov, opis].join('. '),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.go(ClientRoute.appointments.path),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            // Nepročitano je jača ivica, kao na handoffu — oblik, ne boja brenda.
            border: Border.all(color: nova ? scheme.onSurface : scheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kada,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: nova ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(naslov, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                opis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// „Danas · 09:12", „Jučer · 18:40", a starije samo „12.04." — kao na handoffu.
@visibleForTesting
String notificationWhen(AppLocalizations l10n, DateTime kada, DateTime sada) {
  final dan = DateTime(kada.year, kada.month, kada.day);
  final danas = DateTime(sada.year, sada.month, sada.day);
  final razlika = danas.difference(dan).inDays;
  final sat =
      '${kada.hour.toString().padLeft(2, '0')}:'
      '${kada.minute.toString().padLeft(2, '0')}';
  return switch (razlika) {
    0 => '${l10n.notificationsToday} · $sat',
    1 => '${l10n.notificationsYesterday} · $sat',
    _ =>
      '${kada.day.toString().padLeft(2, '0')}.'
          '${kada.month.toString().padLeft(2, '0')}.',
  };
}

/// Naslov po tipu. Nepoznat tip dobija opšti naslov — v. [ClientNotification.type].
@visibleForTesting
String notificationTitle(AppLocalizations l10n, String type) => switch (type) {
  'confirmed' => l10n.notificationTypeConfirmed,
  'rejected' => l10n.notificationTypeRejected,
  'cancelled' => l10n.notificationTypeCancelled,
  'expired' => l10n.notificationTypeExpired,
  'review_request' => l10n.notificationTypeReviewRequest,
  'waitlist_offer' => l10n.notificationTypeWaitlistOffer,
  'reminder_d1' || 'reminder_h3' => l10n.notificationTypeReminder,
  _ => l10n.notificationTypeOther,
};

/// „Fade šišanje · Emir · srijeda 20.05. u 14:30".
///
/// Radnik ide iza tačke, a ne „kod Emira": padež imena se ne može izvesti iz baze.
/// Ponuda liste čekanja nema vrijeme (task 68), pa opis staje na danu: „Fade · Emir ·
/// utorak 27.10.".
@visibleForTesting
String notificationBody(AppLocalizations l10n, ClientNotification n) {
  final datum =
      '${weekdayLong(l10n, n.date.weekday).toLowerCase()} '
      '${n.date.day.toString().padLeft(2, '0')}.'
      '${n.date.month.toString().padLeft(2, '0')}.';
  final pocetak = n.startTime;
  final kad = pocetak == null
      ? datum
      : l10n.notificationBodyWhen(datum, pocetak.format());
  return [?n.serviceName, ?n.employeeName, kad].join(' · ');
}
