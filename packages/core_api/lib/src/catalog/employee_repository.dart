import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Čita radnike salona i vezu radnik–usluga.
///
/// Obje metode su ovdje jer ih booking flow (task 11) koristi zajedno: izbor usluge suzi
/// listu radnika na one koji je rade. Razdvajanje u dva repozitorija bi značilo dva
/// providera za jedan korak ekrana.
class EmployeeRepository {
  const EmployeeRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, salon_id, name, role, bio, image_url, experience_years, is_active';

  /// Svi aktivni radnici salona, po imenu.
  ///
  /// Admin moze citati sve radi historije; javni katalog uvijek trazi samo aktivne.
  Future<List<Employee>> forSalon(
    String salonId, {
    bool includeInactive = false,
  }) => guard(() async {
    var query = _client
        .from('employees')
        .select(_columns)
        .eq('salon_id', salonId);
    if (!includeInactive) query = query.eq('is_active', true);
    final rows = await query
        // Uzlazno eksplicitno — v. `ServiceRepository.forSalon`: default je silazno.
        .order('name', ascending: true);

    return employeesFromRows(rows);
  });

  /// Profil i usluge se snimaju atomski. `null` ID znaci kreiranje.
  Future<Employee> save({
    required String salonId,
    String? employeeId,
    required String name,
    required String role,
    required String bio,
    int? experienceYears,
    String? imageUrl,
    required List<String> serviceIds,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      employeeId == null ? 'create_employee' : 'update_employee',
      params: {
        'p_salon_id': salonId,
        'p_employee_id': ?employeeId,
        'p_name': name,
        'p_role': role,
        'p_bio': bio,
        'p_experience_years': experienceYears,
        'p_image_url': imageUrl,
        'p_service_ids': serviceIds,
      },
    );
    return employeeFromRpc(row);
  });

  Future<Employee> setActive({
    required String salonId,
    required String employeeId,
    required bool isActive,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'set_employee_active',
      params: {
        'p_salon_id': salonId,
        'p_employee_id': employeeId,
        'p_is_active': isActive,
      },
    );
    return employeeFromRpc(row);
  });

  /// Veze radnik–usluga za salon, iz spojne tabele `employee_services`.
  ///
  /// Vraća se kao lista veza, a ne kao radnici sa ugniježđenim uslugama: ekran treba
  /// presjek u oba smjera (radnici za uslugu **i** usluge za radnika), a embed bi
  /// zaključao jedan smjer.
  Future<List<EmployeeService>> serviceLinksForSalon(String salonId) =>
      guard(() async {
        final rows = await _client
            .from('employee_services')
            .select('id, salon_id, employee_id, service_id')
            .eq('salon_id', salonId);

        return employeeServicesFromRows(rows);
      });
}

@visibleForTesting
Employee employeeFromRpc(dynamic value) {
  final dynamic row = value is List && value.length == 1 ? value.single : value;
  if (row is! Map<String, dynamic>) {
    throw const MappingError('Neispravan odgovor radnika');
  }
  return employeesFromRows([row]).single;
}

/// Mapira `employees` redove na [Employee].
@visibleForTesting
List<Employee> employeesFromRows(List<dynamic> rows) {
  try {
    return rows
        .cast<Map<String, dynamic>>()
        .map(Employee.fromJson)
        .toList(growable: false);
  } catch (error) {
    throw MappingError('Neispravan `employees` red', cause: error);
  }
}

/// Mapira `employee_services` redove na [EmployeeService].
@visibleForTesting
List<EmployeeService> employeeServicesFromRows(List<dynamic> rows) {
  try {
    return rows
        .cast<Map<String, dynamic>>()
        .map(EmployeeService.fromJson)
        .toList(growable: false);
  } catch (error) {
    throw MappingError('Neispravan `employee_services` red', cause: error);
  }
}
