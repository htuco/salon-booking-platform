import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer.freezed.dart';
part 'customer.g.dart';

/// Klijent jednog salona — jedan red iz `public.customers`.
///
/// ## Zašto model nastaje tek u tasku 24
///
/// Klijentska app do sada nije trebala ništa osim `customers.id`: `ensure_customer` ga vrati
/// pri prijavi, `book_appointment` ga primi, i time je posao gotov — vlastito ime korisnik
/// već zna. `CustomerRepository` zato barata golim `String`-om i to je i dalje ispravno za
/// njega.
///
/// **Admin je prvi kome treba red, a ne ključ.** Pri ručnom unosu salon pretražuje svoj
/// adresar po imenu i telefonu, vidi koliko je puta neko dolazio i koliko puta nije došao.
///
/// ## Isti čovjek u dva salona su dva reda
///
/// `customers` je tenant-scoped: `unique(salon_id, auth_identity_id)`. Osoba koja se šiša u
/// dva salona ima dva reda, sa odvojenim [visitCount] i [noShowCount] — i tako mora biti.
/// Salon A nema pravo znati koliko puta neko nije došao kod salona B, i cijela izolacija
/// počiva na tome da se ta dva reda nikad ne spoje (`.claude/docs/security.md`).
@freezed
abstract class Customer with _$Customer {
  const factory Customer({
    required String id,
    @JsonKey(name: 'salon_id') required String salonId,

    /// Veza na nalog, ili `null` za **telefonskog klijenta**.
    ///
    /// `null` nije nedostajući podatak nego stanje: čovjek koji je salon nazvao nema nalog
    /// u aplikaciji. Takav red pravi `upsert_walkin_customer` (task 24), a kad se ta ista
    /// osoba kasnije prijavi, `ensure_customer` napravi **zaseban** red — po telefonu se ne
    /// može dokazati da je to ona.
    @JsonKey(name: 'auth_identity_id') String? authIdentityId,

    /// Ime kako ga salon vodi. Kod prijavljenog korisnika stiže iz naloga, ali ga salon
    /// smije ispraviti — zato `ensure_customer` radi `on conflict do nothing`, da druga
    /// prijava ne vrati staro ime.
    required String name,

    /// Broj telefona, jedini podatak po kojem se telefonski klijent prepoznaje pri sljedećem
    /// pozivu. `unique(salon_id, phone)` sprječava duplikat; bez broja ga ništa ne sprječava.
    String? phone,

    /// Napomena salona o klijentu („alergičan na boju", „uvijek kasni"). Interna — klijent
    /// je nikad ne vidi.
    String? note,

    /// Broj održanih termina. Puni ga `set_appointment_status` na `completed`.
    @JsonKey(name: 'visit_count') @Default(0) int visitCount,

    /// Broj nedolazaka. Puni ga `set_appointment_status` na `no_show`.
    ///
    /// **Brojač ima pisca, ali još nema čitaoca.** Prag („tri nedolaska u šest mjeseci")
    /// nigdje se ne provodi — to je pravilo vertikale (`vertical.features.noShowTracking`)
    /// i dolazi u Sprintu 3. Puni se sada da statistika ne počne od nule kad ekran dođe.
    @JsonKey(name: 'no_show_count') @Default(0) int noShowCount,

    /// Oznaka koju salon dodjeljuje ručno.
    @JsonKey(name: 'is_vip') @Default(false) bool isVip,

    @JsonKey(name: 'first_seen_at') DateTime? firstSeenAt,
    @JsonKey(name: 'last_visit_at') DateTime? lastVisitAt,
  }) = _Customer;

  const Customer._();

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);

  /// Klijent bez naloga u aplikaciji — unio ga je salon, telefonom ili na šalteru.
  ///
  /// Ekran po ovome razlikuje red koji smije slobodno mijenjati od reda koji je vezan za
  /// tuđi nalog.
  bool get isWalkin => authIdentityId == null;

  /// Ima li po čemu prepoznati ovog klijenta pri sljedećem pozivu.
  ///
  /// Prazan string je isto što i `null`: red iz starijeg importa može nositi `''`, a
  /// pretraga po praznom broju pogađa sve redom.
  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;
}
