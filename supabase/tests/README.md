# Backend testovi

pgTAP testovi (RLS/tenant izolacija) i Deno skripte koje hitaju REST API
sa različitim JWT-ovima. V. [docs/07-tech-architecture.md §5.3](../../docs/07-tech-architecture.md#53-testiranje-rls-a).

Prvi testovi se pišu u [task 02](../../tasks/sprint-0/02-supabase-schema-rls.md), uz
init_schema migraciju — RLS i test izolacije idu u istom PR-u, ne odvojeno.

## Šta koji fajl dokazuje

| Fajl | Nivo | Dokazuje |
|---|---|---|
| `001_tenant_isolation.test.sql` | pgTAP | šema, RLS politike, `private.*` helperi — u rollback transakciji |
| `002_availability.test.sql` | pgTAP | `get_available_slots`, `get_available_dates`, `book_appointment`, exclusion constraint (task 05) |
| `017_bez_guest_zakazivanja.test.sql` | pgTAP | guest flag je uklonjen; anonimna Auth sesija ne može napraviti klijenta ni termin (task 41) |
| `011_service_crud.test.sql` | pgTAP | RPC upisi usluga, oduzeti direktni grantovi, tenant granica neaktivnih redova, deaktivacija i snapshot cijene/trajanja (task 32) |
| `012_employee_crud.test.sql` | pgTAP | atomski CRUD radnika/usluga, grantovi, tenant granica, nullable staž i očuvanje termina (task 33) |
| `rest_employee_crud.ts` | REST, admin A/B i klijent | novi katalog, RPC autorizacija i originalno ime na klijentovom terminu nakon deaktivacije |
| `rest_isolation.ts` | REST, dva stvarna JWT-a | prijavljeni klijent ne vidi tuđi salon; `x-salon-id` ne daje prava |
| `rest_public_catalog.ts` | REST, **bez korisničkog tokena** | javni katalog je čitljiv prije prijave, sa kolonama koje `core_api` repozitoriji stvarno traže; `appointments` nije; neaktivan salon nestaje |

`rest_public_catalog.ts` je dokaz za task 08 i zato je `packages/core_api/**` u okidačima
workflowa: liste kolona u njemu su kopija onih iz repozitorija, pa preimenovana kolona pada
ovdje, a ne u objavljenoj aplikaciji.
