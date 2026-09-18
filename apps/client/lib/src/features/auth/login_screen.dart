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
import '../booking/booking_flow_provider.dart';
import '../booking/widgets/appointment_hold_card.dart';
import 'login_controller.dart';

/// `/auth/login` — prijava, po `prototype/ui/screenshots/06-korak4-prijava.png`.
///
/// ## Ovo je zadnji korak booking flowa, ne zaseban ekran
///
/// Handoff nema ekran „Prijava": ima **korak 4**, sa karticom „Čuvamo vam 14:30" iznad
/// dugmadi. Zato ovaj ekran crta istu karticu kad je otvoren iz flowa
/// (`/auth/login?from=/book/details`), a bez nje kad je otvoren sam. Korisnik na njemu ne
/// smije izgubiti iz vida termin zbog kojeg se uopšte prijavljuje.
///
/// ## Zašto kartica drži `bookingFlowProvider` živim
///
/// `bookingFlowProvider` je `autoDispose` — kad zadnji slušalac ode, izbor se briše
/// (v. `booking_flow_provider.dart`). Odlazak na prijavu bi bio tačno to, i korisnik bi se
/// vratio na prazan sažetak. [AppointmentHoldCard] ga sluša i time drži živim; to nije
/// zaobilaženje `autoDispose`-a nego posljedica toga što je prijava **dio flowa**.
/// Dokazuje se mjerenjem, ne pretpostavkom: `login_screen_test.dart`.
///
/// Email ima eksplicitnu prijavu i registraciju. Demo ne šalje confirmation/recovery
/// poruke, ali uspjeh vraća stvarnu Supabase sesiju kojom booking prolazi RLS.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({this.from, super.key});

  /// Ruta na koju se korisnik vraća nakon prijave. Dolazi kao `?from=` i, kad je prazna,
  /// pada na početnu.
  ///
  /// Query parametar, a ne zapamćeno stanje: prijava se otvara i iz flowa i sa „Moji
  /// termini", a ruta u URL-u znači da povratak radi i na webu, gdje korisnik može doći i
  /// direktnim linkom.
  final String? from;

  /// Ruta povratka, ograničena na rute koje app poznaje.
  ///
  /// **Ne vjeruje se `?from=` doslovno.** Na webu je to vrijednost iz adresne trake; bez
  /// provjere bi `?from=https://tudje` pretvorio naš login u preusmjerenje na tuđi sajt.
  String get _povratak {
    final trazena = from;
    if (trazena == null || trazena.isEmpty) return ClientRoute.home.path;

    final poznata = ClientRoute.values.any((r) => r.path == trazena);
    return poznata ? trazena : ClientRoute.home.path;
  }

  bool get _izFlowa => _povratak == ClientRoute.bookDetails.path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stanje = ref.watch(loginControllerProvider);

    // **Ovo drži izbor iz flowa živim, i mora stajati ovdje, a ne u kartici.**
    // `bookingFlowProvider` je `autoDispose`: briše se čim ostane bez slušaoca. Kartica
    // „Čuvamo vam" se crta samo u fazi izbora providera, pa je prelazak na unos emaila
    // skidao zadnjeg slušaoca i korisnik se nakon uspješne prijave vraćao na prazan
    // korak 4 — greška koju su widget testovi propustili, a prvi prolaz kroz browser
    // našao (v. status blok taska 13).
    //
    // Vezivanje za vidljivi widget je zato pogrešan mehanizam: sljedeći ko sakrije
    // karticu u jednoj fazi ponovo obara flow, a ekran i dalje izgleda ispravno.
    if (_izFlowa) ref.watch(bookingFlowProvider);

    // Prijavljen korisnik nema šta raditi na login ekranu. Desi se pri povratku nazad
    // nakon uspješne prijave i pri deep linku sa živom sesijom.
    ref.listen(isSignedInProvider, (_, prijavljen) {
      if (prijavljen) context.go(_povratak);
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Zaglavlje(
              label: l10n.bookingBack,
              onBack: () => _nazad(context, ref, stanje.phase),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                ),
                children: [
                  Text(
                    _izFlowa && stanje.phase == LoginPhase.providers
                        ? l10n.bookingLastStepTitle
                        : _naslov(l10n, stanje.phase),
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _podnaslov(l10n, stanje),
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (_izFlowa && stanje.phase == LoginPhase.providers) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    const AppointmentHoldCard(),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  if (stanje.error != null) ...[
                    _Greska(poruka: _poruka(l10n, stanje.error!)),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  switch (stanje.phase) {
                    LoginPhase.providers => const _IzborProvidera(),
                    LoginPhase.signIn => _EmailPasswordForma(
                      povratak: _povratak,
                      registracija: false,
                    ),
                    LoginPhase.signUp => _EmailPasswordForma(
                      povratak: _povratak,
                      registracija: true,
                    ),
                  },
                  if (stanje.phase == LoginPhase.providers) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.bookingLegalNotice,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nazad sa email forme vodi na izbor providera, pa tek onda van ekrana.
  void _nazad(BuildContext context, WidgetRef ref, LoginPhase phase) {
    final kontroler = ref.read(loginControllerProvider.notifier);

    switch (phase) {
      case LoginPhase.signIn:
      case LoginPhase.signUp:
        kontroler.nazadNaProvidere();
      case LoginPhase.providers:
        context.go(_povratak);
    }
  }

  String _naslov(AppLocalizations l10n, LoginPhase phase) => switch (phase) {
    LoginPhase.providers => l10n.loginTitle,
    LoginPhase.signIn => l10n.loginEmailTitle,
    LoginPhase.signUp => l10n.loginSignUpTitle,
  };

  String _podnaslov(AppLocalizations l10n, LoginState stanje) =>
      switch (stanje.phase) {
        LoginPhase.providers =>
          _izFlowa ? l10n.bookingLastStepHint : l10n.loginHint,
        LoginPhase.signIn => l10n.loginEmailHint,
        LoginPhase.signUp => l10n.loginSignUpHint,
      };
}

/// Poruka za korisnika po tipu greške.
///
/// `switch` nad `sealed ApiError` — novi tip greške obori build ovdje, umjesto da padne u
/// generičku poruku i pojavi se kao pogrešan savjet. Razlika nije kozmetička: „prekucajte
/// kod", „sačekajte minut" i „nema veze" su tri različite akcije korisnika.
String _poruka(AppLocalizations l10n, ApiError greska) => switch (greska) {
  AuthRejectedError() => l10n.loginRejected,
  RateLimitError() => l10n.loginRateLimited,
  AuthCancelledError() => l10n.loginCancelled,
  NetworkError() => l10n.noConnection,
  // Apple i Google dok nativni paketi ne postoje stižu ovuda — poruka mora
  // ponuditi izlaz koji radi, a to je email.
  ServerError() => l10n.loginProviderUnavailable,
  NotFoundError() || ConflictError() || MappingError() => l10n.genericError,
};

/// „← Nazad" — isti oblik kao zaglavlje koraka flowa (`BookingStepScaffold`).
class _Zaglavlje extends StatelessWidget {
  const _Zaglavlje({required this.label, required this.onBack});

  final String label;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: onBack,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.arrowLeft, size: 22),
                const SizedBox(width: AppSpacing.md),
                Text(label, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Greška kao **blok na ekranu**, ne `SnackBar`.
///
/// Task 13 to traži izričito. `SnackBar` nestane za četiri sekunde, a korisnik u tom
/// trenutku gleda u mail, ne u app.
class _Greska extends StatelessWidget {
  const _Greska({required this.poruka});

  final String poruka;

  @override
  Widget build(BuildContext context) {
    final status = context.statusColors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(border: Border.all(color: status.danger)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circleAlert, size: 20, color: status.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              poruka,
              style: theme.textTheme.bodyMedium,
              // Semantika, ne samo boja: čitač ekrana mora znati da je ovo greška,
              // a daltonist je ne smije prepoznavati po crvenom obrubu.
              semanticsLabel: poruka,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dugmad iz `visibleAuthProvidersProvider` — **ekran ne zna koji provideri postoje**.
///
/// Lista je već filtrirana po platformi (`docs/06 §6.2`), pa ovdje nema nijednog
/// `if (Platform.isIOS)`. Isključivanje providera za jednog tenanta je time promjena
/// `tenant.yaml`-a, ne novi build.
class _IzborProvidera extends ConsumerWidget {
  const _IzborProvidera();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provideri = ref.watch(visibleAuthProvidersProvider);
    final stanje = ref.watch(loginControllerProvider);
    final kontroler = ref.read(loginControllerProvider.notifier);

    return Column(
      children: [
        for (final provider in provideri) ...[
          AppButton(
            label: _labela(l10n, provider),
            icon: _ikona(provider),
            variant: provider == AuthProvider.apple
                ? AppButtonVariant.primary
                : AppButtonVariant.outline,
            loading: stanje.busy,
            onPressed: () => provider == AuthProvider.email
                ? kontroler.pocniEmail()
                : kontroler.prijaviSe(provider),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  String _labela(AppLocalizations l10n, AuthProvider provider) =>
      switch (provider) {
        AuthProvider.apple => l10n.bookingContinueApple,
        AuthProvider.google => l10n.bookingContinueGoogle,
        AuthProvider.email => l10n.bookingContinueEmail,
      };

  IconData? _ikona(AuthProvider provider) => switch (provider) {
    AuthProvider.apple => LucideIcons.apple,
    AuthProvider.email => LucideIcons.atSign,
    // **Lucide nema Google logo.** Dugme ostaje bez ikone, kao u handoffu; službeni logo
    // nije `IconData` nego asset sa svojim pravilima upotrebe, i uvodi se tek kad Google
    // prijava prvi put stvarno radi.
    AuthProvider.google => null,
  };
}

/// Email + lozinka. **Nema polja za telefon** (`docs/06 §3.1`) niti recovery linka u
/// demo fazi, jer bez SMTP-a ne postoji poruka koju bi korisnik mogao dobiti.
class _EmailPasswordForma extends ConsumerStatefulWidget {
  const _EmailPasswordForma({
    required this.povratak,
    required this.registracija,
  });

  final String povratak;
  final bool registracija;

  @override
  ConsumerState<_EmailPasswordForma> createState() =>
      _EmailPasswordFormaState();
}

class _EmailPasswordFormaState extends ConsumerState<_EmailPasswordForma> {
  final _email = TextEditingController();
  final _lozinka = TextEditingController();
  final _ponovljena = TextEditingController();
  String? _emailGreska;
  String? _lozinkaGreska;
  String? _ponovljenaGreska;
  bool _sakrijLozinku = true;

  @override
  void dispose() {
    _email.dispose();
    _lozinka.dispose();
    _ponovljena.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stanje = ref.watch(loginControllerProvider);

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('login-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: l10n.loginEmailLabel,
              errorText: _emailGreska,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const ValueKey('login-password'),
            controller: _lozinka,
            obscureText: _sakrijLozinku,
            textInputAction: widget.registracija
                ? TextInputAction.next
                : TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: [
              widget.registracija
                  ? AutofillHints.newPassword
                  : AutofillHints.password,
            ],
            decoration: InputDecoration(
              labelText: l10n.loginPasswordLabel,
              errorText: _lozinkaGreska,
              suffixIcon: IconButton(
                tooltip: _sakrijLozinku
                    ? l10n.loginShowPassword
                    : l10n.loginHidePassword,
                onPressed: () =>
                    setState(() => _sakrijLozinku = !_sakrijLozinku),
                icon: Icon(
                  _sakrijLozinku ? LucideIcons.eye : LucideIcons.eyeOff,
                ),
              ),
            ),
            onSubmitted: (_) {
              if (!widget.registracija) _posalji();
            },
          ),
          if (widget.registracija) ...[
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey('login-password-repeat'),
              controller: _ponovljena,
              obscureText: _sakrijLozinku,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: l10n.loginPasswordRepeatLabel,
                errorText: _ponovljenaGreska,
              ),
              onSubmitted: (_) => _posalji(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: widget.registracija
                ? l10n.loginCreateAccount
                : l10n.loginSignIn,
            loading: stanje.busy,
            onPressed: _posalji,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: widget.registracija
                ? l10n.loginHaveAccount
                : l10n.loginNeedAccount,
            variant: AppButtonVariant.outline,
            onPressed: stanje.busy
                ? null
                : () {
                    final kontroler = ref.read(
                      loginControllerProvider.notifier,
                    );
                    widget.registracija
                        ? kontroler.otvoriPrijavu()
                        : kontroler.otvoriRegistraciju();
                  },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.loginDemoEmailNotice,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _posalji() async {
    final l10n = AppLocalizations.of(context);
    final adresa = _email.text.trim();
    final lozinka = _lozinka.text;
    final emailIspravan = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(adresa);
    final lozinkaIspravna =
        lozinka.length >= 8 &&
        RegExp('[A-Za-z]').hasMatch(lozinka) &&
        RegExp('[0-9]').hasMatch(lozinka);
    final ponovljenaIspravna =
        !widget.registracija || _ponovljena.text == lozinka;

    setState(() {
      _emailGreska = emailIspravan ? null : l10n.loginInvalidEmail;
      _lozinkaGreska = lozinkaIspravna ? null : l10n.loginInvalidPassword;
      _ponovljenaGreska = ponovljenaIspravna
          ? null
          : l10n.loginPasswordsDoNotMatch;
    });
    if (!emailIspravan || !lozinkaIspravna || !ponovljenaIspravna) return;

    FocusScope.of(context).unfocus();
    final router = GoRouter.of(context);
    final kontroler = ref.read(loginControllerProvider.notifier);
    final sesija = widget.registracija
        ? await kontroler.registrujEmail(adresa, lozinka)
        : await kontroler.prijaviEmail(adresa, lozinka);

    if (sesija != null) router.go(widget.povratak);
  }
}
