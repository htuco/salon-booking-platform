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
- [ ] `auth_identities` red se kreira/ažurira pri prvoj prijavi
- [ ] `customers` upsert po `(salon_id, auth_identity_id)` kroz **`security definer` funkciju sa
      validacijom**, nikad `insert` sa klijenta ([`security.md`](../../.claude/docs/security.md),
      "Šta još nije zatvoreno")
- [ ] Isti Apple/Google nalog u dva salona daje **dva odvojena `customers` reda**
- [ ] `book_appointment` radi end-to-end sa pravim tokenom — **prvi stvarni upis iz aplikacije**
- [ ] **`409` izazvan uživo**: dva zahtjeva na isti slot, drugi dobije `ConflictError` i ekran
      osvježi listu (ostatak DoD-a iz taska 11)
- [ ] pgTAP: upsert je idempotentan; tuđi `auth_identity_id` vraća istu grešku kao nepostojeći

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
