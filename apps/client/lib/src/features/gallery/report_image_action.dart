import 'package:core_api/core_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../moderation/report_content_action.dart';

/// Prijava slike iz lightboxa galerije — task 51, ADR-0024.
///
/// Tok je zajednički sa recenzijom (`prijaviSadrzaj`); ovdje je samo tekst i šta se šalje.
/// Galeriju gleda i gost; dijalog za prijavu ga vodi na `?from=/gallery`, a lightbox se
/// prvo zatvara, jer je on `PageRoute` na root navigatoru iznad `go_router` steka.
Future<void> prijaviSliku(
  BuildContext context,
  WidgetRef ref,
  String imageUrl,
) {
  final l10n = AppLocalizations.of(context);
  return prijaviSadrzaj(
    context,
    ref,
    tekst: TekstPrijave(
      prijavaNaslov: l10n.galleryReportSignInTitle,
      prijavaOpis: l10n.galleryReportSignInBody,
      naslov: l10n.galleryReportTitle,
      opis: l10n.galleryReportBody,
      razlozi: [
        l10n.galleryReportInappropriate,
        l10n.galleryReportOffensive,
        l10n.galleryReportCopyright,
        l10n.galleryReportOther,
      ],
    ),
    povratnaRuta: ClientRoute.gallery.path,
    zatvoriRootRutu: true,
    posalji: (razlog) => ref
        .read(contentReportRepositoryProvider)
        .reportImage(
          salonId: ref.read(currentSalonIdProvider),
          imageUrl: imageUrl,
          reason: razlog,
        ),
  );
}
