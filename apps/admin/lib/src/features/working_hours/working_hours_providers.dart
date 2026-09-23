import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sav raspored salona — i salonski redovi i oni po radniku, u jednom čitanju.
///
/// Isti upit koji kalendar već radi (`kalendarRadnoVrijemeProvider`), ali zaseban provider:
/// dijeljenje bi značilo da snimanje na ovom ekranu mora znati koje kalendarske providere
/// da poništi, a `autoDispose` ih ionako oslobodi kad se ekran napusti.
final radnoVrijemeProvider = FutureProvider.autoDispose<List<WorkingHour>>((
  ref,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  return ref.watch(workingHoursRepositoryProvider).forSalon(salonId);
});

/// Blokade od danas unaprijed — „Neradni dani" iz `3h`.
///
/// Prošle blokade se ne prikazuju: neradni dan koji je prošao nije podatak nego historija,
/// a lista koja raste unedogled je lista koju niko ne čita.
final buduceBlokadeProvider = FutureProvider.autoDispose<List<BlockedSlot>>((
  ref,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  return ref.watch(blockedSlotRepositoryProvider).fromDay(salonId: salonId);
});

/// Radnici salona — pauza i blokada se mogu vezati za jednog.
final osobljeZaBlokadeProvider = FutureProvider.autoDispose<List<Employee>>((
  ref,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  return ref
      .watch(employeeRepositoryProvider)
      .forSalon(salonId, includeInactive: false);
});

class WorkingHoursActions {
  WorkingHoursActions(this.ref);

  final Ref ref;

  String get _salon =>
      ref.read(adminSalonIdProvider) ??
      (throw const ServerError('Salon nije učitan'));

  /// Termini koji bi ispali van rasporeda — **prije** snimanja.
  ///
  /// Ekran ovo zove dok vlasnik još može odustati. Poziv ništa ne mijenja.
  Future<List<ScheduleConflict>> konflikti(
    List<WorkingHoursInput> dani, {
    String? employeeId,
  }) => ref
      .read(workingHoursRepositoryProvider)
      .conflicts(salonId: _salon, days: dani, employeeId: employeeId);

  Future<void> sacuvaj(
    List<WorkingHoursInput> dani, {
    String? employeeId,
  }) async {
    await ref
        .read(workingHoursRepositoryProvider)
        .save(salonId: _salon, days: dani, employeeId: employeeId);
    ref.invalidate(radnoVrijemeProvider);
  }

  Future<List<ScheduleConflict>> konfliktiBlokade({
    required LocalDate datum,
    required LocalTime od,
    required LocalTime do_,
    String? employeeId,
  }) => ref
      .read(blockedSlotRepositoryProvider)
      .conflicts(
        salonId: _salon,
        date: datum,
        startTime: od,
        endTime: do_,
        employeeId: employeeId,
      );

  Future<void> dodajBlokadu({
    required LocalDate datum,
    required LocalTime od,
    required LocalTime do_,
    String? razlog,
    String? employeeId,
  }) async {
    await ref
        .read(blockedSlotRepositoryProvider)
        .create(
          salonId: _salon,
          date: datum,
          startTime: od,
          endTime: do_,
          reason: razlog,
          employeeId: employeeId,
        );
    ref.invalidate(buduceBlokadeProvider);
  }

  /// Termini koje bi neradni dan otkazao — ekran ih pokazuje prije potvrde.
  Future<List<ScheduleConflict>> terminiNeradnogDana(LocalDate datum) => ref
      .read(blockedSlotRepositoryProvider)
      .dayClosurePreview(salonId: _salon, date: datum);

  /// Neradni dan: blokada cijelog dana i otkazivanje svih termina tog dana.
  Future<int> proglasiNeradniDan(LocalDate datum, {String? razlog}) async {
    final broj = await ref
        .read(blockedSlotRepositoryProvider)
        .closeDay(salonId: _salon, date: datum, reason: razlog);
    ref.invalidate(buduceBlokadeProvider);
    return broj;
  }

  Future<void> obrisiBlokadu(String blokadaId) async {
    await ref
        .read(blockedSlotRepositoryProvider)
        .delete(salonId: _salon, blockedSlotId: blokadaId);
    ref.invalidate(buduceBlokadeProvider);
  }
}

final workingHoursActionsProvider = Provider<WorkingHoursActions>(
  WorkingHoursActions.new,
);
