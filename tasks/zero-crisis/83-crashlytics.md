# Task 83 — Firebase Crashlytics

| | |
|---|---|
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | [79](79-firebase-produkcija.md) |
| **Blokira** | [87](87-sigurnosni-pregled.md), [89](89-prelazak-na-produkciju.md), [90](90-release-i-store.md) |
| **Reference** | ADR-0029 · `docs/07` §7 (Sentry više ne važi) |

## Cilj
Rušenje na tuđem telefonu se vidi prije nego se salon požali.

## Definicija gotovog
- [ ] `firebase_crashlytics` u klijentu i adminu; `FlutterError` i zone greške idu u Crashlytics
- [ ] iOS dSYM upload u build koraku; Android mapping fajl
- [ ] Bez ličnih podataka u izvještajima (bez emaila, imena, telefona)
- [ ] Probno rušenje vidljivo u Firebase konzoli, za klijent i admin
- [ ] Privatnost i Data safety ažurirani

## Status
Nije počet.
