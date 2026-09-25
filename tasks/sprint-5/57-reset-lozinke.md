# Task 57 — Povratak zaboravljene lozinke

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `docs/06` §2.1 · ADR-0010 · `docs/08` (demo sakriva „Zaboravili ste lozinku?") |

## Cilj
Klijent i vlasnik koji zaborave lozinku vrate pristup sami, bez poruke platformi.

## Definicija gotovog
- [ ] Klijent: „Zaboravljena lozinka?" → `resetPasswordForEmail` → link vraća u aplikaciju → nova lozinka (`updateUser`)
- [ ] Admin: isti tok na webu i na mobilnom
- [ ] Generička poruka bez obzira da li email postoji — tok ne otkriva ko ima nalog
- [ ] Pravilo lozinke kao pri registraciji (8+ znakova, slovo i cifra), server je izvor istine
- [ ] Demo napomena „ne podržava zaboravljenu lozinku" nestaje gdje tok radi; `docs/08` usklađen
- [ ] Uživo: email stiže sa hostovanog projekta, link otvara pravi flavor, prijava novom lozinkom radi

## Zamke
- Redirect link je po flavoru (`ba.nasadomena.<flavor>://login-callback`) i mora biti na listi
  dozvoljenih redirecta u Supabase Authu — inače link otvara pogrešnu aplikaciju ili nijednu.
- Slanje emaila traži SMTP na hostovanom projektu; ugrađeni Supabase mailer ima nizak limit.

## Status
Nije počet.
