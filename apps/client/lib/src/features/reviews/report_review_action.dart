import 'package:core_api/core_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../moderation/report_content_action.dart';

/// Prijava neprikladne recenzije sa `/reviews` — task 67, isti put kao slika (ADR-0024).
///
/// Od taska 67 recenzije pišu klijenti, pa aplikacija prikazuje tekst koji je napisao neko
/// drugi i mora imati način prijave. Tok je zajednički sa slikom (`prijaviSadrzaj`); ovdje
/// je samo tekst i šta se šalje.
Future<void> prijaviRecenziju(
  BuildContext context,
  WidgetRef ref,
  String reviewId,
) {
  final l10n = AppLocalizations.of(context);
  return prijaviSadrzaj(
    context,
    ref,
    tekst: TekstPrijave(
      prijavaNaslov: l10n.reviewReportSignInTitle,
      prijavaOpis: l10n.reviewReportSignInBody,
      naslov: l10n.reviewReportTitle,
      opis: l10n.reviewReportBody,
      razlozi: [
        l10n.reviewReportOffensive,
        l10n.reviewReportFake,
        l10n.reviewReportPersonal,
        l10n.galleryReportOther,
      ],
    ),
    povratnaRuta: ClientRoute.reviews.path,
    posalji: (razlog) => ref
        .read(contentReportRepositoryProvider)
        .reportReview(reviewId: reviewId, reason: razlog),
  );
}
