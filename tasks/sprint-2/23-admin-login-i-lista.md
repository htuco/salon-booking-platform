# Task 23 — Admin: login, dashboard i lista termina

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [12](12-auth-provideri.md), [14](14-identitet-i-klijent-upsert.md) |
| **Blokira** | 24, 25 |
| **Reference** | [01 §12](../../docs/01-mvp-spec.md#12-screens) · [`.claude/docs/security.md`](../../.claude/docs/security.md) |

## Cilj
`apps/admin` prestaje biti skelet. Vlasnik salona vidi šta mu je zakazano — to je druga polovina
proizvoda i do sada ne postoji.

## Definicija gotovog
- [ ] Login za osoblje (email + lozinka ili OTP), odvojen od klijentskog flowa
- [ ] `app_metadata.role = salon_admin` **i** red u `public.users` sa istim `salon_id` — oba uslova,
      kako `security.md` traži
- [ ] Dashboard: današnji termini, broj `pending` zahtjeva
- [ ] Lista termina sa filterom po danu i statusu
- [ ] Admin **ne bira salon iz UI-ja** — dobija ga iz svog `users` reda
- [ ] Deno test: admin salona A ne čita termine salona B

## Koraci
1. Auth i `users` provjera prije ijednog ekrana
2. Lista pa dashboard — dashboard je sažetak liste, ne obrnuto
3. Commit: `feat(admin): login i lista termina`

## Zamke
- **`x-salon-id` u adminu nije izvor istine.** Header bira kontekst; članstvo dolazi iz `users`
  reda. Admin koji pošalje tuđi header mora dobiti prazan rezultat.
- `apps/admin` je **generička** app, bez flavora — jedan build za sve salone.
