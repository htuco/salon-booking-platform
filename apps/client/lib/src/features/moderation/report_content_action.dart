import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';

/// Tekst jedne vrste prijave: šta se prijavljuje i zašto.
///
/// Ostatak toka (prijava naloga, zahvala, greška) je isti za svaki sadržaj, pa i tekst za
/// njega stoji u [prijaviSadrzaj], ne ovdje.
class TekstPrijave {
  const TekstPrijave({
    required this.prijavaNaslov,
    required this.prijavaOpis,
    required this.naslov,
    required this.opis,
    required this.razlozi,
  });

  /// Dijalog za neprijavljenog korisnika.
  final String prijavaNaslov;
  final String prijavaOpis;

  /// Sheet sa razlozima.
  final String naslov;
  final String opis;
  final List<String> razlozi;
}

/// Prijava sadržaja koji je objavio neko drugi — zajednički tok za sliku (task 51) i
/// recenziju (task 67), ADR-0024.
///
/// Store review traži da aplikacija koja prikazuje tuđi sadržaj ima način prijave. Prijava
/// ide **platformi**: salon je ne vidi, i sadržaj se ne skriva automatski — jedan klijent
/// lažnom prijavom ne smije sakriti tuđu sliku ni tuđu ocjenu.
///
/// Prijavu prima samo nalog (isto kao zakazivanje, task 41). Gost dobije dijalog i put na
/// prijavu sa `?from=`[povratnaRuta]. [zatvoriRootRutu] prvo zatvori rutu na root
/// navigatoru — lightbox galerije je `PageRoute` iznad `go_router` steka.
///
/// [posalji] je jedino što se razlikuje po sadržaju: poziv repozitorija sa izabranim
/// razlogom.
Future<void> prijaviSadrzaj(
  BuildContext context,
  WidgetRef ref, {
  required TekstPrijave tekst,
  required String povratnaRuta,
  required Future<void> Function(String razlog) posalji,
  bool zatvoriRootRutu = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (!ref.read(isSignedInProvider)) {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final prijava = await AppDialog.show(
      context,
      dialog: AppDialog(
        title: tekst.prijavaNaslov,
        message: tekst.prijavaOpis,
        confirmLabel: l10n.galleryReportSignInConfirm,
        cancelLabel: l10n.galleryReportSignInCancel,
        destructive: false,
      ),
    );
    if (prijava != true) return;
    if (zatvoriRootRutu) navigator.pop();
    router.push(
      Uri(
        path: ClientRoute.login.path,
        queryParameters: {'from': povratnaRuta},
      ).toString(),
    );
    return;
  }

  final razlog = await AppModal.sheet<String>(
    context,
    builder: (context) => _RazlogPrijave(tekst: tekst),
  );
  if (razlog == null) return;

  try {
    await posalji(razlog);
  } on ApiError catch (greska) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          // Samo rečenica baze (`PT…`) ide na ekran; dijagnostički tekst ne.
          greska.displayMessage ?? l10n.galleryReportFailed,
        ),
      ),
    );
    return;
  }
  messenger.showSnackBar(SnackBar(content: Text(l10n.galleryReportSent)));
}

/// Razlozi prijave. Dodir na razlog je slanje — nema drugog koraka „Pošalji", jer bi
/// korisnik koji je već rekao šta nije u redu dobio još jedno pitanje bez nove informacije.
/// Tekst razloga ide platformi onakav kakav je korisnik vidio.
class _RazlogPrijave extends StatelessWidget {
  const _RazlogPrijave({required this.tekst});

  final TekstPrijave tekst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xl,
          AppSpacing.gutter,
          AppSpacing.lg,
        ),
        // Skrol: naslov, opis i četiri reda na velikom sistemskom fontu prelaze visinu
        // koju sheet daje bez `isScrollControlled`.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tekst.naslov, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                tekst.opis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final razlog in tekst.razlozi)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: theme.colorScheme.outline),
                    ),
                  ),
                  child: AppTappable(
                    semanticLabel: razlog,
                    onTap: () => Navigator.of(context).pop(razlog),
                    child: ConstrainedBox(
                      // 48px dodirna meta — `SPEC.md` traži ≥44px.
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(razlog, style: theme.textTheme.bodyLarge),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
