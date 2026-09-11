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

  static const _columns = 'id, salon_id, name, role, bio, image_url';

  /// Svi aktivni radnici salona, po imenu.
  ///
  /// Kao i kod usluga, `is_active` filtrira politika `public_active` — ne ponavlja se ovdje.
  Future<List<Employee>> forSalon(String salonId) => guard(() async {
    final rows = await _client
        .from('employees')
        .select(_columns)
        .eq('salon_id', salonId)
        .order('name');

    return employeesFromRows(rows);
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
