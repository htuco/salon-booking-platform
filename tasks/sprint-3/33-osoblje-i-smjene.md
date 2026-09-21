# Task 33 — Osoblje i smjene (CRUD)

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [29](29-responsive-shell.md) |
| **Blokira** | [34](34-radno-vrijeme-i-blokade.md) |
| **Reference** | `SPEC.md` prikazi `3g` `3r` · [22](../sprint-2/22-sema-slike-i-staz.md) |

## Cilj
Salon dodaje i uklanja radnike i određuje ko radi kada.

## Definicija gotovog
- [x] `/employees` po `3g`, mobilno `3r`
- [x] Dodavanje, izmjena i deaktivacija radnika kroz RPC; `experience_years` ostaje nullable
- [x] Koje usluge radnik radi — veza prema uslugama iz [32](32-usluge-i-cjenovnik.md)
- [x] Radnik se **ne briše** dok ima buduće termine
- [x] pgTAP: izolacija po salonu na svakoj putanji pisanja
- [x] Deaktiviran radnik nestaje iz klijentskog izbora, a **ostaje** na svojim prošlim terminima

## Koraci
1. Migracija + pgTAP, pa ugovor, pa ekran
2. Commit: `feat(admin): crud nad osobljem i smjenama`

## Zamke
- **Radnik nije nalog.** `employees` je osoblje salona; `public.users` + `auth_identities` su
  prijava. Spajanje to dvoje daje radniku pravo prijave koje mu niko nije dao.
- Deaktivacija koja sakrije i prošle termine briše istoriju salona — filtriraj budućnost, ne sve.
- Staž je nullable jer red bez staža **nije** greška, nego predviđeno stanje (task 22).

## Status (2026-09-21) — ✅ zatvoren

[PR #55](https://github.com/htuco/salon-booking-platform/pull/55) spojen u `main` (`d4c54c3`).

Isporučeno: atomski RPC profil/usluge, kreiranje/izmjena/deaktivacija/reaktivacija,
nullable staž, oduzeti direktni write grantovi, snapshot imena na terminu, responsive
`/employees` sa editorom i prikazom ponavljajućeg rasporeda. Uređivanje radnog vremena,
pauza i blokada ostaje tasku 34; nema izmišljenih datiranih smjena iz canvasa.

Dokaz:

- `supabase test db`: `Files=12, Tests=328`, `Result: PASS`.
- `rest_employee_crud.ts`: `PASS: 19 REST provjera osoblja` — admin A/B i klijent, uključujući
  originalno ime na vlastitom terminu poslije preimenovanja/deaktivacije radnika.
- Namjerno oslabljen admin guard obara 7 testova; rollback vraća originalnu funkciju.
- `rest_isolation.ts`: 24 asercije; `rest_public_catalog.ts`: 57 asercija PASS.
- Puna lokalna Flutter suita prolazi; dodatnih 20 ciljnih widget testova potvrđuje i async
  deep link. Analiza svih pet paketa je čista; 237 verzionisanih Dart fajlova formatirano.
- Chromium nad lokalnim backendom: dodavanje, izmjena, deaktivacija, reaktivacija i
  očuvanje `/employees` pri učitavanju prijave; desktop 1440×900 i telefon 402×874.
  Dokaz slikom: `docs/screenshots/task-33-*.png`. Widget testovi dodatno pokrivaju 320, 840,
  1024 i 1440 px te povećan font.
- CI zelen na `8a40a97`: [Flutter](https://github.com/htuco/salon-booking-platform/actions/runs/35601275480)
  i [Supabase tests](https://github.com/htuco/salon-booking-platform/actions/runs/35601275341).

Pregled je našao refresh sa starim vezama i pretijesne desktop kartice; oba su popravljena
uz regresijske testove. Browser je našao rekonstrukciju routera tokom učitavanja članstva:
`read` i postojeći refresh listener sada čuvaju direktnu adresu. Stari test kataloga je pri
zatvaranju streama mogao ostati nedovršen; sada prvo uklanja widget/pretplatu.

Nije provjereno/deployano: hostovani Supabase i native iOS/Android uređaj. Migracija
`20260921140000_employee_crud.sql` mora prethoditi objavi novog builda. Screenshotovi i
REST dokazi su iz lokalnog stacka; snapshot starih termina backfilluje trenutno ime,
jer ranija imena baza nije čuvala. PR je spojen u `main`; hostovani deploy je zaseban korak.
