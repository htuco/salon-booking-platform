# Task 09 — `core_ui`: theme factory po tenantu

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [07 — plumbing](07-app-plumbing.md), [08 — core_api](08-core-api-repozitoriji.md) |
| **Blokira** | 10 (home), 11 (booking flow) |
| **Reference** | [01 §17 korak 8](../../docs/01-mvp-spec.md#17-build-order) · [02 design system](../../docs/02-user-flows-wireframes.md) · [04 §1](../../docs/04-flutter-tenant-factory.md) |

## Cilj
Tema se **gradi iz dvije boje koje dolaze iz backenda**, sa fallbackom iz `tenant.yaml` dok backend ne odgovori. Promjena boje salona ne traži build, a tekst je čitljiv na obje palete bez ručnog dotjerivanja po salonu.

## Definicija gotovog
- [x] `core_ui/src/theme/theme_factory.dart`: `ThemeData build(primary, secondary, brightness)` — jedina funkcija koja pravi temu u cijelom sistemu
- [x] **`onPrimary` se bira automatski po luminanciji** pozadine, ne hardkodira ([01 §17 korak 8](../../docs/01-mvp-spec.md#17-build-order)). Test: bijeli tekst na `#C6A667` i na `#171717` daje kontrast ≥ 4.5:1
- [x] Dvije imenovane teme iz `tenant.yaml` `branding.theme`: `modern_barber` (tamna) i `elegant_beauty` (svijetla); `clinical_calm` ostavljen kao TODO za dentalnu vertikalu
- [x] Tokeni u `core_ui/src/tokens/`: razmaci, radijusi, tipografija, trajanja animacija — nijedan ekran ne piše `EdgeInsets.all(24)` napamet
- [x] Tema se čita kroz provider: `salon.primaryColor` iz backenda → fallback `TenantConfig` iz `tenants.g.dart` → tek onda default. **Nema bijelog flasha** pri startu
- [x] Osnovne komponente u `core_ui/src/components/`: dugme, kartica usluge, chip termina, prazno stanje, skeleton loader — svaka koristi tokene i temu, nijedna literal boju
- [x] Golden ili widget test koji renderuje isti ekran u obje teme i pada na neusklađen kontrast
- [x] `apps/client/test/tenant_theme_test.dart` proširen: prolazi za oba demo tenanta i dalje kroz `--dart-define=SALON_ID`

## Koraci
1. Prebaci logiku iz `main.dart` (`ColorScheme.fromSeed` sa hardkodiranim heksovima) u `theme_factory`, pa je obriši iz app-a
2. Napiši luminancijski izbor `onPrimary`/`onSecondary` i test sa stvarnim paletama oba demo salona
3. Definiši tokene po [docs/02 design system](../../docs/02-user-flows-wireframes.md); ne izmišljaj novu skalu
4. Napravi 4–5 komponenti koje booking flow sigurno treba, ne cijeli katalog unaprijed
5. Poveži temu na `salonProvider` sa fallback lancem i dokaži da nema flasha (usporen mrežni odgovor)
6. Commit: `feat(core_ui): theme factory po tenantu + tokeni + osnovne komponente`

## Zamke
- **`Theme.of(context)` u `build` metodi koja sama postavlja `MaterialApp` vraća Flutterov default**, ne tenant temu. Tijelo mora biti zaseban widget — ta greška je već jednom napravljena (`a53a429`) i test `tenant_theme_test.dart` postoji zbog nje.
- Fallback boje u `tenant.yaml` moraju biti iste kao `salons.primary_color`/`secondary_color`. Kad se raziđu, baza je u pravu — ali korisnik vidi treptaj boje na startu.
- Tamna paleta barbera znači da svaka nova komponenta mora biti provjerena na obje teme. Ekran testiran samo na beauty paleti je ekran testiran napola.

## Status (2026-09-11) — ✅ zatvoren

Svih osam DoD stavki ima dokaz. Zeleno na CI-ju:
[`Flutter` run 34630719984](https://github.com/htuco/salon-booking-platform/actions/runs/34630719984)
— analiza, format, **140 testova** (admin 4 · client 27 · core_api 32 · core_domain 39 ·
**core_ui 38**), plus korak "Regresija teme po tenantu" sa 8 testova po tenantu, oba Android APK-a
i oba iOS builda.

### Dokaz po stavkama

| Stavka | Dokaz |
|---|---|
| `theme_factory` jedina pravi temu | `buildAppTheme` u `packages/core_ui/lib/src/theme/theme_factory.dart`; heksovi obrisani iz `main.dart`, koji sada čita `appThemeProvider` |
| `onPrimary` po kontrastu | `onColorFor` u `contrast.dart`; `contrast_test.dart` mjeri obje demo palete i žutu iz `docs/02 §14` |
| Dvije imenovane teme | `AppTheme.modernBarber`/`elegantBeauty` u `app_theme.dart`; `clinicalCalm` postoji sa TODO za dentalnu vertikalu |
| Tokeni | `tokens/spacing.dart` (razmaci, radijusi, trajanja, dodirne mete), `tokens/status_colors.dart`; tipografija u `_textTheme` |
| Fallback lanac, nema flasha | `apps/client/lib/src/core/theme_provider.dart`; `tenant_theme_test.dart` mjeri **prvi frame** sa `salonProvider`-om koji nikad ne odgovori |
| Komponente | `AppButton`, `ServiceCard`, `TimeSlotChip`, `StatusBadge`, `EmptyState`, `SkeletonLoader` |
| Test u obje teme | `components_test.dart` renderuje isti ekran u obje palete i pada na kontrast ispod 4.5:1 |
| `tenant_theme_test.dart` proširen | 8 testova: kontrast, prvi frame, backend pretekne fallback, neispravan heks, build bez tenanta u registru |

### Šta je test našao, a oko ne bi

`components_test.dart` je pao na **roze cijeni sa 4.12:1**. Uzrok: brand boja za tekst je bila
mjerena samo na `surface`, a kartica usluge stoji na `surfaceContainer`, koji je drugačiji.
Popravljeno u `_citljivoNaObje` — pomak se računa prema težoj od dvije površine. Test mjeri svaki
`Text` prema **njegovoj stvarnoj pozadini**, ne prema pozadini ekrana; verzija koja gleda samo
pozadinu ekrana bi ovo propustila i lažno prijavila badge.

### Odluke koje se ne vide iz DoD-a

- **`onPrimary` se bira poređenjem WCAG odnosa, ne pragom luminancije.** DoD kaže "po luminanciji";
  naivni prag 0.5 na zlatnoj `#C6A667` (luminancija 0.42) stavlja bijeli tekst i daje 2.6:1.
  Poređenje odnosa bira crnu i daje 8:1. Stavka je ispunjena po namjeri, ne po slovu.
- **Statusne boje stoje van `ColorScheme`-a**, u `ThemeExtension`-u (`docs/02 §16`): salon koji
  izabere zelenu kao primarnu ne smije dobiti statuse koji se s njom stope.
- **Brand boja ima dvije varijante**: `colorScheme.primary` je tačna boja (pozadina dugmeta), a
  `AppBrandColors.primaryOnSurface` je pomjerena varijanta za **tekst**. Bez toga sekundarna boja
  barbera (`#171717`) na tamnoj pozadini nestane.
- **Generator nosi boje u registar kao ARGB `int`**, ne heks string — app ne parsira boju pri
  startu, a neispravan format pada u CI-ju umjesto na uređaju.
- **Widget test umjesto goldena.** DoD dozvoljava "golden **ili** widget test"; golden hvata
  piksele, a ovdje je pitanje čitljivost, koja se mjeri.

### Ostaje za sljedećeg

- **Nije pokrenuto na uređaju ni u browseru.** Dokaz je widget-test nivo. Task 07 je pokazao da
  browser nalazi ono što suite propusti (prazna bijela stranica, tihi deep link), pa ovo vrijedi
  ponoviti u tasku 10, kad prvi pravi ekran bude imao šta prikazati.
- **`clinical_calm` nema tenanta.** Paleta i `AppTheme.fromName` su testirani, ali nijedan demo
  salon nije dental — prva prava provjera ide uz dentalnu vertikalu.
- **Komponente iz `docs/02 §16` koje još ne postoje**: `AppTextField`, `AppSelect`, `DateStrip`,
  `StepProgressBar`, `AppBottomSheet`, `StatTile`, `ContactActionRow`. Namjerno — task traži 4–5
  komponenti koje booking flow sigurno treba, ne cijeli katalog unaprijed.
