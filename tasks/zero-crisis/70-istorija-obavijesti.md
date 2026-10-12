# Task 70 — Istorija obavijesti u klijentskoj app-i

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | — |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | task 21 · FE-306 · `notification_logs` |

## Cilj
Ekran „Obavijesti" danas je uvijek prazan. Klijent vidi push poruke koje je dobio (potvrda, odbijanje,
podsjetnik, lista čekanja) i otvara termin iz njih.

## Definicija gotovog
- [ ] RLS: klijent čita samo svoje redove iz `notification_logs` (ili pogled), negativan test
- [ ] Lista po datumu, tap otvara termin; oznaka nepročitanog
- [ ] Prazno stanje ostaje za korisnika bez obavijesti

## Status
Nije počet.
