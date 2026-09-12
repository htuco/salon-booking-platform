#!/usr/bin/env bash
# Jedna komanda do artefakta za jednog tenanta — docs/04 §7.1, task 04.
#
#   tool/build_tenant.sh <flavor> <apk|aab|ios> [debug|release]
#
# Sve sto build treba cita se iz tenants/<flavor>/tenant.yaml, pa se komanda ne
# mijenja kad se doda polje. Ovo je referenca za CI: CI poziva ovu skriptu, ne
# svoju kopiju flutter komande — inace lokalni i CI build tiho odlutaju.
#
# Okolina koju skripta postuje (sve opciono):
#   BUILD_NUMBER   nadjacava androidVersionCode/iosBuildNumber iz tenant.yaml.
#                  CI ga postavlja na monotoni broj; lokalno se ne dira.
#   API_URL        prosljedjuje se kao --dart-define, ako je postavljen.
#   SUPABASE_URL, SUPABASE_ANON_KEY   isto. Nikad se ne commituju.
#   GOOGLE_WEB_CLIENT_ID, GOOGLE_IOS_CLIENT_ID   Google Sign-In, task 12.
#                  Client ID je PO FLAVORU, ne po projektu (docs/06 §7.1): jedan
#                  zajednicki ID znaci da korisnik u Google dijalogu vidi tude ime
#                  salona. Skripta prvo trazi <IME>_<FLAVOR>, pa tek onda <IME>:
#                  GOOGLE_WEB_CLIENT_ID_BARBERSTUDIOVITEZ nadjacava GOOGLE_WEB_CLIENT_ID.
#                  Ne commituju se; u CI-ju idu kroz GitHub `vars` (client ID nije tajna,
#                  ali se mijenja po tenantu i okruzenju).
set -euo pipefail

usage() { echo "Upotreba: tool/build_tenant.sh <flavor> <apk|aab|ios> [debug|release]" >&2; exit 2; }

flavor="${1:-}"; target="${2:-}"; mode="${3:-release}"
[ -n "$flavor" ] && [ -n "$target" ] || usage

root="$(cd "$(dirname "$0")/.." && pwd)"
yaml="$root/tenants/$flavor/tenant.yaml"

if [ ! -f "$yaml" ]; then
  known="$(find "$root/tenants" -mindepth 1 -maxdepth 1 -type d ! -name '_*' -exec basename {} \; | sort | tr '\n' ' ')"
  echo "Nema $yaml. Postojeci tenanti: $known" >&2
  exit 1
fi

# Plitko citanje YAML-a: vrijednosti su skalari na fiksnim kljucevima, pa grep
# radi. Da tenant.yaml ikad dobije ugnijezdene liste, ovo ide u dart alat.
read_key() {
  local key="$1"
  sed -n "s/^[[:space:]]*${key}:[[:space:]]*//p" "$yaml" | head -1 | tr -d '"' | tr -d "'" | sed 's/[[:space:]]*#.*$//'
}

salon_id="$(read_key salonId)"
version_name="$(read_key versionName)"
android_code="$(read_key androidVersionCode)"
ios_build="$(read_key iosBuildNumber)"
ios_enabled="$(sed -n '/^targets:/,$p' "$yaml" | sed -n 's/^[[:space:]]*ios:[[:space:]]*//p' | head -1)"
android_enabled="$(sed -n '/^targets:/,$p' "$yaml" | sed -n 's/^[[:space:]]*android:[[:space:]]*//p' | head -1)"

[ -n "$salon_id" ] || { echo "tenant.yaml nema salonId" >&2; exit 1; }

case "$mode" in debug|release|profile) ;; *) usage ;; esac

defines=(--dart-define="SALON_ID=$salon_id")
[ -n "${API_URL:-}" ]           && defines+=(--dart-define="API_URL=$API_URL")
[ -n "${SUPABASE_URL:-}" ]      && defines+=(--dart-define="SUPABASE_URL=$SUPABASE_URL")
[ -n "${SUPABASE_ANON_KEY:-}" ] && defines+=(--dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY")

# Vrijednost po flavoru, sa padom na zajednicku: <IME>_<FLAVOR> pa <IME>.
flavor_upper="$(echo "$flavor" | tr '[:lower:]' '[:upper:]')"
po_flavoru() {
  local ime="$1" po_tenantu="$1_$flavor_upper"
  echo "${!po_tenantu:-${!ime:-}}"
}

for ime in GOOGLE_WEB_CLIENT_ID GOOGLE_IOS_CLIENT_ID; do
  vrijednost="$(po_flavoru "$ime")"
  [ -n "$vrijednost" ] && defines+=(--dart-define="$ime=$vrijednost")
done

echo "== $flavor / $target / $mode"
echo "   salonId      $salon_id"
echo "   versionName  $version_name"
# Ispisuje se da li je ID stigao i odakle, ali nikad sama vrijednost — build log je
# artefakt koji se cuva i cita.
for ime in GOOGLE_WEB_CLIENT_ID GOOGLE_IOS_CLIENT_ID; do
  po_tenantu="${ime}_$flavor_upper"
  if [ -n "${!po_tenantu:-}" ]; then
    echo "   ${ime}  postavljen (iz ${po_tenantu})"
  elif [ -n "${!ime:-}" ]; then
    echo "   ${ime}  postavljen (zajednicki — provjeri da je tacan za $flavor)"
  else
    echo "   ${ime}  NIJE postavljen — Google prijava nece raditi u ovom buildu"
  fi
done

# Generisani kod (freezed/json_serializable) nije u gitu — nastaje determinsticki iz
# anotacija. Bez ovoga `flutter build` pada na `part 'x.freezed.dart': No such file or
# directory` na svakom svjezem klonu. Build je jedina ulazna tacka, pa se generise ovdje,
# a ne u svakom pozivaocu posebno.
echo "-> generisem freezed/json_serializable kod"
(cd "$root" && dart run melos exec --depends-on=build_runner -- dart run build_runner build >/dev/null)

cd "$root/apps/client"

case "$target" in
  apk|aab)
    [ "$android_enabled" = "true" ] || { echo "targets.android nije true za $flavor" >&2; exit 1; }
    build_number="${BUILD_NUMBER:-$android_code}"
    echo "   versionCode  $build_number${BUILD_NUMBER:+ (iz BUILD_NUMBER)}"
    # versionCode se prosljedjuje i kao Gradle property: generisani flavor blok
    # nadjacava flutter.versionCode, pa --build-number sam ne bi stigao do APK-a.
    cmd=(flutter build)
    [ "$target" = "apk" ] && cmd+=(apk) || cmd+=(appbundle)
    "${cmd[@]}" "--$mode" \
      --flavor "$flavor" \
      --build-name "$version_name" \
      --build-number "$build_number" \
      "${defines[@]}" \
      -PtenantVersionCode="$build_number" \
      -PtenantVersionName="$version_name"
    ;;
  ios)
    [ "$ios_enabled" = "true" ] || { echo "targets.ios nije true za $flavor" >&2; exit 1; }
    [ "$(uname -s)" = "Darwin" ] || { echo "iOS build trazi macOS" >&2; exit 1; }
    build_number="${BUILD_NUMBER:-$ios_build}"
    echo "   buildNumber  $build_number${BUILD_NUMBER:+ (iz BUILD_NUMBER)}"
    flutter build ios "--$mode" --no-codesign \
      --flavor "$flavor" \
      --build-name "$version_name" \
      --build-number "$build_number" \
      "${defines[@]}"
    ;;
  *) usage ;;
esac

# Artefakt se ispisuje da ga CI (i covjek) ne mora traziti po build stablu.
case "$target" in
  apk) find build/app/outputs/flutter-apk -name "*${flavor}*.apk" -print ;;
  aab) find build/app/outputs/bundle -name "*.aab" -print ;;
  ios) ls -d build/ios/iphoneos/*.app 2>/dev/null || true ;;
esac
