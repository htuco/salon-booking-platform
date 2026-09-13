# Task 18 — Client: Početna po handoffu + bottom tab bar

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [11](../sprint-1/11-booking-flow.md), [22](22-sema-slike-i-staz.md) |
| **Blokira** | 19, 20, 21 (svi tab-level ekrani) |
| **Reference** | `prototype/ui/screenshots/01-pocetna.png` · `SPEC.md` §Bottom tab bar |

## Cilj
Početna izgleda kao `5a`, i aplikacija dobija navigaciju kakvu handoff pretpostavlja. Danas je
Početna iz taska 10 — naslijedila je nove tokene, ali joj je raspored stariji od dizajna.

## Definicija gotovog
- [x] **Bottom tab bar** u `core_ui`: pet ćelija, redoslijed **Usluge · Termini · Početna ·
      Obavijesti · Postavke**, Početna namjerno u sredini
- [x] Aktivna ćelija: bijela, `weight 600`, traka 3 px na vrhu, inset 16% lijevo/desno
- [x] Pod-ekrani (Galerija, Recenzije, O aplikaciji, Pravila, Lightbox) **nemaju** tab bar
- [x] Početna po `01-pocetna.png`: hero foto + serif naslov, živi status, CTA, **Cjenovnik** sa tri
      usluge + "Prikaži svih N", Majstori (2 kolone), Galerija (3 kolone), Recenzije sa ocjenom
- [x] Tab se vraća na svoj korijen pri ponovnom tapu; prelaz je instant, bez cross-fade
- [x] Screenshot uz `01-pocetna.png`

## Koraci
1. Tab bar kao `core_ui` komponenta + `StatefulShellRoute` u `go_router`-u
2. Početna sekciju po sekciju, odozgo
3. Commit: `feat(client): pocetna po handoffu i tab bar`

## Zamke
- **`StatefulShellRoute` mijenja oblik rutiranja** — deep linkovi iz taska 07 moraju i dalje raditi.
  Test iz `router_test.dart` je tu da to uhvati.
- Tab bar je **jedina zajednička komponenta koja se gradi prva** (`SPEC.md` to kaže doslovno);
  ekrani ispod nje su lakši kad ona postoji.

## Status (2026-09-13) — ✅ mergeovan

Grana `feat/pocetna-i-tab-bar`, [PR #29](https://github.com/htuco/salon-booking-platform/pull/29),
mergeovan u `main` 2026-09-13.

## Napomene

### Dokaz (2026-09-13)

**325 Dart testova PASS** — `admin` 4, `core_domain` 58, `core_api` 67, `core_ui` 55, `client` 141.
Novo: 14 za traku (`core_ui`), 15 za shell (`client`), 4 za mapiranje galerije (`core_api`); testovi
Početne prepisani po novom rasporedu. Čista `melos run analyze` i `dart format`.

**Odigrano u Chromiumu na 402 px protiv živog Supabase stacka**, oba tenanta, kroz `lib/main.dart`
(ne `demo_main.dart`): Početna, `/services`, `/appointments`, `/book/service`. Snimci su u
`docs/screenshots/task-18-*.png`.

**Pokrenuto na iOS simulatoru** (iPhone 17, iOS 26.3), barber flavor protiv istog živog stacka:
`docs/screenshots/task-18-home-barber-simulator.png`. Prazni okviri u Cjenovniku su seed stanje
(`images.demo.invalid` iz taska 22), hero je brand gradijent jer `cover_image_url` nije popunjen.

### Greška koju je našao **samo** simulator

**Sadržaj svake ćelije trake bio je poravnat ulijevo, ne centriran.** `Stack` u `_Celija` je bio na
podrazumijevanom `topStart`, a `Column` je `MainAxisSize.min` — pa je uzak koliko i najširi
potomak i lijepio se uz lijevu ivicu. Mjereno: ikone na 21/101/185/270/348 px umjesto
40/121/201/281/362.

**Nijedan od 14 testova trake to nije vidio, i nije mogao.** Testni font crta svaki znak kao
kvadrat veličine fonta, pa su labele u testu šire nego u stvarnosti, popune ćeliju i ispadnu
„centrirane" slučajno. Novi test zato mjeri **ikonu** (fiksnih 23 px, ne zavisi od fonta) i pada
bez `alignment: Alignment.topCenter` — provjereno vraćanjem greške.

Prije i poslije: `task-18-traka-pomjerena-ulijevo.png` naspram `task-18-home-barber-simulator.png`.

Tri stvari koje su testovi propustili a našle su se pri pisanju i u browseru:

1. **`freezed` 3.2.5 ne može `List` polje.** Generiše `final` na imenovanom parametru, što Dart
   odbija. Prvi `List` u ijednom modelu ovog repoa, pa se to do sada nije vidjelo. Galerija zato
   ide kroz `SalonRepository.galleryUrls`, ne kroz polje na `Salon`-u. Zapisano u `architecture.md`.
2. **`scrollUntilVisible` staje čim finder *nađe* widget**, a `CustomScrollView` gradi i komad
   izvan viewporta. Dugme „Prikaži svih" je tako postojalo na y≈853 u viewportu visine 600, tap
   nije pogodio ništa, i test je tvrdio da ruta ne radi. Ide `ensureVisible`.
3. **Test kontrasta na dvije palete u jednoj petlji mjeri pola prelaza.** `MaterialApp`
   interpolira `ThemeData`, pa je drugi `pumpWidget` dao 1.50:1 — barberov svijetli tekst na
   beauty pozadini. Svaka paleta sada ima svoj test.

Snimak je napravljen **privremenim** usmjeravanjem `cover_image_url`, `gallery_urls` i slika
radnika na lokalno poslužene ploče iz `prototype/ui/assets/`, pa vraćanjem baze u seed stanje —
isti postupak kao u tasku 22. `seed.sql` nije mijenjan i baza je vraćena (provjereno `select`-om).

### Ostalo za sljedećeg

- **Recenzije ne izlaze nigdje.** Sekcija i `RatingSummary` su napisani i pokriveni testom, ali
  `salonRatingProvider` vraća `null` jer šema nema tabelu `reviews`. [Task 20](20-galerija-recenzije.md)
  mijenja **provider**, ne ekran — test „recenzije izađu čim ocjena postoji" to čuva.
- **Galerija u demou ne izlazi**, jer je `gallery_urls` prazan u oba seed salona. Kod je pravi i
  čita iz baze; sekcija se sakriva, kako DoD taska 20 (red 19) i traži.
- **Radno vrijeme i kontakt više nisu na Početnoj** — po `SPEC.md` 5b idu na „O nama"
  ([task 19](19-o-nama-i-usluge.md)). `working_hours_card.dart` i `contact_card.dart` su ostavljeni
  netaknuti, ali su **trenutno bez ijednog korisnika**; sama logika sekcija (koji kontakt red,
  `socialLinks` gating, imena dana) je obrisana iz `home_screen.dart` i task 19 je piše ponovo.
  Do tada su radno vrijeme i kontakt **nedostupni u aplikaciji**.
- **`terms` nema plural termina.** Labela ćelije „Termini" ide iz `.arb`-a, jer je
  `appointmentSingular` pogrešan oblik za listu a `myAppointments` predugačak za petinu ekrana.
  Dentalna vertikala traži „Pregledi" i time ovo postaje `appointmentPlural` u `VerticalTerms`.
- **Ikone u traci su barberske** (makaze za Usluge) — odluka iz taska 11, ali će je druga
  vertikala otvoriti.
- **`home_hero.dart` čita i `assets/…`** — dopunjeno mimo ovog PR-a dok se pravio tenant Studio
  Maestro, i **nije stiglo u #29**. Stoji u stashu uz ostatak tog tenanta i ulazi sa njegovim PR-om.
- **Katalog je stizao naopako sortiran, i taj PR to nije primijetio.** `order` u `postgrest`-u
  podrazumijeva **silazno**, pa su usluge, radnici i radno vrijeme svih ovih mjeseci dolazili
  obrnuto. Na Početnoj se vidjelo tek na salonu sa osam usluga. Popravljeno zasebno, v.
  `fix/sortiranje-kataloga`.
