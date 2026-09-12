# Task 14 — Backend: `AuthIdentity` + `Customer` upsert kroz validiranu funkciju

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [13](13-client-login-ekran.md) |
| **Blokira** | 15, 16, 25 — i zatvaranje taska 11 |
| **Reference** | [06 §4](../../docs/06-auth-login-flow.md) · [`.claude/docs/security.md`](../../.claude/docs/security.md) |

## Cilj
Prijavljeni korisnik dobija `customers` red u **svom** salonu, i `book_appointment` konačno ima
`customerId` koji mu fali od taska 11.

## Definicija gotovog
- [x] `auth_identities` red se kreira/ažurira pri prvoj prijavi
- [x] `customers` upsert po `(salon_id, auth_identity_id)` kroz **`security definer` funkciju sa
      validacijom**, nikad `insert` sa klijenta
- [x] Isti nalog u dva salona daje **dva odvojena `customers` reda**
- [x] `book_appointment` radi end-to-end sa pravim tokenom — **prvi stvarni upis iz aplikacije**
- [x] **`409` izazvan uživo**: slot zauzet izvana, drugi zahtjev dobije `ConflictError` i ekran
      osvježi listu (ostatak DoD-a iz taska 11)
- [x] pgTAP: upsert je idempotentan; tuđi salon i nepostojeći identitet vraćaju istu grešku

## Koraci
1. Migracija sa funkcijom + grantovi; politika se piše prije funkcije, ne poslije
2. pgTAP testovi, pa Deno REST test sa dva stvarna tokena
3. Klijent: `bookingCustomerIdProvider` čita iz upserta
4. **Izazovi konflikt ručno** i snimi ponašanje ekrana
5. Commit: `feat(supabase): upsert identiteta i klijenta`

## Zamke
- **Tuđi i nepostojeći klijent moraju vraćati istu grešku.** Razlika je endpoint za nabrajanje
  tuđih klijenata ([`security.md`](../../.claude/docs/security.md)).
- `auth_identity_id` je **nullable namjerno** — salon admin unosi telefonske klijente koji nemaju
  nalog ([06 §4](../../docs/06-auth-login-flow.md)).
- Ovo je jedini task koji zatvara `[~]` stavke iz taska 11. Ne zaboravi ih čekirati tamo.

---

## Status (2026-09-12) — ✅ zatvoren

`public.ensure_customer` zatvara zadnju rupu između prijave i rezervacije. **Termin je prvi put
stvarno nastao iz aplikacije**, i `409` je prvi put izazvan uživo — čime padaju i dvije 🟡 stavke
iz [taska 11](../sprint-1/11-booking-flow.md).

### Šta je isporučeno

| Sloj | Šta |
|---|---|
| `supabase` | Migracija `20260912120000_ensure_customer.sql` — `security definer` funkcija, identitet iz tokena, salon iz `x-salon-id`, `on conflict do nothing`. |
| `supabase` | `003_customer_upsert.test.sql` — 16 pgTAP testova. |
| `supabase` | `rest_customer_upsert.ts` — 20 asercija kroz PostgREST sa stvarnim JWT-om; `tool/test_supabase.sh` ga sada vrti. |
| `core_api` | `CustomerRepository.ensureCustomer`, `customerIdFromRow`; `currentCustomerIdProvider` zove upsert umjesto čitanja. |
| `apps/client` | `bookingCustomerIdProvider` je `FutureProvider`; slanje `await`-a klijenta umjesto da čita snimak. |

### Dokazano

```
$ ./tool/test_supabase.sh
==> pgTAP
  001_tenant_isolation.test.sql .. ok
  002_availability.test.sql ...... ok
  003_customer_upsert.test.sql ... ok
  Files=3, Tests=82,  Result: PASS
==> REST izolacija (dva stvarna JWT-a)
  REST tenant isolation passed: 24 assertions, two real JWTs.
==> Javni katalog (bez tokena)
  Public catalog readable without a login: 26 assertions passed.
==> Upsert klijenta i rezervacija (stvaran JWT, stvaran 409)
  REST upsert + rezervacija prolazi: 20 asercija, stvaran JWT, stvaran 409.

$ melos run format && melos run analyze && melos run test
  SUCCESS; 256 testa PASS (bilo 253)
```

**Prva stvarna rezervacija iz app-e** — web build protiv lokalnog stacka, prijava emailom, pa
„Pošalji zahtjev":

```
$ psql -c "select a.status, a.date, a.start_time, a.end_time, a.buffer_minutes,
           c.name, e.name, s.name from public.appointments a join ..."
 pending | 2026-09-16 | 10:00:00 | 10:40:00 | 5 | Klijent | Emir | Fade
```

**`409` izazvan uživo.** Korisnik je na koraku 4 sa izabranim terminom 17.09. u 11:00; slot je u
međuvremenu zauzet izvan app-e (`insert` kao `postgres`, simulacija drugog korisnika). Na „Pošalji
zahtjev":

```
[ERROR] Failed to load resource: the server responded with a status of 409
        (Termin je upravo zauzet) @ .../rest/v1/rpc/book_appointment
```

Ekran se vratio na `/book/slot`, dan je zadržan, vrijeme obrisano, a lista osvježena — 11:00 je
nestao, i sa njim 10:30–11:30, jer 40-minutna usluga plus buffer zatvara taj prozor. Slika:
[`docs/screenshots/task-14-409-osvjezena-lista.png`](../../docs/screenshots/task-14-409-osvjezena-lista.png).
Uspješan zahtjev: [`task-14-zahtjev-poslan.png`](../../docs/screenshots/task-14-zahtjev-poslan.png).

### Tri greške koje su našli testovi i browser, ne čitanje

**1. `not (A and B)` je rupa kad `B` može biti `NULL`** — pgTAP.
`private.client_salon_id()` vraća `NULL` bez headera; `true and NULL` je `NULL`, `not NULL` je
`NULL`, a `if NULL then` se **ne izvršava**. Zahtjev bez `x-salon-id` headera je prolazio kroz
guard i pravio klijenta u salonu koji je pozivalac poslao kao argument. Provjera je rastavljena,
`NULL` se hvata prvi.

**2. `revoke all on function ... from public` ne skida ništa** — pgTAP.
Supabase kroz `pg_default_acl` daje `execute` **direktno** rolama `anon` i `authenticated`, ne kroz
`PUBLIC`. `anon` je mogao zvati `ensure_customer`. Isti propust je stajao na `book_appointment` od
taska 05: tok je bio branjen logikom (`auth.uid()` je `NULL` za `anon`), ali granica koju
`security.md` opisuje nije postojala. Zatvoreno na obje funkcije; `get_available_*` namjerno ostaju
javne (`docs/06 §1.1`).

**3. „Nema klijenta" i „još nije stigao" nisu ista stvar** — browser.
`bookingCustomerIdProvider` je bio sinhroni snimak, pa je dodir na „Pošalji zahtjev" pola sekunde
nakon prijave davao grešku iako je red u bazi već postojao (`ensure_customer` u `17:52:11.529`,
dodir odmah iza). Provider je sada `FutureProvider`, a slanje `await`-a taj isti poziv.

### Zamka za sljedećeg

**`supabase db reset` ne učitava `config.toml`.** Promjena auth podešavanja traži `supabase stop`
pa `start`. Simptom je podmukao: prijava i dalje radi, ali mail stigne kao podrazumijevani engleski
magic link umjesto kao šestocifreni kod — pa lokalni dokaz o OTP-u ne govori ništa o tome šta je u
konfiguraciji. Provjera je subject u Mailpitu: mora pisati „Vaš kod za prijavu". Zapisano i u
`.claude/docs/workflows.md`.

### Šta **nije** provjereno

- **Ništa na uređaju ni u emulatoru** — dokaz je web build, pgTAP i REST.
- **Admin unos telefonskih klijenata** (`auth_identity_id is null`) namjerno nije u ovoj funkciji
  — to je drugi tok sa drugom validacijom, Sprint 3.
- **`devices` upisi** i dalje nemaju validiranu funkciju — [task 25](25-push-notifikacije.md).
- **CI nije ništa potvrdio** — naplata blokira workflowove do 29.09.2026.
