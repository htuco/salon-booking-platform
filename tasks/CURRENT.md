# Trenutni task: 42 — Neradni dan: zaključana prošlost i kaskadno otkazivanje

Puni task: [tasks/sprint-4/42-neradni-dan-i-zakljucana-proslost.md](sprint-4/42-neradni-dan-i-zakljucana-proslost.md) · učitan 2026-09-23

## Status

U toku

## Ciljevi

- [x] Migracija: RPC `public.set_day_closed(p_salon_id, p_date, p_reason)` — `security definer`, `private.is_admin`, grant samo `authenticated`
- [x] Odbija prošli datum i danas **poslije** najranijeg početka radnog vremena tog dana (zona iz `salon_settings.timezone`), razumljiva greška
- [x] Otkazuje sve `pending`/`confirmed` termine tog dana uz `cancel_reason` i `cancelled_by = 'salon'`; `completed`/`cancelled` ne dira
- [x] Obavijest klijentu se zapisuje za svaki otkazan termin
- [x] Read-only pregled „koliko termina će biti otkazano" za admin dijalog
- [x] pgTAP: prošlost odbijena, danas prije/poslije otvaranja, broj otkazanih tačan, tuđi salon nedirnut, ne-admin odbijen
- [ ] Admin ekran: akcija „Neradni dan" sa brojem termina prije potvrde
- [x] `.claude/docs/security.md` (+ `supabase/IMPLEMENTATION.md`) ažurirani

## Napomene

- **Zavisnosti 38 i 39 su ✅.** Ništa nije isporučeno ranije — `set_day_closed` ne postoji u repou.
- **Zamka u task fajlu je netačna:** `set_appointment_status`
  (`20260914150000_admin_akcije_nad_terminima.sql`) izričito **odbija** otkazivanje (PT400).
  Kanonska putanja je `public.cancel_appointment` (`20260912140000_cancel_appointment.sql`), koja za
  admina već postavlja `cancelled_by='salon'` i `cancel_reason`. Otkazivati kroz nju ili zajednički
  `private.*` helper, ne direktnim `update`. Provjeriti ima li vremensko ograničenje koje blokira admina.
- **`notification_logs` je po uređaju** (`device_id`); puni ga trigger iz
  `20260922140000_push_u_auto_modu.sql` na promjenu statusa. Klijent bez registrovanog uređaja
  dobija nula redova — DoD „red za svaki termin" treba pojasniti ili dodati red bez uređaja.
  Odluka ide u status blok (ADR ako mijenja ugovor).
- „Prošlost zaključana" za radno vrijeme i blokade (`working_hours_dialogs.dart`, `blocked_slots`)
  nije u DoD-u — samo za `set_day_closed`. Ne širiti bez odluke.
- Neradni dan vjerovatno treba i `blocked_slots` red za cijeli dan, da availability ne nudi slotove
  nakon otkazivanja — provjeriti oblik iz taska 34.
- Prije pisanja: `.claude/docs/security.md`. Dokaz: `supabase start && supabase test db` + `/verify`.
- Procjena 2–3 dana ostaje.

## Istorija

### FE-403 — Kalendar termina (gotov)

Spojen u `main` ([PR #72](https://github.com/htuco/salon-booking-platform/pull/72)). Zahtjev na
odobrenju nosi isprekidan rub na mreži, u listi i u legendi — razlika **oblikom**, ne samo bojom.
309 testova PASS, viđeno na 1440×900, 402×874 i u tamnoj temi. Prekidač dan/sedmica i realtime
osvježavanje ostali **imenovan dug** — oba traže ADR jer ih `prototype/admin/SPEC.md` izričito
izostavlja. Time je admin blok FE-401…FE-406 zatvoren.

### FE-404 — Usluge, osoblje i klijenti (gotov)

Spojen u `main` ([PR #71](https://github.com/htuco/salon-booking-platform/pull/71)).
Terminologija po vertikali umjesto „Majstor" iz canvasa, zelen CI na oba joba.

### 39 — Push obavijesti na Androidu (gotov)

Zatvoren uživo 2026-09-22 i spojen u `main`: migracija za `auto` mod je na hostovanom projektu,
admin Firebase aplikacija i staff uređaj su registrovani, a push je dokazan u oba smjera. Zvuk i
vlastiti Android kanal spojeni su zasebno kroz PR #80. iOS push ostaje imenovan dug do Apple
developer naloga.

### 41 — Zakazivanje bez prijave se uklanja (gotov)

Zatvoren 2026-09-23 ([PR #100](https://github.com/htuco/salon-booking-platform/pull/100)): gost
uklonjen iz koda, `tenant.yaml`-a, šeme i admin postavki; `private.is_client()` odbija anonimnu
sesiju. 478 pgTAP asercija, 9 REST testova, `melos run test` i CI zeleni. `register_device` zadržava
push registraciju prije prijave. Nakon merge-a: `supabase db push`.
