# Task 50 — Galerija salona, logo i cover

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [48](48-storage-bucket-po-salonu.md) |
| **Blokira** | 52, 53 |
| **Reference** | ADR-0008 · ADR-0015 · `docs/01` §6.1 (logo, cover) |

## Cilj
Salon sam uređuje galeriju radova, logo i naslovnu sliku; „Promjena fotografije" u postavkama
prestaje biti „uskoro".

## Definicija gotovog
- [x] Galerija: dodaj, obriši i promijeni redoslijed; vrijednost ostaje u `salons.gallery_urls` (ADR-0008)
- [x] Logo i cover iz postavki salona
- [x] Klijent vidi novu galeriju i cover na početnoj i u lightboxu
- [x] Prazna galerija u klijentu ostaje prazno stanje, ne tri sive kutije
- [x] Widget testovi za editor galerije; uživo na oba tenanta, 1440 i 402

## Zamke
- App ikona i splash su **build** artefakti iz `tenant.yaml`, ne runtime slika — logo iz admina ih ne
  mijenja i to ekran mora reći.
- Redoslijed galerije je redoslijed niza; dva taba koja istovremeno mijenjaju niz ne smiju tiho
  pregaziti jedan drugog.

## Status (2026-09-26) — ✅ zatvoren

Spojen kao #114. CI na PR-u zelen (`Schema, RLS and tenant isolation`, `Analiza, format i testovi`),
`supabase migration list` pokazuje `20260926120000` i lokalno i remote.

### Dokaz prije merge-a

Grana `feat/galerija-logo-cover`, PR #114.

- **Baza** (`20260926120000_galerija_logo_cover.sql`): `set_salon_image(salon, logo|cover, url)` i
  `set_salon_gallery(salon, expected, urls)`, obje `security definer` iza `private.is_admin`.
  Nova slika mora biti `salon-media/<svoj salon>/<vrsta>/…`; zatečeni (seed) URL smije ostati u
  galeriji. Zastarjeli `expected` → `PT409`, ništa se ne upisuje. Grant nad `salons` ostaje SELECT.
- `supabase test db`: `Files=23, Tests=671 … Result: PASS`. `023` ima 47 asercija; sabotaža
  helpera obara 15, provjere `p_expected` 4, guarda 7. `rest_galerija.ts`: 26 provjera, dvaput
  zaredom sa vraćenim stanjem; `rest_storage` 19.
- Usput: `022` je padao (4/27) na svakoj mašini koja je uživo probala upload, jer je brojao sve
  objekte u bucketu. Sada sam isprazni bucket u transakciji.
- **Admin**: naslovna i logo preko `SlikaPolje` na jedno „Sačuvaj" (samo promijenjena slika ide u
  bazu); uz logo piše da ikonu i splash ne mijenja. Galerija je svoja kartica, svaka radnja je
  odmah jedan upis sa prikazanim nizom kao `expected`; redoslijed su strelice.
- `melos run analyze` čist; `melos run test`: admin 470, client 393, core_api 140, core_ui 104,
  core_domain 87 — sve PASS. `galerija_editor_test` 8 testova (prazno, dodaj, neuspio upload,
  strelice, brisanje sa potvrdom, konflikt, puna galerija, 402 uz font 160 %); sabotaža koja šalje
  novi niz kao `expected` obara 3. `settings_screen_test` +3 (cover/logo na „Sačuvaj", tekst uz logo).
- **Uživo, lokalni stack, web buildovi** (admin 4320, klijent Vitez 4321, beauty 4322):
  - Vitez admin 1440: zamjena naslovne + novi logo → „Sačuvaj"; `logo_url`/`cover_image_url` =
    `…/salon-media/550e8400…0000/{logo,cover}/…jpg`; sidebar odmah pokazuje novi logo.
  - Vitez galerija: pomjeranje prve slike (seed URL-ovi) upisano; konflikt izazvan direktnim upisom
    u bazu → HTTP 409, baza netaknuta, ekran učitao 11/30 i kaže „promijenjena na drugom mjestu";
    „Dodaj" → nova slika prva; brisanje traži potvrdu i upisuje 11.
  - Admin 402 (Vitez): kartice bez prelivanja, dvije sličice u redu.
  - Klijent Vitez 402: novi cover na Početnoj, galerija u novom redoslijedu, lightbox 1/11 počinje
    novom slikom.
  - Beauty **prije**: Početna bez sekcije galerije, hero gradijent brenda, `/gallery` „Salon još
    nije dodao fotografije." Admin 1440: prazno stanje „Galerija je prazna…", 0/30.
  - Beauty **poslije**: cover + dvije slike; klijent 1440 cover i galerija na Početnoj, 402 lightbox 1/2.
  - Konzola: samo namjerni 409 i poznati `images.demo.invalid` iz beauty seeda.

**Ostalo za sljedećeg (nije dio DoD-a):**
- ~~CI na PR-u i `supabase db push`~~ — zatvoreno, v. gore.
- Admin 402 na beautyju nije posebno otvaran (isti kod kao Vitez 402).
- Klijent nema osvježavanje dok je otvoren: nova galerija i cover stižu pri sljedećem pokretanju
  aplikacije. DoD to ne traži; kandidat za 52 ili 60.
- Logo se u klijentu nigdje ne prikazuje — samo u adminu (sidebar, „Još"). Tekst uz polje to kaže.
- Zamijenjene i obrisane slike ostaju u bucketu kao siročad — čisti ih task 51.
