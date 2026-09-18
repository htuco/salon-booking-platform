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
- [ ] `/employees` po `3g`, mobilno `3r`
- [ ] Dodavanje, izmjena i deaktivacija radnika kroz RPC; `experience_years` ostaje nullable
- [ ] Koje usluge radnik radi — veza prema uslugama iz [32](32-usluge-i-cjenovnik.md)
- [ ] Radnik se **ne briše** dok ima buduće termine
- [ ] pgTAP: izolacija po salonu na svakoj putanji pisanja
- [ ] Deaktiviran radnik nestaje iz klijentskog izbora, a **ostaje** na svojim prošlim terminima

## Koraci
1. Migracija + pgTAP, pa ugovor, pa ekran
2. Commit: `feat(admin): crud nad osobljem i smjenama`

## Zamke
- **Radnik nije nalog.** `employees` je osoblje salona; `public.users` + `auth_identities` su
  prijava. Spajanje to dvoje daje radniku pravo prijave koje mu niko nije dao.
- Deaktivacija koja sakrije i prošle termine briše istoriju salona — filtriraj budućnost, ne sve.
- Staž je nullable jer red bez staža **nije** greška, nego predviđeno stanje (task 22).

## Status

Nije počet.
