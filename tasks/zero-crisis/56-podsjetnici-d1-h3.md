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
- [x] `send-reminders` postoji kao kod — kao SQL + `pg_cron` (`private.queue_reminders`, posao `queue-reminders`), po obrascu taska 64; README to kaže (ADR-0033)
- [x] Podsjetnik ide samo za `confirmed` termin i samo ako salon ima `reminders_enabled` (dnevni) odnosno `hourly_reminder_enabled` (satni)
- [x] Tipovi `reminder_d1` i `reminder_h3` već postoje u `notification_type`; red u `notification_logs`
      se pravi jednom po terminu i tipu — restart schedulera ne duplira
- [x] Slanje ide postojećim putem (`dispatch_push`, task 39), ne drugim kanalom
- [x] Otkazan ili pomjeren termin ne dobija podsjetnik koji je ostao u redu (pomjeranje danas ne postoji, v. ADR-0033)
- [x] pgTAP: pravi se tačno jedan red; drugi prolaz ne pravi novi; otkazan termin ne dobija red
- [ ] Uživo na Android uređaju: termin za sutra → D-1 stiže, tekst po vertikali

## Zamke
- **Vremenska zona.** „Sutra u 14:30" je lokalno vrijeme salona, a cron radi u UTC-u.
- Termin zakazan za manje od 3 sata ne smije dobiti H-3 poslije početka.
- Poslije merge-a migracija na hostovani projekat; cron bez migracije ne radi ništa.

## Status

### U toku 🟡 (2026-10-21)

Grana `feat/podsjetnici`, [PR #144](https://github.com/htuco/salon-booking-platform/pull/144),
[ADR-0033](../../docs/adr/0033-podsjetnici-dnevni-24h-i-satni-n-sati.md) (Hamzine odluke
prihvaćene; N 1–12 h i „zakazan ili potvrđen kasnije → ne šalje se" su prijedlog koji čeka
potvrdu).

- **Baza** (`20261021172634_podsjetnici.sql`): `hourly_reminder_enabled`, `hourly_reminder_hours`
  (check 1–12); `update_salon_settings` sa 13 argumenata, stari potpis dropan, novi argumenti
  `default null` = ne mijenjaj; `appointments.confirmed_at` (samo trigger);
  `private.queue_reminders()` + cron `queue-reminders` (*/5); `claim_push_notifications` gasi
  nevažeće podsjetnike i daje `appointment_term` i `starts_in_minutes`.
- **`send-push`**: „Podsjetnik" / „Termin je sutra." / „Tretman počinje za 3 sata.", fallback bez
  novih kolona.
- **Melura**: dva prekidača i izbor N (1–12) u „Obavijesti klijentima", snimaju se na „Sačuvaj".
- **Klijent**: „O aplikaciji" kaže „Dobijete podsjetnik" samo kad ga salon šalje.

**Dokaz:** `./tool/test_supabase.sh` na čistom stacku — pgTAP Files=35, Tests=1170 PASS (`035`: 67
asercija), svi REST i Deno testovi zeleni; 26 mutacija nad migracijom, svaka obara bar jednu
aserciju (popis u `security.md`, „Podsjetnici"). `melos run test`: admin 730, client 690, core_api
158, core_domain 106, core_ui 147. Uživo na lokalnom stacku: N = 1 snimljen kroz Melura web
(`docs/screenshots/task-56-melura-1440.png`, `-402.png`), dnevni isključen i snimljen (`f` u bazi);
termin za 24 h + 4 min i za 1 h + 4 min → cron `queue-reminders` u 17:55:00 UTC napravio
`reminder_d1` i `reminder_h3` (`succeeded`), ručni `queue_reminders()` poslije toga 0, claim daje
`Termin` i `starts_in_minutes = 60`.

**Ostaje:** review i merge; deploy (Hamza) **`supabase functions deploy send-push` pa `supabase db
push`**, pa `select jobname from cron.job where jobname = 'queue-reminders'`; uživo na Android
emulatoru (API 36, arm64-v8a, Google Play image) sa pravim FCM-om — nije urađeno, nema SDK-a.


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
