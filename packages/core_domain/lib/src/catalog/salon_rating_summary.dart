import 'package:freezed_annotation/freezed_annotation.dart';

part 'salon_rating_summary.freezed.dart';
part 'salon_rating_summary.g.dart';

/// Sažetak ocjena salona — prosjek, ukupan broj i histogram 5→1 (`13-recenzije.png`).
///
/// Jedan red iz pogleda `public.salon_rating_summary`. **Računa ga baza, ne Dart:**
/// PostgREST ima `max_rows = 1000`, pa bi salon sa 1200 ocjena dao prosjek nad prvih
/// hiljadu — pogrešan broj koji ništa ne prijavljuje.
///
/// **Salon bez recenzija nema red ovdje**, umjesto reda sa nulama. Razlika je vidljiva na
/// ekranu: red sa nulama se crta kao „0,0 od 5" i izgleda kao loš salon, a odsustvo reda
/// sekcija uredno sakrije.
@freezed
abstract class SalonRatingSummary with _$SalonRatingSummary {
  const factory SalonRatingSummary({
    @JsonKey(name: 'salon_id') required String salonId,

    /// Prosjek 1–5, zaokružen na jednu decimalu u bazi (`round(avg(rating), 1)`).
    /// Zaokruživanje je tamo namjerno — dva mjesta koja zaokružuju daju dva broja.
    required double average,

    /// Ukupan broj **ocjena**, ne recenzija sa tekstom.
    required int total,

    @JsonKey(name: 'count_5') @Default(0) int count5,
    @JsonKey(name: 'count_4') @Default(0) int count4,
    @JsonKey(name: 'count_3') @Default(0) int count3,
    @JsonKey(name: 'count_2') @Default(0) int count2,
    @JsonKey(name: 'count_1') @Default(0) int count1,
  }) = _SalonRatingSummary;

  const SalonRatingSummary._();

  factory SalonRatingSummary.fromJson(Map<String, dynamic> json) =>
      _$SalonRatingSummaryFromJson(json);

  /// Broj ocjena za dati broj zvjezdica (1–5).
  ///
  /// Pet imenovanih polja umjesto liste: `freezed` 3.2.5 za `List` polje generiše kod koji
  /// aktuelni Dart odbija (v. `salon.dart`). Histogram je fiksno pet redova, pa lista ovdje
  /// ionako ne bi nosila ništa.
  int countFor(int star) => switch (star) {
    5 => count5,
    4 => count4,
    3 => count3,
    2 => count2,
    1 => count1,
    _ => 0,
  };

  /// Udio ocjena sa datim brojem zvjezdica, 0.0–1.0 — širina trake u histogramu.
  ///
  /// Dijeli se sa [total], ne sa najvećim redom: traka mjeri koliki dio svih ocjena nosi
  /// taj red. Normalizacija na maksimum bi svakom salonu nacrtala jednu punu traku, pa bi
  /// salon sa 5 petica izgledao isto kao salon sa 500.
  double share(int star) => total == 0 ? 0 : countFor(star) / total;
}
