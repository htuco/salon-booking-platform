#!/usr/bin/env bash
# Sve sto CI dokazuje, lokalno, u kontejnerima.
#
#   ./tool/test_all.sh
#
# 1. Dart/Flutter u kontejneru  → docker/Dockerfile.test
# 2. Supabase stack             → supabase CLI (i on je Docker)
#
# Ne gradi APK ni IPA — za to ide ./tool/build_tenant.sh na hostu.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon ne radi — pokreni Docker Desktop pa ponovo." >&2
  exit 1
fi

echo "════════ 1/2  Dart i Flutter (kontejner) ════════"
docker compose -f docker/compose.yaml run --rm --build tests

echo
echo "════════ 2/2  Supabase (pgTAP + REST izolacija) ════════"
./tool/test_supabase.sh

echo
echo "════════ Sve prolazi. ════════"
echo "Isto sto CI dokazuje, bez ijedne GitHub minute."
