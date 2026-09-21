#!/usr/bin/env bash
# Puna Supabase suite lokalno: pgTAP + cetiri Deno REST testa.
# Isto sto radi CI workflow `Supabase tests`, samo bez GitHub minuta i bez cekanja.
#
#   ./tool/test_supabase.sh            # reset baze pa svi testovi
#   ./tool/test_supabase.sh --no-reset # preskoci reset (baza je vec svjeza)
#
# Zavisnosti: Docker, `supabase` CLI, `deno`. Instalacija: brew install supabase/tap/supabase deno
set -euo pipefail
cd "$(dirname "$0")/.."

RESET=1
[[ "${1:-}" == "--no-reset" ]] && RESET=0

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon ne radi — pokreni Docker Desktop pa ponovo." >&2
  exit 1
fi

echo "==> supabase start"
supabase start >/dev/null

# `supabase start` nad postojecim volumeom dize bazu IZ BACKUPA i NE primjenjuje
# migracije — testovi tada padnu na "relation does not exist" i izgleda kao da je
# sema pokvarena. `db reset` je jedini nacin da se dokaze da migracije + seed
# stvarno prolaze od nule, sto je i ono sto CI radi na praznom runneru.
if [[ $RESET -eq 1 ]]; then
  echo "==> supabase db reset (migracije + seed od nule)"
  supabase db reset >/dev/null
fi

echo "==> pgTAP"
supabase test db

# Izlaz `supabase status -o env` sadrzi service role kljuc — ostaje u ovoj ljusci
# i nikad ne ide u commit ni u sazetak.
set -a; eval "$(supabase status -o env)"; set +a
export SUPABASE_URL="${API_URL:-http://127.0.0.1:54321}"
export SUPABASE_ANON_KEY="${ANON_KEY:-}"
export SUPABASE_SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY:-}"
[[ -n "$SUPABASE_ANON_KEY" ]] || { echo "ANON_KEY nedostaje iz supabase status" >&2; exit 1; }
[[ -n "$SUPABASE_SERVICE_ROLE_KEY" ]] || { echo "SERVICE_ROLE_KEY nedostaje iz supabase status" >&2; exit 1; }

echo "==> REST izolacija (dva stvarna JWT-a)"
deno run --allow-env --allow-net supabase/tests/rest_isolation.ts

echo "==> Javni katalog (bez tokena)"
deno run --allow-env --allow-net supabase/tests/rest_public_catalog.ts

echo "==> Upsert klijenta i rezervacija (stvaran JWT, stvaran 409)"
deno run --allow-env --allow-net supabase/tests/rest_customer_upsert.ts

echo "==> Izolacija izmedju salona (isti covjek, dva salona, tri JWT-a)"
deno run --allow-env --allow-net supabase/tests/rest_cross_salon_isolation.ts

echo "==> Brisanje naloga (Edge Function, oba salona)"
deno run --allow-env --allow-net supabase/tests/rest_delete_account.ts

echo "==> Admin prijava i izolacija (seed admini kroz GoTrue)"
deno run --allow-env --allow-net supabase/tests/rest_admin_login.ts
deno run --allow-env --allow-net supabase/tests/rest_employee_crud.ts

echo "==> Radno vrijeme i blokade mijenjaju ono sto klijent vidi"
deno run --allow-env --allow-net supabase/tests/rest_working_hours.ts

echo "==> Push registracija i izolacija"
deno run --allow-env --allow-net supabase/tests/rest_push_devices.ts
deno test supabase/functions/send-push/handler_test.ts

echo
echo "Sve prolazi. Stack ostaje dignut — 'supabase stop' kad zavrsis."
