import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/router/app_router.dart';
import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../appointments/appointment_labels.dart';
import 'booking_flow_provider.dart';
import 'booking_submit_provider.dart';
import 'date_labels.dart';
import '../../core/prikaz_cijena.dart';

/// Ekran nakon slanja (`prototype/ui/screenshots/07-zahtjev-poslan.png`).
///
/// **Ekran ne pretpostavlja ishod nego ga čita.** Do taska 37 je `book_appointment` uvijek
/// vraćao `pending`, pa je ekran smio hardkodirati "ZAHTJEV JE POSLAN" i "Na čekanju". Od
/// tada `salon_settings.booking_mode = 'auto'` pravi red koji je **već `confirmed`**, i
/// tekst se grana po `appointment.status` — nikad po postavci, koju ovaj ekran ni ne vidi.
///
/// Greška je skupa u **oba** smjera. Lažno "Potvrđeno!" znači da korisnik dođe u salon koji
/// ga ne očekuje; lažno "čeka potvrdu" nad potvrđenim terminom znači da čeka obavijest koja
/// nikad neće stići, i zove salon da pita nešto što mu je aplikacija već rekla.
///
/// Copy `manual` grane je **doslovno iz handoffa** ("Salon vas je vidio"). Barber je 1:1;
/// druge vertikale dobijaju svoj dizajn, pa se rod djelatnosti ("Ordinacija vas je
/// vidjela") rješava tamo. `auto` grana nema svoj canvas u handoffu — oblik ekrana ostaje
/// isti, mijenja se samo tekst i ton badgea.
///
/// **Badge ide kroz `statusLabel`/`statusTone`**, isti helper koji koriste kartica i detalj
/// termina. Vlastita mapa ovdje je bila kopija koja je slučajno bila tačna dok je status
/// bio samo jedan.
///
/// **Nema konfeta.** Prvi prolaz ih je imao, jer ih DoD taska spominje "kao u prototipu";
/// sam prototip ih nema — ima hero površinu, kicker, serif naslov i tabelu.
class BookingSuccessScreen extends ConsumerWidget {
  const BookingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vertical = verticalOf(ref);
    final appointment = ref.watch(lastBookingProvider);

    // Dok termin nije stigao, ekran stoji u `manual` tekstu: to je stanje koje ne obećava
    // ništa. Obrnuto bi značilo da prazan ekran na trenutak tvrdi da je termin potvrđen.
    final potvrdjen = appointment?.status == AppointmentStatus.confirmed;

    final services = ref.watch(servicesProvider).valueOrNull;
    final usluga = appointment == null || services == null
        ? null
        : services.where((s) => s.id == appointment.serviceId).firstOrNull;

    // Flow i zapamćeni termin se čiste **na izlasku**, ne pri otvaranju ovog ekrana:
    // `pop` na uređaju bi inače vratio korisnika na prazan sažetak.
    void izadji(String ruta) {
      ref.read(bookingFlowProvider.notifier).reset();
      ref.read(lastBookingProvider.notifier).clear();
      context.go(ruta);
    }

    // Flow ide kroz `context.go`, pa ispod ovog ekrana nema ničega: sistemski back bi
    // na Androidu zatvorio aplikaciju. Termin je poslan — u flow se ne vraća, back vodi
    // na Početnu.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) izadji(ClientRoute.home.path);
      },
      child: Scaffold(
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
                          potvrdjen
                              ? l10n.bookingSuccessKickerConfirmed
                              : l10n.bookingSuccessKicker,
                          style: kicker(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          potvrdjen
                              ? l10n.bookingSuccessHeadlineConfirmed
                              : l10n.bookingSuccessHeadline,
                          style: theme.textTheme.displaySmall,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          potvrdjen
                              ? l10n.bookingSuccessBodyConfirmed
                              : l10n.bookingSuccessBody,
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
                                    formatDateWithWeekday(
                                      l10n,
                                      appointment.date,
                                    ),
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
                                    : ref.watch(prikaziCijeneProvider)
                                    ? '${usluga.name} · ${formatPrice(usluga.price)}'
                                    : usluga.name,
                              ),
                              SpecRow(
                                label: l10n.bookingStatusLabel,
                                trailing: StatusBadge(
                                  label: statusLabel(l10n, appointment.status),
                                  tone: statusTone(appointment.status),
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
                onPressed: () => izadji(ClientRoute.appointments.path),
              ),
            ),
          ],
        ),
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
