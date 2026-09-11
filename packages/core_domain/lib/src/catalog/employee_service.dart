import 'package:freezed_annotation/freezed_annotation.dart';

part 'employee_service.freezed.dart';
part 'employee_service.g.dart';

/// Veza "ovaj radnik radi ovu uslugu" — spojna tabela `employee_services`.
///
/// Treba je booking flow (task 11): kad klijent izabere uslugu, lista radnika se suzi na
/// one koji je rade. Zato je ovo model, a ne detalj skriven u upitu — ekran bira iz
/// presjeka, i taj presjek mora biti vidljiv.
@freezed
abstract class EmployeeService with _$EmployeeService {
  const factory EmployeeService({
    required String id,
    @JsonKey(name: 'salon_id') required String salonId,
    @JsonKey(name: 'employee_id') required String employeeId,
    @JsonKey(name: 'service_id') required String serviceId,
  }) = _EmployeeService;

  factory EmployeeService.fromJson(Map<String, dynamic> json) =>
      _$EmployeeServiceFromJson(json);
}
