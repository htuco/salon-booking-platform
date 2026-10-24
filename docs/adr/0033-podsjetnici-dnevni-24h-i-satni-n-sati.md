# Podsjetnici: dnevni tačno 24 h prije, satni N sati prije, dva prekidača

## Status

prihvaćen (2026-10-21) — Hamzine odluke za task 56. Dvije stvari u odjeljku „Prijedlog, potvrdi"
su podrazumijevane vrijednosti koje je uveo task, a ne Hamzine odluke; čekaju potvrdu u reviewu
PR-a.

## Kontekst

`docs/01` §6.2 traži podsjetnik dan prije (D-1) i tri sata prije (H-3), a enum
`notification_type` ima `reminder_d1` i `reminder_h3` od init šeme. Do taska 56 ih niko nije
pravio: `send-reminders` je bio samo README, `send-push` je za oba tipa bacao `unsupported_type`,
a admin Postavke su crtale dva ugašena prekidača („24 sata prije" i „sat prije") nad jednom
kolonom `salon_settings.reminders_enabled`.

Otvorena su bila dva pitanja: kad tačno ide D-1 (24 h prije ili fiksan sat dan prije u zoni
salona) i da li salon ima jedan prekidač ili dva.

## Odluka

**Dnevni podsjetnik ide tačno 24 h prije početka termina.** U Meluri ga salon samo uključi ili
isključi. Kolona ostaje postojeći `salon_settings.reminders_enabled` (podrazumijevano `true`);
od ovog taska ona znači samo dnevni podsjetnik.

**Satni podsjetnik ide N sati prije početka, a N bira salon** (1 h, 2 h, 3 h …;
podrazumijevano 3 h). U Meluri ima svoj prekidač i izbor N. Nove kolone su
`hourly_reminder_enabled` (podrazumijevano `true`) i `hourly_reminder_hours` (podrazumijevano 3,
sa `check` granicom).

**Enum se ne mijenja.** Satni podsjetnik je i dalje `reminder_h3`, i kad je N različit od 3.
Preimenovanje vrijednosti enuma bi tražilo migraciju svih već upisanih redova i istovremenu
promjenu klijenta (lista Obavijesti čita tip), a ime nosi samo istoriju.

**Prijedlog, potvrdi** (uveo task 56, nije Hamzina odluka):

1. **N je 1–12 sati.** Više od 12 se preklapa sa dnevnim i nije više „isti dan".
2. **Podsjetnik se ne šalje za termin zakazan ili potvrđen kasnije od trenutka podsjetnika.**
   Termin zakazan 2 h prije početka ne dobija satni od 3 h, a termin zakazan danas za sutra, u
   roku kraćem od 24 h, ne dobija dnevni. Zahtjev koji salon potvrdi kasnije od trenutka
   podsjetnika ga takođe ne dobija: klijent je upravo dobio „Zahtjev je potvrđen". Za to
   `appointments` dobija `confirmed_at`. Podsjetnik se nikad ne šalje poslije početka termina.

## Razmatrane opcije

- **D-1 u fiksan sat dan prije (npr. 18:00 u zoni salona)** — odbačeno (Hamza): 24 h prije je
  pravilo koje klijent razumije bez objašnjenja, a ne traži novu postavku.
- **Jedan prekidač za oba podsjetnika** — odbačeno (Hamza): salon koji ne želi poruku tri sata
  prije ne mora izgubiti dnevnu.
- **Novi enum `reminder_hours`** — odbačeno: v. „Enum se ne mijenja".
- **Kasni podsjetnik sa tekstom „za N sati" iz postavke** — odbačeno: ako cron ili worker kasne,
  ili salon promijeni N dok red čeka, tekst laže. Tekst satnog računa preostale minute pri slanju.

## Posljedice

- Podsjetnike pravi `private.queue_reminders()` u bazi, `pg_cron` posao `queue-reminders`
  svakih 5 minuta, a šalje ih postojeći put (`dispatch_push` → `send-push`). Edge Function
  `send-reminders` ne postoji; njen README to kaže.
- Dnevni se šalje od trenutka 24 h prije do ponoći pred dan termina (zona salona). Poslije
  ponoći bi „sutra" u tekstu bila laž, pa red koji zakasni ide u `logged`.
- `claim_push_notifications` red podsjetnika ne šalje ako termin više nije `confirmed`, ako je
  počeo, ako je salon ugasio taj podsjetnik ili ako je dnevni zakasnio preko ponoći.
- Promjena N vrijedi za termine kojima trenutak podsjetnika još nije prošao. Red koji već čeka
  ostaje.
- Ako se odluka 1 ili 2 promijeni u reviewu, mijenja se `check` granica i uslov nad
  `confirmed_at`/`created_at` u `queue_reminders`, ne enum ni klijent.
- Pomjeranje termina danas ne postoji (task 54). Kad dođe, mora obrisati ili ponovo napraviti
  redove podsjetnika, jer unique `(appointment_id, device_id, type)` inače drži stari.
