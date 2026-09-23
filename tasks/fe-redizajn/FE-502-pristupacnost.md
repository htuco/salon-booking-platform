# FE-502 — Pristupačnost i kontrast

| | |
|---|---|
| **Epik** | FE-5 · Kvalitet i konzistentnost |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | [FE-101](FE-101-tokeni-boja.md), [FE-102](FE-102-tipografija-barlow.md) |
| **Blokira** | — |
| **Reference** | `packages/core_ui/test/contrast_test.dart` · `packages/core_ui/lib/src/theme/contrast.dart` |

## Cilj
Kontrast, dodirne površine i uvećan sistemski font ne lome nijedan ekran.

## Zatečeno stanje
Kontrast **već ima aparaturu i test**: `packages/core_ui/lib/src/theme/contrast.dart` nosi `readableOn`, a
`buildAppTheme` pomjera brand boju dok ne bude čitljiva na **obje** površine teme (pozadina ekrana
i kartica), računajući prema težem slučaju. `contrast_test.dart` to provjerava.

Ono što ne postoji: provjera dodirnih meta i ponašanja pri uvećanom sistemskom fontu.

## Definicija gotovog
- [x] Tekst ≥ 4,5:1, naslovi ≥ 3:1 — dokazano testom, ne okom
- [x] Sve dodirne mete ≥ 44 px, uključujući tabove i slotove
- [x] Aplikacija podnosi sistemski font uvećan do 130 % bez presijecanja teksta
- [x] Fokus je vidljiv na svim interaktivnim elementima (bitno za admin na webu)
- [x] Uppercase je stil, ne `toUpperCase()` nad stringom — čitač ekrana čita slova umjesto riječi
- [x] Postojeći `contrast_test` proširen na nove tokene, ne zaobiđen

## Zamke
- **Kontrast se ne mjeri na jednoj pozadini.** Ista boja nosi tekst i na pozadini ekrana i na
  kartici; `buildAppTheme` to već računa i tu logiku ne treba ponavljati u ekranu.
- Uvećan font najprije lomi ono što je „taman stalo" — a [FE-102](FE-102-tipografija-barlow.md) mijenja visinu svakog reda.
  Zato ovaj task ide poslije njega.
- Koralna na bijeloj je 3,05:1 (`prototype/admin/SPEC.md:104`) — zato tekst na koralu jeste `#2C2C2C`,
  a ne bijel. To je već izmjereno i ne preispituje se bez novog mjerenja.

## Status

**Gotovo, dokazano testovima.** Grana `feat/fe-502-pristupacnost`. Na uređaju i u browseru
**nije viđeno** — v. „Ostalo" ispod.

### Mjerenje prije popravke

Prvo je napisano mjerenje, pa tek onda popravke. Flutterovi `meetsGuideline` matcheri
(`iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`) mjere
**iscrtane piksele i stvarno stablo semantike**, ne tokene:

- **Klijent** — `apps/client/test/accessibility_test.dart`: 11 ruta na 390 × 844. Kontrast
  se mjeri na **svakom tenantu iz registra**, jer je brand boja podatak (ADR-0018).
- **Admin** — `apps/admin/test/support/pristupacnost.dart`: jedan poziv iz test fajla
  svakog ekrana (11 ekrana), na obje širine iz handoffa, plus 130 % fonta na telefonu.
  Helper ne nosi svoj harness — koristi onaj koji test ekrana već ima.
- **Fokus** — nova provjera nad stablom semantike: svaki čvor sa tap radnjom mora biti
  fokusabilan. Material kontrole fokus crtaju same; rupa je bila meta do koje tastatura
  uopšte ne dolazi.

Prvi prolaz: **klijent 3 pada, admin 21**. Sabotažom je provjereno da svaka provjera
stvarno pada (mete, kontrast, fokus, verzal) — poruka imenuje element i broj reda.

### Šta je nađeno i popravljeno

- **Booking zaglavlje se lomilo i na normalnom fontu** — 3,7 px na 390 px, 95 px na 130 %.
  Nazad se sad skraćuje, oznaka koraka ostaje cijela.
- **Admin mete od 34–42 px** — stavka sidebara (37), dugmad u top baru i karticama (34–42),
  polja pretrage (42), filteri klijenata (38), strelice kalendara (38), ćelija smjene (34),
  prekidači (42 × 24). Sve je na `AdminSize.touchTarget`; `buttonHeight` i
  `topBarButtonHeight` su sada **aliasi** tog tokena, pa se ne mogu razići. **Ovo je
  svjesno odstupanje od piksela iz `adminv2/`**: DoD je jači od izmjerenog piksela.
- **Crvena za destruktivne radnje** — „Otkaži" je bio 4,12:1 (svijetla, `#C94C4C` →
  `#B83C3C`) i 3,93:1 (tamna, `#F03E3E` → `#FF6B6B`).
- **Vrijeme pauze na šrafuri** — `#666` preko crta `separator` 4,43:1; ide punom bojom.
- **Separator `/` u breadcrumbu** — čitač ga je izgovarao, a kontrast ga je mjerio kao
  tekst. Sada je `ExcludeSemantics`.
- **Dugmad bez imena** — strelice kalendara (samo `Tooltip`) i „Blokiraj vrijeme" (samo
  ikona). Labela ide na `Icon.semanticLabel`, koji se spaja u čvor dugmeta.
- **Tap bez fokusa** — dva admin prekidača i fotografije galerije (dva mjesta) bili su
  goli `GestureDetector`. Admin prelazi na `InkWell`; slike dobijaju novi `AppTappable` u
  `core_ui`, jer bi preklop `InkWell`-a bio ispod slike. Prsten fokusa je 2 px u `primary`
  boji tenanta (`prototype/ui/README.md`).
- **130 %** — ćelija dana u kalendaru (fiksna visina 68) i zaglavlje detalja termina.
- **Verzal** — sedam mjesta bez `semanticsLabel`, uključujući doslovne stringove
  `'CIJENA'`/`'ONLINE'` u zaglavlju usluga i kicker dijaloga u `core_ui`. Čuvar:
  `verzal_semantika_test.dart` u obje aplikacije; izuzetak se piše kao `// verzal-ok:`.
  Ćelija odsustva na telefonu (`GO`) čitaču daje puni razlog.
- **`contrast_test`** — `core_ui` mjeri FE-101 tokene `error`/`onError` na sve tri teme;
  admin mjeri `destructive` kao tekst, ne samo kao ispunu.
- **Slotovi** — `TimeSlotChip` je već imao 44 × 58; sada je to dokazano testom na sve tri
  teme (`core_ui/test/time_slot_chip_a11y_test.dart`), jer korak 3 traži stanje flowa.

### Zamka koju je mjerenje našlo u sebi

Na beauty tenantu natpis dugmeta je mjerio **1,03:1** — bijel na bijelom. Nije greška
teme: `AnimatedTheme` se završi u zadnjem frejmu, a tek tada dugme krene svoj prelaz boje
teksta. Test čeka još jedan frejm. Ista zamka je već opisana u `tenant_theme_test.dart`;
ko mjeri kontrast na drugom tenantu, mora je znati.

### Dokaz

**Admin 392, klijent 309, `core_ui` 104, `core_api` 134, `core_domain` 88 — PASS.**
Analiza čista u svih pet paketa, `dart format --set-exit-if-changed` čist.

### Ostalo za sljedećeg

- **Fokus nije viđen u browseru.** Testovi dokazuju da je svaka meta fokusabilna i da
  `AppTappable` crta prsten; da se Materialov preklop fokusa na admin kontrolama **dovoljno
  vidi** na webu, to test ne mjeri. Provjera: `cd apps/admin && flutter run -d chrome`, pa
  Tab kroz sidebar, filtere klijenata i prekidače radnog vremena.
- **Admin tamna tema nije mjerena na ekranima** — helper mjeri svijetlu; tokeni tamne
  palete su pokriveni u `theme_contrast_test.dart`.
- **Booking koraci 2–4** nisu u `accessibility_test.dart` (traže stanje flowa); slotovi su
  pokriveni kroz `core_ui`.
