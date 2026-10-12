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
- [ ] Isteklo = `cancelled`, `cancelled_by = 'system'`, `cancel_reason = 'isteklo'` — bez novog
      statusa u enumu (postojeći filteri i exclusion constraint ostaju tačni)
- [ ] `pg_cron` posao (svakih 5 min) zove `private.expire_pending()`; samo `pending` čiji je rok prošao
- [ ] Klijent dobija push „Salon nije odgovorio na vrijeme" kroz postojeći `dispatch_push`, jednom
- [ ] Melura: istekli zahtjev nestaje iz „Zahtjeva", vidi se u istoriji kao „isteklo"
- [ ] pgTAP: istekao se zatvara, neistekao ne, potvrđen se ne dira, drugi prolaz ne radi ništa,
      oslobođen slot se vraća u `get_available_slots`
- [ ] Migracija i cron na hostovanom projektu

## Zamke
- Rok se računa iz `pending_expiry_hours` u trenutku zahtjeva — promjena postavke ne mijenja postojeće.
- Termin koji počinje prije isteka roka: zatvara se najkasnije na početak termina.

## Status
Nije počet.
