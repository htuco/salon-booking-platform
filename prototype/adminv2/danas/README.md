# Prijedlog izmjena (1. oktobar 2026.) — usvojen u tasku 55

Ova kopija handoffa ima izmjene ucrtane u `Melura Danas.dc.html` (sekcija **P** na vrhu canvasa) i u
`screenshots/`, koji su ponovo snimljeni iz izmijenjenog canvasa. Original iz zipa nije u repou; ovo je verzija koja je ugrađena (ADR-0027).

**Nacrtano:**
- Postavke vraćene u sidebar vlasnika. „Pretraži klijenta" ostaje uklonjen, namjerno.
- Zahtjevi poredani po vremenu termina (danas prije sutra), ne po čekanju.
- „· Emir" umjesto „kod Emira"; 6b „Termin 15:00–15:40 je slobodan · Amar"; 6l razlog
  „Odabrana osoba ne radi u to vrijeme". Ime se ne sklanja, rod radnika ne postoji u podacima.
- 6m ostaje kako ga je dizajner nacrtao: upis kad toast istekne. Prijedlog „upiši odmah,
  Poništi vraća" je povučen, jer `set_appointment_status` ne prima `pending`, a
  `visit_count`/`no_show_count` bi ostali uvećani (ADR-0027).
- Prognoza dana: „od toga 60 KM čeka potvrdu" umjesto „svi koji drže slot".
- „U toku": jedan termin po redu.
- „Još 3 ranija termina" umjesto „Ranije danas · 3 termina".
- U rasporedu čip „Bez oznake" umjesto dugmeta „Označi dolazak" — radnja je u bloku „je li došao?".
- Telefon (6c, 6m): jedan zahtjev otvoren, ostali iza „Još N zahtjeva".
- 6i: bez zahtjeva nema ni kartica „Na čekanju" u rasporedu (u originalu su ostale tri).

**Otvoreno, nije nacrtano:** razlog odbijanja u obavijesti klijentu (baza ima `cancel_reason`, push i
klijent ga ne prikazuju), rupe u rasporedu i za vlasnika, „Dodaj uslugu" u brzim akcijama, tamna tema.

Pravilo „sorted by waiting time, oldest first" u tekstu ispod je zamijenjeno gornjim; ostatak
originalnog README-ja važi.

---

# Handoff — Melura admin: „Danas" (redizajn)

Reference: `Melura Danas.dc.html` (open in a browser), section **6**. PNGs in `screenshots/`. Replaces 3b (desktop) and 3k (phone); the rest of the admin is unchanged.

Example moment in every screen: **Monday 18 May, 13:12**, Barber Studio Vitez, 3 staff.

## Screens
| id | What |
|---|---|
| 6a | Owner · 1440 |
| 6b | Owner · 2560 — context panel with the selected request |
| 6c | Owner · 402 |
| 6d | Staff (Vedad) · 1440 |
| 6e | Staff · 402 |
| 6f | Loading (skeleton) |
| 6g | Empty day (no appointments) |
| 6h | Non-working day · 402 |
| 6i | No requests |
| 6j | Many requests (12) |
| 6k | One section fails (schedule), rest works |
| 6l | Reject — dialog with reason |
| 6m | Confirm — undo toast · 402 |

## Layout
Order is fixed: **1. needs a response → 2. what's next → 3. numbers.**

- **≥ 840 px**: desktop shell (sidebar 236 + top bar 66). Two columns: main (requests, unresolved, timeline) + side 330 (Next, numbers, occupancy).
- **≥ 1920 px**: third column — a permanent context panel 560 on the right (6b). Below 1920 the same panel opens as an overlay drawer from the right when a row is clicked; Esc / × closes it.
- **< 840 px**: phone layout, bottom tab bar. Order: requests (max 2 + „Još N"), Next, 3-cell number strip, timeline.

## Blocks and behaviour

### Zahtjevi na odobrenju (top)
- Shows requests with status `Na čekanju`, today and future days, **sorted by waiting time, oldest first**. Desktop shows 3, phone 2; the rest behind „Još N zahtjeva" / „Vidi sve ›" → `/appointments?status=pending`.
- Row: time + day, client, service · from–to · staff · price, „čeka X min", **Odbij** / **Potvrdi** (44 px).
- Pending = **dashed border** (shape, not only color) — same in the timeline and the context panel.
- **Potvrdi** → row leaves, status becomes `Potvrđeno`, undo toast „Zahtjev potvrđen · Poništi" (5 s). The client notification is sent **when the toast expires**; Poništi restores the request with no notification.
- **Odbij** → dialog (6l): reason radio (client sees it) + optional message; „Odbij zahtjev" is destructive red. No undo — the client is notified immediately.
- More than 3 hidden (6j): „Potvrdi sve bez preklapanja" (existing bulk action) next to „Vidi sve".
- Empty (6i): one quiet 52 px row „Nema zahtjeva na čekanju"; the timeline moves up.
- Clicking the row (outside the buttons) selects it → context panel / drawer.

### Unresolved appointments
`Potvrđeno` whose `end ≤ now` → „Ime — je li došao?" with **Nije došao** / **✓ Završeno**. Both are undoable via toast (no dialog). Hidden when there are none.

### Sljedeći
First `Potvrđeno` with `start > now`: „za X min", time, client, service, „kod {staff}", price. Under it „U toku: …" for appointments where `start ≤ now < end`. Click → selects it.

### Ostatak dana (timeline)
- Vertical line, one card per appointment, chronological. Filter chips Svi / per staff (owner only).
- **Sad HH:MM** line moves every minute.
- Past (`end ≤ now`) opacity .5; all but the last 2 collapse into „Ranije danas · N termina · Prikaži".
- `U toku` is derived (not a stored status): blue chip + tinted card.
- `Otkazano` = strikethrough name; `Nije došao` red chip; `Na čekanju` dashed card + dashed dot.
- Staff view (6d/6e) also shows **Slobodno X min** and **Pauza** rows, computed from the shift.
- Click a card → context panel / drawer with details and actions for that status.

### Brze akcije (top bar)
**+ Novi termin** (primary, coral) · Blokiraj vrijeme · Dodaj uslugu (owner only). On phone: „+ Novi" in the header, the other two behind „⋯".

## Live updates (realtime channel)
- **New request**: inserted into the requests block at its sort position with a 320 ms slide + soft highlight; count pill, sidebar badge and tab badge +1; appears dashed in the timeline. No toast while the user is on Danas; on other pages: info toast „Novi zahtjev · Otvori".
- Request cancelled by the client: row removed, counts −1.
- Every minute: „čeka X min", „za X min", the Sad line, past dimming, unresolved block.
- Numbers recompute on every status change.

## Numbers — data source for each
| Shown | Formula |
|---|---|
| čeka X min | `now − request.sentAt` |
| najstariji prije X | max of the above |
| za X min (Sljedeći) | `next.start − now`, next = first `Potvrđeno` with `start > now` |
| Naplaćeno | Σ price of today's `Završeno` |
| Prognoza dana | Σ price of today's `Završeno + Potvrđeno + Na čekanju` (holding a slot) |
| Termini danas | count of the same set; sub: count of `Nije došao`, `Otkazano` |
| Zauzetost {staff} % | Σ duration of that staff member's slot-holding appointments ÷ (shift length − break) |
| Najveća rupa | largest free interval from `max(now, shiftStart)` to `shiftEnd`, excluding appointments and break, across staff |
| Ova sedmica | count of slot-holding appointments Mon–Sun of the current week |
| Otvoreno do 20:00 / Danas zatvoreno | salon working hours for today / non-working day |
| Sljedeći radni dan · N termina (6h) | first working day after today + count of its appointments |
| Klijent: dolasci / nedolasci / zadnji (6b) | client record (existing Klijenti data) |
| „{staff} je slobodan" (6b) | overlap check against the staff member's appointments + break |

Example values (6a) come from the dataset in the generator: 60 KM / 283 KM / 16 termina / Amar 17:30–19:20 (1 h 50 min) / Emir 40 %, Vedad 44 %, Amar 29 %. No trends, ratings, channels or multi-location — that data doesn't exist.

## Roles
- **Vlasnik**: everything above.
- **Radnik**: only own appointments; requests only if the salon routes them to them; no revenue, no other staff's occupancy. Numbers: Moji termini, Moja zauzetost, Najveća rupa, Ova sedmica (own). Sidebar: Danas, Kalendar, Zahtjevi. Actions: Novi termin, Blokiraj vrijeme.

## States
- **Loading (6f)**: skeleton per block, same geometry; each block loads independently.
- **Section error (6k)**: inline card in that block — „… se nije učitao" + **Pokušaj ponovo**; other blocks keep working.
- **Empty day (6g)**: timeline empty card; numbers 0; Najveća rupa = whole shift.
- **Non-working day (6h)**: „Danas ne radimo", future requests still shown, next working day.

## Staff word is variable
Anything underlined with a dotted line in the design depends on the vertical: `{staff.singular}` majstor / stilistica / terapeut, `{staff.genitivePlural}` majstora / stilistica / terapeuta. Use the existing vertical dictionary (rječnik), never hardcode.

## Visual rules
Sidebar `#141517`, ground `#fcfcf9`, cards `#fff` with hairline `#e2e2e2`, radius 4, Barlow. Coral `#EE6C4D` = main action only (Potvrdi, Novi termin, request count). Blue `#3D5A80` = selection, data, Sad line, U toku, links. Pending = `1px dashed #6b7076`. Status chips: Potvrđeno `#e0f2f1/#004d40`, Završeno/Otkazano `#f0f1f3/#666`, Nije došao `#f7e4e4/#c94c4c`. Selected = `outline 2px #3D5A80, offset 2px`. Hit targets ≥ 44 px. Toast = existing component from section 5 (`design_handoff_toasts/`).

## Out of scope
Location network overview, week calendar, drag-and-drop, analytics over time.
