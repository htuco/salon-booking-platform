#!/usr/bin/env bash
# Pokreće Vitez klijent ili admin protiv hostovanog demo projekta. Vrijednosti čita iz
# ignorisanog `.env.live`; u child proces prosljeđuje samo javnu runtime konfiguraciju.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
config="$root/.env.live"
[ -f "$config" ] || {
  echo "Nedostaje $config. Kopiraj .env.example i popuni lokalne vrijednosti." >&2
  exit 1
}

# shellcheck disable=SC1090
source "$config"
: "${SUPABASE_URL:?Nedostaje SUPABASE_URL u .env.live}"
: "${SUPABASE_ANON_KEY:?Nedostaje SUPABASE_ANON_KEY u .env.live}"

# Prazan define fajl nije greška — rad protiv hostovanog projekta ne mora imati Firebase.
# Tišina jeste: bez njega `PUSH_ENABLED` ostaje `false`, `pushServiceProvider` vraća `null`,
# aplikacija nikad ne pozove `register_device`, i push izostaje bez ijedne poruke. Task 39 je
# na tome izgubio trag — u bazi nije bilo nijednog staff uređaja ni reda tipa `new_request`.
upozori_bez_pusha() {
  echo "UPOZORENJE: $1 je prazan — build ide bez PUSH_ENABLED." >&2
  echo "            Aplikacija neće registrovati uređaj, pa push neće stizati." >&2
  echo "            Postavljanje: .claude/docs/workflows.md, „Push provjere i konfiguracija\"." >&2
}

target="${1:-}"
[ -n "$target" ] || {
  echo "Upotreba: tool/run_live_demo.sh <client|admin> [flutter argumenti]" >&2
  exit 2
}
shift

case "$target" in
  client)
    firebase_file="${FIREBASE_CLIENT_DEFINES_FILE:-}"
    [ -n "$firebase_file" ] || upozori_bez_pusha FIREBASE_CLIENT_DEFINES_FILE
    SUPABASE_URL="$SUPABASE_URL" \
    SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    FIREBASE_DEFINES_FILE="$firebase_file" \
    GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID_BARBERSTUDIOVITEZ:-}" \
    GOOGLE_IOS_CLIENT_ID="${GOOGLE_IOS_CLIENT_ID_BARBERSTUDIOVITEZ:-}" \
      exec "$root/tool/run_tenant.sh" barberstudiovitez "$@"
    ;;
  admin)
    defines=(
      --dart-define="SUPABASE_URL=$SUPABASE_URL"
      --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
    )
    if [ -n "${FIREBASE_ADMIN_DEFINES_FILE:-}" ]; then
      [ -f "$FIREBASE_ADMIN_DEFINES_FILE" ] || {
        echo "FIREBASE_ADMIN_DEFINES_FILE ne postoji: $FIREBASE_ADMIN_DEFINES_FILE" >&2
        exit 1
      }
      defines+=(--dart-define-from-file="$FIREBASE_ADMIN_DEFINES_FILE")
    else
      upozori_bez_pusha FIREBASE_ADMIN_DEFINES_FILE
    fi
    cd "$root/apps/admin"
    exec flutter run "${defines[@]}" "$@"
    ;;
  *)
    echo "Nepoznat target '$target'. Koristi client ili admin." >&2
    exit 2
    ;;
esac
