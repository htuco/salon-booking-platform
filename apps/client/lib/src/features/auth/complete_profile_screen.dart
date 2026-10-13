import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../core/router/nazad.dart';
import '../../l10n/generated/app_localizations.dart';
import 'terms_checkbox.dart';

/// Status profila prijavljenog korisnika. `autoDispose`: čita se na ulazu u ekran, a
/// poslije spremanja ekran odlazi.
final clientProfileStatusProvider =
    FutureProvider.autoDispose<ClientProfileStatus>(
      (ref) => ref.watch(clientProfileRepositoryProvider).status(),
    );

/// `/auth/complete-profile` — „Dopuni profil" (task 66).
///
/// Dolazi se samo sa prijave, kad profilu nešto fali: Apple i Google prvi put ne daju
/// telefon ni pristanak, a ko je prihvatio staru verziju uslova mora prihvatiti novu.
///
/// **Traži se samo ono što fali.** Apple HIG ne dozvoljava da se poslije Sign in with
/// Apple ponovo traže ime i email, pa se ime pojavljuje samo kad ga nalog stvarno nema
/// (Apple ga daje jednom, i može se izgubiti). Korisnik koji samo prihvata novu verziju
/// uslova vidi samo checkbox.
///
/// **Izlaz bez spremanja je odjava.** Profil je uslov računa, ne opcija ekrana: prijavljen
/// korisnik bez telefona i pristanka bi zakazivao kod salona koji ga ne može nazvati.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({this.from, super.key});

  /// Ruta na koju se korisnik vraća poslije spremanja, kao na loginu.
  final String? from;

  String get _povratak {
    final trazena = from;
    if (trazena == null || trazena.isEmpty) return ClientRoute.home.path;
    final poznata = ClientRoute.values.any((r) => r.path == trazena);
    return poznata ? trazena : ClientRoute.home.path;
  }

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _ime = TextEditingController();
  final _telefon = TextEditingController();
  String? _imeGreska;
  String? _telefonGreska;
  String? _greska;
  bool _uslovi = false;
  bool _radi = false;

  @override
  void dispose() {
    _ime.dispose();
    _telefon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(clientProfileStatusProvider);

    return Scaffold(
      body: SafeArea(
        child: switch (status) {
          AsyncData(:final value) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xxl,
              AppSpacing.gutter,
              AppSpacing.xxl,
            ),
            children: [
              Text(
                l10n.completeProfileTitle,
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value.hasPhone && value.hasName
                    ? l10n.completeProfileTermsOnlyHint
                    : l10n.completeProfileHint,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (_greska case final poruka?) ...[
                Text(
                  poruka,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.statusColors.danger,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (!value.hasName) ...[
                TextField(
                  key: const ValueKey('profile-name'),
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
              ],
              if (!value.hasPhone) ...[
                TextField(
                  key: const ValueKey('profile-phone'),
                  controller: _telefon,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: InputDecoration(
                    labelText: l10n.loginPhoneLabel,
                    helperText: l10n.loginPhoneHelper,
                    helperMaxLines: 3,
                    errorText: _telefonGreska,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              TermsCheckbox(
                value: _uslovi,
                enabled: !_radi,
                onChanged: (v) => setState(() => _uslovi = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.completeProfileSave,
                loading: _radi,
                onPressed: _uslovi ? () => _spremi(value) : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: l10n.completeProfileSignOut,
                variant: AppButtonVariant.outline,
                onPressed: _radi ? null : _odjavi,
              ),
            ],
          ),
          AsyncError() => EmptyState(
            message: l10n.genericError,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(clientProfileStatusProvider),
          ),
          // Skeleton, ne spinner — pravilo koje je postavio prvi ekran (task 10).
          _ => const Padding(
            padding: EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              children: [
                SkeletonLoader(height: 48),
                SizedBox(height: AppSpacing.lg),
                SkeletonLoader(height: 56),
                SizedBox(height: AppSpacing.lg),
                SkeletonLoader(height: 56),
              ],
            ),
          ),
        },
      ),
    );
  }

  Future<void> _spremi(ClientProfileStatus status) async {
    final l10n = AppLocalizations.of(context);
    final ime = _ime.text.trim();
    final telefon = _telefon.text.trim();
    final imeIspravno = status.hasName || isValidFullName(ime);
    final telefonIspravan = status.hasPhone || isValidPhone(telefon);

    setState(() {
      _imeGreska = imeIspravno ? null : l10n.loginInvalidName;
      _telefonGreska = telefonIspravan ? null : l10n.loginInvalidPhone;
      _greska = null;
    });
    if (!imeIspravno || !telefonIspravan || !_uslovi) return;

    setState(() => _radi = true);
    try {
      await ref
          .read(clientProfileRepositoryProvider)
          .complete(
            acceptTerms: _uslovi,
            phone: status.hasPhone ? null : telefon,
            name: status.hasName ? null : ime,
          );
    } on ApiError catch (greska) {
      if (!mounted) return;
      setState(() {
        _radi = false;
        // `PT400` nosi rečenicu na bosanskom iz baze; ostalo dobija opštu poruku.
        _greska = greska.displayMessage ?? l10n.genericError;
      });
      return;
    }
    if (!mounted) return;
    context.nazadIli(widget._povratak);
  }

  Future<void> _odjavi() async {
    setState(() => _radi = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on ApiError {
      // Odjava koja padne na mreži i dalje briše lokalnu sesiju; ekran svejedno odlazi.
    }
    if (!mounted) return;
    context.nazadIli(widget._povratak);
  }
}
