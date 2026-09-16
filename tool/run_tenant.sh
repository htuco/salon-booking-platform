#!/usr/bin/env bash
# Jedna komanda do pokrenute app-e jednog tenanta u simulatoru.
#
#   tool/run_tenant.sh vitez              # barberstudiovitez, pravi backend ako radi
#   tool/run_tenant.sh travnik            # beautystudiotravnik
#   tool/run_tenant.sh vitez demo         # lib/demo_main.dart — ekran bez backenda
#   tool/run_tenant.sh vitez -d chrome    # sve iza flavora ide ravno flutteru
#
# Sestra od build_tenant.sh, i iz istog razloga: `flutter run` ovdje nikad nije gola
# komanda. Bez --flavor iOS build uzme podrazumijevanu konfiguraciju (pogresan bundle ID
# i ime), a **bez --dart-define=SALON_ID app pada na startu** u AppEnv.fromDefines().
# Oboje se cita iz tenants/<flavor>/tenant.yaml, pa se UUID ne prepisuje iz glave —
# demo tenanti se razlikuju u zadnjoj cifri i pogresan izgleda ispravno dok se ne
# pogleda ime salona u zaglavlju.
#
# Backend: eksplicitni `SUPABASE_URL`/`SUPABASE_ANON_KEY` imaju prednost (hostovani demo).
# Bez njih skripta koristi lokalni Supabase ako radi. Ako nema nijednog, app se digne bez
# klijenta i ekrani ostanu na kosturu. Za vizuelnu provjeru postoji `demo`.
#
# Sta se NIKAD ne uzima iz `supabase status -o env`: SERVICE_ROLE_KEY i SECRET_KEY.
# Service role kljuc zaobilazi RLS u potpunosti i ne smije postojati u klijentskom buildu.
set -euo pipefail

usage() {
  echo "Upotreba: tool/run_tenant.sh <nadimak|flavor> [demo] [dodatni flutter argumenti]" >&2
  exit 2
}

arg="${1:-}"
[ -n "$arg" ] || usage
shift

root="$(cd "$(dirname "$0")/.." && pwd)"

tenanti() {
  find "$root/tenants" -mindepth 1 -maxdepth 1 -type d ! -name '_*' -exec basename {} \; | sort
}

# Nadimak se razrjesava iz repoa, ne iz tabele u ovoj skripti: tenant koji se doda sutra
# mora raditi bez izmjene ovog fajla. Tacan pogodak pobjedjuje podstring, da flavor koji
# je prefiks drugog ne postane dvosmislen.
if [ -d "$root/tenants/$arg" ]; then
  flavor="$arg"
else
  pogoci="$(tenanti | grep -i -- "$arg" || true)"
  broj="$(printf '%s' "$pogoci" | grep -c . || true)"
  if [ "$broj" -eq 0 ]; then
    echo "Nema tenanta koji odgovara '$arg'. Postojeci: $(tenanti | tr '\n' ' ')" >&2
    exit 1
  elif [ "$broj" -gt 1 ]; then
    echo "'$arg' odgovara vise tenanata: $(printf '%s' "$pogoci" | tr '\n' ' ')" >&2
    exit 1
  fi
  flavor="$pogoci"
fi

yaml="$root/tenants/$flavor/tenant.yaml"
citaj() {
  sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$yaml" | head -1 | tr -d "\"'" | sed 's/[[:space:]]*#.*$//'
}
salon_id="$(citaj salonId)"
[ -n "$salon_id" ] || { echo "tenant.yaml nema salonId" >&2; exit 1; }

# `demo` je prvi opcioni argument; sve ostalo ide ravno flutteru (-d, --profile, ...).
entry=(lib/main.dart)
nacin="main"
if [ "${1:-}" = "demo" ]; then
  entry=(lib/demo_main.dart)
  nacin="demo"
  shift
fi

# Verzija se cita iz tenant.yaml, kao u build_tenant.sh. Bez ovoga `flutter run` uzme
# `version:` iz apps/client/pubspec.yaml (1.0.0+1), pa ekran „O aplikaciji" u razvoju
# pokazuje drugi broj nego store build — a to je jedini ekran koji verziju i prikazuje.
version_name="$(citaj versionName)"
ios_build="$(citaj iosBuildNumber)"

# Android emulator host vidi kroz 10.0.2.2; 127.0.0.1 bi pokazao na sam emulator.
flutter_device=""
previous_arg=""
for current_arg in "$@"; do
  if [ "$previous_arg" = "-d" ] || [ "$previous_arg" = "--device-id" ]; then
    flutter_device="$current_arg"
    break
  fi
  case "$current_arg" in
    --device=*) flutter_device="${current_arg#--device=}"; break ;;
  esac
  previous_arg="$current_arg"
done

defines=(--dart-define="SALON_ID=$salon_id")
backend="bez backenda (ekrani ostaju na kosturu)"

# Samo za pravi entry point: demo_main.dart puni providere sam i Supabase mu ne treba.
if [ "$nacin" = "main" ]; then
  if { [ -n "${SUPABASE_URL:-}" ] && [ -z "${SUPABASE_ANON_KEY:-}" ]; } ||
     { [ -z "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_ANON_KEY:-}" ]; }; then
    echo "SUPABASE_URL i SUPABASE_ANON_KEY moraju biti postavljeni zajedno" >&2
    exit 1
  fi

  if [ -n "${SUPABASE_URL:-}" ]; then
    defines+=(
      --dart-define="SUPABASE_URL=$SUPABASE_URL"
      --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
    )
    backend="hostovani Supabase ($SUPABASE_URL)"
  elif command -v supabase >/dev/null 2>&1; then
  # Podljuska, da se SERVICE_ROLE_KEY i SECRET_KEY ne zadrze u okolini koju nasljedjuje
  # flutter proces. Izlaz `supabase status -o env` nosi oba.
    supabase_env="$(
      cd "$root" && supabase status -o env 2>/dev/null | grep -E '^(API_URL|ANON_KEY)=' || true
    )"
    if [ -n "$supabase_env" ]; then
      api_url="$(printf '%s\n' "$supabase_env" | sed -n 's/^API_URL="\{0,1\}//p' | tr -d '"')"
      anon_key="$(printf '%s\n' "$supabase_env" | sed -n 's/^ANON_KEY="\{0,1\}//p' | tr -d '"')"
      if [ -n "$api_url" ] && [ -n "$anon_key" ]; then
        if [[ "$flutter_device" == emulator-* ]]; then
          api_url="${api_url/127.0.0.1/10.0.2.2}"
          api_url="${api_url/localhost/10.0.2.2}"
        fi
        defines+=(--dart-define="SUPABASE_URL=$api_url" --dart-define="SUPABASE_ANON_KEY=$anon_key")
        backend="lokalni Supabase ($api_url)"
      fi
    fi
  fi

  if [ -n "${FIREBASE_DEFINES_FILE:-}" ]; then
    [ -f "$FIREBASE_DEFINES_FILE" ] || {
      echo "FIREBASE_DEFINES_FILE ne postoji: $FIREBASE_DEFINES_FILE" >&2
      exit 1
    }
    defines+=(--dart-define-from-file="$FIREBASE_DEFINES_FILE")
  fi
  [ -n "${GOOGLE_WEB_CLIENT_ID:-}" ] &&
    defines+=(--dart-define="GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID")
  [ -n "${GOOGLE_IOS_CLIENT_ID:-}" ] &&
    defines+=(--dart-define="GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID")
fi

# Simulator: bez pokrenutog uredjaja `flutter run` ili pita, ili padne na desktop target.
# Dize se samo na macOS-u i samo ako nijedan vec ne radi; izbor konkretnog uredjaja
# ostaje korisniku kroz `-d`.
if [ "$(uname -s)" = "Darwin" ] && [ $# -eq 0 ]; then
  if ! xcrun simctl list devices booted 2>/dev/null | grep -q Booted; then
    echo "-> nijedan iOS simulator ne radi, dizem Simulator.app"
    open -a Simulator || true
    for _ in $(seq 1 30); do
      xcrun simctl list devices booted 2>/dev/null | grep -q Booted && break
      sleep 1
    done
  fi
fi

echo "== $flavor ($nacin)"
echo "   salonId  $salon_id"
echo "   verzija  $version_name ($ios_build)"
echo "   backend  $backend"

cd "$root/apps/client"
# `flutter run` sam pokrece gen-l10n, ali ne i build_runner: freezed/json_serializable
# izlaz nije u gitu, pa na svjezem klonu prvi run pada na `part 'x.freezed.dart'`.
if [ ! -f "$root/packages/core_domain/lib/src/catalog/salon.freezed.dart" ]; then
  echo "-> generisem freezed/json_serializable kod (prvi put)"
  (cd "$root" && dart run melos exec --depends-on=build_runner -- dart run build_runner build >/dev/null)
fi

exec flutter run -t "${entry[@]}" --flavor "$flavor" \
  --build-name "$version_name" --build-number "$ios_build" \
  "${defines[@]}" "$@"
