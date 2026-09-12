# Task 22 — Šema: fotografije usluga i staž radnika

| | |
|---|---|
| **Procjena** | 0.5 dana |
| **Zavisi od** | — |
| **Blokira** | [18](18-pocetna-i-tab-bar.md), [20](20-galerija-recenzije.md), i 1:1 na koraku 1 |
| **Reference** | `prototype/ui/README.md` §Fotografije · [`.claude/docs/security.md`](../../.claude/docs/security.md) |

## Cilj
Dvije kolone koje handoff traži, a šema nema. Bez njih red usluge ima prazan okvir i nikad neće
biti 1:1 sa mockupom.

## Definicija gotovog
- [x] `services.image_url` (nullable) — thumb 1:1, 76 px u redu usluge
- [x] `employees.experience_years` (nullable int) — handoff piše „Barber · 9 godina"
- [x] Modeli u `core_domain` prošireni, `fromJson` testovi dopunjeni
- [x] `seed.sql` puni obje kolone za oba demo salona — **i namjerno ostavlja po jedan red bez**
- [x] `anon` politika propušta nove kolone (javni katalog) — provjereno REST testom
- [x] Ekran koraka 1 i 2 prikazuju thumb i staž kad postoje, prazan okvir kad ne

## Koraci
1. Migracija, seed, pa model, pa ekran
2. `./tool/test_supabase.sh`
3. Commit: `feat(supabase): slike usluga i staz radnika`

## Zamke
- **Nullable namjerno.** Salon koji nema fotografije mora raditi; prazan okvir je predviđeno
  stanje, ne greška.
- Ne dodavati `image_url` kao obavezan u modelu — app iz storea je starija od baze i mora
  podnijeti red bez kolone.

---

## Status (2026-09-12) — ✅ zatvoren

Dvije kolone koje handoff traži, a šema ih nije imala. Red usluge konačno ima okvir za
fotografiju, a red radnika piše „Barber · 9 godina".

### Šta je isporučeno

| Sloj | Šta |
|---|---|
| `supabase` | `20260912160000_service_images_and_tenure.sql` — `services.image_url`, `employees.experience_years` sa `check (0..70)`. |
| `supabase` | `seed.sql` puni obje kolone; **po jedan red namjerno ostaje prazan** (Brada bez slike, Lejla bez staža). |
| `core_domain` | `Service.imageUrl`, `Employee.experienceYears` + `hasExperience`. |
| `core_api` | Obje kolone u `_columns` listama repozitorija. |
| `apps/client` | Korak 1 prosljeđuje `imageUrl`, korak 2 spaja titulu i staž; `experienceYears` u `.arb` sa ICU pluralom. |

### Dokazano

```
$ ./tool/test_supabase.sh
==> pgTAP                    Files=2, Tests=66,  Result: PASS
==> REST izolacija           24 assertions, two real JWTs.
==> Javni katalog            29 assertions passed.   (bilo 26)

$ melos run format && melos run analyze && melos run test
  SUCCESS; 242 testa PASS
```

**`anon` vidi obje nove kolone** — tri nove asercije u `rest_public_catalog.ts`. To nije
formalnost: grantovi iz init migracije su **tabelarni**, pa nova kolona ulazi u postojeći grant
sama; da su bili kolonski, javni katalog bi tiho izgubio fotografije. Razlika se ne vidi iz
migracije nego iz poziva bez tokena.

**Na ekranu, protiv živog stacka:**

```
korak 2 →  "E Emir  Barber · 9 godina"
           "A Amar  Barber · 4 godine"
```

Oba plural oblika tačna, iz prave baze. Bosanski ima tri (`1 godina`, `2–4 godine`, `5+ godina`);
ICU `few` ih pokriva po CLDR pravilima za `bs`, i to je pokriveno testom
(`catalog_media_test.dart`), jer bi ključ bez plural oblika svuda ispisao „godina" i to bi se
vidjelo tek u prodavnici.

Korak 1: [`task-22-korak1-thumb.png`](../../docs/screenshots/task-22-korak1-thumb.png) —
fotografija u 76×76 okviru na jednom redu, prazan okvir na ostalima.

### Zamka koju je našao prvi prolaz kroz browser

**Seed URL-ovi se ne razrješavaju** (`images.demo.invalid`), pa je prvi snimak pokazao **četiri
prazna okvira** — red sa URL-om izgleda identično redu bez njega. Taj snimak ne dokazuje ništa:
ne razlikuje „fotografija radi" od „fotografija tiho pada".

Dokaz je zato napravljen tako što je **jedan red privremeno usmjeren na sliku koja stvarno
postoji** (lokalni HTTP server), snimljen, pa vraćen na seed vrijednost. Baza je provjerena nakon
vraćanja. `seed.sql` nije mijenjan — lokalni URL u commitovanom seedu bi radio samo na mašini na
kojoj je napisan.

### Šta **nije** provjereno

- **Prave fotografije salona ne postoje** i neće do onboardinga. `seed.sql` nosi
  `images.demo.invalid` URL-ove namjerno: oni **ne smiju** raditi, da demo ne bi izgledao gotovije
  nego što jeste. Stvarne slike dolaze sa [taskom 18](18-pocetna-i-tab-bar.md) i
  [20](20-galerija-recenzije.md).
- **Početna (`ServiceCard`) ne prikazuje thumb** — ta komponenta ga ne prima, a Početna se ionako
  prepisuje po handoffu u tasku 18. Ovdje su korak 1 i 2, kako DoD i traži.
- **Ništa na uređaju ni u emulatoru.**
- **CI nije ništa potvrdio** — naplata blokira workflowove do 29.09.2026.
