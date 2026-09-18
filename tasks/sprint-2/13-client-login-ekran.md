# Task 13 — Client: login ekran na kraju booking flowa

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [12](12-auth-provideri.md), [11](../sprint-1/11-booking-flow.md) |
| **Blokira** | 14 (upsert traži token), 16, 17 |
| **Reference** | [06 §1.1](../../docs/06-auth-login-flow.md) · [06 §3](../../docs/06-auth-login-flow.md) · `prototype/ui/SPEC.md` 5f |

> **Promjena plana 16.09.2026.** Ovaj task ostaje dokaz ranije implementiranog OTP toka. Ciljni
> email + lozinka tok, registracija i recovery opisani su u
> [tasku 27](27-email-password-auth.md); kod još nije promijenjen.

## Cilj
Korisnik koji je izabrao termin prijavi se **na zadnjem koraku** i zahtjev ode dalje — bez izlaska
iz flowa i bez gubitka izbora.

## Definicija gotovog
- [x] `/auth/login` ima pravo tijelo; dugmad sa koraka 4 vode na stvarnu prijavu
      — **email do kraja**, Apple/Google javljaju da nisu dostupni (v. status blok)
- [x] **Nema polja za telefon** ([06 §3.1](../../docs/06-auth-login-flow.md))
- [x] Email OTP: unos maila → 6 cifara → nazad u flow, **bez izlaska iz app-a**
- [x] Nakon prijave korisnik se vraća **tačno na `/book/details`**, sa netaknutim izborom
- [x] `bookingCustomerIdProvider` dobija pravu implementaciju; `book(...)` se poziva bez izmjene
      ijednog ekrana
- [x] Greška prijave je stanje ekrana, ne `SnackBar` koji nestane
- [x] Widget testovi: povratak u flow čuva izbor, otkazana prijava vraća na korak 4

## Koraci
1. Ekran po `prototype/ui` 5f — oblik je već tamo, ovdje se dodaje ponašanje
2. `authStateProvider` u `core_api`; ekran ga sluša, ne poziva `supabase.auth` direktno
3. Povratak u flow: `go_router` `redirect` sa `from` parametrom
4. Commit: `feat(client): login na kraju booking flowa`

## Zamke
- **Stanje flowa je `autoDispose`.** Odlazak na `/auth/login` ne smije ga počistiti, inače se
  korisnik vraća na prazan sažetak. Provjeri prije nego što napišeš ekran.
- Login se traži **samo ovdje**. Guard na `/book/*` je odluka koja se ne otvara
  ([06 §1.1](../../docs/06-auth-login-flow.md)).

---

## Status (2026-09-12) — 🟡 email prijava radi i dokazana je, nativni provideri nisu

`/auth/login` više nije placeholder. Cio tok email OTP-a — unos adrese, šestocifreni kod,
povratak u flow — **odigran je do kraja u browseru protiv živog Supabase stacka**, ne samo u
testu.

### Šta je isporučeno

| Sloj | Šta |
|---|---|
| `core_api` | `SupabaseAuthRepository` — prva implementacija ugovora iz taska 12. Email OTP kroz `signInWithOtp`/`verifyOTP`; Apple/Google/Facebook bacaju `ServerError` sa imenom paketa koji fali. |
| `core_api` | `CustomerRepository.currentCustomerId` — čita `customers` pod politikom `own_customer`. Upis je task 14. |
| `core_api` | `AuthRejectedError` i `RateLimitError`; `mapError` više ne slijeva svaki `AuthException` u `ServerError`. |
| `apps/client` | `LoginScreen` + `LoginController` (tri faze: provideri → email → kod), `AppointmentHoldCard` izvučena iz koraka 4, `/auth/login?from=` u routeru. |
| `apps/client` | `bookingCustomerIdProvider` čita iz baze umjesto da vraća konstantu. |

### Dokazano

**Puna suita — 253 testa PASS** (bilo 238):

```
$ melos run test
[core_domain]: 00:00 +54: All tests passed!
[admin]:       00:02 +4:  All tests passed!
[core_api]:    00:00 +52: All tests passed!   (bilo 45)
[core_ui]:     00:02 +40: All tests passed!
[client]:      00:09 +103 ~1: All tests passed!  (bilo 85)
$ melos run format && melos run analyze
  └> SUCCESS   (oba)
```

**Email OTP odigran u browseru, protiv lokalnog stacka.** Web build sa stvarnim
`SUPABASE_URL`/`ANON_KEY`, Chromium na 402×874, podaci iz `seed.sql` — usluge, radnici,
slobodni termini iz `get_available_slots`:

```
/ → /book/service → /book/employee → /book/slot → /book/details
  → /auth/login?from=/book/details → unos maila → kod iz Mailpita → /book/details
```

Mail koji stvarno stigne (Mailpit `:54324`):

```
Vaš kod za prijavu
274431
Kod vrijedi 60 minuta.
--- ima li linka: False
```

Bez linka — `docs/06 §2.1` traži OTP, nikad magic link.

Baza nakon četiri prolaza kroz prijavu:

```
$ psql -c "select email, providers, is_anonymous from public.auth_identities ..."
 gost.task13d@primjer.ba | {email} | f
 gost.task13c@primjer.ba | {email} | f
 gost.task13b@primjer.ba | {email} | f
 gost.task13@primjer.ba  | {email} | f

$ psql -c "select count(*) from public.customers;"
 0
```

**`customers` je 0 i to je poenta**: `bookingCustomerIdProvider` vraća `null` zato što reda
**nema**, a ne zato što je zakucan. Task 14 pravi red i ništa iznad se ne mijenja.

Slike: [`docs/screenshots/task-13-korak4-prijava.png`](../../docs/screenshots/task-13-korak4-prijava.png),
[`docs/screenshots/task-13-otp-kod.png`](../../docs/screenshots/task-13-otp-kod.png).

### Šta je browser našao, a testovi nisu

**1. Prijava je brisala izbor iz flowa.** Nakon uspješne prijave korak 4 je pokazivao
„Nedostaje izbor iz prethodnog koraka." `bookingFlowProvider` je `autoDispose`, a jedini
slušalac na login ekranu bila je kartica „Čuvamo vam" — koja se crta **samo** u fazi izbora
providera. Prelazak na unos emaila je skidao zadnjeg slušaoca.

Popravka je eksplicitan `ref.watch(bookingFlowProvider)` na nivou ekrana. Vezivanje za vidljivi
widget je pogrešan mehanizam: sljedeći ko sakrije karticu u jednoj fazi obara flow, a ekran i
dalje izgleda ispravno.

**Test je bio kriv na isti način.** `_pump` je držao vlastitu pretplatu na `bookingFlowProvider`
cijelo vrijeme testa, pa bi test prolazio i nad app-om koja izbor gubi — mjerio je harness, ne
app. Sada se pretplata zatvara čim app preuzme slušanje. Provjereno da test **može** pasti: bez
popravke padaju dva testa (`melos run test` → `+9 -2`).

**2. Provideri na webu.** Korak 4 u browseru nudi samo „Nastavi sa emailom" — `forPlatform`
odsijeca Apple i Google na `AuthPlatform.web`. Nije greška; prvi put viđeno uživo.

**3. Slanje bez `customers` reda više nije mrtvo dugme.** `BookingSubmitNotifier` je tiho vraćao
`false` kad je `customerId == null`. Sada vraća `NotFoundError`, pa ekran pokaže poruku. Viđeno u
browseru: „Nešto je pošlo naopako. Pokušaj ponovo."

### Ostalo za sljedećeg

**Apple i Google prijava (🟡, ne mogu se dokazati ovdje).** Nedostaju paketi
`sign_in_with_apple` i `google_sign_in` (`docs/06 §6.1`) — **namjerno nisu dodani**, jer ni sa
njima tok ne bi mogao biti odigran: client ID-evi iz
[`12-konzole-checklist.md`](12-konzole-checklist.md) nisu upisani, mašina nema nijedan iOS
certifikat (`security find-identity` → `0 valid identities found`), pa nema ni instalacije na
fizički uređaj. Dugmad zato javljaju da provider nije dostupan i nude email, umjesto da tiho ne
rade ništa. Nastavak: popuni konzole po checklistu, pa

```sh
flutter pub add sign_in_with_apple google_sign_in
# implementiraj signInWithApple/signInWithGoogle u SupabaseAuthRepository
```

**Web + čitač ekrana: polje za kod zadrži upisani email.** Flutter web ponovo koristi isti
semantics `<input>` za oba polja — `aria-label` postane „Šestocifreni kod", vrijednost ostane
adresa. **Vidljivo polje je prazno** (v. `task-13-otp-kod.png`; Dart kontroler je prazan, što
potvrđuje poruka „Kod ima šest cifara" na pokušaj potvrde), pa sighted korisnik ovo ne vidi.
Probani i **odbačeni**: `ValueKey` po polju i `FocusScope.unfocus()` prije prelaza (oba ostaju u
kodu, jer su ispravna sama po sebi), i `AutofillGroup` po koraku (uklonjen — nije promijenio
ništa). Web nije store target nijednog tenanta (`targets.web`), pa ovo ne blokira task.

**Odjava nema ekran.** `signOut()` postoji u repozitoriju, ali ga niko ne zove — „Moj račun" je
[task 17](17-moj-racun-i-brisanje.md). Do tada se sesija u razvoju čisti sa
`localStorage.clear()` u konzoli.

**Guest** ostaje `UnimplementedError` bez taska, a **Facebook** je u međuvremenu uklonjen iz koda
([ADR-0011](../../docs/adr/0011-facebook-login-se-ne-implementira.md)).

**CI nije ništa potvrdio** — naplata na `htuco` nalogu blokira workflowove do 29.09.2026.
Sve gore je pokrenuto lokalno.
