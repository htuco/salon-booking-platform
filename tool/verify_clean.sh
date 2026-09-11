#!/usr/bin/env bash
# Dokaz iz CISTOG CHECKOUTA, lokalno — ono jedino sto CI daje a obicno lokalno
# pokretanje ne moze.
#
# Klonira repo u temp folder, pa tamo pokrene bootstrap, codegen, analizu i
# testove. Klon nosi SAMO commitovane fajlove, pa hvata:
#   - fajl koji si zaboravio commitovati, a lokalno postoji
#   - codegen koji nije ozicen kako treba (*.g.dart i *.freezed.dart su u
#     .gitignore, lokalno ih imas, na praznom klonu ih nema)
#   - drift generisanih flavora (tenants.g.dart naspram tenants/*.yaml)
# Tacno taj razred greske je bio commit e628237.
#
#   ./tool/verify_clean.sh              # bootstrap + codegen + gen --check + analyze + test
#   ./tool/verify_clean.sh --with-apk   # plus APK za oba tenanta (sporo, ~15 min)
#
# Ne dira tvoj radni folder. Klon se brise na izlazu.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
WITH_APK=0
[[ "${1:-}" == "--with-apk" ]] && WITH_APK=1

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
  echo "UPOZORENJE: imas necommitovanih izmjena. Klon ih NECE vidjeti —"
  echo "to je i poenta, ali znaci da ne dokazujes ono sto trenutno gledas."
  echo
fi

WORK="$(mktemp -d)/clean"
cleanup() { rm -rf "$(dirname "$WORK")"; }
trap cleanup EXIT

echo "==> kloniram '$REF' u cist folder"
git clone --quiet --depth 1 --branch "$REF" "file://$REPO_ROOT" "$WORK"
cd "$WORK"

# MORA `flutter pub get`, ne `dart pub get`: apps/client ima `generate: true` uz
# l10n.yaml, pa tek flutter varijanta stvori lib/src/l10n/generated/. Taj folder je
# u .gitignore, dakle na cistom klonu ga nema — sa `dart pub get` analiza padne na
# deset "Undefined name 'AppLocalizations'" gresaka koje ne postoje u repou.
# Isto radi i CI. Ne koristi `melos bootstrap`: paralelni resolve-ovi na cistom
# klonu znaju pasti na "Bad state: Attempting to send request on closed client".
echo "==> flutter pub get (workspace resolve + gen-l10n)"
flutter pub get

echo "==> codegen (na praznom klonu nema nijednog *.g.dart)"
dart run melos run codegen

echo "==> gen_flavors --check (drift generisanog registra)"
dart run tool/gen_flavors.dart --check

echo "==> analyze"
dart run melos run analyze

echo "==> test"
dart run melos run test

if [[ $WITH_APK -eq 1 ]]; then
  echo "==> APK za oba tenanta"
  for flavor in barberstudiovitez beautystudiotravnik; do
    echo "--- $flavor"
    ./tool/build_tenant.sh "$flavor" apk debug
  done
fi

echo
echo "Cist checkout prolazi. Ovo je dokaz koji je ranije davao CI job 'analyze'."
