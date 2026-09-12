#!/usr/bin/env bash
# Blokira commit ako git identitet nije na dozvoljenoj listi.
#
# Zasto postoji: commit 87f0aff je usao sa firmskim mailom (@symphony.is), jer je
# `git config user.email` na toj masini bio postavljen za posao. To se u istoriji
# ne moze "obrisati" — moze se samo prepisati, sto mijenja sve SHA-ove poslije.
# Repo je klijentski i planira se javno objaviti, pa firmska adresa u istoriji
# nije kozmetika nego trajna veza projekta sa poslodavcem.
#
# Zove ga lefthook na pre-commit. Rucno: ./tool/check_git_identity.sh
set -euo pipefail

# Dozvoljeni autori. Novi saradnik se dodaje ovdje, svjesno.
DOZVOLJENI=(
  "htuco04@gmail.com"
  "dajiceniz@gmail.com"
)
# Uz njih prolazi svaka GitHub noreply adresa (merge preko weba ih koristi).
NOREPLY_SUFIKS="users.noreply.github.com"

email="$(git config user.email || true)"

if [[ -z "$email" ]]; then
  echo "BLOKIRANO: git user.email nije postavljen." >&2
  echo "  git config user.email htuco04@gmail.com" >&2
  exit 1
fi

for ok in "${DOZVOLJENI[@]}"; do
  [[ "$email" == "$ok" ]] && exit 0
done
[[ "$email" == *"$NOREPLY_SUFIKS" ]] && exit 0

cat >&2 <<EOF
BLOKIRANO: nedozvoljena git adresa za ovaj repo.

  trenutno:  $email
  dozvoljeno: ${DOZVOLJENI[*]}, *@$NOREPLY_SUFIKS

Ovo je klijentski repo koji moze otici javno. Firmska adresa u commitu je
trajna — javni GitHub se zanje u arhive (GH Archive, Software Heritage) koje
vracanje repoa na private ne dotice.

Popravi za ovaj repo (ne globalno):
  git config user.email htuco04@gmail.com
  git config user.name  hamzatuco

Ako je adresa stvarno u redu, dodaj je u DOZVOLJENI u tool/check_git_identity.sh.
EOF
exit 1
