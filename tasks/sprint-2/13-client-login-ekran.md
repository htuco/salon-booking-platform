# Task 13 — Client: login ekran na kraju booking flowa

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [12](12-auth-provideri.md), [11](../sprint-1/11-booking-flow.md) |
| **Blokira** | 14 (upsert traži token), 16, 17 |
| **Reference** | [06 §1.1](../../docs/06-auth-login-flow.md) · [06 §3](../../docs/06-auth-login-flow.md) · `prototype/ui/SPEC.md` 5f |

## Cilj
Korisnik koji je izabrao termin prijavi se **na zadnjem koraku** i zahtjev ode dalje — bez izlaska
iz flowa i bez gubitka izbora.

## Definicija gotovog
- [ ] `/auth/login` ima pravo tijelo; tri dugmeta sa koraka 4 vode na stvarnu prijavu
- [ ] **Nema polja za telefon** ([06 §3.1](../../docs/06-auth-login-flow.md))
- [ ] Email OTP: unos maila → 6 cifara → nazad u flow, **bez izlaska iz app-a**
- [ ] Nakon prijave korisnik se vraća **tačno na `/book/details`**, sa netaknutim izborom
- [ ] `bookingCustomerIdProvider` dobija pravu implementaciju; `book(...)` se poziva bez izmjene
      ijednog ekrana
- [ ] Greška prijave je stanje ekrana, ne `SnackBar` koji nestane
- [ ] Widget testovi: povratak u flow čuva izbor, otkazana prijava vraća na korak 4

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
