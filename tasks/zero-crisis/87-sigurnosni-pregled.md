# Task 87 — Sigurnosni pregled prije lansiranja

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [76](76-supabase-produkcija-i-staging.md), [81](81-potvrda-emaila-kodom.md), [82](82-izmjena-profila-klijenta.md), [83](83-crashlytics.md), [84](84-apple-google-prijava.md), 64–72 i [91](91-lista-cekanja-raspon.md) (sve nove tabele i funkcije postoje) |
| **Blokira** | [89](89-prelazak-na-produkciju.md), [60](../polishing/60-regresija-i-testiranje.md) (regresija) |
| **Reference** | `.claude/docs/security.md` · agent `rls-auditor` · skill `/security-review` |

## Cilj
Prije prvih pravih podataka: nijedan put do tuđeg salona ili tuđeg klijenta, nijedna tajna van
mjesta, nijedan demo nalog u produkciji.

## Definicija gotovog
- [ ] `rls-auditor` nad cijelim `supabase/` — svaka tabela iz zero-crisis (lista čekanja, recenzije,
      prihvatanje uslova, obavijesti) ima politiku i negativan test
- [ ] `/security-review` nad klijentom, adminom i Edge Functions
- [ ] Supabase security advisors na produkciji bez upozorenja
- [ ] Rate limiti i limit otvorenih zahtjeva (65) provjereni na produkciji
- [ ] U produkciji nema demo salona, test naloga ni `*.test` emailova
- [ ] Zavisnosti bez poznatih ranjivosti (pub, npm za super admin ako postoji)
- [ ] Nalazi i odluke zapisani u `security.md`

## Status
Nije počet.
