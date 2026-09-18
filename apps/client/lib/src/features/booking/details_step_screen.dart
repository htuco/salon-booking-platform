import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth_config_provider.dart';
import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import 'booking_flow_state.dart';
import 'booking_submit_provider.dart';
import 'widgets/appointment_hold_card.dart';
import 'widgets/booking_step_scaffold.dart';

/// Korak 4 — prijava (`prototype/ui/screenshots/06-korak4-prijava.png`).
///
/// ## Ovo je ekran prijave, ne ekran sažetka
///
/// Handoff ga zove „Još jedan korak": kartica **„Čuvamo vam 14:30"** koja drži izbor na
/// oku, pa tri načina prijave i pravna napomena. Nema polja za napomenu i **nema polja za
/// telefon** (`docs/06 §3.1` — push zamjenjuje i poziv i SMS).
///
/// `docs/06 §1.1`: cijeli flow je javan do ovog trenutka. Guard na `/book/*` bi značio da
/// korisnik mora imati nalog da bi vidio cijene — odluka koja se ne otvara.
///
/// ## Šta odlučuje koji se CTA vidi
///
/// **Prijavljenost, ne `customerId`.** Do taska 13 je gate bio `bookingCustomerIdProvider`
/// jer prijave nije ni bilo; sada je ona stvarna, pa neprijavljen korisnik vidi dugmad
/// prijave, a prijavljen dugme koje šalje zahtjev. Klijentski red (`customers`) je
/// posljednji komad koji fali i donosi ga
/// [task 14](../../../../../tasks/sprint-2/14-identitet-i-klijent-upsert.md); dok ga nema,
/// slanje vraća grešku umjesto da dugme tiho ne radi ništa — v. `BookingSubmitNotifier`.
///
/// ## `409` je ishod, ne kvar
///
/// Slot može otići između prikaza i potvrde. Tada se ne prikazuje generička greška: poruka
/// kaže šta se desilo, lista slotova se invalidira (u `BookingSubmitNotifier`) i korisnik
/// se vraća na korak 3 sa **osvježenom** listom i zadržanim danom.
class DetailsStepScreen extends ConsumerWidget {
  const DetailsStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final slanje = ref.watch(bookingSubmitProvider);
    final prijavljen = ref.watch(isSignedInProvider);

    return BookingStepScaffold(
      step: BookingStep.details,
      title: l10n.bookingLastStepTitle,
      subtitle: l10n.bookingLastStepHint,
      // Kad je korisnik prijavljen, zadnji korak je jedno dugme koje šalje zahtjev.
      // Dok nije, šalje se kroz prijavu — ista akcija, drugi put do nje.
      cta: prijavljen
          ? AppButton(
              label: l10n.bookingSubmit,
              loading: slanje.isLoading,
              onPressed: () => _posalji(context, ref),
            )
          : null,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          const AppointmentHoldCard(),
          if (!prijavljen) ...[
            const SizedBox(height: AppSpacing.xxl),
            const _Prijava(),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.bookingLegalNotice, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Future<void> _posalji(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    // Oba se uzimaju **prije** `await`-a: nakon njega je `context` možda već otišao sa
    // ekrana (uspjeh navigira), a `ScaffoldMessenger.of` bi tada gađao mrtav element.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final uspjeh = await ref.read(bookingSubmitProvider.notifier).submit();

    if (uspjeh) {
      router.go(ClientRoute.bookSuccess.path);
      return;
    }

    final greska = ref.read(bookingSubmitProvider).error;
    final poruka = switch (greska) {
      ConflictError() => l10n.bookingConflict,
      NetworkError() => l10n.noConnection,
      _ => l10n.genericError,
    };

    messenger.showSnackBar(SnackBar(content: Text(poruka)));

    // Konflikt vraća na izbor termina, gdje je lista već invalidirana. Ostale greške
    // ostavljaju korisnika ovdje — tamo je dugme koje može pritisnuti ponovo.
    if (greska is ConflictError) {
      router.go(BookingStep.slot.path);
    }
  }
}

/// Načini prijave iz `docs/06 §1.2`, redoslijedom koji propisuje `AuthProvider`.
///
/// **Telefona nema i neće ga biti** (`docs/06 §3.1`). Lista dolazi iz
/// `visibleAuthProvidersProvider`, već filtrirana po platformi — Apple je na iOS-u prvi
/// jer je obavezan kad postoji ijedan drugi social provider (`docs/06 §7.2`), a na
/// Androidu ga nema uopšte.
///
/// Dugmad vode na `/auth/login?from=/book/details`; sam tok prijave je tamo, da ekran
/// koraka ne nosi i korake OTP-a.
class _Prijava extends ConsumerWidget {
  const _Prijava();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provideri = ref.watch(visibleAuthProvidersProvider);

    final ruta = Uri(
      path: ClientRoute.login.path,
      queryParameters: {'from': ClientRoute.bookDetails.path},
    ).toString();

    return Column(
      children: [
        for (final provider in provideri) ...[
          AppButton(
            label: switch (provider) {
              AuthProvider.apple => l10n.bookingContinueApple,
              AuthProvider.google => l10n.bookingContinueGoogle,
              AuthProvider.email => l10n.bookingContinueEmail,
            },
            icon: switch (provider) {
              AuthProvider.apple => LucideIcons.apple,
              AuthProvider.email => LucideIcons.atSign,
              // Lucide nema Google logo.
              AuthProvider.google => null,
            },
            variant: provider == AuthProvider.apple
                ? AppButtonVariant.primary
                : AppButtonVariant.outline,
            onPressed: () => context.go(ruta),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
