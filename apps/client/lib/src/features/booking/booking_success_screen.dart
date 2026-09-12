import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/router/app_router.dart';
import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'booking_flow_provider.dart';
import 'booking_submit_provider.dart';
import 'date_labels.dart';

/// Ekran nakon slanja (`prototype/ui/screenshots/07-zahtjev-poslan.png`).
///
/// **Ne kaže da je termin potvrđen, jer nije.** `book_appointment` uvijek pravi `pending`
/// red — i kad salon radi u `auto` modu, potvrdu dodjeljuje baza, ne ovaj poziv
/// (`docs/01 §18`). Lažno "Potvrđeno!" ovdje je najskuplja moguća greška u proizvodu:
/// korisnik dođe u salon koji ga ne očekuje. Zato kicker kaže **"ZAHTJEV JE POSLAN"**, a
/// status u tabeli stoji kao "Na čekanju".
///
/// **Nema konfeta.** Prvi prolaz ih je imao, jer ih DoD taska spominje "kao u prototipu";
/// sam prototip ih nema — ima hero površinu, kicker, serif naslov i tabelu. Slavlje nad
/// zahtjevom koji salon još nije potvrdio je obećanje koje ekran ne smije dati.
class BookingSuccessScreen extends ConsumerWidget {
  const BookingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vertical = verticalOf(ref);
    final appointment = ref.watch(lastBookingProvider);

    final services = ref.watch(servicesProvider).valueOrNull;
    final usluga = appointment == null || services == null
        ? null
        : services.where((s) => s.id == appointment.serviceId).firstOrNull;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Hero površina. Prave fotografije još nema (`prototype/ui/README.md`:
                // svih 45 slotova su placeholderi), pa stoji brand prelaz — ne prazan
                // prostor, koji bi skratio ekran i pomjerio sve ispod kad slika stigne.
                const _Hero(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.xxl,
                    AppSpacing.gutter,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.bookingSuccessKicker,
                        style: kicker(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.bookingSuccessHeadline,
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.bookingSuccessBody,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      if (appointment != null)
                        SpecCard(
                          header: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                appointment.startTime.format(),
                                style: theme.textTheme.displayMedium,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  formatDateWithWeekday(l10n, appointment.date),
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          rows: [
                            SpecRow(
                              label: vertical.terms.serviceSingular,
                              value: usluga == null
                                  ? null
                                  : vertical.features.prices
                                  ? '${usluga.name} · ${formatPrice(usluga.price)}'
                                  : usluga.name,
                            ),
                            SpecRow(
                              label: l10n.bookingStatusLabel,
                              trailing: StatusBadge(
                                label: l10n.bookingStatusPending,
                                tone: StatusTone.warning,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: l10n.bookingAddToCalendar,
                        variant: AppButtonVariant.outline,
                        // Kalendar uređaja dolazi sa "Moji termini" u Sprintu 2 —
                        // dugme stoji jer je dio ekrana, ali se ne pretvara da radi.
                        onPressed: null,
                      ),
                    ],
                  ).animate().fadeIn(duration: AppDuration.slow),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            child: AppButton(
              label: vertical.terms.myAppointments,
              onPressed: () {
                // Flow i zapamćeni termin se čiste **na izlasku**, ne pri otvaranju ovog
                // ekrana: `pop` na uređaju bi inače vratio korisnika na prazan sažetak.
                ref.read(bookingFlowProvider.notifier).reset();
                ref.read(lastBookingProvider.notifier).clear();
                context.go(ClientRoute.appointments.path);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Površina na vrhu ekrana, do dolaska pravih fotografija.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.primary, scheme.surface],
        ),
      ),
    );
  }
}
