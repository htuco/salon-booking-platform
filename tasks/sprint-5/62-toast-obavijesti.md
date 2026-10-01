# Task 62 — Toast obavijesti u adminu

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `prototype/adminv2/toast/` (`README.md`, `toast.css`, `toast.ts`, `5b-varijante.png`) |

## Cilj
Admin javlja ishod radnje tamnom toast karticom iz handoffa umjesto Material `SnackBar`-a:
vrsta se vidi po krugu (uspjeh, informacija, upozorenje, greška), naslov kaže šta se desilo,
opis i akcija su opcioni.

## Definicija gotovog
- [x] `AdminToast.uspjeh|info|upozorenje|greska` u `core/widgets/admin_toast.dart`; svih ~30
      poziva `showSnackBar` u adminu prebačeno, svaki sa svojom vrstom
- [x] Desktop gore desno (16 px ispod top bara, 24 od ruba, širina 360), najviše tri, najnoviji
      gore. Telefon odozgo ispod safe-area, jedan po jedan, povlačenje gore zatvara
- [x] Uspjeh i informacija se gase za 5 s uz koralnu liniju; hover i fokus pauziraju.
      Upozorenje i greška stoje dok se ne zatvore
- [x] Ulaz 320 ms sa prebačajem, izlaz 220 ms ease-in; bez pokreta kad sistem to traži
- [x] `role=alert`/`status` na webu, live region na uređaju; × ima labelu „Zatvori", mete ≥ 44 px
- [x] Boje iz palete (`toastOk/Info/Warn/Err` + postojeći sidebar tokeni), kontrast izmjeren
- [x] Test da se `SnackBar` ne vrati; `admin_toast_test.dart` za pravila iz handoffa
- [x] Viđeno uživo na 1440 i 402 (demo build)
- [ ] Viđeno na hostovanom projektu sa pravim nalogom
- [ ] CI zelen na PR-u

## Odstupanja od handoffa
- **Validacija radnog vremena ostaje i toast** (upozorenje): dugme za snimanje je daleko od
  poruke iznad sedmice. Poruka i dalje stoji i uz formu.
- **Isti naslov dvaput je jedan toast** — realtime koji pada u petlji ne slaže tri ista.
- **Glifovi su Material ikone** (kvačica, uskličnik, ×) i slovo „i" u Barlowu, ne tekstualni znakovi.
- **Akcija je visoka 44 px** (FE-502), pa je kartica sa akcijom par piksela viša od izvoza.

## Zamke
- `SizeTransition` uvijek clipuje: sjena kartice se sjekla na razmaku ispod nje i ostajala je
  siva traka oštrih ivica. Visina se zato animira kroz `Align(heightFactor:)`.
- Toast živi u **korijenskom** overlayu. U aplikaciji je to `AdminToastSloj` iznad navigatora
  (toast je iznad dijaloga), u testu sa golim `MaterialApp` overlay navigatora — isti poziv radi.
- Odbrojavanje je animacija, pa `pumpAndSettle` čeka da se uspjeh sam skloni. Test koji gleda
  toast poslije radnje koristi `pump`.

## Status
U toku (grana `feat/admin-toastovi`, 2026-10-01).
