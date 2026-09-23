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
- [x] Prošli termini vizuelno odvojeni od budućih
- [x] Otkazivanje otvara modal iz [FE-203](FE-203-modali-i-bottom-sheet.md); potvrda je obavezna
- [x] Prazno stanje: jedna rečenica i CTA na booking
- [ ] Pull-to-refresh radi i koristi komponentu iz [FE-205](FE-205-ukidanje-default-flutter-indikatora.md), ne Material `RefreshIndicator` — **čeka FE-501**
- [x] Status i dalje ide kroz `statusLabel`/`statusTone` — nijedan ekran ne mapira status sam
- [x] Razlika „otkazao salon" / „otkazali ste vi" / „isteklo" ostaje vidljiva

## Zamke
- **Rok otkazivanja dolazi iz `salon_settings.min_cancel_hours`, nikad iz konstante.** Dugme koje
  se onemogući po tvrdom broju laže na svakom salonu koji ima drugi rok, a baza tada vrati `PT403`.
- Klijent mora invalidirati `salonSettingsProvider` na realtime signal — propušteno u tasku 36 i
  popravljeno tek kad je baza počela odbijati ono što je ekran nudio.

## Status

🟡 **Kod gotov i dokazan testovima; pull-to-refresh čeka FE-501.** Grana `feat/fe-304-moji-termini`.

**Nađena i popravljena greška — upravo ona iz prve zamke.** `minCancelHoursProvider` je rok
čitao iz `vertical.rules.minCancelHours`, a `cancel_appointment` čita
`salon_settings.min_cancel_hours`
(`supabase/migrations/20260912140000_cancel_appointment.sql`). Kad vlasnik promijeni rok u
postavkama, dugme je nudilo otkazivanje koje baza odbije sa `PT403`. Provider sada čita
`salonSettingsProvider`, a vertikala je samo rezerva dok postavke ne stignu. Realtime
invalidacija `salonSettingsProvider` već postoji (`apps/client/lib/main.dart:73`, task 36).

Zatečeno isporučeno (provjereno čitanjem koda):
- Prošli i budući termini su u dva taba (`splitAppointments`). Zatvoren termin ide u „Prošli"
  bez obzira na datum.
- Otkazivanje ide kroz `AppDialog.show` iz FE-203. `null` i `false` znače odustajanje.
- Prazno stanje: `EmptyState`, jedna poruka i CTA na booking. U „Prošli" nema CTA-a, jer je
  prazno tamo očekivano.
- Status mapira samo `appointment_labels.dart`. Nijedan drugi fajl ne radi `switch` nad
  `AppointmentStatus`.

**Dokaz (2026-09-23):**
- `apps/client`: `flutter test` → **255 pass, 1 skip**, a
  `test/appointments_screen_test.dart` → **18 pass**. `flutter analyze` → No issues found.
- Dva nova testa, oba provjerena sabotažom:
  - `rok dolazi iz salon_settings, ne iz vertikale` (vertikala 3 h, postavke 5 h). Kad provider
    ponovo čita vertikalu, pada tačno taj test (`+16 -1`).
  - `prošli tab razlikuje ko je otkazao`. Kad se ukloni mapiranje za `salon`, pada tačno taj
    test (`+17 -1`).

**Ostalo za sljedećeg:** ekran i dalje koristi Material `RefreshIndicator`. FE-205 je vlastitu
refresh komponentu izričito prebacio u FE-501, pa se ovdje ne pravi usput. Kad FE-501 uvede
komponentu, zamjena su dva mjesta u `appointments_screen.dart` (`_Lista`, prazna i puna grana),
a postojeći testovi za povlačenje ostaju dokaz. Na uređaju nije viđeno.
