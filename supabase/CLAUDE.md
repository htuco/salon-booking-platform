# supabase/ — Postgres, RLS, Edge Functions

Migracije su izvor istine za šemu. Root pravila važe — v. `../CLAUDE.md`.

**Prije nego napišeš ijedan red SQL-a pročitaj `../.claude/docs/security.md`.** Ovo je jedini dio
sistema gdje greška ne pravi bug nego curi tuđe podatke.

## Pravila koja se ovdje ne pregovaraju

- **Svaki red pripada salonu, i svaka putanja do njega mora to dokazati.** Nema "dohvati pa
  filtriraj u aplikaciji" — RLS je jedina odbrana koja stvarno stoji.
- **Nova tabela treba `salon_id`, `enable row level security`, eksplicitan `grant`, politiku i
  negativan test.** Migracija prvo sve oduzme (`revoke all from anon, authenticated`), pa vraća
  taksativno — tabela bez granta je nevidljiva, tabela bez politike je rupa.
- **Autorizacija ide kroz `private.*` helpere**, politika ih zove umjesto da prepisuje uslov.
  Svaka `security definer` funkcija ima `set search_path = ''` i potpuno kvalifikovane reference.
- **`x-salon-id` bira kontekst, ne daje prava** ([ADR-0003](../docs/adr/0003-x-salon-id-bira-kontekst-ne-daje-prava.md)).
  Klijentska politika traži i `private.client_salon_id()` **i** `private.owns_identity(...)`.
- **Uloga iz JWT-a sama po sebi ne znači ništa** — traži se i red u `public.users`.
- **Deployana migracija se ne mijenja.** Nova promjena je nova migracija
  (`supabase migration new <opis>`).

## Kako se ovdje dokazuje

Lokalno, prije commita:

```bash
supabase start
supabase test db                                        # pgTAP
eval "$(supabase status -o env)"
deno run --allow-env --allow-net tests/rest_isolation.ts        # dva stvarna JWT-a
deno run --allow-env --allow-net tests/rest_public_catalog.ts   # bez tokena
```

Dok ta suite nije prošla, u sažetku piše "napisano, nije pokrenuto", ne "radi".

CI workflow `Supabase tests` pokriva isto, ali **samo na push u `main`**, i dodaje jedino što
lokalno ne možeš: čist checkout. Izlaz `supabase status -o env` sadrži service role ključ —
nikad u commit ni u sažetak.

**pgTAP test koji ne pada kad se politika ukloni ne testira ništa.** Piši negativan slučaj.

## Detalji

`../.claude/docs/security.md` (autorizacija, grantovi, otvorene rupe) ·
`../.claude/docs/workflows.md` (komande) · `IMPLEMENTATION.md` (ugovori šeme i pretpostavke)
