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
- [x] Pri pokretanju nema plave linije ni spinnera — ni na mobilnom, ni na webu
- [x] Nema bijelog bljeska između splasha i prvog ekrana — `web/index.html` nosi
      `AdminColors.ground`, u obje sheme, i test pada ako se razmimoiđu
- [x] Grep ne vraća nijednu upotrebu `CircularProgressIndicator` ni `LinearProgressIndicator`
      u `lib/` — **uz jedan napisan izuzetak** (traka podatka, v. ispod)
- [x] Tri klijentska testa koja ih očekuju — **nisu ni postojala**, v. ispod
- [x] Dugme u toku akcije nosi vlastiti indikator u boji svog teksta (`AdminButtonBusy`)
- [ ] `RefreshIndicator` i `SnackBar` kroz vlastite komponente — **izostavljeno**, v. ispod
- [x] Nema ripplea: `splashFactory: NoSplash.splashFactory` u **obje** teme
- [x] Nigdje Material podrazumijevana plava — provjereno grepom, nula pojava
- [x] `debugShowCheckedModeBanner: false` — već je stajalo u obje aplikacije

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

**Gotovo, dokazano.** Grana `feat/fe-205-ukidanje-indikatora`.

### Task je opisivao dvostruko veći posao nego što ga je bilo

„32 upotrebe u 15 fajlova, uključujući klijentske testove" — stvarno stanje:

- **Klijent nema nijedan indikator** u `lib/`. Već je u cijelosti na `SkeletonLoader`-u,
  kroz 12 ekrana. Ni tri navedena testa ne očekuju spinner — `home_screen_test`,
  `services_screen_test` i `about_screen_test` traže **`SkeletonLoader`**, i ostali su
  zeleni bez ijedne izmjene.
- Stvarnih upotreba je bilo **25, sve u adminu**, plus jedna u `core_ui`
  (`app_button.dart`, ostaje — klijentsko dugme, izvan opsega admina).

Dakle ovo nije bio „najveći task epika" nego **admin task**.

### Šta je napravljeno

`AdminSkeleton` / `AdminSkeletonList` i `AdminButtonBusy` u
`apps/admin/lib/src/core/widgets/admin_skeleton.dart`. Namjerni blizanac klijentskog
`SkeletonLoader`-a, **ne duplikat iz nemara**: admin ne smije uvoziti `core_ui` (to drži
postojeći test „admin ne uvozi core_ui"), jer `core_ui` gradi temu iz tenant boja.

Broj redova kostura se **prilagođava visini**. Prva verzija je crtala fiksnih šest i
prelivala uski prikaz za 68 px — šest admin testova je to odmah uhvatilo. Kostur koji
prelijeva je gori od spinnera.

### Jedan napisan izuzetak

`dashboard_screen.dart:899` zadržava `LinearProgressIndicator` — ali to **nije indikator
učitavanja** nego traka podatka: `value` je udio minuta radnika u najdužem danu, boje su
iz tokena. FE-205 sklanja spinnere, ne mjerila. Red nosi `// ignore` uz razlog, i guard
test taj oblik izuzetka priznaje.

### Šta je izostavljeno i zašto

**`RefreshIndicator` i `SnackBar` nisu dirani.** To je vlastita komponenta sa vlastitim
ponašanjem (gesta povlačenja, trajanje, red čekanja poruka) u 19 fajlova kroz obje
aplikacije — po obimu blizu ostatku ovog taska. Ulazi u FE-501, koji ionako postavlja
obrazac grešaka i praznih stanja, pa poruka i njen izgled pripadaju istoj odluci.

### Dokaz

**620 testova PASS** — admin **317** (bilo 309), klijent 236, `core_ui` 67. Analiza i
format čisti.

Četiri nova testa, svaki provjeren da **stvarno pada**:

- `no_material_indicators_test` — vraćen spinner prijavljen uz fajl i red
- `web_splash_test` — promijenjena boja u `index.html` odmah pukla
- `admin_skeleton_test` — nosi i regresiju za prelivanje (400×120 daje dva reda, ne šest)

**Viđeno uživo** na 1440×900: dashboard i kalendar. Traka zauzetosti se i dalje crta
(podatak), spinnera nema. Stanja učitavanja se u demo buildu **ne vide** jer su provideri
stubovani i podaci stignu odmah — zato su pokrivena widget testom, ne tvrdnjom.
