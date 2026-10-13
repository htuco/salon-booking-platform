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
