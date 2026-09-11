import 'package:freezed_annotation/freezed_annotation.dart';

part 'salon.freezed.dart';
part 'salon.g.dart';

/// Salon — tenant. Jedan red u `public.salons`, jedan brandirani app u storeu.
///
/// Čita se bez prijave: politika `public_salons` daje `select` roli `anon`, ali **samo za
/// `status = 'active'`**. Neaktivan salon zato ne dolazi kao greška nego kao prazan
/// rezultat — repozitorij to razlikuje (v. `SalonRepository`).
///
/// Nisu sva polja iz tabele ovdje. `plan`, `status`, `salon_builds` i identifikatori
/// buildova su platformske stvari koje klijentski app ne prikazuje; dodaju se kad ih neki
/// ekran zatraži, a ne unaprijed.
@freezed
abstract class Salon with _$Salon {
  const factory Salon({
    required String id,
    required String name,
    required String slug,
    @Default('') String description,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'cover_image_url') String? coverImageUrl,

    /// `#RRGGBB`. Temu iz ovoga gradi `core_ui` (task 09) — ovaj sloj ne zna za `Color`.
    @JsonKey(name: 'primary_color') @Default('#C6A667') String primaryColor,
    @JsonKey(name: 'secondary_color') @Default('#171717') String secondaryColor,
    @Default('modern_barber') String theme,
    @Default('') String address,
    required String city,
    String? phone,
    String? email,
    @JsonKey(name: 'instagram_url') String? instagramUrl,
    @JsonKey(name: 'facebook_url') String? facebookUrl,

    /// FK na `vertical_packs.key`. Punu vertikalu (terminologiju, pravila, flagove) daje
    /// `VerticalRepository` — ovdje stoji samo ključ, da model ne vuče cijeli pack.
    @JsonKey(name: 'vertical_pack_key') @Default('generic') String verticalPackKey,
  }) = _Salon;

  factory Salon.fromJson(Map<String, dynamic> json) => _$SalonFromJson(json);
}
