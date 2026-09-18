# Task 32 — Usluge i cjenovnik (CRUD)

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [29](29-responsive-shell.md) |
| **Blokira** | — |
| **Reference** | `SPEC.md` prikazi `3f` `3p` `3q` · [01 §17 korak 25](../../docs/01-mvp-spec.md) · [`security.md`](../../.claude/docs/security.md) |

## Cilj
Salon sam mijenja svoj cjenovnik. Danas usluge postoje samo u seedu i mijenjaju se `psql`-om.

## Definicija gotovog
- [ ] `/services` po `3f`, mobilna lista `3p`, unos i izmjena kao bottom sheet `3q`
- [ ] Kreiranje, izmjena i deaktivacija idu **kroz RPC**, ne direktnim `insert`/`update`
- [ ] Grantovi: `authenticated` nema `insert`/`update` nad `services` — isto kao što od taska 24
      nema nad `appointments`
- [ ] Usluga se **ne briše** dok ima termine; deaktivira se
- [ ] pgTAP: admin salona A ne može ni pročitati ni promijeniti uslugu salona B
- [ ] Trajanje i cijena mijenjaju buduću dostupnost, a ne već zakazane termine
- [ ] `security.md` i `supabase/IMPLEMENTATION.md` ažurirani u istoj promjeni

## Koraci
1. Migracija + `private.*` provjera + pgTAP **prije ekrana** (isti red kao task 24)
2. Ugovor u `core_api`, pa ekran
3. Commit: `feat(admin): crud nad uslugama i cjenovnikom`

## Zamke
- **Grant je jači od konvencije.** Task 24 je pokazao da rupu zatvara `revoke`, a ne dodavanje
  funkcija: dok grant stoji, validirane funkcije su konvencija koju je dovoljno zaboraviti.
- **`create or replace` sa novim parametrom pravi preopterećenje, ne zamjenu.** Obje verzije ostanu
  u bazi sa grantom, i stari poziv tiho ode na staru funkciju. Provjeri `pg_proc` upitom.
- **`revoke ... from public` ne skida `execute`** — Supabase ga daje `anon`-u direktno kroz
  `pg_default_acl` (task 14).
- Cijena je novac: ne `double`. Prati tip koji šema već koristi.

## Status

Nije počet.
