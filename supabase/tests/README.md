# Backend testovi

pgTAP testovi (RLS/tenant izolacija) i Deno skripte koje hitaju REST API
sa različitim JWT-ovima. V. [docs/07-tech-architecture.md §5.3](../../docs/07-tech-architecture.md#53-testiranje-rls-a).

Prvi testovi se pišu u [task 02](../../tasks/02-supabase-schema-rls.md), uz
init_schema migraciju — RLS i test izolacije idu u istom PR-u, ne odvojeno.
