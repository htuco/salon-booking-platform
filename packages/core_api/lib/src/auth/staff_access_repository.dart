import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Ko ima pristup admin aplikaciji salona: članovi osoblja i pozivi (task 45, ADR-0023).
///
/// ## Poziv je kod, ne email
///
/// Vlasnik napravi poziv ([createInvite]), dobije kod i pošalje ga radniku kako god hoće.
/// Radnik ga iskoristi kroz [acceptInvite], koji zove Edge Function `accept-staff-invite`:
/// samo ona, sa service role ključem, smije napraviti `auth.users` red i postaviti
/// `app_metadata`. **Uloga i salon ne idu iz aplikacije** — čitaju se iz poziva.
///
/// ## Lista osoblja ide kroz RPC
///
/// `list_staff_users`, a ne `from('users')`: [StaffRepository.membership] čita `public.users`
/// bez filtera i oslanja se na to da politika vraća samo vlastiti red. Politika koja bi
/// adminu pokazala cijelo osoblje srušila bi prijavu.
class StaffAccessRepository {
  const StaffAccessRepository(this._client);

  final SupabaseClient _client;

  Future<List<StaffMember>> members(String salonId) => guard(() async {
    final rows = await _client.rpc<dynamic>(
      'list_staff_users',
      params: {'p_salon_id': salonId},
    );
    try {
      return [
        for (final r in (rows as List).cast<Map<String, dynamic>>())
          StaffMember(
            id: r['id'] as String,
            name: r['name'] as String,
            email: r['email'] as String,
            role: r['role'] as String,
            salonId: salonId,
          ),
      ];
    } catch (error) {
      throw MappingError('Neispravan red osoblja', cause: error);
    }
  });

  /// Pozivi koji još mogu biti iskorišteni — nisu prihvaćeni, povučeni ni istekli.
  Future<List<StaffInvite>> pendingInvites(String salonId) => guard(() async {
    final rows = await _client
        .from('staff_invites')
        .select('id, name, role, expires_at')
        .eq('salon_id', salonId)
        .isFilter('accepted_at', null)
        .isFilter('revoked_at', null)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        // Uzlazno eksplicitno — default u ovom paketu je silazno.
        .order('created_at', ascending: true);
    try {
      return rows.map(StaffInvite.fromJson).toList(growable: false);
    } catch (error) {
      throw MappingError('Neispravan red poziva', cause: error);
    }
  });

  Future<StaffInviteCode> createInvite({
    required String salonId,
    required String role,
    required String name,
    String? employeeId,
  }) => guard(() async {
    final rows = await _client.rpc<dynamic>(
      'create_staff_invite',
      params: {
        'p_salon_id': salonId,
        'p_role': role,
        'p_name': name,
        // Obavezan za radnika (task 46): nalog se veže na red u `employees`.
        'p_employee_id': employeeId,
      },
    );
    final dynamic red = rows is List ? rows.single : rows;
    try {
      final map = red as Map<String, dynamic>;
      return StaffInviteCode(
        inviteId: map['invite_id'] as String,
        code: map['code'] as String,
        expiresAt: DateTime.parse(map['expires_at'] as String),
      );
    } catch (error) {
      throw MappingError('Neispravan odgovor poziva', cause: error);
    }
  });

  Future<void> revokeInvite({
    required String salonId,
    required String inviteId,
  }) => guard(() async {
    await _client.rpc<dynamic>(
      'revoke_staff_invite',
      params: {'p_salon_id': salonId, 'p_invite_id': inviteId},
    );
  });

  /// Pristup prestaje odmah; termini i istorija ostaju (v. `security.md`).
  Future<void> removeMember({
    required String salonId,
    required String userId,
  }) => guard(() async {
    await _client.rpc<dynamic>(
      'remove_staff_user',
      params: {'p_salon_id': salonId, 'p_user_id': userId},
    );
  });

  /// Radnik koristi poziv: nastaje nalog sa ulogom i salonom **iz poziva**.
  ///
  /// Ne prijavljuje — pozivalac poslije zove [StaffRepository.signIn] istim podacima, da bi
  /// prijava išla istim putem kao svaka druga.
  ///
  /// Greške nose poruku servera, već pisanu za čovjeka: [NotFoundError] za nepostojeći,
  /// istekao ili iskorišten kod, [ConflictError] za zauzet email ili neispravan unos.
  Future<void> acceptInvite({
    required String code,
    required String email,
    required String password,
  }) async {
    try {
      await _client.functions.invoke(
        'accept-staff-invite',
        body: {'code': code, 'email': email, 'password': password},
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final poruka = details is Map && details['error'] is String
          ? details['error'] as String
          : 'Nalog se ne može napraviti.';
      throw switch (e.status) {
        404 => NotFoundError(poruka, cause: e),
        400 || 409 => ConflictError(poruka, cause: e),
        _ => ServerError(poruka, cause: e),
      };
    } catch (e) {
      throw mapError(e);
    }
  }
}
