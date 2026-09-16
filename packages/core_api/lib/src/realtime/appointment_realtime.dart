import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Javni, bezlični signal da treba ponovo izračunati slobodne termine salona.
///
/// `appointments` stream ne može služiti za ovu svrhu: klijentski RLS namjerno skriva
/// tuđe termine. Backend zato mijenja samo nasumični `revision_id` u
/// `availability_signals`; nikakav podatak o terminu ili klijentu ne dolazi do app-e.
final availabilityChangesProvider = StreamProvider.autoDispose
    .family<int, String>((ref, salonId) async* {
      var revision = 0;
      final snapshots = ref
          .watch(supabaseClientProvider)
          .from('availability_signals')
          .stream(primaryKey: ['salon_id'])
          .eq('salon_id', salonId);

      await for (final _ in snapshots) {
        yield revision++;
      }
    });

/// Promjene termina koje trenutni JWT smije vidjeti u jednom salonu.
///
/// Supabase stream prvo emituje trenutni snapshot, zatim promjene iz
/// `supabase_realtime` publikacije. RLS ostaje granica: admin vidi termine svog salona,
/// klijent samo vlastite. Provider namjerno vraća samo reviziju — ekran nakon događaja
/// ponovo čita tipizirani repozitorij umjesto da iz Realtime mape gradi drugi izvor istine.
final appointmentChangesProvider = StreamProvider.autoDispose
    .family<int, String>((ref, salonId) async* {
      var revision = 0;
      final snapshots = ref
          .watch(supabaseClientProvider)
          .from('appointments')
          .stream(primaryKey: ['id'])
          .eq('salon_id', salonId);

      await for (final _ in snapshots) {
        yield revision++;
      }
    });
