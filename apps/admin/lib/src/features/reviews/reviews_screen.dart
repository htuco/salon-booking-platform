import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/datum.dart';
import '../../core/poruka_greske.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_load_error.dart';
import '../../core/widgets/admin_refresh.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/admin_toast.dart';
import '../../core/widgets/app_header.dart';

/// `/more/reviews` — recenzije salona (task 67).
///
/// Canvas ovaj ekran ne crta; oblik je lista kartica kao u Klijentima. Salon ovdje može
/// **samo sakriti i vratiti** recenziju (`set_review_published`): tekst, ocjenu i autora
/// ne mijenja, i to nije ograničenje ekrana nego baze — tabela mu nema `update` grant.
///
/// Sakrivena recenzija ne ulazi u prosjek ni u javnu listu, a njen autor je i dalje vidi
/// kao svoju. Prijavu neprikladne recenzije salon ne vidi: ona ide platformi (ADR-0024).
class AdminReviewsScreen extends ConsumerWidget {
  const AdminReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stanje = ref.watch(adminReviewsProvider);

    return AdminScaffold(
      title: 'Recenzije',
      header: AppHeader(title: 'Recenzije', tabRoot: false),
      body: AdminRefresh(
        onRefresh: () => ref.refresh(adminReviewsProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.gutterMobile,
            AdminSpacing.lg,
            AdminSpacing.gutterMobile,
            AdminSpacing.xxl,
          ),
          children: [
            ...stanje.when(
              loading: () => const [AdminSkeletonList()],
              error: (greska, _) => [
                AdminLoadError(
                  poruka: porukaGreske(greska),
                  onRetry: () => ref.invalidate(adminReviewsProvider),
                ),
              ],
              data: (recenzije) => recenzije.isEmpty
                  ? [const _Prazno()]
                  : [
                      for (final r in recenzije) ...[
                        // Ključ po recenziji: `_radi` ne smije preći na drugu karticu kad
                        // refresh doda novu recenziju na vrh.
                        _Kartica(key: ValueKey(r.id), recenzija: r),
                        const SizedBox(height: AdminSpacing.md),
                      ],
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Recenzije salona prijavljenog vlasnika, i sakrivene.
final adminReviewsProvider = FutureProvider<List<Review>>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(staffReviewRepositoryProvider).forSalon(salonId);
});

class _Kartica extends ConsumerStatefulWidget {
  const _Kartica({required this.recenzija, super.key});

  final Review recenzija;

  @override
  ConsumerState<_Kartica> createState() => _KarticaState();
}

class _KarticaState extends ConsumerState<_Kartica> {
  bool _radi = false;

  Future<void> _prebaci() async {
    final r = widget.recenzija;
    final objavi = !r.isPublished;
    setState(() => _radi = true);
    try {
      await ref
          .read(staffReviewRepositoryProvider)
          .setPublished(r.id, published: objavi);
      ref.invalidate(adminReviewsProvider);
      if (!mounted) return;
      AdminToast.uspjeh(
        context,
        objavi ? 'Recenzija je vraćena.' : 'Recenzija je sakrivena.',
        opis: objavi
            ? 'Ponovo je javna i ulazi u prosjek.'
            : 'Klijenti je ne vide i ne ulazi u prosjek.',
      );
    } on ApiError catch (greska) {
      if (!mounted) return;
      AdminToast.greska(context, porukaGreske(greska));
    } finally {
      if (mounted) setState(() => _radi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recenzija;
    final boje = context.adminColors;
    final tekst = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        color: boje.surface,
        border: Border.all(color: boje.border),
        borderRadius: BorderRadius.circular(AdminRadius.base),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.authorName,
                  style: tekst.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                datumSaGodinom(r.createdAt.toLocal()),
                style: tekst.bodySmall?.copyWith(color: boje.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.xs),
          Text(
            '${'★' * r.rating}${'☆' * (5 - r.rating)}',
            semanticsLabel: '${r.rating} od 5',
            style: tekst.titleMedium?.copyWith(color: boje.ink),
          ),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            r.hasComment ? r.comment! : 'Samo ocjena, bez teksta.',
            style: r.hasComment
                ? tekst.bodyMedium
                : tekst.bodyMedium?.copyWith(color: boje.textSecondary),
          ),
          const SizedBox(height: AdminSpacing.md),
          Row(
            children: [
              if (!r.isPublished)
                Expanded(
                  child: Text(
                    'Sakrivena — klijenti je ne vide',
                    style: tekst.bodySmall?.copyWith(color: boje.textSecondary),
                  ),
                )
              else
                const Spacer(),
              // Na listi čitač ekrana inače čuje samo niz „Sakrij"; labela kaže čiju.
              Semantics(
                label:
                    '${r.isPublished ? 'Sakrij' : 'Vrati'} recenziju: ${r.authorName}',
                button: true,
                excludeSemantics: true,
                child: SizedBox(
                  height: AdminSize.touchTarget,
                  child: OutlinedButton(
                    onPressed: _radi ? null : _prebaci,
                    child: Text(r.isPublished ? 'Sakrij' : 'Vrati'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Prazno extends StatelessWidget {
  const _Prazno();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AdminSpacing.xxl),
    child: Text(
      'Još nema recenzija. Klijent ocjenjuje posjet kad ga označite završenim.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: context.adminColors.textSecondary),
    ),
  );
}
