import 'package:freezed_annotation/freezed_annotation.dart';

part 'review.freezed.dart';
part 'review.g.dart';

/// Jedna recenzija salona — jedan red iz `public.reviews` (`SPEC.md` 5m).
///
/// **Klijent je piše samo kroz `submit_review`** (task 67), za svoj završen termin; salon je
/// samo sakriva kroz `set_review_published`. Direktnog upisa u tabelu nema ni za koga osim
/// `service_role` (seed, import), pa ovdje nema ni `toJson` putanje koju bi neko poslao nazad.
@freezed
abstract class Review with _$Review {
  const factory Review({
    required String id,
    @JsonKey(name: 'salon_id') required String salonId,

    /// Ime kako ga salon prikazuje: „Nedim H.", ne puno prezime. Za recenziju iz aplikacije
    /// ga pravi baza iz identiteta; uvezena recenzija sa Googlea ga nosi kao tekst.
    @JsonKey(name: 'author_name') required String authorName,

    /// 1–5. Baza to čuva `check`-om; ekran se na to oslanja kad crta zvjezdice.
    required int rating,

    /// Tekst recenzije, ili `null` kad je čovjek dao samo zvjezdice.
    ///
    /// **Nullable nosi histogram.** Većina ocjena nema tekst — handoff pokazuje „142
    /// ocjene" iznad tri napisane recenzije. Lista prikazuje samo one sa tekstom, prosjek
    /// računa sve.
    String? comment,

    /// Kad je recenzija napisana. Kod importa je to datum originalne recenzije, ne datum
    /// uvoza — ekran ga pokazuje relativno („prije 3 dana").
    @JsonKey(name: 'created_at') required DateTime createdAt,

    /// Sakrivenu recenziju vidi samo salon; javna lista i prosjek je ne broje. Termin i
    /// identitet autora namjerno nisu polja: te kolone app ne smije čitati (task 67).
    @JsonKey(name: 'is_published') @Default(true) bool isPublished,
  }) = _Review;

  const Review._();

  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);

  /// Ima li ova ocjena šta za pokazati u listi.
  ///
  /// Prazan string je isto što i `null`: red u bazi može doći iz importa sa `''`, a
  /// kartica sa imenom, zvjezdicama i prazninom ispod izgleda kao greška u učitavanju.
  bool get hasComment => comment != null && comment!.trim().isNotEmpty;
}
