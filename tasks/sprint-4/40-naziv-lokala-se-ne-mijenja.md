# Task 40 — Naziv lokala se ne mijenja iz admina

| | |
|---|---|
| **Procjena** | 0,5 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | [ADR-0003](../../docs/adr/0003-x-salon-id-bira-kontekst-ne-daje-prava.md) · `tenants/<flavor>/tenant.yaml` |

## Cilj
Vlasnik može promijeniti naziv salona iz postavki, a taj naziv se kosi sa imenom brandirane
aplikacije u prodavnici. Dvije istine o istoj stvari, i ona u storeu se ne mijenja bez submissiona.

## Definicija gotovog
- [x] Naziv salona je u postavkama **samo za čitanje**, uz rečenicu zašto
- [x] RPC odbija promjenu naziva — ugovor se brani u bazi, ne samo na ekranu
- [x] pgTAP: pokušaj izmjene naziva vraća grešku
- [x] Zapisano gdje naziv **jeste** promjenjiv: `tenant.yaml` → generator → store build

## Otvoreno pitanje
Treba li salonu zaseban **prikazni naziv** koji se smije mijenjati (npr. „Barber Studio Vitez —
Stari Grad") dok ime aplikacije ostaje fiksno? Ako da, to je nova kolona i nova odluka, ne dio ovog
taska.

## Zamke
- Naziv se pojavljuje na više mjesta (breadcrumb, klijentska Početna, pravila korištenja). Kad se
  zaključa, nijedan ekran ne smije nuditi polje koje ne radi.

## Status (2026-09-23) — ✅ zatvoren

Spojen u `main` kroz [PR #99](https://github.com/htuco/salon-booking-platform/pull/99). Admin prikazuje
naziv samo za čitanje uz objašnjenje; `update_salon_contact` (migracija
`20260923100000_zakljucaj_naziv_salona.sql`) tretira `p_name` kao provjeru zatečenog naziva i odbija
promjenu sa `PT400`, bez djelimičnog upisa. Put promjene naziva (`tenant.yaml` → `gen_flavors` → store
build) zapisan je u `.claude/docs/tenant-factory.md`.

**Dokazano:** `melos run analyze|test` zeleni (PR #99); pgTAP `014_postavke_lokacije` sa negativnim
slučajem izmjene naziva prolazi lokalno na Dockeru (`supabase test db`, 478/478, 2026-09-23) i u CI-ju.

**Nije provjereno:** ručni test na uređaju; migracija na hostovanom projektu (`supabase db push`).
