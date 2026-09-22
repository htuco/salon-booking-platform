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
- [~] Dokaz iz `notification_logs` — stanje prije popravke pročitano nad hostovanom bazom, a nastanak
      reda nakon nje dokazan u CI-ju; `attempts`/`error` nad hostovanom traže primijenjenu migraciju
- [ ] Obavijest stigla na Android emulator ili uređaj, sa snimkom — **blokirano**, v. status
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

### Drugi prekid — admin nema staff uređaj, **nije popravljen u repou**

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

## Ostalo za sljedećeg

1. **Registrovati `ba.nasadomena.admin` u Firebase projektu** (`hades-75751`), skinuti
   `google-services.json`, pa:
   `dart run tool/firebase_defines.dart <json> ba.nasadomena.admin .firebase-config/admin.json`
   i upisati putanju u `FIREBASE_ADMIN_DEFINES_FILE`. Traži pristup konzoli — nije posao u repou.
2. **Primijeniti migraciju na hostovani projekat.** MCP veza je `--read-only`, pa je ovdje nije
   dirala nijedna komanda. Bug je tamo i dalje živ.
3. **Snimak sa uređaja i red sa `attempts`/`error`** tek nakon 1 i 2 — to su dvije DoD stavke koje
   ostaju otvorene. Docker na ovoj mašini ne postoji, pa ni lokalni emulator preko `supabase start`
   nije alternativa.
4. **iOS ostaje imenovan dug** dok nema Apple developer naloga (bilo izvan DoD-a i prije ovoga).
