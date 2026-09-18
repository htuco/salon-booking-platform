import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/admin_destinations.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../appointments/appointment_tile.dart';
import '../appointments/appointments_providers.dart';

/// Dashboard — današnji termini i broj zahtjeva koji čekaju.
///
/// **Sažetak liste, ne zaseban izvor.** Piše se poslije nje i dijeli iste repozitorije;
/// da je išao prvi, upit za „današnje termine" bi postojao dvaput.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clan = ref.watch(currentStaffProvider).valueOrNull;
    final danasnji = ref.watch(danasnjiTerminiProvider);
    final naCekanju = ref.watch(pendingCountProvider);
    // Gutter dolazi iz ljuske (20 na telefonu, 28 na desktopu), ne iz broja u ekranu —
    // inače bi desktop dobio telefonski razmak, a to se vidi tek na 1440.
    final gutter = AdminShell.gutterOf(context);

    return AdminScaffold(
      title: 'Pregled',
      aktivna: AdminRoute.dashboard,
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(danasnjiTerminiProvider)
            ..invalidate(pendingCountProvider);
        },
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: gutter,
            vertical: AdminSpacing.lg,
          ),
          children: [
            if (clan != null)
              Text(clan.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _ZahtjeviKartica(brojac: naCekanju),
            const SizedBox(height: 24),
            Text('Danas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            danasnji.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Termini se ne mogu učitati.'),
              ),
              data: (lista) => lista.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Danas nema zakazanih termina.'),
                    )
                  : Column(
                      children: [
                        for (final termin in lista)
                          AppointmentTile(termin: termin),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Broj `pending` zahtjeva, kao ulaz u filtriranu listu.
///
/// Kartica je **tap-abilna i vodi na listu filtriranu po „Na čekanju"** — brojka koja kaže
/// da tri zahtjeva čekaju, a ne vodi nigdje, tjera vlasnika da ih traži ručno.
class _ZahtjeviKartica extends ConsumerWidget {
  const _ZahtjeviKartica({required this.brojac});

  final AsyncValue<int> brojac;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final broj = brojac.valueOrNull ?? 0;
    final imaZahtjeva = broj > 0;

    return Card(
      margin: EdgeInsets.zero,
      color: imaZahtjeva ? theme.colorScheme.tertiaryContainer : null,
      child: InkWell(
        // **Adresa, ne stanje providera.** Ranije je kartica mijenjala filter pa
        // navigirala; na webu je to značilo da refresh i „nazad" vrate nefiltriranu listu,
        // a URL ne opisuje šta se vidi. Ista adresa nosi i ćelija „Zahtjevi" u navigaciji,
        // pa oba ulaza vode na isti ekran.
        onTap: imaZahtjeva ? () => context.go(kZahtjeviPutanja) : null,
        borderRadius: BorderRadius.circular(AdminRadius.base),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                imaZahtjeva
                    ? Icons.pending_actions
                    : Icons.check_circle_outline,
                color: imaZahtjeva
                    ? theme.colorScheme.onTertiaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brojac.when(
                        loading: () => '…',
                        error: (_, _) => '—',
                        data: (n) => '$n',
                      ),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: imaZahtjeva
                            ? theme.colorScheme.onTertiaryContainer
                            : null,
                      ),
                    ),
                    Text(
                      // Bosanski plural: 1 zahtjev, 2-4 zahtjeva, 5+ zahtjeva.
                      _zahtjeviTekst(broj),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: imaZahtjeva
                            ? theme.colorScheme.onTertiaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (imaZahtjeva)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bosanski plural po zadnjoj cifri, uz izuzetak za 11–14.
  static String _zahtjeviTekst(int broj) {
    if (broj == 0) return 'nema zahtjeva na čekanju';
    final zadnjeDvije = broj % 100;
    final zadnja = broj % 10;
    if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return 'zahtjeva čeka odgovor';
    if (zadnja == 1) return 'zahtjev čeka odgovor';
    if (zadnja >= 2 && zadnja <= 4) return 'zahtjeva čeka odgovor';
    return 'zahtjeva čeka odgovor';
  }
}
