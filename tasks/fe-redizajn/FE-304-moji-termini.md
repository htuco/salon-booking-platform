# FE-304 — Moji termini

| | |
|---|---|
| **Epik** | FE-3 · Klijentski ekrani |
| **Aplikacija** | `apps/client` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | [FE-203](FE-203-modali-i-bottom-sheet.md) |
| **Blokira** | — |
| **Reference** | `apps/client/lib/src/features/appointments/` · `apps/client/lib/src/features/appointments/appointment_labels.dart` · `prototype/ui/screenshots/08-moji-termini.png`, `16-modal-otkazivanje.png` |

## Cilj
Lista termina sa statusima i akcijom otkazivanja, po handoffu.

## Zatečeno stanje
- Ekran postoji (`features/appointments/`), sa testom `appointments_screen_test.dart`.
- **Status je već tekstualna oznaka u okviru, ne obojena tačka** — `StatusBadge` + `statusLabel`/
  `statusTone` iz `appointment_labels.dart`. Kriterij iz handoffa je time ispunjen prije početka;
  posao je da to ostane tako i poslije redizajna.
- `statusTone` nosi odluku koja se lako slučajno poništi: **`pending` je `warning`, ne `info`** —
  „na čekanju" je stanje koje traži pažnju jer termin još nije korisnikov.
- `cancelledByNote` razlikuje ko je otkazao (`salon` / `system` / `customer`); `system` je istekao
  `pending` i **ne smije izgledati kao odbijanje**.

## Definicija gotovog
- [ ] Prošli termini vizuelno odvojeni od budućih
- [ ] Otkazivanje otvara modal iz [FE-203](FE-203-modali-i-bottom-sheet.md); potvrda je obavezna
- [ ] Prazno stanje: jedna rečenica i CTA na booking
- [ ] Pull-to-refresh radi i koristi komponentu iz [FE-205](FE-205-ukidanje-default-flutter-indikatora.md), ne Material `RefreshIndicator`
- [ ] Status i dalje ide kroz `statusLabel`/`statusTone` — nijedan ekran ne mapira status sam
- [ ] Razlika „otkazao salon" / „otkazali ste vi" / „isteklo" ostaje vidljiva

## Zamke
- **Rok otkazivanja dolazi iz `salon_settings.min_cancel_hours`, nikad iz konstante.** Dugme koje
  se onemogući po tvrdom broju laže na svakom salonu koji ima drugi rok, a baza tada vrati `PT403`.
- Klijent mora invalidirati `salonSettingsProvider` na realtime signal — propušteno u tasku 36 i
  popravljeno tek kad je baza počela odbijati ono što je ekran nudio.

## Status

Nije počet.
