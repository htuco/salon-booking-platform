# FE-607 — Novi termin i kontekst u bočnom panelu

| | |
|---|---|
| **Epik** | FE-6 · Admin kao radni alat |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 2–3 dana |
| **Zavisi od** | [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) (grupa 2), [FE-406](FE-406-desktop-fluidni-layout.md) |
| **Blokira** | — |
| **Reference** | `appointments/new_appointment_screen.dart` · `appointments/appointment_detail_screen.dart` · `core/widgets/admin_scaffold.dart` |

## Cilj
Na desktopu se novi termin pravi u bočnom panelu uz vidljiv kalendar; na širokim ekranima desni panel nosi detalje termina ili klijenta umjesto da se sadržaj rasteže.

## Zatečeno stanje
Novi termin je zaseban ekran. Detalj termina je ekran sa `_maxSirina = 720` (FE-406). Pojasevi širine su na jednom mjestu, u `AdminShell`.

## Definicija gotovog
- [ ] Panel samo u desktop pojasevima; ispod 900 px ostaje današnji ekran
- [ ] Isti widget forme u panelu i na ekranu — ne dvije forme
- [ ] Desni kontekstni panel od pojasa > 1440 px; ispod ostaje navigacija na detalj
- [ ] Dubinski link na termin i dalje radi i na desktopu otvara panel

## Zamke
- Prag za panel se ne izvodi u ekranu (zamka iz FE-406).
- Fokus se vraća na kalendar kad se panel zatvori.

## Status

Nije počet. Blokiran: [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) je `predložen`.
