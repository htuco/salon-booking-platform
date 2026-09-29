# Task 53 — Vertikala `health` — masaža i fizioterapija, sa vlastitim izgledom

| | |
|---|---|
| **Procjena** | 4–5 dana |
| **Zavisi od** | [49](49-slike-usluga-i-radnika.md), [50](50-galerija-logo-cover.md) |
| **Blokira** | — |
| **Reference** | **`prototype/masaza/`** (handoff za masažu i `fizio/`, kandidat, 2026-09-29) · `docs/05` §3–5 · ADR-0018 · ADR-0019 · `/new-tenant` skill · `.claude/docs/tenant-factory.md` |

## Cilj
Salon za masažu i fizioterapeutska ordinacija dobijaju svoje brandirane aplikacije kao barber i
beauty: **isti shell** (rute, navigacija, zakazivanje, ekrani), a vlastita tipografija i boje.

## Definicija gotovog

**Odluka prije koda**
- [x] ADR koji dopunjuje ADR-0019: par pisama se veže za **temu**, ne za salon. `modern_barber` i
      `elegant_beauty` zadržavaju DM Serif Display + Archivo; `health` teme dobijaju svoj par.
      ADR kaže i da li masaža i fizio dijele jednu temu ili dobijaju dvije (npr. topla „wellness"
      za masažu i hladna `clinical_calm` za fizio)

**Platforma (`core_ui`)**
- [x] `AppTheme` nosi par pisama (naslov + tijelo) uz svjetlinu i neutralnu paletu; `kSerifFamily`
      i `kBodyFamily` prestaju biti jedine konstante
- [x] Nova pisma su zapakovana uz aplikaciju sa OFL licencom, ne sa mreže (`prototype/ui/SPEC.md`)
- [x] Skala veličina i razmaci ostaju isti za sve teme — mijenja se pismo, ne oblik
- [ ] Barber i beauty izgledaju **isto kao prije** — snimci prije i poslije

**Vertikala i tenanti**
- [x] `vertical_packs` seed za `health`: terminologija, pravila i flagovi po `docs/05` (danas u seedu: barber, beauty, generic)
- [x] Pravila po tabeli §4: korak 30 min, buffer 10, `requireStaffChoice: true` (booking flow ga već poštuje)
- [ ] Dva demo tenanta kroz `/new-tenant` — salon za masažu i fizioterapeutska ordinacija: `tenant.yaml`
      sa vlastitim bojama, seed red sa uslugama i terapeutima, sve tri CI matrice
- [x] Nijedan `if (vertical == 'health')` ni `if (flavor == …)` u ekranu — razlika je tema, `vertical.terms` i flagovi
- [ ] CI zelen za oba nova flavora; snimci početne i zakazivanja za sva četiri tenanta jedan do drugog

## Zamke
- **Drugo pismo mijenja visinu svakog reda** (ADR-0019). Ekrani koji su „taman stali" počinju
  prelijevati — QA prolaz kroz klijentske ekrane na obje nove teme, na 402, nije opcija.
- **Hex ne ide u ekran.** Boja salona ide kroz `tenant.yaml` i `buildAppTheme()`; tema nosi samo
  neutralnu paletu i pismo.
- `clinical_calm` je i dentalna tema. Veći body font (`TODO(dental-tipografija)`) je dentalni
  zahtjev i ovdje se **ne** uvodi — zubari su van sprinta.
- „Bilo koji dostupan" mora nestati iz koraka 2 kad je `requireStaffChoice: true`; provjeri na
  ekranu, ne samo u testu.
- Pravi `google-services.json` ne ide u repo — novi flavori dobijaju placeholder kao i ostali.
- Task je velik. Ako ADR i `core_ui` promjena prerastu jedan PR, ADR + pisma po temi se odvajaju u
  zaseban task, a tenanti idu poslije.

## Status (2026-09-30)

U toku, grana `feat/vertikala-health`, [PR #121](https://github.com/htuco/salon-booking-platform/pull/121).

**Dokazano:**
- ADR-0026 (dopunjuje ADR-0025): `warm_wellness` za masažu, `clinical_calm` prepisan za fizio,
  Newsreader + Public Sans, izbor brandom; bez darka, bez galerije, shell ostaje bazni.
- `core_ui`: nove neutrale i pisma, skala ista u svim temama — `core_ui` testovi zeleni na CI-ju
  (kontrast, a11y, pismo po temi, pragovi brand uloga za 7 brandova × 3 svijetle teme).
- Seed: pack `health` i dva salona. `tool/test_supabase.sh` od nule lokalno: pgTAP 716 PASS, svi
  REST i Deno testovi; CI `Supabase tests` zelen. Anon: masaža 60 min → slotovi 09:00–16:00 / 30 min.
- `serviceAccusative` u rječniku; `core_domain` 88 PASS lokalno.
- Tenanti `masazamostar` i `fiziozenica` u sve tri CI matrice; `gen_flavors --check` ažuran.
- Grep: nema grananja po vertikali ni flavoru u ekranu.
- CI na PR #121 (`5ad6895`): `Analiza, format i testovi` (analyze, format, svi testovi, `gen_flavors --check`) i `Supabase tests` zeleni.

**Ostalo za sljedećeg** (traži Flutter mašinu):
- „Bilo ko od nas" nestaje u koraku 2, viđeno na ekranu: `tool/run_tenant.sh mostar demo -d chrome`.
- Snimci početne i zakazivanja, sva četiri tenanta na 402; barber i beauty isti kao prije
  (`git worktree` sa `main`-a prije #120 za „prije").
- APK i iOS build novih flavora idu na push u `main`.
