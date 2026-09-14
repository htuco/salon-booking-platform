# Task 24 — Admin: potvrda, odbijanje, otkazivanje i ručni termin

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [23](23-admin-login-i-lista.md) |
| **Blokira** | 25 (push se okida na ove akcije) |
| **Reference** | [01 §8](../../docs/01-mvp-spec.md) · [`.claude/docs/security.md`](../../.claude/docs/security.md) |

## Cilj
Salon odgovara na zahtjev. Bez ovoga termin ostaje `pending` dok ne istekne, i cijeli klijentski
flow visi u zraku.

## Definicija gotovog
- [ ] Akcije: **potvrdi / odbij / otkaži / no-show**, svaka kroz RPC sa provjerom vlasništva
- [ ] Ručno dodavanje termina, sa pretragom po `Customer` i unosom telefonskog klijenta
      (`auth_identity_id` ostaje `null`)
- [ ] **Ručni upis prolazi istu validaciju slota** kao klijentski — danas je to poznata rupa
      (`security.md`, "Šta još nije zatvoreno"): exclusion constraint hvata preklapanje, ali radno
      vrijeme, blokade i `min_advance_booking_hours` ne
- [ ] `cancel_reason` i `cancelled_by` se popunjavaju na svakoj akciji
- [ ] pgTAP: sve četiri akcije, plus odbijanje ručnog termina van radnog vremena

## Koraci
1. RPC funkcije + pgTAP prije ekrana
2. Ekran akcija, pa ručni unos
3. Commit: `feat(admin): akcije nad terminima i rucni unos`

## Zamke
- **Ovo zatvara rupu iz `security.md`.** Ako ručni unos ostane direktan `insert`, admin može
  napraviti termin koji availability engine nikad ne bi dozvolio.
- No-show je statistika za kasnije (`vertical.features.noShowTracking`) — polje se puni sada, ekran
  dolazi u Sprintu 3.

## Status (2026-09-15)

✅ **Gotovo i dokazano uživo na oba tenanta.**
Grana `feat/admin-akcije-nad-terminima`, [PR #42](https://github.com/htuco/salon-booking-platform/pull/42).

### Dokazano

- **220 pgTAP** (bilo 177), 42 nova u `008_admin_akcije.test.sql`. Provjereno da mogu pasti:
  vraćanjem `insert`/`update` granta padne sedam asercija u tri fajla.
- **515 Dart testova** (bilo 479) — `core_api` 91→109, `admin` 16→27, `core_domain` 74→81.
- **Uživo u browseru na oba tenanta**, protiv žive baze. Sve četiri akcije upisane i provjerene
  `psql` upitom, ne pretpostavkom:

  | Klijent | Status | `source` | `cancelled_by` | Brojač |
  |---|---|---|---|---|
  | Mujo Telefonski | `cancelled` | **`manual`** | `salon` | razlog „Nema frizera" |
  | Adnan Music | `completed` | `app` | — | `visit_count = 1` |
  | Emir Hodzic | `no_show` | `app` | `salon` | `no_show_count = 1` |
  | Amina Sabic (tenant B) | `confirmed` | `app` | — | rok isteka skinut |

  Slike: `docs/screenshots/task-24-akcije-barber.png` i `task-24-akcije-beauty.png` — ista
  aplikacija, druga prijava, **nijedan tuđi termin**.
- **Ručni termin je stvarno nastao iz aplikacije**: telefonski klijent kroz dijalog
  (`auth_identity_id` je `null`), pa termin sa `source = manual`.

### Šta zatvara

`security.md` je rupu vodio ovako: *„direktan admin `insert`/`update` nad `appointments` zaobilazi
validaciju slota"*. **Zatvorena je oduzimanjem granta, ne dodavanjem funkcija** —
`revoke insert, update on public.appointments from authenticated`. `select` i `delete` ostaju.

### Odluke koje nisu bile u task fajlu

- **Admin izuzetak vrijedi samo za `min_advance_booking_hours`**, kroz peti argument
  `get_available_slots`. Radno vrijeme, pauze, blokade i preklapanje vrijede i adminu.
- **Ručni termin je odmah `confirmed`**, ne `pending`: kad salon sam upisuje termin, odgovor je sam
  upis.
- **`no_show_count` dobija pisca, ne čitaoca.** Prag je pravilo vertikale, Sprint 3.
- **Otkazivanje ostaje u `cancel_appointment`** (`PT400` upućuje na njega), jer ono nosi rok.

### Šest grešaka koje je našlo pokretanje, ne čitanje

1. **`create or replace` sa novim parametrom pravi preopterećenje, ne zamjenu.** Obje verzije
   `get_available_slots` su ostale u bazi sa grantom; PostgREST bira po imenima argumenata, pa bi
   poziv bez `p_ignore_min_advance` tiho išao na staru funkciju. Migracija ima `drop function if
   exists` prije `create`. Nađeno upitom nad `pg_proc`.
2. **Prvi test admin izuzetka je bio zelen samo ujutro** — tražio je slot „za pola sata", a salon
   radi do 17:00. Sada mjeri razliku između dva poziva nad istim danom.
3. **`TextEditingController` dispose-ovan dok dijalog još animira zatvaranje.**
4. **`AlertDialog` sa `TextField` i `maxLength` prelio se za 99672px.**
5. **`MockClient` odgovor bez `request:` puca u `postgrest`-u** (`response.request!.method`).
6. **Ručni unos je crtao duplirana vremena — `09:00 09:00 09:15 09:15…`** Vidjelo se **tek na
   ekranu**: `get_available_slots` vraća red po **radniku**, pa za „bilo koji" isto vrijeme dođe
   dvaput. `distinctTimes` postoji od taska 11 i nosi komentar koji tačno opisuje zamku, ali
   **nije imao nijedan test** — sada ima sedam (`available_slot_test.dart`), provjerenih da padnu
   kad se `toSet()` ukloni. Uz to ekran više ne uzima `employeeId` iz slota: kod „bilo koji" bi to
   značilo da ekran tiho bira radnika umjesto korisnika.

### Ostalo za sljedećeg

- 🟡 **Nijedan Deno REST test nije dodan** — `deno` nije instaliran na ovoj mašini. pgTAP glumi
  claimove kroz `set_config` i nikad ne prolazi kroz PostgREST, pa **prevod `PT400`/`PT409` u HTTP
  400/409 nije dokazan**. Isti rod rupe koji je task 23 našao sa GoTrue prijavom.
- 🟡 **`cancel_reason` nosi obrazloženje svake akcije**, ne samo otkazivanja. Ime kolone je usko;
  alternativa je nova kolona, ali bi to bila dva mjesta koja admin ekran mora čitati.
- 🟡 **Admin nije pokrenut na mobilnom uređaju** — dokaz je iz Chromiuma, kao i u tasku 23.
- Push (`notification_logs`) nije dodan; `set_appointment_status` ima označeno mjesto gdje ga
  [task 25](25-push-notifikacije.md) upisuje bez prepravke funkcije.
