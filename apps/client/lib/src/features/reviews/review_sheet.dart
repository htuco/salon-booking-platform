import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';

/// Ocjena završenog posjeta — task 67.
///
/// Klijent ocjenjuje iz „Moji termini" (`5h`), i tamo ga vodi i push `review_request`.
/// Pravila drži baza (`submit_review`): samo svoj termin, samo `completed`, jednom. Ekran
/// samo ne nudi ono što baza sigurno odbija.

/// Ocjene klijenta za njegove završene termine, kao `appointment_id → ocjena`.
///
/// Prati `myAppointmentsProvider`: novi završen termin ili odjava mijenjaju i ovo.
final myRatingsProvider = FutureProvider<Map<String, int>>((ref) async {
  final termini = await ref.watch(myAppointmentsProvider.future);
  final zavrseni = [
    for (final t in termini)
      if (t.status == AppointmentStatus.completed) t.id,
  ];
  return ref
      .watch(reviewRepositoryProvider)
      .myRatings(ref.watch(currentSalonIdProvider), zavrseni);
});

/// Otvara sheet za ocjenu [appointmentId] i šalje je.
Future<void> ocijeniTermin(
  BuildContext context,
  WidgetRef ref,
  String appointmentId,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final poslano = await AppModal.sheet<bool>(
    context,
    // Tastatura za tekst podiže sheet; bez ovoga polje ostane ispod nje.
    isScrollControlled: true,
    builder: (_) => _OcjenaSheet(appointmentId: appointmentId),
  );
  if (poslano != true) return;

  // Lista, prosjek i moja ocjena se bacaju, ne „ažuriraju": istina je u bazi.
  ref
    ..invalidate(myRatingsProvider)
    ..invalidate(salonRatingProvider)
    ..invalidate(salonReviewsProvider);
  messenger.showSnackBar(SnackBar(content: Text(l10n.reviewSent)));
}

class _OcjenaSheet extends ConsumerStatefulWidget {
  const _OcjenaSheet({required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<_OcjenaSheet> createState() => _OcjenaSheetState();
}

class _OcjenaSheetState extends ConsumerState<_OcjenaSheet> {
  final _tekst = TextEditingController();
  int _ocjena = 0;
  bool _radi = false;
  String? _greska;

  @override
  void dispose() {
    _tekst.dispose();
    super.dispose();
  }

  Future<void> _posalji() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _radi = true;
      _greska = null;
    });
    try {
      await ref
          .read(reviewRepositoryProvider)
          .submit(
            appointmentId: widget.appointmentId,
            rating: _ocjena,
            comment: _tekst.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (greska) {
      if (!mounted) return;
      setState(() {
        _radi = false;
        _greska = switch (greska) {
          // Već ocijenjeno, npr. sa drugog uređaja: sheet se nema šta ponoviti.
          ConflictError() => l10n.reviewAlreadyRated,
          NetworkError() => l10n.noConnection,
          // `PT400` nosi rečenicu baze („tek kad salon označi završenim").
          ServerError(:final message) when message.isNotEmpty => message,
          _ => l10n.reviewFailed,
        };
      });
      if (greska is ConflictError) ref.invalidate(myRatingsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xl,
          AppSpacing.gutter,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.reviewSheetTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.reviewSheetBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    AppTappable(
                      key: ValueKey('ocjena-$i'),
                      semanticLabel: l10n.reviewsStarsLabel(i),
                      onTap: _radi ? null : () => setState(() => _ocjena = i),
                      child: SizedBox.square(
                        // 48px dodirna meta, isto kao redovi prijave.
                        dimension: 48,
                        child: Center(
                          child: StarRating(
                            value: i <= _ocjena ? 1 : 0,
                            max: 1,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                key: const ValueKey('ocjena-tekst'),
                controller: _tekst,
                enabled: !_radi,
                minLines: 3,
                maxLines: 6,
                maxLength: ReviewRepository.maxCommentLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.reviewSheetCommentHint,
                ),
              ),
              if (_greska case final poruka?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  poruka,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.statusColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.reviewSheetSubmit,
                loading: _radi,
                // Ocjena je obavezna, tekst nije: bez zvjezdice nema šta poslati.
                onPressed: _ocjena == 0 ? null : _posalji,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
