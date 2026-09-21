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

    /// Admin vidi i ugašene redove kroz `staff_manage`; javni katalog ih RLS sakrije.
    /// Default čuva kompatibilnost sa starijim backendom koji kolonu nije birao.
    @JsonKey(name: 'is_active') @Default(true) bool isActive,

    /// Fotografija usluge — 1:1 thumb u redu usluge (`SPEC.md`: 76×76).
    ///
    /// **Nullable namjerno.** Salon koji nema fotografije mora raditi; prazan okvir je
    /// predviđeno stanje koje `PhotoFrame` već crta, ne greška. Obavezna kolona bi značila
    /// da onboarding novog klijenta staje dok neko ne nađe slike.
    ///
    /// Uz to: app iz storea je starija od baze, pa red **bez ove kolone** mora proći —
    /// `String?` bez `required` to i garantuje.
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _Service;

  factory Service.fromJson(Map<String, dynamic> json) =>
      _$ServiceFromJson(json);
}
