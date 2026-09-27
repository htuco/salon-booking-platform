import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';

/// Prijava slike iz lightboxa galerije — task 51, ADR-0024.
///
/// Store review traži da aplikacija koja prikazuje sadržaj koji neko drugi objavljuje ima
/// način prijave. Prijava ide **platformi**: salon je ne vidi, i slika se ne skriva
/// automatski — jedan klijent lažnom prijavom ne smije sakriti tuđu galeriju.
///
/// ## Neprijavljen korisnik
///
/// Galeriju gleda i gost, ali prijavu prima samo nalog (isto kao zakazivanje, task 41).
/// Dijalog to objasni i vodi na prijavu sa `?from=/gallery`; lightbox se prvo zatvara, jer
/// je on `PageRoute` na root navigatoru iznad `go_router` steka.
Future<void> prijaviSliku(
  BuildContext context,
  WidgetRef ref,
  String imageUrl,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (!ref.read(isSignedInProvider)) {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final prijava = await AppDialog.show(
      context,
      dialog: AppDialog(
        title: l10n.galleryReportSignInTitle,
        message: l10n.galleryReportSignInBody,
        confirmLabel: l10n.galleryReportSignInConfirm,
        cancelLabel: l10n.galleryReportSignInCancel,
        destructive: false,
      ),
    );
    if (prijava != true) return;
    navigator.pop();
    router.push(
      Uri(
        path: ClientRoute.login.path,
        queryParameters: {'from': ClientRoute.gallery.path},
      ).toString(),
    );
    return;
  }

  final razlog = await AppModal.sheet<String>(
    context,
    builder: (context) => const _RazlogPrijave(),
  );
  if (razlog == null) return;

  try {
    await ref
        .read(contentReportRepositoryProvider)
        .reportImage(
          salonId: ref.read(currentSalonIdProvider),
          imageUrl: imageUrl,
          reason: razlog,
        );
  } on ApiError catch (greska) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          greska.message.isEmpty ? l10n.galleryReportFailed : greska.message,
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
  const _RazlogPrijave();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final razlozi = [
      l10n.galleryReportInappropriate,
      l10n.galleryReportOffensive,
      l10n.galleryReportCopyright,
      l10n.galleryReportOther,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xl,
          AppSpacing.gutter,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.galleryReportTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.galleryReportBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final razlog in razlozi)
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
    );
  }
}
