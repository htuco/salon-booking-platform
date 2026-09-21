# Task 46 — Uloga `employee` i sužena izolacija

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [45](45-nalozi-za-osoblje.md) |
| **Blokira** | [47](47-admin-ljuska-za-radnika.md) |
| **Reference** | [01 §5.3](../../docs/01-mvp-spec.md) · [ADR-0013](../../docs/adr/0013-radnik-dobija-suzen-pristup-svojim-terminima.md) · `.claude/docs/security.md` |

## Cilj
Radnik se prijavi u istu admin aplikaciju i vidi **samo svoje** termine. Ovo je jedino mjesto u
sprintu gdje greška curi tuđe podatke.

## Zatečeno stanje
`staff_role` enum **već ima** vrijednost `employee`, ali je nijedna politika ne prihvata:
`private.is_admin()` traži `salon_admin` i u JWT-u i u `public.users`, a `private.is_client()`
isključuje `employee`. Takav nalog danas nema **nijedno** pravo. Uz to, `public.users` nema kolonu
koja bi nalog vezala za red u `employees`.

## Definicija gotovog
- [ ] `public.users.employee_id` — FK na `employees(salon_id, id)`, obavezan kad je uloga `employee`
- [ ] `private.is_employee(p_salon)` i `private.current_employee_id()`
- [ ] Politike: radnik čita i mijenja **svoje** termine; cjenovnik, osoblje i postavke su mu čitanje
      ili ništa, po odluci iz ADR-a
- [ ] `set_appointment_status` i `cancel_appointment` prihvataju radnika **samo** za njegove termine
- [ ] pgTAP: radnik A ne vidi termine radnika B; ne mijenja tuđi termin; ne mijenja cjenovnik; ne
      vidi drugi salon
- [ ] Deno REST test sa **stvarnim** JWT-om radnika — pgTAP ne dokazuje PostgREST sloj
- [ ] `.claude/docs/security.md` dobija red za `employee` u tabeli uloga

## Zamke
- **Ovo mijenja model autorizacije.** Do sada je `is_admin()` bila jedina kapija za osoblje. Svaka
  politika koja je pisana na „osoblje = admin" mora biti pregledana, ne samo dopunjena.
- Termin **bez** dodijeljenog radnika (`employee_id is null`) nije ničiji — odluči vidi li ga radnik
  i zapiši; tiho izostavljanje znači da termin nestane iz svih pogleda.
- `rls-auditor` subagent ide prije PR-a.

## Status

Nije počet.
