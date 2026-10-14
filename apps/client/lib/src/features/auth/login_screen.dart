import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth_config_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/router/nazad.dart';
import '../../l10n/generated/app_localizations.dart';
import '../booking/booking_flow_provider.dart';
import '../booking/widgets/appointment_hold_card.dart';
import 'login_controller.dart';
import 'phone_field.dart';
import 'terms_checkbox.dart';

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
/// Email ima eksplicitnu registraciju (prva) i prijavu (druga). Uspjeh vraća stvarnu
/// Supabase sesiju kojom booking prolazi RLS; potvrda emaila kodom je task 81, a
/// zaboravljena lozinka task 57.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.from, this.metod, super.key});

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

  /// Način prijave koji je korisnik **već izabrao** na ekranu ispod (korak 4, Termini),
  /// kao `?metod=email|apple|google`. Tada se izbor providera preskače: `email` otvara
  /// formu, a `apple`/`google` odmah pokreću nativnu prijavu. Bez ovoga je login ponavljao
  /// dugmad koju je korisnik upravo pritisnuo. Nepoznata ili skrivena vrijednost se
  /// ignoriše i ekran počinje od izbora.
  final String? metod;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// Jedan izlazak sa ekrana. Uspješna prijava se javlja kroz `isSignedInProvider`, a
  /// izlazak je `pop` — drugi poziv bi skinuo i ekran ispod (korak 4).
  bool _izasao = false;

  @override
  void initState() {
    super.initState();
    final izabran = AuthProvider.values
        .where((p) => p.name == widget.metod)
        .firstOrNull;
    if (izabran == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pocni(izabran));
  }

  Future<void> _pocni(AuthProvider provider) async {
    if (!mounted ||
        !ref.read(visibleAuthProvidersProvider).contains(provider)) {
      return;
    }
    final kontroler = ref.read(loginControllerProvider.notifier);
    if (provider == AuthProvider.email) {
      kontroler.pocniEmail();
      return;
    }
    await kontroler.prijaviSe(provider);
    // Otkazan Apple/Google dijalog vraća tamo gdje je korisnik izabrao provider, umjesto
    // da ga ostavi na istom izboru još jednom.
    if (mounted &&
        ref.read(loginControllerProvider).error is AuthCancelledError) {
      _izadji();
    }
  }

  void _izadji() {
    if (_izasao || !mounted) return;
    _izasao = true;
    context.nazadIli(widget._povratak);
  }

  /// Poslije prijave: profil kojem fali telefon, ime ili važeća verzija uslova ide na
  /// „Dopuni profil" (task 66), a kompletan izlazi kao i do sada.
  ///
  /// Email registracija šalje sve odjednom, pa ovdje prolazi bez zastoja. Apple i Google
  /// prvi put nemaju telefon ni pristanak, a svako ko je prihvatio staru verziju uslova
  /// dobija novu ovdje — „pri sljedećoj prijavi".
  ///
  /// **Greška pri čitanju statusa ne zaustavlja prijavu.** Korisnik je upravo uspješno
  /// prijavljen; zadržati ga na ekranu zbog pada drugog poziva bi izgledalo kao da prijava
  /// nije uspjela. Provjera se ponavlja pri sljedećoj prijavi.
  Future<void> _poslijePrijave() async {
    if (_izasao || !mounted) return;
    ClientProfileStatus? status;
    try {
      status = await ref.read(clientProfileRepositoryProvider).status();
    } on ApiError {
      status = null;
    }
    if (!mounted || _izasao) return;
    if (status == null || status.isComplete) {
      _izadji();
      return;
    }

    _izasao = true;
    // `pushReplacement`: login nestaje sa stacka, a ispod ostaje ekran sa kojeg je
    // korisnik došao (korak 4), pa „Nastavi" na profilu vraća tačno tamo.
    context.pushReplacement(
      Uri(
        path: ClientRoute.completeProfile.path,
        queryParameters: {'from': widget._povratak},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
    if (widget._izFlowa) ref.watch(bookingFlowProvider);

    // Prijavljen korisnik nema šta raditi na login ekranu. **Ovo je jedini izlazak nakon
    // prijave** — email forma i nativni provideri ne navigiraju sami. Ranije je i forma
    // radila `go`, pa se nakon prijave navigiralo dvaput.
    ref.listen(isSignedInProvider, (_, prijavljen) {
      if (prijavljen) _poslijePrijave();
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Zaglavlje(
              label: l10n.bookingBack,
              onBack: () => _nazad(stanje.phase),
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
                    widget._izFlowa && stanje.phase == LoginPhase.providers
                        ? l10n.bookingLastStepTitle
                        : _naslov(l10n, stanje.phase),
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _podnaslov(l10n, stanje),
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (widget._izFlowa &&
                      stanje.phase == LoginPhase.providers) ...[
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
                    LoginPhase.signIn => const _PrijavaForma(),
                    LoginPhase.signUp => const _RegistracijaForma(),
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

  /// Nazad sa email forme vodi na izbor providera, pa tek onda van ekrana — osim kad je
  /// forma otvorena direktno (`?metod=email`): izbor tada nije ni prikazan, pa nazad vodi
  /// odmah na ekran ispod.
  void _nazad(LoginPhase phase) {
    final kontroler = ref.read(loginControllerProvider.notifier);

    switch (phase) {
      case LoginPhase.signIn:
      case LoginPhase.signUp:
        if (widget.metod == AuthProvider.email.name) {
          _izadji();
        } else {
          kontroler.nazadNaProvidere();
        }
      case LoginPhase.providers:
        _izadji();
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
          widget._izFlowa ? l10n.bookingLastStepHint : l10n.loginHint,
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
  AccountExistsError() => l10n.loginAccountExists,
  WeakPasswordError() => l10n.loginWeakPassword,
  RateLimitError() => l10n.loginRateLimited,
  AuthCancelledError() => l10n.loginCancelled,
  EmailNotConfirmedError() => l10n.loginEmailNotConfirmed,
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
                const Icon(LucideIcons.arrowLeft, size: AppSize.iconAction),
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

/// Registracija: ime i prezime, telefon, email i lozinka jednom, plus uslovi (task 66).
///
/// Telefon se traži bez SMS verifikacije (ADR-0029): služi salonu za poziv kad se termin
/// mijenja, ne kao dokaz identiteta. Lozinka se kuca **jednom**, sa „prikaži lozinku" —
/// ponovljeno polje je samo drugi način da se pogriješi na telefonu.
///
/// Pravila polja su ista kao u bazi (`isValidPhone`, `isValidFullName`), a lozinke kao na
/// Auth serveru. Server ostaje izvor istine; forma samo štedi put do greške.
class _RegistracijaForma extends ConsumerStatefulWidget {
  const _RegistracijaForma();

  @override
  ConsumerState<_RegistracijaForma> createState() => _RegistracijaFormaState();
}

class _RegistracijaFormaState extends ConsumerState<_RegistracijaForma> {
  final _ime = TextEditingController();
  final _telefon = PhoneFieldController();
  final _email = TextEditingController();
  final _lozinka = TextEditingController();
  String? _imeGreska;
  String? _telefonGreska;
  String? _emailGreska;
  String? _lozinkaGreska;
  bool _sakrijLozinku = true;
  bool _uslovi = false;

  @override
  void dispose() {
    _ime.dispose();
    _telefon.dispose();
    _email.dispose();
    _lozinka.dispose();
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
            key: const ValueKey('signup-name'),
            controller: _ime,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(
              labelText: l10n.loginNameLabel,
              errorText: _imeGreska,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PhoneField(
            controller: _telefon,
            greska: _telefonGreska,
            enabled: !stanje.busy,
            fieldKey: const ValueKey('signup-phone'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _EmailPolje(controller: _email, greska: _emailGreska),
          const SizedBox(height: AppSpacing.lg),
          _LozinkaPolje(
            controller: _lozinka,
            greska: _lozinkaGreska,
            sakrij: _sakrijLozinku,
            nova: true,
            onPrebaci: () => setState(() => _sakrijLozinku = !_sakrijLozinku),
            onSubmitted: _posalji,
          ),
          const SizedBox(height: AppSpacing.lg),
          TermsCheckbox(
            value: _uslovi,
            enabled: !stanje.busy,
            onChanged: (v) => setState(() => _uslovi = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.loginCreateAccount,
            loading: stanje.busy,
            // Bez pristanka dugme nije aktivno — ne greška poslije tapa (ADR-0029).
            onPressed: _uslovi ? _posalji : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.loginHaveAccount,
            variant: AppButtonVariant.outline,
            onPressed: stanje.busy
                ? null
                : ref.read(loginControllerProvider.notifier).otvoriPrijavu,
          ),
        ],
      ),
    );
  }

  Future<void> _posalji() async {
    if (!_uslovi) return;
    final l10n = AppLocalizations.of(context);
    final ime = _ime.text.trim();
    final telefon = _telefon.vrijednost;
    final adresa = _email.text.trim();
    final lozinka = _lozinka.text;
    final imeIspravno = isValidFullName(ime);
    final telefonIspravan = telefon != null;
    final emailIspravan = _emailIspravan(adresa);
    final lozinkaIspravna =
        lozinka.length >= 8 &&
        RegExp('[A-Za-z]').hasMatch(lozinka) &&
        RegExp('[0-9]').hasMatch(lozinka);

    setState(() {
      _imeGreska = imeIspravno ? null : l10n.loginInvalidName;
      _telefonGreska = telefonIspravan ? null : l10n.loginInvalidPhone;
      _emailGreska = emailIspravan ? null : l10n.loginInvalidEmail;
      _lozinkaGreska = lozinkaIspravna ? null : l10n.loginInvalidPassword;
    });
    if (!imeIspravno ||
        !telefonIspravan ||
        !emailIspravan ||
        !lozinkaIspravna) {
      return;
    }

    FocusScope.of(context).unfocus();
    // Uspjeh ne navigira odavde: izlazak radi slušalac `isSignedInProvider` na ekranu.
    await ref
        .read(loginControllerProvider.notifier)
        .registrujEmail(
          email: adresa,
          password: lozinka,
          fullName: ime,
          phone: telefon,
          acceptedTerms: _uslovi,
        );
  }
}

/// Prijava postojećim računom: email i lozinka.
///
/// **Pravila registracije se ovdje ne provjeravaju** (task 66). Lozinka napravljena prije
/// nego što je pravilo postojalo, ili po pravilu koje se kasnije promijeni, mora i dalje
/// moći ući — forma koja je odbija prije servera zaključava korisnika iz vlastitog računa.
class _PrijavaForma extends ConsumerStatefulWidget {
  const _PrijavaForma();

  @override
  ConsumerState<_PrijavaForma> createState() => _PrijavaFormaState();
}

class _PrijavaFormaState extends ConsumerState<_PrijavaForma> {
  final _email = TextEditingController();
  final _lozinka = TextEditingController();
  String? _emailGreska;
  String? _lozinkaGreska;
  bool _sakrijLozinku = true;

  @override
  void dispose() {
    _email.dispose();
    _lozinka.dispose();
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
          _EmailPolje(controller: _email, greska: _emailGreska),
          const SizedBox(height: AppSpacing.lg),
          _LozinkaPolje(
            controller: _lozinka,
            greska: _lozinkaGreska,
            sakrij: _sakrijLozinku,
            nova: false,
            onPrebaci: () => setState(() => _sakrijLozinku = !_sakrijLozinku),
            onSubmitted: _posalji,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.loginSignIn,
            loading: stanje.busy,
            onPressed: _posalji,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.loginNeedAccount,
            variant: AppButtonVariant.outline,
            onPressed: stanje.busy
                ? null
                : ref.read(loginControllerProvider.notifier).otvoriRegistraciju,
          ),
        ],
      ),
    );
  }

  Future<void> _posalji() async {
    final l10n = AppLocalizations.of(context);
    final adresa = _email.text.trim();
    final lozinka = _lozinka.text;
    final emailIspravan = _emailIspravan(adresa);
    final lozinkaUnesena = lozinka.isNotEmpty;

    setState(() {
      _emailGreska = emailIspravan ? null : l10n.loginInvalidEmail;
      _lozinkaGreska = lozinkaUnesena ? null : l10n.loginEmptyPassword;
    });
    if (!emailIspravan || !lozinkaUnesena) return;

    FocusScope.of(context).unfocus();
    await ref
        .read(loginControllerProvider.notifier)
        .prijaviEmail(adresa, lozinka);
  }
}

bool _emailIspravan(String adresa) => isValidEmail(adresa);

class _EmailPolje extends StatelessWidget {
  const _EmailPolje({required this.controller, required this.greska});

  final TextEditingController controller;
  final String? greska;

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('login-email'),
    controller: controller,
    keyboardType: TextInputType.emailAddress,
    textInputAction: TextInputAction.next,
    autocorrect: false,
    autofillHints: const [AutofillHints.email],
    decoration: InputDecoration(
      labelText: AppLocalizations.of(context).loginEmailLabel,
      errorText: greska,
    ),
  );
}

class _LozinkaPolje extends StatelessWidget {
  const _LozinkaPolje({
    required this.controller,
    required this.greska,
    required this.sakrij,
    required this.nova,
    required this.onPrebaci,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String? greska;
  final bool sakrij;

  /// Nova lozinka (registracija) ili postojeća (prijava) — razlika je samo za autofill.
  final bool nova;
  final VoidCallback onPrebaci;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: const ValueKey('login-password'),
      controller: controller,
      obscureText: sakrij,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        nova ? AutofillHints.newPassword : AutofillHints.password,
      ],
      decoration: InputDecoration(
        labelText: l10n.loginPasswordLabel,
        errorText: greska,
        suffixIcon: IconButton(
          tooltip: sakrij ? l10n.loginShowPassword : l10n.loginHidePassword,
          onPressed: onPrebaci,
          icon: Icon(sakrij ? LucideIcons.eye : LucideIcons.eyeOff),
        ),
      ),
      onSubmitted: (_) => onSubmitted(),
    );
  }
}
