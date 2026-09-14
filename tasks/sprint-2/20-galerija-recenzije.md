# Task 20 — Client: Galerija, lightbox i Recenzije

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [18](18-pocetna-i-tab-bar.md), [22](22-sema-slike-i-staz.md) |
| **Blokira** | — |
| **Reference** | `prototype/ui/screenshots/12-galerija.png`, `17-lightbox-galerije.png`, `13-recenzije.png` |

## Cilj
Salon pokazuje rad i ocjene. Ovo je jedini dio app-e koji prodaje prije nego što korisnik zakaže.

## Definicija gotovog
- [x] `/gallery` — mreža 3 kolone, kvadrat, `gap 8`, bez naslova i opisa na slikama
- [x] Lightbox 5q: preko cijelog ekrana, brojač "4 / 18", zatvaranje, traka sličica
- [x] `/reviews` — prosjek u serifu, histogram 5→1, lista recenzija
- [x] Tabela `reviews` (migracija + seed + RLS `anon` za čitanje). **`gallery_photos` ne nastaje** —
      galerija ostaje na postojećoj `salons.gallery_urls`, v.
      [ADR-0008](../../docs/adr/0008-galerija-ostaje-u-salons-gallery-urls.md)
- [x] Oba ekrana su **pod-ekrani**: back header, **bez tab bara**
- [x] Prazno stanje: salon bez galerije ne pokazuje praznu mrežu nego sakrije sekciju na Početnoj

## Koraci
1. Migracija + seed za obje tabele, pa repozitoriji, pa ekrani
2. Lightbox prije galerije — on diktira kako se slike učitavaju
3. Commit: `feat(client): galerija, lightbox i recenzije`

## Zamke
- **Recenzije se ne pišu u app-i** u ovom obimu; dolaze iz admina ili importa. Ekran je read-only.
- Slike su velike: bez `cached_network_image` i `maxWidth` galerija pojede podatke na mobilnoj.

## Status (2026-09-14) — ✅ zatvoren

`/gallery`, lightbox 5q i `/reviews` rade iz prave baze, na oba tenanta. Grana
`feat/galerija-i-recenzije`, [PR #37](https://github.com/htuco/salon-booking-platform/pull/37).

### Odluka koja je promijenila obim

**`gallery_photos` ne postoji** — [ADR-0008](../../docs/adr/0008-galerija-ostaje-u-salons-gallery-urls.md).
`salons.gallery_urls` stoji u init migraciji od prvog dana i već je bila spojena do Početne i
`/about` kroz `SalonRepository.galleryUrls`; nova tabela bi bila drugi izvor istine za istu listu.
Migracija ovog taska zato dira **samo `reviews`**. Red 17 DoD-a je ispravljen da ne upućuje na
tabelu koje neće biti.

### Šta nosi `reviews`, i zašto tako

- **`comment` je nullable, i to nosi histogram.** Handoff pokazuje „142 ocjene" iznad tri napisane
  recenzije — većina ljudi da zvjezdice bez teksta. Da je obavezan, prosjek bi se računao nad
  drugim skupom nego što salon vidi na Googleu. Lista prikazuje samo redove sa tekstom, prosjek
  računa sve: zato 25 ocjena i četiri kartice, što **nije** nesklad.
- **`author_name` je tekst, ne FK na `customers`** — uvezena recenzija sa Googlea nema red u ovoj
  bazi, a FK bi značio da se ne može upisati bez izmišljanja klijenta.
- **Prosjek i histogram računa baza**, pogled `salon_rating_summary`. PostgREST ima
  `max_rows = 1000`; salon sa 1200 ocjena bi klijentu vratio 1000 redova i prosjek bi bio **tih i
  pogrešan**. Isti razlog zbog kojeg je availability u bazi (`docs/01 §8.1`).
- **`security_invoker = true` na pogledu nije kozmetika.** Bez njega pogled radi sa pravima
  vlasnika i zaobilazi RLS tabele ispod — `anon` dobije prosjek koji uključuje sakrivene recenzije
  i neaktivne salone. Ništa ne pukne, samo je broj drugi.

### Kako je curenje napravljeno vidljivim

Seed drži **jednu sakrivenu jedinicu**, pa je tačan prosjek `4.8`, a procurio `4.7`. Test koji broji
redove to ne bi uhvatio; test koji mjeri prosjek hvata. Asercije su u `006_reviews.test.sql` i
`rest_public_catalog.ts`.

### Dokazano pokretanjem

| Šta | Prije | Sad |
|---|---|---|
| pgTAP | 124 | **147** (23 nova u `006_reviews`) |
| `rest_public_catalog.ts` (bez tokena) | 33 | **43** |
| Dart | 372 | **419** |

Uz to: `rest_isolation` 24, `rest_cross_salon_isolation` 22, `rest_customer_upsert` 20 asercija —
sve prolazi. Čista analiza, `dart format` bez izmjena.

**Sve provjereno da može pasti**, pa vraćeno: politika bez `is_published` obara 8 pgTAP asercija;
pogled bez `security_invoker` obara 6 i REST test uz poruku „got 4.7 … check security_invoker";
histogram normalizovan na maksimum, mreža na dvije kolone i prazan agregat koji crta „0,0" obaraju
svoj Dart test.

**Uživo**: Chromium 402×874 i **iOS simulator** (iPhone 17 Pro, flavor `barberstudiovitez`) protiv
lokalnog stacka, oba tenanta. Snimci: `docs/screenshots/task-20-*`.

**CI je zelen** — `Analiza, format i testovi` 2m53s, `Schema, RLS and tenant isolation` 2m08s.
Ovo je **prvi zeleni CI od 11.09.**, kad su potrošene besplatne minute; blokada je prošla ranije
nego što je najavljeni reset 29.09. sugerisao. Build jobovi (APK / iOS / AAB) stoje na `skipping`
po konfiguraciji — idu na push u `main` i na ručni trigger, ne na PR.

### Dvije greške koje je našao ekran, a testovi nisu mogli

1. **Zvjezdica se razlikovala samo bojom.** Lucide set nema popunjenu zvjezdicu — sve su linijske —
   pa su kartica sa peticom i kartica sa četvorkom izgledale isto. Izmjereno: **2,4%** razlike u
   svjetlini po zvjezdici, a **3,5 se crtalo identično kao 4,0**. Sada je `CustomPainter`: puna je
   ispunjena površina, prazna obris, razlika ~11%. Razlika nošena samo bojom je i WCAG 1.4.1 problem.
   **Prvi test za to je bio bezvrijedan** i ostavljen je zapisan u `star_rating_test.dart`: poredio
   je piksele i tvrdio „4 i 5 nisu identični", pa je prolazio i nad pokvarenom verzijom. Sada mjeri
   *koliko* — prag 5% po zvjezdici.
2. **Naslov je bio u `AppBar`-u.** Handoff (`12-galerija.png`, `13-recenzije.png`) crta
   „← Početna" pa naslov u tijelu kao veliki serif; `AppBar` je davao upola manji sans naslov i
   platformski chevron. Zaglavlje je izvučeno u `core_ui` kao `BackHeader`. **`/account` iz taska
   17 je popravljen istim potezom** — bio je jedini preostali ekran sa `AppBar`-om.

### Ostalo za sljedećeg

- 🟡 **Share ⤴ u lightboxu.** `SPEC.md` §Interactions ga navodi uz ✕ i traku sličica; DoD ga nije
  nabrajao. Traži `share_plus` i konfiguraciju po platformi — paket se ne dodaje usput.
- **Brojač nikad nije vidio „4 / 18"** iz handoffa: demo salon ima dvanaest fotografija.
- **Dugme „Ostavi recenziju"** sa dna 5m namjerno ne postoji — klijent nad `reviews` nema write
  grant. Kad pisanje dobije svoj task, dugme se vraća **zajedno sa RPC-om** koji ga podupire.
- **Lightbox i „Sve ›" ulazi nisu tapnuti na simulatoru** — nema accessibility dozvole za
  automatizaciju tapova, a lightbox je overlay pa nema rutu. Oboje je odigrano u Chromiumu
  („1 / 12" → „2 / 12"). Nastavak: otvori app na simulatoru i tapni ćeliju galerije.
- **Zatečeno, nije popravljeno:** web build loguje `Failed to load font Archivo` (dvostruko
  enkodovano `%255B` u imenu variable fonta sa zagradama). Pogađa svaki ekran, nije uvedeno ovdje.

Nastavak suite:

```bash
supabase start && supabase test db
eval "$(supabase status -o env)" && deno run --allow-env --allow-net supabase/tests/rest_public_catalog.ts
dart run melos run test
```
