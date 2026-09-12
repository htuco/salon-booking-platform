# Task 15 — Dokaz izolacije: isti klijent u dva salona

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | [14](14-identitet-i-klijent-upsert.md) |
| **Blokira** | prvi pravi klijent |
| **Reference** | [01 §17](../../docs/01-mvp-spec.md#17-build-order) korak 15 · [`.claude/docs/security.md`](../../.claude/docs/security.md) |

## Cilj
Dokazati da salon A **ne vidi** da je njegov klijent i klijent salona B. Ovo je poslovni rizik, ne
tehnička formalnost: salon koji otkrije da mu konkurencija vidi klijentelu otkazuje ugovor.

## Definicija gotovog
- [x] Deno REST test: isti identitet se prijavi u oba demo salona i rezerviše u oba
- [x] Admin salona A ne vidi `customers` red iz salona B — ni po `id`, ni po `auth_identity_id`,
      ni kroz `appointments` embed
- [x] Klijent ne vidi svoje termine iz salona B dok je `x-salon-id` salon A
- [x] Test pada kad se politika oslabi — **provjereno namjernim kvarenjem dvije politike**
- [x] Test ide u `Supabase tests` suite i u `tool/test_supabase.sh`

## Koraci
1. Napiši test **prije** nego što pogledaš politike — ako prođe iz prve, politika je možda slaba
2. Pokvari politiku namjerno, potvrdi da test pada, vrati je
3. Commit: `test(supabase): izolacija klijenta izmedju salona`

## Zamke
- **`x-salon-id` bira kontekst, ne daje članstvo.** Test koji samo mijenja header, a ne provjerava
  šta baza vrati, ne dokazuje ništa.
- Curenje kroz **join** je češće od curenja kroz direktan upit: `appointments → customers` je
  mjesto gdje politika najčešće propusti.

---

## Status (2026-09-12) — ✅ zatvoren

`supabase/tests/rest_cross_salon_isolation.ts` — **22 asercije, tri stvarna JWT-a** (klijent,
admin salona A, i admin kroz `public.users`). Jedan čovjek se prijavi u oba demo salona,
rezerviše u oba, pa se provjerava šta ko vidi.

### Zašto REST, a ne pgTAP

pgTAP vrti SQL kao rola; ovdje je pitanje šta vrati **PostgREST** na stvaran token i stvaran
`x-salon-id` header. Dva mjesta gdje se to razlikuje i gdje curenje stvarno prolazi:

- **embed**: `appointments?select=*,customers(*)` — join kojim admin može povući tuđi red;
- **filter po `auth_identity_id`**: admin ga **zna**, jer stoji u njegovom vlastitom redu. Ako
  politika propusti, admin salona A može nabrojati sve salone u kojima je njegov klijent.

Usput je nađeno da kompozitni FK-ovi čine embed **dvosmislenim** (`PGRST201`, HTTP **300**):
`appointments` ima dva FK-a ka `customers`. To je prva prepreka napadaču, ali prepreka koja samo
traži da pročita poruku o grešci — pa se testira **imenovana** veza, tačno kako bi je on napisao.
Zbog toga `ok()` u testu baca na `>= 300`, ne na `>= 400`; sa pragom 400 bi `PGRST201` prošao kao
uspjeh i test bi pukao kasnije, na `.every is not a function`.

### Dokazano

```
$ ./tool/test_supabase.sh
==> pgTAP                                   Files=3, Tests=82,  Result: PASS
==> REST izolacija (dva stvarna JWT-a)      24 assertions, two real JWTs.
==> Javni katalog (bez tokena)              26 assertions passed.
==> Upsert klijenta i rezervacija           20 asercija, stvaran JWT, stvaran 409.
==> Izolacija izmedju salona                22 asercija, tri stvarna JWT-a.
```

### Test **može** pasti — provjereno kvarenjem, ne pretpostavkom

Dvije politike, pokvarene na dva različita načina, obaraju dvije različite asercije:

**1. `staff_manage` bez veze sa salonom reda** — klasična greška „admin bilo gdje ⇒ admin svugdje":

```sql
create policy staff_manage on public.customers for all to authenticated
 using (exists (select 1 from public.users u
                where u.id = auth.uid() and u.role = 'salon_admin'));
```
```
error: Admin A ne smije dobiti nijedan red iz drugog salona.
```

**2. `own_customer` bez `salon_id = private.client_salon_id()`** — header prestane biti kontekst:

```sql
create policy own_customer on public.customers for select to authenticated
 using (private.is_client() and private.owns_identity(auth_identity_id));
```
```
error: Klijent u kontekstu A vidi samo svoj A red.
```

Obje su vraćene i provjerene naspram migracije:

```
$ psql -tAc "select polname, pg_get_expr(polqual, polrelid) from pg_policy
             where polrelid='public.customers'::regclass"
own_customer|(private.is_client() AND (salon_id = private.client_salon_id())
              AND private.owns_identity(auth_identity_id))
staff_manage|private.is_admin(salon_id)
```

### Šta test pokriva

| Ko | Pokušaj | Očekivano |
|---|---|---|
| Klijent, kontekst A | `customers`, `appointments` | samo redovi salona A |
| Klijent, kontekst A | `appointments?salon_id=eq.<B>` | prazno — filter ne zaobilazi RLS |
| Admin A | `customers` bez filtera | samo salon A, **i** njegov vlastiti klijent je tu (inače test prolazi iz pogrešnog razloga) |
| Admin A | `customers?id=eq.<B red>` | prazno |
| Admin A | `customers?auth_identity_id=eq.<identitet>` | samo A red |
| Admin A | `appointments` + imenovani embed `customers` | nijedan red salona B |
| Admin A | `x-salon-id: B` | i dalje samo salon A — header ne daje članstvo |
| Admin A | `auth_identities` | prazno — identitet je klijentov, ne salonov |

### Šta **nije** provjereno

- **Super admin** nije u ovom testu — on je namjerno iznad izolacije (`security.md`).
- **`devices`** nema upisa pa ni termina za curenje — dolazi sa [taskom 25](25-push-notifikacije.md).
- **CI nije pokrenut** — naplata blokira workflowove do 29.09.2026. Test je dodan u
  `.github/workflows/supabase-tests.yml` i vrtiće se na PR i na push u `main` kad se kvota vrati.
