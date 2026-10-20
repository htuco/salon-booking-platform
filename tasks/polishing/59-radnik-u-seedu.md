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
- [x] Nalog radnika u `supabase/seed.sql` po obrascu vlasnika — vezan za **Aminu (beauty)**, ne za
      „Emir"; razlog u statusu
- [x] Članstvo sa ulogom `employee` i veza na `employees` red
- [x] Demo lozinka samo za lokalni stack; ništa ne ide na hostovani projekat
- [x] `supabase test db` i dalje zelen — seed ne smije pomjeriti postojeće asercije
- [x] `/verify` skill i `.claude/docs/workflows.md` navode lokalni nalog radnika

## Zamke
- Seed je i ulaz za pgTAP. Novi red koji mijenja broj termina ili članstava obara postojeće testove.

## Status (2026-10-20)

Gotov, grana `chore/radnik-u-seedu`.

**Šta je urađeno.** `radnik@beautystudiotravnik.test` / `admin123456`: red u `auth.users` sa
`role = employee` i `salon_id` salona B u `raw_app_meta_data`, identitet u `auth.identities`, red u
`public.users` sa `employee_id` Amine. Prazni stringovi umjesto NULL-a (GoTrue zamka) idu kroz
postojeći `do` blok, proširen na treći id.

**Zašto Amina, a ne Emir.** `users_employee_unique` dozvoljava jedan nalog po radniku, a testovi
vežu svoje naloge za Emira i Amara: `021_uloga_employee`, `025_moj_profil`,
`rest_employee_izolacija.ts` i `rest_pozivi_osoblja.ts`. Seed nalog na Emiru bi oborio sva četiri,
a REST testove i trajno, jer ne rollbackuju. Treći barber u salonu A bi pomjerio brojače (`001`
broji 10 aktivnih radnika, availability „bilo ko"). Aminu ne veže nijedan test (samo je koriste kao
radnika drugog salona), a oba seed termina salona B su njena — radnik odmah vidi svoje termine.

**Dokaz.**

```
$ ./tool/test_supabase.sh            # reset + pgTAP + svi REST/Deno testovi
Files=31, Tests=888 ... Result: PASS
REST tenant isolation passed: 24 assertions, two real JWTs.
rest_pozivi_osoblja: 17 provjera PASS
rest_employee_izolacija: 13 provjera PASS
PASS: 19 REST provjera osoblja
exit 0
```

Prijava kroz GoTrue (lokalni stack, poslije reseta):

```
token: app_metadata {"role":"employee","salon_id":"550e8400-…-446655440001"}
GET /rest/v1/appointments  → 2 reda, oba salon B, employee_name "Amina" (Lejla Karic confirmed, Amina Sabic pending)
GET /rest/v1/users         → [{"role":"employee","salon_id":"…0001","employee_id":"20000000-…-000000000003"}]
```

Nijedan red salona A. Brojevi su isti kao na `develop`-u (888), dakle seed nije pomjerio nijednu
aserciju.

**Nije viđeno:** Melura prijavljena kao radnik na ekranu. To je dio regresije (60), za koju je ovaj
nalog i napravljen.
