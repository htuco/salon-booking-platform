# FE-205 — Ukinuti default Flutter indikatore i loading assete

| | |
|---|---|
| **Epik** | FE-2 · Navigacija i tranzicije |
| **Aplikacija** | `apps/client` + `apps/admin` (uklj. Flutter Web) |
| **Procjena** | 2–3 dana |
| **Zavisi od** | — |
| **Blokira** | [FE-501](FE-501-stanja-i-skeletoni.md) |
| **Reference** | `packages/core_ui/lib/src/components/app_button.dart` · `packages/core_ui/lib/src/components/step_progress_bar.dart` · `apps/admin/web/index.html` |

## Cilj
Nijedan ugrađeni Material indikator ne ostaje u proizvodu: ni plava linija pri učitavanju, ni
spinner, ni ripple, ni podrazumijevani SnackBar.

## Zatečeno stanje
Najveći task epika po broju dodirnutih fajlova, i jedini koji se vidi pri **svakom** pokretanju:

- **32 upotrebe** `CircularProgressIndicator` / `LinearProgressIndicator` u 15 fajlova. Od toga
  **12 admin ekrana** (`clients`, `settings`, `working_hours` ×2, `calendar`, `appointments` ×3,
  `auth`, `dashboard`, `services`, `employees`) i dvije komponente u `core_ui`
  (`app_button.dart`, `step_progress_bar.dart`).
- Klijentski ekrani ih nemaju u `lib/`, ali ih **tri testa očekuju**
  (`home_screen_test.dart`, `services_screen_test.dart`, `about_screen_test.dart`) — ti testovi
  padaju kad indikator ode i moraju se mijenjati u istoj promjeni, ne poslije.
- `RefreshIndicator` / `SnackBar` / `splashFactory` se pojavljuju u 19 fajlova kroz obje aplikacije.
- Admin je Flutter **web** i ima `apps/admin/web/index.html` — bootstrap loader tamo je odvojen
  problem od svega u Dartu i lako ostane zaboravljen.

## Definicija gotovog
- [ ] Pri pokretanju nema plave linije ni spinnera — ni na mobilnom, ni na webu
- [ ] Nema bijelog bljeska između splasha i prvog ekrana; boja native splasha,
      `scaffoldBackgroundColor` i `background-color` u `index.html` su **ista vrijednost iz tokena**
- [ ] Grep ne vraća nijednu upotrebu `CircularProgressIndicator` ni `LinearProgressIndicator` u `lib/`
- [ ] Tri klijentska testa koja ih očekuju prepisana da traže novo stanje, ne obrisana
- [ ] Dugme u toku akcije nosi vlastiti tanki indikator u boji svog teksta
- [ ] `RefreshIndicator` i `SnackBar` idu kroz vlastite komponente sa tokenima
- [ ] Nema ripplea: `splashFactory: NoSplash.splashFactory`, feedback je kratka promjena pozadine
- [ ] Nigdje Material podrazumijevana plava (`Colors.blue`, `#2196F3`)
- [ ] `debugShowCheckedModeBanner: false`

## Koraci
1. `core_ui` prvo — `app_button.dart` i `step_progress_bar.dart` nose indikator koji koriste svi
2. Zatim admin ekrani (12 fajlova), pa web `index.html` i splash
3. Testovi u istom prolazu kao ekran koji mijenjaju, ne na kraju

## Zamke
- **Obrisati indikator bez zamjene znači prazan bijeli ekran** — tačno stanje koje
  [FE-501](FE-501-stanja-i-skeletoni.md) zabranjuje. Zato ova dva taska idu zajedno; ovaj sklanja,
  onaj postavlja skeleton.
- **`NoSplash.splashFactory` ukida i vizuelnu potvrdu dodira.** Bez zamjene (promjena pozadine ili
  opacity) aplikacija djeluje kao da ne reaguje — gore nego ripple.
- Web loader u `index.html` nije Dart kod i ne vidi ga nijedan Flutter test; provjerava se otvaranjem.
- `flutter_native_splash` regeneriše platformske fajlove — to je generisani izlaz i vrijedi mu
  pravilo iz `CLAUDE.md`: mijenja se konfiguracija, pa se pokrene generator.

## Status

Nije počet.
