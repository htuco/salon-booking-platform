import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';

/// [ClientProfileRepository] bez mreže (task 66). Podrazumijevano je profil kompletan, pa
/// prijava u postojećim testovima izlazi kao i ranije.
class FakeClientProfileRepository implements ClientProfileRepository {
  FakeClientProfileRepository({
    this.trenutni = const ClientProfileStatus(
      hasName: true,
      hasPhone: true,
      termsCurrent: true,
    ),
    this.statusGreska,
  });

  ClientProfileStatus trenutni;

  /// Greška koju baca [status], ili `null` za uspjeh.
  final ApiError? statusGreska;

  /// Argumenti zadnjeg „Dopuni profil", ili `null` ako nije pozvan.
  ({bool acceptTerms, String? phone, String? name})? zadnjeDopunjavanje;

  @override
  Future<ClientProfileStatus> status() async {
    if (statusGreska != null) throw statusGreska!;
    return trenutni;
  }

  @override
  Future<void> complete({
    required bool acceptTerms,
    String? phone,
    String? name,
  }) async {
    zadnjeDopunjavanje = (acceptTerms: acceptTerms, phone: phone, name: name);
    trenutni = const ClientProfileStatus(
      hasName: true,
      hasPhone: true,
      termsCurrent: true,
    );
  }
}
