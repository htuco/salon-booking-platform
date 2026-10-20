import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';

/// Prijava neprikladne recenzije sa `/reviews` — task 67, isti put kao slika (ADR-0024).
///
/// Od taska 67 recenzije pišu klijenti, pa aplikacija prikazuje tekst koji je napisao neko
/// drugi i mora imati način prijave (isti razlog kao `prijaviSliku`). Prijava ide
/// **platformi**: salon je ne vidi, i recenzija se ne skriva automatski — jedan klijent
/// lažnom prijavom ne smije sakriti tuđu ocjenu.
Future<void> prijaviRecenziju(
  BuildContext context,
  WidgetRef ref,
  String reviewId,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (!ref.read(isSignedInProvider)) {
    final router = GoRouter.of(context);
    final prijava = await AppDialog.show(
      context,
      dialog: AppDialog(
        title: l10n.reviewReportSignInTitle,
        message: l10n.reviewReportSignInBody,
        confirmLabel: l10n.galleryReportSignInConfirm,
        cancelLabel: l10n.galleryReportSignInCancel,
        destructive: false,
      ),
    );
    if (prijava != true) return;
    router.push(
      Uri(
        path: ClientRoute.login.path,
        queryParameters: {'from': ClientRoute.reviews.path},
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
        .reportReview(reviewId: reviewId, reason: razlog);
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

/// Razlozi prijave. Dodir na razlog je slanje, kao kod slike.
class _RazlogPrijave extends StatelessWidget {
  const _RazlogPrijave();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final razlozi = [
      l10n.reviewReportOffensive,
      l10n.reviewReportFake,
      l10n.reviewReportPersonal,
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
            Text(l10n.reviewReportTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.reviewReportBody,
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
