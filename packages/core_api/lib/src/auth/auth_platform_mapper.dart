import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';

/// Jedino mjesto gdje Flutterov [TargetPlatform] postaje domenski [AuthPlatform].
///
/// `core_domain` je čist Dart i ne smije uvesti `package:flutter`
/// (`docs/adr/0006-modeli-u-core-domain.md`), a `AuthConfig.forPlatform` ipak mora znati na
/// čemu radi. Granica se plaća ovdje, jednom funkcijom, umjesto da se domen otvori cijelom
/// frameworku. `docs/06 §6.2` je do ovog taska pokazivao `forPlatform(TargetPlatform)` —
/// ta skica se nije mogla kompajlirati.
///
/// Sve što nije iOS ni Android ide u [AuthPlatform.web]: web je jedini preostali target u
/// `tenant.yaml`, a desktop build ne postoji. Kad se pojavi, ovdje je jedno mjesto koje ga
/// treba naučiti.
AuthPlatform authPlatformOf(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS => AuthPlatform.ios,
  TargetPlatform.android => AuthPlatform.android,
  _ => AuthPlatform.web,
};

/// Platforma na kojoj app trenutno radi.
///
/// [kIsWeb] se provjerava **prije** [defaultTargetPlatform]: u browseru na iPhoneu
/// `defaultTargetPlatform` vraća `TargetPlatform.iOS`, pa bi web build ponudio Sign in with
/// Apple koji tamo nema nativnu implementaciju.
AuthPlatform get currentAuthPlatform =>
    kIsWeb ? AuthPlatform.web : authPlatformOf(defaultTargetPlatform);
