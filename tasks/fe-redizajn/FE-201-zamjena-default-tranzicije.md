# FE-201 — Jedna tranzicija na obje platforme

| | |
|---|---|
| **Epik** | FE-2 · Navigacija i tranzicije |
| **Aplikacija** | `apps/client` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | — |
| **Blokira** | [FE-302](FE-302-booking-flow.md) |
| **Reference** | `packages/core_ui/lib/src/theme/theme_factory.dart:189` · `apps/admin/lib/src/core/theme/admin_theme.dart` · `docs/02 §14` |

## Cilj
Push i pop prelaz izgledaju **isto** na Androidu i iOS-u: kratak fade uz pomak 8–12 px po X osi,
bez parallaxa i bez odskoka.

## Šta je stvarno zatečeno
Task iz handoffa polazi od toga da je u upotrebi defaultna Flutter tranzicija sa vertikalnim
izdizanjem na Androidu. **To nije tačno i provjereno je u kodu** — polazna tačka je drugačija, pa
je i posao drugačiji:

```dart
// packages/core_ui/lib/src/theme/theme_factory.dart:189
// `docs/02 §14`: max 300 ms. Fade je najkraci prelaz koji jos citljivo povezuje ekrane.
pageTransitionsTheme: const PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  },
),
```

Dakle: Android **već** ne radi vertikalno izdizanje. Stvarni nedostatak je što su registrovana
**dva različita** buildera, pa se ponašanje razlikuje po platformi — što je tačno ono što DoD
zabranjuje. Uz to:

- Registrovane su samo dvije `TargetPlatform` vrijednosti. `macOS`, `windows`, `linux` i **web**
  padaju na Material podrazumijevani builder — a admin je Flutter web.
- `apps/admin/lib/src/core/theme/admin_theme.dart` **nema `pageTransitionsTheme` uopšte**.
- Nijedan ekran ne pravi vlastiti `PageRouteBuilder` ni `CustomTransitionPage` — grep ne vraća
  nijednu upotrebu. Korak „ukloniti pojedinačne implementacije po ekranima" je time već ispunjen.

## Definicija gotovog
- [x] Jedan `AppPageTransitionsBuilder` registrovan za **sve** `TargetPlatform` vrijednosti, ne za dvije
      — `packages/core_ui/lib/src/theme/page_transition.dart`, test prolazi kroz `TargetPlatform.values`
- [ ] Prelaz vizuelno identičan na Androidu i iOS-u — dokaz je snimak oba, ne tvrdnja
      — **nedokazano**: isti builder na obje platforme (test), ali snimka sa uređaja nema
- [x] Trajanje 220 ms push / 180 ms pop, `easeOutCubic` ulaz, `easeInCubic` izlaz; ostaje unutar
      granice od 300 ms koju traži `docs/02 §14`
- [x] **iOS swipe-back i dalje radi** — vlastiti builder ga gubi ako se ne zadrži eksplicitno
      — vraćen kroz javni predictive-back ugovor rute; test, provjeren sabotažom
- [ ] Nema bijelog bljeska pozadine tokom prelaza — po konstrukciji (stari ekran ostaje ispod,
      novi se pretapa preko), ali **nije viđeno uživo**
- [x] `MediaQuery.disableAnimationsOf` / *Reduce Motion*: samo fade, bez pomaka
- [x] Odlučeno i zapisano dobija li admin isti builder ili ostaje na podrazumijevanom
      — **admin ostaje na svom pretapanju od ~150 ms** ([ADR-0020](../../docs/adr/0020-admin-je-1na1-sa-adminv2-barlow-i-svijetla-tema.md) tačka 5)

## Zamke
- **Swipe-back nije dio tranzicije nego `CupertinoRouteTransitionMixin`-a.** Zamjena buildera ga
  tiho ukine; korisnik to ne prijavi kao grešku nego kao „aplikacija se čudno ponaša".
- `FadeForwardsPageTransitionsBuilder` je Material 3 expressive builder i **već je odabran svjesno**
  uz komentar koji se poziva na `docs/02 §14`. Ako novi builder mijenja taj dogovor, mijenja se i
  komentar, ne samo kod.
- Prelaz koji izgleda dobro u debug buildu na simulatoru zna da pukne na profile buildu na starom
  Androidu. Dokaz je uređaj.

## Status

**Kod gotov, dokazan testovima; uređaj nedostaje.** Grana `feat/fe-201-jedna-tranzicija`.

- `AppPageTransitionsBuilder` u `core_ui` zamjenjuje par `FadeForwards` + `Cupertino` i
  registrovan je za svih šest platformi. Trajanje nosi sam builder (`transitionDuration`), pa ga
  `MaterialPage` iz `go_router`-a poštuje bez izmjena u rutama.
- Swipe-back: Cupertino detektor je privatan, pa builder na iOS/macOS dodaje svoj rub od 20 px
  koji vodi rutu kroz `handleStartBackGesture` / `handleCommitBackGesture`. Android ga nema.

**Dokaz (2026-09-23):**
- `packages/core_ui`: `flutter analyze` — No issues found; `flutter test` — **75 pass**
  (8 novih u `page_transition_test.dart`). Sabotaža (uklonjen rub za povlačenje) obara tačno
  test povlačenja.
- `apps/client`: `flutter analyze` — No issues found; `flutter test` — **238 pass**.
  Zamka: sa zastarjelim `*.freezed.dart` u `core_domain` (gitignored) 22 fajla ne kompajliraju;
  `dart run build_runner build -d` u `packages/core_domain` to rješava. Nije regresija.

**Ostalo za sljedećeg:** snimak push/pop i swipe-backa na Android i iOS uređaju
(`flutter run --profile --flavor <f> -t lib/main.dart`), i potvrda da nema bljeska.
