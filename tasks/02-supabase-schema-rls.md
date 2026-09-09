# Task 02 — Supabase šema + RLS + policy testovi

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [01 — repo skeleton](01-repo-skeleton.md) |
| **Blokira** | [03 — flavor sistem](03-flavor-system.md) (treba `salonId` da postoji), [05 — availability engine](05-availability-engine.md) |
| **Reference** | [01 §11](../docs/01-mvp-spec.md#11-database-entities) · [06 §4](../docs/06-auth-login-flow.md) · [07 §5](../docs/07-tech-architecture.md#5-supabase--struktura-i-konvencije) |

## Cilj
Prva migracija sa punom MVP šemom, RLS policy po `salon_id` na svakoj tenant-scoped tabeli, i **dokaz da izolacija stvarno radi** — ne pretpostavka, test.

## Definicija gotovog
- [x] Migracija `supabase/migrations/<timestamp>_init_schema.sql` sadrži sve tabele iz [01 §11](../docs/01-mvp-spec.md#11-database-entities): `Salon`, `SalonBuild`, `VerticalPack`, `User`, `Service`, `Employee`, `EmployeeService`, `WorkingHour`, `AuthIdentity`, `Customer`, `Device`, `Appointment`, `BlockedSlot`, `NotificationLog`, `SalonSettings`
- [x] Svaka tenant-scoped tabela ima RLS uključen i policy koji filtrira po `salon_id` iz JWT claima
- [x] `anon` rola može **SELECT** `services`/`employees`/availability samo za salone sa `status = 'active'`, i **ne može pisati ništa** — javni pregled bez logina ([06 §1.1](../docs/06-auth-login-flow.md))
- [x] `AuthIdentity` je globalna tabela (nije `salon_id`-scoped), `Customer` je strogo per-salon — provjereno testom, ne samo dokumentacijom ([06 §4.3](../docs/06-auth-login-flow.md))
- [x] `seed.sql` kreira dva demo salona (Barber Studio Vitez, Beauty Studio Travnik iz [01 §14](../docs/01-mvp-spec.md#14-demo-saloni)) sa uslugama, radnicima i radnim vremenom
- [x] `supabase/tests/` sadrži pgTAP test: "korisnik salona A ne može SELECT/UPDATE/DELETE nad `appointments` salona B"
- [x] `supabase/tests/` sadrži Deno skriptu koja hita REST API sa dva različita JWT-a (dva različita `AuthIdentity`) i asertuje da klijent prijavljen u salon A ne vidi svoje podatke iz salona B — [06 §4.4](../docs/06-auth-login-flow.md)
- [x] Svi testovi prolaze lokalno (`supabase test db`) i CI korak koji ih pokreće na svaki PR koji dira `supabase/migrations/`

## Koraci
1. `supabase migration new init_schema`, prepiši šemu iz [01 §11](../docs/01-mvp-spec.md#11-database-entities) u SQL (tipovi, foreign key-evi, enum-i za `status`/`source`/`role`)
2. Uključi RLS na svakoj tabeli (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`), napiši policy-je — odvoji `anon`, `authenticated` i `service_role` slučajeve
3. Napiši `seed.sql` sa dva demo salona ([01 §14](../docs/01-mvp-spec.md#14-demo-saloni))
4. `supabase db reset` lokalno, provjeri da migracija + seed prolaze čisto
5. Instaliraj pgTAP (`create extension pgtap`), napiši prvi test izolacije
6. Napiši Deno skriptu za REST-level test sa dva JWT-a (koristi `supabase.auth.admin.generateLink` ili ručno kreirane test korisnike)
7. Dodaj CI korak (GH Actions) koji pokreće `supabase test db` na svaki PR koji dira `supabase/migrations/**`
8. Commit: "feat(db): init schema + RLS + tenant isolation tests"

## Zašto ovo prije UI-ja
Tenant izolacija je poslovni rizik, ne tehnički detalj — [06 §4.3](../docs/06-auth-login-flow.md) eksplicitno upozorava da "salon otkrije da mu vidiš klijentelu kod konkurencije" ubija povjerenje trenutno i nepovratno. Test mora postojati prije prvog pravog korisnika, ne poslije prve žalbe.

## Status — verifikovan 2026-09-10

Zeleno na CI-ju: [run 34417077084](https://github.com/htuco/salon-booking-platform/actions/runs/34417077084), PR #2.

```
supabase test db  →  Files=1, Tests=38, Result: PASS
rest_isolation.ts →  REST tenant isolation passed: 24 assertions, two real JWTs.
```

Migracije + seed se primjenjuju čisto na praznu bazu (`supabase start` u workflowu),
38 pgTAP asercija i 24 REST asercije prolaze protiv žive Postgres/PostgREST/GoTrue
instance. Šema više nije nacrt — task 03 i 05 se mogu osloniti na nju.

Workflow [`.github/workflows/supabase-tests.yml`](../.github/workflows/supabase-tests.yml)
ponavlja isti dokaz na svaki PR koji dira `supabase/migrations/**`, `seed.sql`,
`tests/**` ili `config.toml`, pa regresija u izolaciji pada na PR-u, ne u produkciji.

Napomena za lokalni rad: na razvojnoj mašini nema Docker daemona, pa se `supabase start`
ne može pokrenuti lokalno. Dok se Docker Desktop ne instalira, CI je jedini način da se
promjene u šemi dokažu — ne mergaj `supabase/` promjene bez zelenog run-a.
