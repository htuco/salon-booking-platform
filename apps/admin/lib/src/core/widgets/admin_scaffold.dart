import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/admin_router.dart';

/// Zajedničko zaglavlje i navigacija admin ekrana.
///
/// **`AppBar` je ovdje ispravan**, za razliku od klijentske app-e, gdje ga
/// `prototype/ui/README.md` odbija u korist „← Početna" i serif naslova u tijelu. Razlog je
/// što su to dva različita proizvoda: klijentska app je brandirana vitrina salona i nosi
/// oblik iz handoffa, a admin je generička alatka za rad — jedan build za sve salone, bez
/// brenda i bez `core_ui`.
class AdminScaffold extends ConsumerWidget {
  const AdminScaffold({
    required this.title,
    required this.body,
    this.aktivna,
    this.actions,
    this.floatingActionButton,
    super.key,
  });

  final String title;
  final Widget body;

  /// Ruta koju ovaj ekran predstavlja, za oznaku u donjoj navigaciji.
  ///
  /// Prosljeđuje je ekran, a **ne čita se iz `GoRouterState`**: čitanje iz routera veže
  /// svaki admin ekran za router stablo, pa se ne može podići u widget testu bez pravog
  /// `GoRouter`-a. Test koji mora graditi router da bi provjerio listu termina testira
  /// navigaciju, ne listu.
  final AdminRoute? aktivna;

  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clan = ref.watch(currentStaffProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          PopupMenuButton<String>(
            tooltip: 'Nalog',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (izbor) async {
              if (izbor == 'odjava') {
                await ref.read(staffRepositoryProvider).signOut();
                // Preusmjeravanje na `/login` radi router kroz `currentStaffProvider`.
              }
            },
            itemBuilder: (context) => [
              if (clan != null)
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(clan.name),
                      Text(
                        clan.email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'odjava',
                child: Text('Odjavi se'),
              ),
            ],
          ),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: _AdminNavigacija(aktivna: aktivna),
    );
  }
}

/// Donja navigacija — samo ekrani koji **postoje**.
///
/// Kalendar, usluge, radnici i postavke su rute iz `AdminRoute`, ali ih pišu taskovi 24 i
/// Sprint 3. Ćelija koja vodi na placeholder je gora od ćelije koje nema: obeća funkciju
/// koja ne postoji i vlasnik je traži ponovo.
class _AdminNavigacija extends StatelessWidget {
  const _AdminNavigacija({this.aktivna});

  final AdminRoute? aktivna;

  @override
  Widget build(BuildContext context) {
    final indeks = aktivna == AdminRoute.appointments ? 1 : 0;

    return NavigationBar(
      selectedIndex: indeks,
      onDestinationSelected: (i) {
        final cilj = i == 0 ? AdminRoute.dashboard : AdminRoute.appointments;
        if (cilj != aktivna) context.goNamed(cilj.name);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Pregled',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_note_outlined),
          selectedIcon: Icon(Icons.event_note),
          label: 'Termini',
        ),
      ],
    );
  }
}
