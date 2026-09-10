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
- [ ] `core_ui/src/theme/theme_factory.dart`: `ThemeData build(primary, secondary, brightness)` — jedina funkcija koja pravi temu u cijelom sistemu
- [ ] **`onPrimary` se bira automatski po luminanciji** pozadine, ne hardkodira ([01 §17 korak 8](../../docs/01-mvp-spec.md#17-build-order)). Test: bijeli tekst na `#C6A667` i na `#171717` daje kontrast ≥ 4.5:1
- [ ] Dvije imenovane teme iz `tenant.yaml` `branding.theme`: `modern_barber` (tamna) i `elegant_beauty` (svijetla); `clinical_calm` ostavljen kao TODO za dentalnu vertikalu
- [ ] Tokeni u `core_ui/src/tokens/`: razmaci, radijusi, tipografija, trajanja animacija — nijedan ekran ne piše `EdgeInsets.all(24)` napamet
- [ ] Tema se čita kroz provider: `salon.primaryColor` iz backenda → fallback `TenantConfig` iz `tenants.g.dart` → tek onda default. **Nema bijelog flasha** pri startu
- [ ] Osnovne komponente u `core_ui/src/components/`: dugme, kartica usluge, chip termina, prazno stanje, skeleton loader — svaka koristi tokene i temu, nijedna literal boju
- [ ] Golden ili widget test koji renderuje isti ekran u obje teme i pada na neusklađen kontrast
- [ ] `apps/client/test/tenant_theme_test.dart` proširen: prolazi za oba demo tenanta i dalje kroz `--dart-define=SALON_ID`

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
