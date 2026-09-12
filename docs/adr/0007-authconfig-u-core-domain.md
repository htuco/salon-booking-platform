# `AuthConfig` živi u `core_domain` i nosi vlastiti enum platforme

## Status

prihvaćen

## Kontekst

`docs/06 §6.2` je od početka tražio da lista providera prijave bude **podatak, a ne `if` u
widgetu** — isto pravilo kao za vertikale. Skica je stavljala `AuthConfig` u `core_domain` i
filtrirala po Flutterovom `TargetPlatform`:

```dart
List<AuthProvider> forPlatform(TargetPlatform p) { ... }
```

Ta skica se **ne može kompajlirati**. `core_domain` je u [tasku 06](../../tasks/06-vertical-pack.md)
preveden na čist Dart — zavisnosti su mu `freezed_annotation`, `json_annotation` i `meta`, bez
`package:flutter` ([ADR-0006](0006-modeli-u-core-domain.md)) — a `TargetPlatform` je Flutterov tip.

Uz to, `tasks/sprint-2/12-auth-provideri.md` je u definiciji gotovog tražio `AuthConfig` u
`core_api`, što se sa `docs/06` nije slagalo. Task 12 nije mogao početi dok se to ne razriješi.

## Odluka

`AuthConfig`, `AuthProvider` i `AuthSession` ostaju u `core_domain`. Domen dobija **vlastiti enum
platforme**, `AuthPlatform { ios, android, web }`, i `forPlatform` prima njega.

Mapiranje Flutterovog tipa u domenski radi jedna funkcija u `core_api`, gdje Flutter ionako
postoji:

```dart
AuthPlatform authPlatformOf(TargetPlatform p);
AuthPlatform get currentAuthPlatform;   // kIsWeb se provjerava PRIJE defaultTargetPlatform
```

Koji provider na kojoj platformi uopšte ima implementaciju stoji na samom `AuthProvider`-u
(`platforms`), pa je to znanje na jednom mjestu, a ne raspoređeno po ekranima.

## Razmatrane opcije

- **`AuthConfig` u `core_api`** — odbačeno: `core_api` je transportni sloj ("jedini sloj koji zna za
  HTTP i imena tabela"), a ovo je konfiguracija koja nema veze sa mrežom. Uz to bi obrazloženje iz
  ADR-0006 — modeli se drže u domenu da ih može koristiti i backend koji nije Flutter — vrijedilo
  za sedam modela, a za osmi ne.
- **`core_domain` uvozi `package:flutter`** — odbačeno: poništava ADR-0006 zbog jednog enuma i
  otvara domen cijelom frameworku, čime prestaje biti testabilan bez Flutter runtimea.
- **`forPlatform(String)` sa golim stringom** — odbačeno: `switch` nad enumom Dart provjerava na
  iscrpnost, pa nova platforma obori build na mjestima koja je ne obrađuju; string bi tiho pao u
  `else`.
- **Bez filtriranja u domenu, `if (Platform.isIOS)` u ekranu** — odbačeno: to je tačno ono što
  `docs/06 §6.2` zabranjuje, i vraća nas na stanje gdje se provider gasi novim store submissionom.

## Posljedice

- `docs/06 §6.2` je ispravljen u istoj promjeni; skica sa `TargetPlatform` više ne stoji nigdje.
- Definicija gotovog u tasku 12 je odstupila od svog originalnog teksta (`AuthConfig` u `core_api`)
  i to je zabilježeno u njegovom status bloku.
- Svaka nova platforma traži dopunu na dva mjesta: `AuthPlatform` i `authPlatformOf`. To je cijena
  granice i plaća se jednom.
- **Izgleda kao bug, a nije:** Apple se ne pojavljuje na Androidu ni kad je `apple: true` u
  `tenant.yaml`. Presjek je namjeran u oba smjera — tenant ne može uključiti provider koji na toj
  platformi nema implementaciju.
- **Izgleda kao bug, a nije:** web build nudi samo email OTP, jer nativni tokovi tamo nemaju
  implementaciju. `kIsWeb` se provjerava prije `defaultTargetPlatform` upravo zato što bi browser
  na iPhoneu inače prijavio `TargetPlatform.iOS` i ponudio Sign in with Apple koji ne radi.
