# Task 56 — Push podsjetnici D-1 i H-3

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `docs/01` §6.2 · `supabase/functions/send-reminders/README.md` · sprint-4 task 39 |

## Cilj
Klijent dan prije i tri sata prije termina dobije push, tačno jednom.

## Definicija gotovog
- [ ] `send-reminders` postoji kao kod — danas je samo README
- [ ] Podsjetnik ide samo za `confirmed` termin i samo ako salon ima `reminders_enabled`
- [ ] Tipovi `reminder_d1` i `reminder_h3` već postoje u `notification_type`; red u `notification_logs`
      se pravi jednom po terminu i tipu — restart schedulera ne duplira
- [ ] Slanje ide postojećim putem (`dispatch_push`, task 39), ne drugim kanalom
- [ ] Otkazan ili pomjeren termin ne dobija podsjetnik koji je ostao u redu
- [ ] pgTAP: pravi se tačno jedan red; drugi prolaz ne pravi novi; otkazan termin ne dobija red
- [ ] Uživo na Android uređaju: termin za sutra → D-1 stiže, tekst po vertikali

## Zamke
- **Vremenska zona.** „Sutra u 14:30" je lokalno vrijeme salona, a cron radi u UTC-u.
- Termin zakazan za manje od 3 sata ne smije dobiti H-3 poslije početka.
- Poslije merge-a migracija na hostovani projekat; cron bez migracije ne radi ništa.

## Status

### Odložen (2026-10-13)

Učitan pa vraćen: nema Android uređaja ni emulatora za stavku „uživo", a prije koda trebaju dvije
odluke. Na Macu (arm64) nema Android SDK-a. Emulator mora biti **API 36, arm64-v8a, Google Play
image**; bez Google Playa FCM ne radi. Stavka se tada piše kao „viđeno na emulatoru (pravi FCM)",
ne „na uređaju".

**Odluke prije koda:**
- Kad ide D-1? 24 h prije početka, ili fiksan sat dan prije u zoni salona? Admin Postavke danas pišu
  „24 sata prije" i „sat prije", a task kaže H-3.
- `reminders_enabled` je jedna kolona, a admin ima dva prekidača. Za dvije kolone pazi na task 37:
  novi potpis `update_salon_settings` je preopterećenje.

**Nađeno pri učitavanju:**
- Već postoje enum `reminder_d1`/`reminder_h3`, `salon_settings.reminders_enabled`, unique
  `(appointment_id, device_id, type)` na `notification_logs` i `dispatch_push` + cron
  `send-push-queued`. Lista Obavijesti (task 70) ima naslov „Podsjetnik".
- `claim_push_notifications` ne gleda status termina: podsjetnik u redu otišao bi i poslije
  otkazivanja. Treba filter za tipove podsjetnika (`confirmed`, početak nije prošao).
- `send-push` za oba tipa baca `unsupported_type`. Tekst po vertikali može doći iz
  `vertical_packs.terminology` + `salons.terminology_override`.
- Obrazac je task 64 (SQL + `pg_cron`, README ostaje). Pomjeranje termina danas ne postoji.
- Ekrani koji kažu da podsjetnika nema: admin `_ObavijestiKartica` u `settings_screen.dart` i klijent
  `about_app_screen.dart` + `aboutAppStep3Title`.
- Deploy: `send-push` **prije** `db push`.
