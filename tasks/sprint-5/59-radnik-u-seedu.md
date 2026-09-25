# Task 59 — Radnik u lokalnom seedu

| | |
|---|---|
| **Procjena** | 0,5 dan |
| **Zavisi od** | — |
| **Blokira** | 60 |
| **Reference** | sprint-4 task 47 (status: nalog radnika pravljen ručnim SQL-om) · `supabase/seed.sql` |

## Cilj
`supabase db reset` daje i nalog radnika, pa se uloga radnika provjerava bez ručnog SQL-a.

## Definicija gotovog
- [ ] Nalog radnika u `supabase/seed.sql` po obrascu vlasnika, vezan za „Emir" (barber)
- [ ] Članstvo sa ulogom `employee` i veza na `employees` red
- [ ] Demo lozinka samo za lokalni stack; ništa ne ide na hostovani projekat
- [ ] `supabase test db` i dalje zelen — seed ne smije pomjeriti postojeće asercije
- [ ] `/verify` skill i `.claude/docs/workflows.md` navode lokalni nalog radnika

## Zamke
- Seed je i ulaz za pgTAP. Novi red koji mijenja broj termina ili članstava obara postojeće testove.

## Status
Nije počet.
