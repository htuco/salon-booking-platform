import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../appointments/appointments_providers.dart';

class EmployeeInput {
  const EmployeeInput({
    required this.name,
    required this.role,
    required this.bio,
    required this.serviceIds,
    this.experienceYears,
    this.imageUrl,
  });
  final String name;
  final String role;
  final String bio;
  final List<String> serviceIds;
  final int? experienceYears;
  final String? imageUrl;
}

class EmployeeActions {
  EmployeeActions(this.ref);
  final Ref ref;

  String get _salon =>
      ref.read(adminSalonIdProvider) ??
      (throw const ServerError('Salon nije učitan'));

  Future<Employee> save(Employee? employee, EmployeeInput input) async {
    final result = await ref
        .read(employeeRepositoryProvider)
        .save(
          salonId: _salon,
          employeeId: employee?.id,
          name: input.name,
          role: input.role,
          bio: input.bio,
          experienceYears: input.experienceYears,
          imageUrl: input.imageUrl,
          serviceIds: input.serviceIds,
        );
    ref.invalidate(adminEmployeesProvider);
    ref.invalidate(adminEmployeeLinksProvider);
    return result;
  }

  Future<void> setActive(Employee employee, bool active) async {
    await ref
        .read(employeeRepositoryProvider)
        .setActive(salonId: _salon, employeeId: employee.id, isActive: active);
    ref.invalidate(adminEmployeesProvider);
  }
}

final employeeActionsProvider = Provider<EmployeeActions>(EmployeeActions.new);
