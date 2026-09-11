#!/usr/bin/env bash
# Entrypoint testnog kontejnera. Isti lanac koji CI job `analyze` pokrece.
set -euo pipefail
cd /repo

echo "==> codegen (freezed / json_serializable)"
dart run melos run codegen

echo "==> gen_flavors --check (drift generisanog registra)"
dart run tool/gen_flavors.dart --check

echo "==> format"
dart format --set-exit-if-changed --output=none $(git ls-files '*.dart')

echo "==> analyze"
dart run melos run analyze

echo "==> test"
dart run melos run test

echo
echo "Kontejner prolazi. Codegen je isao od nule, kao na praznom klonu."
