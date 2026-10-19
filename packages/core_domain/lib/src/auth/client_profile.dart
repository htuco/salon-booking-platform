import 'package:meta/meta.dart';

/// Šta klijentskom profilu fali — onako kako ga vrati `client_profile_status` (task 66).
///
/// Profil je **osoba**, ne red u salonu: ime, telefon i prihvatanje uslova stoje na
/// identitetu, a salon ih dobija tek kroz svoj adresar. Email registracija ih šalje odmah;
/// Apple i Google prijava ih nemaju, pa takav korisnik poslije prve prijave prolazi kroz
/// „Dopuni profil". Isto i korisnik kojem je prihvaćena verzija uslova zastarjela.
@immutable
class ClientProfileStatus {
  const ClientProfileStatus({
    required this.hasName,
    required this.hasPhone,
    required this.termsCurrent,
  });

  /// Mapira red iz `client_profile_status`. Baca [FormatException] kad red nije
  /// očekivanog oblika — `core_api` ga pretvara u `MappingError`.
  factory ClientProfileStatus.fromJson(Map<String, dynamic> json) {
    final ime = json['has_name'];
    final telefon = json['has_phone'];
    final uslovi = json['terms_current'];
    if (ime is! bool || telefon is! bool || uslovi is! bool) {
      throw FormatException('Status profila bez očekivanih polja', '$json');
    }
    return ClientProfileStatus(
      hasName: ime,
      hasPhone: telefon,
      termsCurrent: uslovi,
    );
  }

  final bool hasName;
  final bool hasPhone;

  /// Prihvaćena je **važeća** verzija i Uslova i Politike privatnosti.
  final bool termsCurrent;

  /// Ništa ne fali — „Dopuni profil" se ne prikazuje.
  bool get isComplete => hasName && hasPhone && termsCurrent;

  @override
  bool operator ==(Object other) =>
      other is ClientProfileStatus &&
      other.hasName == hasName &&
      other.hasPhone == hasPhone &&
      other.termsCurrent == termsCurrent;

  @override
  int get hashCode => Object.hash(hasName, hasPhone, termsCurrent);
}

/// Telefon kakav prihvata baza (`private.clean_phone`): cifre, razmaci i `+ ( ) / -`, sa
/// 6–15 cifara. **Format se ne mijenja** — salon zove broj onako kako ga je klijent napisao.
///
/// Stoji u domeni, a ne u ekranu, jer isto pravilo važi za registraciju i za „Dopuni
/// profil". Server ostaje izvor istine: ovo samo štedi korisniku put do greške.
bool isValidPhone(String unos) {
  final v = unos.trim();
  if (!RegExp(r'^\+?[0-9 ()/-]+$').hasMatch(v)) return false;
  final cifara = v.replaceAll(RegExp('[^0-9]'), '').length;
  return cifara >= 6 && cifara <= 15;
}

/// Ime i prezime kakvo prihvata baza (`private.clean_name`): 1–120 znakova poslije trima.
bool isValidFullName(String unos) {
  final v = unos.trim();
  return v.isNotEmpty && v.length <= 120;
}

/// Email kakav forma pušta do servera: lokalni dio, `@`, domena sa bar jednom tačkom i
/// vršnim dijelom od 2+ slova. Bez razmaka, bez dvije tačke zaredom, bez tačke na rubu.
///
/// Auth server ostaje izvor istine; ovo hvata tipfelere („ana@gmail", „ana@@x.ba",
/// „ana@gmail..com") prije mreže, jer server na njih vraća grešku koja ne kaže šta je krivo.
bool isValidEmail(String unos) {
  final v = unos.trim();
  if (v.length > 254 || v.contains('..')) return false;
  return RegExp(
    r'^[A-Za-z0-9!#$%&*+/=?^_`{|}~-]+(\.[A-Za-z0-9!#$%&*+/=?^_`{|}~-]+)*'
    r'@[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*'
    r'\.[A-Za-z]{2,}$',
  ).hasMatch(v);
}

/// Pozivni broj države za polje telefona. Prvi u [phoneCountryCodes] je podrazumijevani.
typedef PhoneCountryCode = ({String code, String country});

/// Države iz kojih klijenti realno dolaze: region, pa dijaspora. Lista je kratka namjerno
/// — padajući meni od 200 država na telefonu je gori od kucanja `+`.
const List<PhoneCountryCode> phoneCountryCodes = [
  (code: '+387', country: 'BiH'),
  (code: '+385', country: 'Hrvatska'),
  (code: '+381', country: 'Srbija'),
  (code: '+382', country: 'Crna Gora'),
  (code: '+386', country: 'Slovenija'),
  (code: '+389', country: 'Sjeverna Makedonija'),
  (code: '+49', country: 'Njemačka'),
  (code: '+43', country: 'Austrija'),
  (code: '+41', country: 'Švicarska'),
  (code: '+46', country: 'Švedska'),
];

/// Broj **bez** pozivnog: „061 123 456", „61/123-456". Vodeća nula je dozvoljena jer je
/// tako ljudi pišu lokalno; poslije nje broj ne počinje nulom i ima 6–12 cifara.
bool isValidNationalNumber(String unos) {
  final cifre = unos.trim().replaceAll(RegExp(r'[\s/().-]'), '');
  return RegExp(r'^0?[1-9][0-9]{5,11}$').hasMatch(cifre);
}

/// Pozivni + broj u zapis koji ide u bazu: „+387 61 123 456". Vodeća nula lokalnog zapisa
/// otpada, a razmaci koje je korisnik napisao ostaju — salon broj čita onako kako ga je
/// klijent grupisao. Rezultat zadovoljava [isValidPhone] (i `private.clean_phone`).
String composePhone(String pozivni, String broj) {
  var b = broj.trim().replaceAll(RegExp(r'[/().-]'), ' ');
  b = b.replaceAll(RegExp(r'\s+'), ' ');
  if (b.startsWith('0')) b = b.substring(1).trimLeft();
  return '$pozivni $b';
}
