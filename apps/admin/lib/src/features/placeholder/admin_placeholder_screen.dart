import 'package:flutter/material.dart';

import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';

/// Privremeno tijelo rute koja još nema ekran — pišu ih taskovi 31–36.
///
/// **Stoji u `AdminScaffold`, ne u vlastitom `Scaffold`-u.** Do taska 29 je imao svoj, i to
/// nije smetalo jer navigacija nije nudila nijednu nenapisanu rutu. Otkad ih nudi, vlastiti
/// `Scaffold` znači slijepu ulicu: `/clients` otvoren iz „Još" se crtao bez sidebara i bez
/// donje navigacije, pa se iz njega izlazilo samo dugmetom „nazad" u browseru. Nijedan
/// widget test to nije mogao uhvatiti — svaki od njih diže **jedan** ekran, a ovo je
/// svojstvo prelaza između dva; našao ga je browser.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({
    required this.title,
    required this.path,
    this.route,
    super.key,
  });

  final String title;
  final String path;

  /// Ruta koju ovaj placeholder predstavlja, za oznaku u navigaciji.
  ///
  /// `null` za `errorBuilder`: stranica koja ne postoji nije modul i ne smije označiti
  /// nijednu ćeliju.
  final AdminRoute? route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: title,
      aktivna: route,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AdminSpacing.sm),
            Text(
              path,
              style: AdminText.dataInline.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
