# Task 72 — Super admin konzola, lokalna i minimalna

| | |
|---|---|
| **Procjena** | 4–5 dana |
| **Zavisi od** | — |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | ADR-0029 · `docs/01` §6.1 · skill `/new-tenant` · `tenants/_template/` |

## Cilj
Novi salon bez ručnog `tenant.yaml` i SQL-a. Alat radi **samo na mašini developera**, nikad se ne
deploya, i ima mali ali jasan UI.

## Odluke prije koda (ADR)
- Tehnologija: Flutter desktop/web (dijeli `core_ui`) ili mali lokalni web alat
- Da li piše `tenants/<flavor>/tenant.yaml` i pokreće generatore, ili samo bazu (pa se fajl generiše)
- Gdje stoji service role ključ (`.env.live`, nikad u repo)

## Definicija gotovog
- [ ] Lista salona sa statusom (aktivan, build, store)
- [ ] Novi salon: ime, flavor, vertikala, tema, boje, logo → red u bazi + `tenant.yaml` + generatori
- [ ] Admin nalog vlasnika kroz poziv (kod), ne ručni SQL
- [ ] Deaktivacija salona; promjena boja i teme
- [ ] Status store objave (`draft` → `in_review` → `live`)
- [ ] Dokumentovano u `tenant-factory.md` i skillu `/new-tenant`

## Status
Nije počet.
