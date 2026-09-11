import 'package:freezed_annotation/freezed_annotation.dart';

part 'employee.freezed.dart';
part 'employee.g.dart';

/// Radnik salona — barber, stilistica, doktor. Kako se zove na ekranu odlučuje
/// `Vertical.terms`, ne ovaj model.
///
/// **Nije nalog.** `employees` je ko radi i kad radi; `users` je ko se može prijaviti.
/// Radnik bez naloga je uredan slučaj — salon ga vodi u rasporedu, a on se nikad ne
/// prijavljuje u admin app.
@freezed
abstract class Employee with _$Employee {
  const factory Employee({
    required String id,
    @JsonKey(name: 'salon_id') required String salonId,
    required String name,

    /// Titula kako je salon napisao ("Barber", "Stilistica") — slobodan tekst, ne
    /// `staff_role` enum iz `users`.
    @Default('') String role,
    @Default('') String bio,
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _Employee;

  factory Employee.fromJson(Map<String, dynamic> json) =>
      _$EmployeeFromJson(json);
}
