# Trenutni task: 39 — Push obavijesti na Androidu

Učitan 2026-09-22 iz [sprint-4/39](sprint-4/39-push-na-androidu.md). Bug, procjena 1–2 dana,
bez zavisnosti, **blokira task 42**. Grana `fix/push-na-androidu` sa svježeg `main`-a.

## Status

U toku.

## Ciljevi

- [ ] Imenovati **gdje** lanac puca — nalazi ispod sužavaju na dva mjesta, ostaje ih potvrditi
      pokretanjem, ne samo čitanjem
- [ ] **Admin nikad ne registruje staff uređaj** — `PUSH_ENABLED` je na `false` jer su oba
      `FIREBASE_*_DEFINES_FILE` u `.env.live` prazna, a `.firebase-config/` ima samo klijenta
- [ ] **`auto` mod guši i preostale dvije putanje** — `queue_appointment_push` na `INSERT` traži
      `status = 'pending'`, a tip `confirmed` traži *promjenu* statusa; u `auto` modu nema nijednog
- [ ] Dokaz iz `notification_logs` — red sa `status`, `attempts` i `error` nakon popravke
- [ ] Obavijest stigla na Android emulator ili uređaj, sa snimkom
- [ ] Ako je uzrok konfiguracija (Firebase app za `ba.nasadomena.admin`), zapisati u `workflows.md`

## Napomene uz 39

Nalazi su iz čitanja koda i **read-only upita nad hostovanim projektom** (`olggovhqwirxamggkwuf`),
prije ijedne izmjene.

- **Transport radi — kvar je uzvodno od FCM-a.** `cron.job` `send-push-queued` je `active`, oba
  vault tajna (`push_worker_url`, `push_worker_secret`) postoje, a svih **24 redova u
  `notification_logs` su `sent`, `attempts = 1`, `error = null`**. Nijedan red nije `failed` ni
  `sending`. Ne troši dan na `send-push` i odgovor FCM-a — lanac ne dolazi dotle.
- **Red se prestao puniti 2026-09-16 22:44.** Aplikacija je 2026-09-21 napravila **17 `app`
  termina**, a `notification_logs` za njih nema **nijedan** red. To je tačka prekida.
- **Tipa `new_request` nema nijednog, ikad.** Postoje samo `confirmed` (17), `rejected` (6),
  `cancelled` (1) — sve ka klijentu. Salon nije dobio obavijest o novoj rezervaciji od početka.
- **U `devices` je tačno jedan red, i to klijentski** (`android`, `staff_user_id is null`,
  `last_seen_at` 2026-09-16). Staff uređaja nema, pa grana `v_staff` u `queue_appointment_push`
  bira nula redova bez obzira na sve ostalo.
- **Zašto ga nema:** `apps/admin/lib/main.dart:20` uredno postavlja `pushStaffProvider` na `true`,
  ali `pushServiceProvider` vraća `null` dok je `pushEnabledProvider` `false`, a on visi o
  `const bool.fromEnvironment('PUSH_ENABLED')`. `tool/run_live_demo.sh` dodaje
  `--dart-define-from-file` samo ako je `FIREBASE_ADMIN_DEFINES_FILE` neprazan — **u `.env.live` su
  prazna oba**, i klijentski i admin. `.firebase-config/` sadrži samo `barberstudiovitez.json`.
  Admin ima svoj `applicationId` (`ba.nasadomena.admin`), pa traži **zasebnu Firebase Android app**
  u projektu, ne kopiju klijentskog fajla.
- **Drugi prekid je logički, ne konfiguracijski.** Salon `Barber Studio VItez` je u
  `salon_settings.booking_mode = 'auto'`. Trigger `queue_appointment_push`:
  - na `INSERT` odustaje ako `status <> 'pending'` → u `auto` modu nema `new_request`;
  - `confirmed` šalje samo kad se `status` **promijeni** → u `auto` modu termin je `confirmed` već
    na `INSERT`, pa **ni klijent ne dobije potvrdu**.

  Isti nalaz stoji u status bloku taska 37 (`sprint-4/README.md`). Popravka je vjerovatno novi
  uslov u trigeru, ne u aplikaciji — to je **migracija**, znači `security.md` + `supabase test db`.
- **Zamka iz task fajla i dalje važi:** `devices.device_id` je instalacioni identifikator (`text`),
  `appointments.device_id` je FK na `devices.id`. Zamjena prolazi tipove i tiho lomi push.
- **`booking_mode` je na `salon_settings`, ne na `salons`.** Upit po `salons.booking_mode` pada.
- **Tajne su čiste:** `.firebase-config/` i `.dart_tool/` su u `.gitignore`, `git ls-files` ih ne
  vraća. Izlaz `supabase status -o env` i dalje ne ide ni u commit ni u sažetak.
- **Korigovana procjena:** posao je bliži gornjoj granici. Dva nezavisna uzroka, jedan traži
  migraciju i pgTAP, drugi Firebase registraciju admin aplikacije — a taj drugi je **izvan repoa**
  i može čekati na tuđi pristup Firebase konzoli.
- **iOS ostaje imenovan dug** dok nema Apple developer naloga. Nije dio DoD-a.

## Šta je sljedeće

`/task start 39` — grana `fix/push-na-androidu` sa svježeg `main`-a. Prvi korak je potvrditi
`auto`-mod prekid lokalno (pgTAP koji ubaci `app` termin u `auto` salonu i očekuje red u
`notification_logs`), jer se taj dio dokazuje bez Firebase naloga.

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
