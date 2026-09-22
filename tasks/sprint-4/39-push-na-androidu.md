# Task 39 — Push obavijesti na Androidu

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | — |
| **Blokira** | 42 |
| **Reference** | `supabase/functions/send-push/` · task [25](../sprint-2/25-push-notifikacije.md) |

## Cilj
Push je prestao stizati na Androidu.

## Definicija gotovog
- [x] Imenovano **gdje** lanac puca: **dva mjesta, oba uzvodno od FCM-a** — `queue_appointment_push`
      u `auto` modu i `register_device` koji se iz admina nikad ne pozove
- [x] Dokaz iz `notification_logs` — stanje prije popravke pročitano nad hostovanom bazom, nastanak
      reda dokazan u CI-ju, a lanac zatim prošao i uživo nad hostovanim projektom
- [x] Obavijest stigla na Android emulator — potvrđeno ručno 2026-09-22, oba smjera
- [x] Ako je uzrok istekao ključ ili promjena konfiguracije, to je zapisano u `workflows.md`

## Koraci
1. Ima li uređaj red u `devices` i je li `fcm_token` svjež
2. `notification_logs` za zadnje pokušaje
3. Pozvati `send-push` ručno i pročitati odgovor FCM-a
4. Tek onda tražiti grešku u aplikaciji

## Zamke
- **`devices.device_id` nije `appointments.device_id`** — prvo je instalacioni identifikator, drugo
  FK na `devices.id`. Zamjena prolazi tipove i tiho slomi push.
- Izlaz `supabase status -o env` nosi service role ključ — ne ide ni u commit ni u sažetak.

## Ostalo izvan repoa
**iOS ostaje nedokazan** dok ne postoji Apple developer nalog. To nije dio DoD-a nego imenovani dug.

## Status (2026-09-22)

Grana `fix/push-na-androidu`, [PR #77](https://github.com/htuco/salon-booking-platform/pull/77) (draft).

**Lanac ne puca na FCM-u.** Prije ijedne izmjene, read-only nad hostovanim projektom:
`cron.job send-push-queued` je `active`, oba vault tajna postoje, a svih **24 redova u
`notification_logs` su `sent`, `attempts = 1`, `error = null`** — nijedan `failed` ni zaglavljen
`sending`. Koraci 3 i 4 iz ovog taska (ručni poziv `send-push`, odgovor FCM-a) bi bili izgubljen dan.

**Red se prestao stvarati.** Aplikacija je 2026-09-21 napravila **17 `app` termina**, a za njih u
`notification_logs` nema nijedan red. Tipa `new_request` nema **nijednog, ikad**.

### Prvi prekid — `auto` mod, popravljen

`queue_appointment_push` je pisan u tasku 25, kad je `pending` bio jedini ishod klijentske
rezervacije: `if new.source <> 'app' or new.status <> 'pending' then return new`. Task 37 je spojio
`booking_mode`, pa u `auto` modu termin nastaje odmah kao `confirmed` — drugi uslov je postao lažan
i trigger je tiho odustajao. Salon `Barber Studio VItez` **jeste** u `auto` modu.

Na `INSERT` sada presuđuje `source`, pa tek onda status: `new_request` za `pending`, novi tip
**`new_booking`** za `confirmed`. Tip nosi *šta se desilo*, ne kome se šalje — naslov „Novi zahtjev"
bi vlasnika poslao na ekran zahtjeva koji je u `auto` modu prazan.

**Klijent u `auto` modu namjerno ostaje bez pusha.** Tip `confirmed` visi o *promjeni* statusa,
koje tamo nema, a klijent u tom trenutku gleda ekran koji mu potvrdu već piše. Odluka, ne previd.

Dokaz — CI `Supabase tests` **zelen**, pgTAP `Files=16, Tests=469, Result: PASS` (bilo 455), novi
`016_push_u_auto_modu.test.sql` nosi 14 asercija. Sabotaža starom granom trigera, pokrenuta preko
`workflow_dispatch` na odbačenoj grani, obara **tačno 2 od 14**: „Auto mod javlja salonu novu
rezervaciju" i „Jedna rezervacija u auto modu daje tacno jedan red". Ostalih 15 fajlova ostaje
zeleno, pa test ne visi o tuđem ponašanju. Worker: `deno test handler_test.ts` **6/6** i
`deno check` nad `index.ts`.

### Drugi prekid — admin nema staff uređaj, **zatvoren 2026-09-22**

U `devices` je **tačno jedan red i on je klijentski**. Bez staff uređaja grana `v_staff` bira nula
redova, pa bi i popravljen trigger slao u prazno. `apps/admin/lib/main.dart` uredno postavlja
`pushStaffProvider = true`, ali `pushServiceProvider` vraća `null` dok je `PUSH_ENABLED` prazan, a
`tool/run_live_demo.sh` dodaje `--dart-define-from-file` samo ako je `FIREBASE_ADMIN_DEFINES_FILE`
neprazan — **u `.env.live` su prazna oba**. Nijedan sloj na to nije pravio grešku.

U repou je popravljeno samo ono što je bilo u repou: skripta sada **upozorava** umjesto da tiho
preskoči push, a `workflows.md` ima odjeljak „Bez define fajla nema pusha, i to tiho" sa komandom
za `firebase_defines.dart`. Sam uzrok je izvan repoa: `apps/admin` ima `applicationId`
`ba.nasadomena.admin`, pa traži **vlastitu Firebase Android aplikaciju** — klijentski
`google-services.json` na njemu namjerno pada (`Firebase package name se ne poklapa`).

## Dokaz uživo (2026-09-22, nakon PR #77)

Migracija je primijenjena na hostovani projekat (`db push`, jedna migracija): enum ima
`new_booking`, a stara grana više ne postoji u `prosrc` funkcije. Firebase Android aplikacija za
`ba.nasadomena.admin` je registrovana, define fajl generisan iz njenog `google-services.json`, i
admin pokrenut na drugom emulatoru.

`devices` je time prvi put dobio **staff uređaj sa tokenom** (`1e60ef0e…`), pored klijentskog
(`92fedc78…`). Do tada je tabela imala jedan jedini red, klijentski — zato grana `v_staff` nije
imala kome slati ni prije ni poslije popravke trigera.

Obavijesti stižu na oba smjera. Dvije zamke nađene pri tome:

- **Emulator bez default rute.** Drugi AVD je imao `eth0` i `wlan0` na istoj podmreži i nijednu
  default rutu, pa je aplikacija javljala `Failed host lookup`. Nije kvar aplikacije; rješenje je
  `ip route add default via 10.0.2.2 dev eth0` ili nov AVD.
- **`--dart-define-from-file` traži apsolutnu putanju.** `run_tenant.sh` uđe u `apps/client/` prije
  `flutter run`, pa se relativna putanja iz `.env.live` lomi — a provjera postojanja fajla u
  skripti prođe, jer se radi iz korijena.

## Zvuk — nastavak u zasebnom PR-u

Obavijesti su stizale **nijemo**. Tri nalaza, po težini:

1. **Payload nije tražio zvuk na Androidu.** iOS je imao `aps.sound` od taska 25, Android nijedno
   polje. Dodani `sound: "default"` i `channel_id`.
2. **Admin nije imao notification kanal uopšte** — ni meta-data u manifestu ni kreiranje u
   `MainActivity`. `dumpsys` je to i pokazao: postojao je samo FCM-ov
   `fcm_fallback_notification_channel` („Miscellaneous", `mImportance=3`). Sada ima
   `appointment_updates` sa `mImportance=4`, `mSound` i `USAGE_NOTIFICATION`.
3. **Pravi uzrok tišine bio je prvi plan.** FCM na Androidu ne crta notification payload dok je
   aplikacija otvorena. Klijent to rješava kroz `ForegroundNotifications.show(...)`; admin na istom
   mjestu (`apps/admin/lib/main.dart`) zove samo `refreshAdminAppointments(ref)`. Sa adminom u
   pozadini zvuk i banner rade — potvrđeno ručno.

## Ostalo za sljedećeg

1. **`supabase functions deploy send-push` nije pokrenut** — blokiran kao produkcijska akcija.
   Dok ne prođe, `sound`/`channel_id` iz payloada ne postoje na hostovanom. Zvuk na adminu ipak
   radi, jer `default_notification_channel_id` iz manifesta sam usmjerava FCM.
2. **Admin nema obavijest u prvom planu.** Dok je otvoren, push samo tiho osvježi listu. Popravka
   znači preseliti `ForegroundNotifications` iz `apps/client/lib/src/core/` u `core_api` (da se ne
   duplira) i dodati MethodChannel u admin `MainActivity`. **Zaseban task.**
3. **Klijentov kanal na zatečenim instalacijama ostaje bez izmjene.** Android ignoriše naknadne
   izmjene zvuka i importance na postojećem kanalu — traži reinstalaciju.
4. **`tool/run_tenant.sh` je pokvaren sa Flutterom 3.47.4** — šalje `--build-name`/`--build-number`
   koje `flutter run` više ne prima, pa svaki `run_live_demo.sh client` pada. Zaobiđeno shimom van
   repoa. **Zaseban task.**
5. **iOS ostaje imenovan dug** dok nema Apple developer naloga (bilo izvan DoD-a i prije ovoga).
