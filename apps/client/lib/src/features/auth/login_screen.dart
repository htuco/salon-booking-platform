import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// ## Koda za OTP ima dva koraka, i to nije u handoffu
///
/// `docs/06 §2.1` traži šestocifreni kod, a handoff ga nije nacrtao — 16 ekrana ne
/// uključuje nijedan OTP ekran. Oblik je zato izveden iz tokena (`AppSpacing`, hairline
/// granica, radius 0) i iz `inputDecorationTheme`, ne izmišljen: isti ritam kao ostatak
/// flowa, bez ijedne nove vrijednosti.
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
                  if (stanje.notice != null) ...[
                    _Obavijest(poruka: stanje.notice!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  switch (stanje.phase) {
                    LoginPhase.providers => const _IzborProvidera(),
                    LoginPhase.email => const _UnosEmaila(),
                    LoginPhase.code => _UnosKoda(povratak: _povratak),
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

  /// Nazad korak po korak kroz prijavu, pa tek onda van ekrana.
  ///
  /// Bez ovoga bi korisnik sa koraka sa kodom jednim dodirom ispao iz cijele prijave i
  /// morao ponovo tražiti mail.
  void _nazad(BuildContext context, WidgetRef ref, LoginPhase phase) {
    final kontroler = ref.read(loginControllerProvider.notifier);

    switch (phase) {
      case LoginPhase.code:
        kontroler.promijeniEmail();
      case LoginPhase.email:
        kontroler.nazadNaProvidere();
      case LoginPhase.providers:
        context.go(_povratak);
    }
  }

  String _naslov(AppLocalizations l10n, LoginPhase phase) => switch (phase) {
    LoginPhase.providers => l10n.loginTitle,
    LoginPhase.email => l10n.loginEmailTitle,
    LoginPhase.code => l10n.loginCodeTitle,
  };

  String _podnaslov(AppLocalizations l10n, LoginState stanje) =>
      switch (stanje.phase) {
        LoginPhase.providers =>
          _izFlowa ? l10n.bookingLastStepHint : l10n.loginHint,
        LoginPhase.email => l10n.loginEmailHint,
        LoginPhase.code => l10n.loginCodeSentTo(stanje.email),
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
  // Apple/Google/Facebook dok nativni paketi ne postoje stižu ovuda — poruka mora
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

/// Potvrda koja nije greška („Novi kod je poslan"). Neutralan obrub, ne crveni.
class _Obavijest extends StatelessWidget {
  const _Obavijest({required this.poruka});

  final String poruka;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.mailCheck, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(poruka, style: theme.textTheme.bodyMedium)),
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
        AuthProvider.facebook => l10n.bookingContinueFacebook,
        AuthProvider.email => l10n.bookingContinueEmail,
      };

  IconData? _ikona(AuthProvider provider) => switch (provider) {
    AuthProvider.apple => LucideIcons.apple,
    AuthProvider.email => LucideIcons.atSign,
    // **Lucide nema brand ikone** — ni Google ni Facebook. Dugmad ostaju bez ikone,
    // kao u handoffu; službeni logo nije `IconData` nego asset sa svojim pravilima
    // upotrebe, i uvodi se tek kad ti provideri prvi put stvarno rade.
    AuthProvider.google || AuthProvider.facebook => null,
  };
}

/// Unos email adrese. **Nema polja za telefon** (`docs/06 §3.1`).
class _UnosEmaila extends ConsumerStatefulWidget {
  const _UnosEmaila();

  @override
  ConsumerState<_UnosEmaila> createState() => _UnosEmailaState();
}

class _UnosEmailaState extends ConsumerState<_UnosEmaila> {
  final _polje = TextEditingController();
  String? _lokalnaGreska;

  @override
  void dispose() {
    _polje.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stanje = ref.watch(loginControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('login-email'),
          controller: _polje,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: l10n.loginEmailLabel,
            errorText: _lokalnaGreska,
          ),
          onSubmitted: (_) => _posalji(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.loginSendCode,
          loading: stanje.busy,
          onPressed: _posalji,
        ),
      ],
    );
  }

  /// Validacija prije poziva, da se rate limit ne troši na očigledno pogrešnu adresu.
  ///
  /// Provjera je namjerno gruba (`nešto@nešto.nešto`): stroža regula odbija adrese koje
  /// stvarno postoje, a jedini pouzdan dokaz da adresa radi je kod koji na nju stigne.
  void _posalji() {
    final adresa = _polje.text.trim();
    final ispravna = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(adresa);

    setState(() {
      _lokalnaGreska = ispravna
          ? null
          : AppLocalizations.of(context).loginInvalidEmail;
    });
    if (!ispravna) return;

    // **Odfokusiraj prije prelaza na korak sa kodom.** Flutter web drži jedan DOM
    // `<input>` za fokusirano polje i ne čisti mu vrijednost kad ga preuzme drugi
    // `TextField` — korisnik bi u polju za kod zatekao svoju email adresu. Dart kontroler
    // je pri tome prazan, pa nijedan widget test to ne vidi; našao je prvi prolaz kroz
    // browser (v. status blok taska 13). `ValueKey` na poljima nije dovoljan, jer
    // vrijednost ne dolazi iz Flutterovog stabla nego iz DOM-a.
    //
    // Na mobilnom je ovo usput i ispravno ponašanje: tastatura se sklanja kad zahtjev ode.
    FocusScope.of(context).unfocus();

    ref.read(loginControllerProvider.notifier).posaljiKod(adresa);
  }
}

/// Unos šestocifrenog koda, pa povratak u flow.
class _UnosKoda extends ConsumerStatefulWidget {
  const _UnosKoda({required this.povratak});

  final String povratak;

  @override
  ConsumerState<_UnosKoda> createState() => _UnosKodaState();
}

class _UnosKodaState extends ConsumerState<_UnosKoda> {
  final _polje = TextEditingController();
  String? _lokalnaGreska;

  @override
  void dispose() {
    _polje.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stanje = ref.watch(loginControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // **Otvoreno, samo na webu i samo uz čitač ekrana:** Flutter web ponovo koristi
        // isti semantics `<input>` za oba polja, pa mu `aria-label` postane „Šestocifreni
        // kod" a vrijednost ostane upisani email. Vidljivo polje na canvasu je prazno
        // (Dart kontroler je prazan — potvrđeno porukom „Kod ima šest cifara" na pokušaj
        // potvrde), pa sighted korisnik ovo ne vidi; čitač ekrana pročita tuđu vrijednost.
        //
        // Probani i **odbačeni** kao nedjelotvorni: `ValueKey` po polju (ostaje, jer je
        // ispravan sam po sebi), `FocusScope.unfocus()` prije prelaza (ostaje, jer sklanja
        // tastaturu na mobilnom), i `AutofillGroup` po koraku (uklonjen — ništa nije
        // promijenio, a dodavao je gniježđenje). Detalji u status bloku taska 13.
        //
        // Web nije store target nijednog tenanta (`targets.web` u `tenant.yaml`), pa ovo
        // ne blokira task — ali se ne piše kao riješeno.
        TextField(
          key: const ValueKey('login-code'),
          controller: _polje,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            labelText: l10n.loginCodeLabel,
            errorText: _lokalnaGreska,
          ),
          onSubmitted: (_) => _potvrdi(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.loginVerify,
          loading: stanje.busy,
          onPressed: _potvrdi,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: l10n.loginResend,
          variant: AppButtonVariant.outline,
          onPressed: stanje.busy
              ? null
              : () => ref
                    .read(loginControllerProvider.notifier)
                    .ponovoPosalji(l10n.loginCodeResent),
        ),
      ],
    );
  }

  Future<void> _potvrdi() async {
    final kod = _polje.text.trim();

    setState(() {
      _lokalnaGreska = kod.length == 6
          ? null
          : AppLocalizations.of(context).loginInvalidCode;
    });
    if (kod.length != 6) return;

    FocusScope.of(context).unfocus();

    // Router se uzima prije `await`-a: uspjeh navigira, a `GoRouter.of(context)` bi
    // nakon toga gađao element koji je već otišao sa stabla.
    final router = GoRouter.of(context);
    final sesija = await ref
        .read(loginControllerProvider.notifier)
        .potvrdiKod(kod);

    if (sesija != null) router.go(widget.povratak);
  }
}
