/// Platforma na kojoj app radi, izražena u domenskim terminima.
///
/// **Zašto vlastiti enum, a ne Flutterov `TargetPlatform`.** `core_domain` je čist Dart —
/// bez `package:flutter` — jer se domen mora moći testirati i ponovo upotrijebiti izvan
/// Flutter runtimea (v. `docs/adr/0006-modeli-u-core-domain.md`). `TargetPlatform` je
/// Flutterov tip, pa bi ga uvoz ovdje povukao cijeli framework u sloj koji ga nema.
///
/// Mapiranje `TargetPlatform → AuthPlatform` radi sloj iznad (`core_api`), gdje Flutter
/// ionako postoji. `docs/06 §6.2` je do ovog taska pokazivao `forPlatform(TargetPlatform)`
/// — ta skica se nije mogla kompajlirati i ispravljena je.
enum AuthPlatform {
  ios,
  android,

  /// Web build postoji samo kao preview za brzu vizuelnu provjeru — nije store target
  /// nijednog tenanta (`targets.web` u `tenant.yaml`). Nativni provideri tu nemaju
  /// implementaciju, pa ostaje samo ono što radi kroz običan HTTP.
  web,
}
