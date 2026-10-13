# Task 64 — Istek neodgovorenih zahtjeva

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | — |
| **Blokira** | [68](68-lista-cekanja.md), [87](87-sigurnosni-pregled.md) |
| **Reference** | `docs/01` §8 pravilo 9 · `supabase/functions/expire-pending/README.md` · `appointments.pending_expires_at` |

## Cilj
Zahtjev na koji salon ne odgovori do `pending_expires_at` se sam zatvara, termin se oslobađa, a
klijent dobija push. Danas `pending_expires_at` postoji, ali ga niko ne čita — zahtjev koji salon
zaboravi **zauvijek drži termin**, što je na salonu sa jednim radnikom najveća rupa u logici.

## Definicija gotovog
- [x] Isteklo = `cancelled`, `cancelled_by = 'system'`, `cancel_reason = 'isteklo'` — bez novog
      statusa u enumu (postojeći filteri i exclusion constraint ostaju tačni)
- [x] `pg_cron` posao (svakih 5 min) zove `private.expire_pending()`; samo `pending` čiji je rok prošao
- [x] Klijent dobija push „Salon nije odgovorio na vrijeme" kroz postojeći `dispatch_push`, jednom
- [ ] Melura: istekli zahtjev nestaje iz „Zahtjeva", vidi se u istoriji kao „isteklo"
- [x] pgTAP: istekao se zatvara, neistekao ne, potvrđen se ne dira, drugi prolaz ne radi ništa,
      oslobođen slot se vraća u `get_available_slots`
- [ ] Migracija i cron na hostovanom projektu

## Zamke
- Rok se računa iz `pending_expiry_hours` u trenutku zahtjeva — promjena postavke ne mijenja postojeće.
- Termin koji počinje prije isteka roka: zatvara se najkasnije na početak termina.

## Status (2026-10-13) — 🟡 kod dokazan lokalno, čeka deploy

Grana `feat/istek-zahtjeva`. Migracija `20261013100000_istek_zahtjeva.sql`: `private.expire_pending()`
(samo `service_role`), cron `expire-pending` svakih 5 min, novi tip obavijesti `expired` u
`queue_appointment_push`, naslov „Salon nije odgovorio na vrijeme" u `send-push`. Melura istekli
termin piše „Isteklo" (pilula, kalendar, panel, detalj), a „Otkazao" glasi „niko, salon nije
odgovorio na vrijeme". Klijentska app je `system` već prikazivala („Isteklo je vrijeme za potvrdu").
Edge Function nije potrebna — `supabase/functions/expire-pending/README.md` to objašnjava.

**Dokazano:** `./tool/test_supabase.sh` — pgTAP 27 fajlova / 818 asercija PASS (nov
`027_istek_zahtjeva`, 18), svi REST testovi i `send-push` `deno test` (6) PASS. Mutacija bez uslova
početka obara 2 asercije, a mutacija koja zatvara i `confirmed` obara 4. Admin `flutter analyze`
čist, `flutter test` 577 PASS (nov test za „Isteklo" u detalju).

**Ostalo za sljedećeg:**
- Hamza poslije merge-a: `supabase db push` (migracija + cron u njoj) i deploy `send-push`
  (`supabase functions deploy send-push`). Provjera: `select schedule from cron.job where jobname =
  'expire-pending'` vraća `*/5 * * * *`.
- Istekli zahtjev viđen uživo u Meluri (nestaje iz „Zahtjeva", u istoriji „Isteklo") i push na
  uređaju — widget test pokriva oznaku, ekran nije gledan.
