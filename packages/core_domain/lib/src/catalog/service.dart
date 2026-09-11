import 'package:freezed_annotation/freezed_annotation.dart';

part 'service.freezed.dart';
part 'service.g.dart';

/// Usluga koju salon nudi — "Muško šišanje", "Farbanje".
///
/// [durationMinutes] je ono iz čega availability engine računa kraj termina; `buffer_minutes`
/// se dodaje **odvojeno**, iz `salon_settings`, i namjerno nije uračunat ovdje.
///
/// Politika `public_active` propušta samo `is_active` redove roli `anon`, pa lista koju
/// klijent dobije već ne sadrži ugašene usluge — model ih ne filtrira ponovo.
@freezed
abstract class Service with _$Service {
  const factory Service({
    required String id,
    @JsonKey(name: 'salon_id') required String salonId,
    required String name,
    @Default('') String description,

    /// Grupisanje na ekranu ("Šišanje", "Boja", "Paketi"). Slobodan tekst, ne enum —
    /// kategorije se razlikuju po vertikali i mijenja ih salon, ne build.
    @Default('') String category,

    /// `numeric(10,2)` iz baze. Prikazuje se samo ako je `salon_settings.show_prices_in_app`.
    required double price,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
  }) = _Service;

  factory Service.fromJson(Map<String, dynamic> json) =>
      _$ServiceFromJson(json);
}
