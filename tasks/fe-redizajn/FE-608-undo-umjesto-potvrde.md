# FE-608 — Undo toast umjesto dijaloga potvrde

| | |
|---|---|
| **Epik** | FE-6 · Admin kao radni alat |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 1–2 dana (+ ADR) |
| **Zavisi od** | [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) (grupa 3), zaseban ADR o odgodi obavijesti |
| **Blokira** | — |
| **Reference** | `appointments/appointment_actions_bar.dart` · `appointments/appointments_screen.dart` |

## Cilj
Otkazivanje i brisanje se poništavaju iz toasta umjesto da se potvrđuju dijalogom, gdje god je to pošteno.

## Zatečeno stanje
Potvrde idu kroz `AlertDialog` (`appointment_actions_bar.dart:226`, `appointments_screen.dart:648`). Obavijest klijentu ide kroz `notification_logs` i cron worker (task 39).

## Definicija gotovog
- [ ] ADR: obavijest se odgađa za trajanje toasta, ili undo važi samo za akcije bez obavijesti
- [ ] Undo za brisanje usluge ili radnika samo ako je brisanje meko ili odgođeno
- [ ] Akcija koja je već izašla van sistema zadržava potvrdu

## Zamke
- Undo koji vrati termin u bazi, a klijent je već dobio „otkazano”, gori je od dijaloga.

## Status

Nije počet. Blokiran: [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) je `predložen`.
