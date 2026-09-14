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

## Status (2026-09-14)

🟡 **Backend i ekran napisani i dokazani testovima; živi dokaz na ekranu nije odigran.**
Grana `feat/admin-akcije-nad-terminima`, [PR #42](https://github.com/htuco/salon-booking-platform/pull/42).

### Dokazano

- **220 pgTAP testova** (bilo 177), 42 nova u `008_admin_akcije.test.sql`. Provjereno da mogu
  pasti: vraćanjem `insert`/`update` granta padne sedam asercija u tri fajla.
- **508 Dart testova** (bilo 479) — `core_api` 91→109, `admin` 16→27. Čista analiza u pet paketa.
- **Oba CI joba zelena iz čistog checkouta**: `Schema, RLS and tenant isolation` i
  `Analiza, format i testovi`.

### Šta zatvara

`security.md` je rupu vodio ovako: *„direktan admin `insert`/`update` nad `appointments` zaobilazi
validaciju slota"*. **Zatvorena je oduzimanjem granta, ne dodavanjem funkcija** —
`revoke insert, update on public.appointments from authenticated`. Dok je grant stajao, validirane
funkcije su bile konvencija koju je bilo dovoljno zaboraviti. `select` i `delete` ostaju.

### Odluke koje nisu bile u task fajlu

- **Admin izuzetak vrijedi samo za `min_advance_booking_hours`**, kroz peti argument
  `get_available_slots`. Salon upisuje klijenta koji stoji na vratima; prag je pravilo prema
  klijentu, ne fizičko ograničenje salona — isti oblik kao `min_cancel_hours`. Radno vrijeme,
  pauze, blokade i preklapanje vrijede i adminu.
- **Ručni termin je odmah `confirmed`**, ne `pending`: kad salon sam upisuje termin, odgovor je sam
  upis. Ostavljen `pending` bi istekao kroz `pending_expires_at`.
- **`no_show_count` dobija pisca, ne čitaoca.** Prag („tri nedolaska u šest mjeseci") namjerno nije
  provođen — pravilo vertikale, Sprint 3. Brojač se puni sada da statistika ne počne od nule.
- **Otkazivanje ostaje u `cancel_appointment`.** `set_appointment_status` ga odbija sa `PT400`:
  dvije funkcije koje pišu isti status bile bi dva mjesta gdje se pravilo o roku može razići.

### Zamke nađene pokretanjem, ne čitanjem

1. **`create or replace` sa novim parametrom pravi preopterećenje, ne zamjenu.** Obje verzije
   `get_available_slots` su ostale u bazi, obje sa grantom; PostgREST bira po imenima argumenata, pa
   bi poziv bez `p_ignore_min_advance` išao na staru funkciju i ručni unos bi tiho radio po starom
   pravilu. Migracija zato ima `drop function if exists` **prije** `create`. Nađeno upitom nad
   `pg_proc` — migracija je prošla čisto i ništa nije ukazivalo na problem.
2. **Prvi test admin izuzetka je bio zelen samo ujutro.** Tražio je slot „za pola sata" i pao u
   18:13, jer salon radi do 17:00 — bez veze sa pragom koji testira. Isti rod greške koji je task 17
   našao kod tri zatečena testa. Sada mjeri razliku između dva poziva nad istim danom.
3. **`TextEditingController` dispose-ovan dok dijalog još animira zatvaranje** — `finally` se
   izvrši čim `showDialog` vrati. Dijalog je zato vlastiti `StatefulWidget`.
4. **`AlertDialog` sa `TextField` i `maxLength` prelio se za 99672px.** `AlertDialog` ne ograničava
   visinu sadržaja; dodan `SingleChildScrollView` na oba mjesta.
5. **`MockClient` odgovor bez `request:` puca u `postgrest`-u** (`response.request!.method`), i
   `guard` to pretvori u `MappingError` koji izgleda kao razilaženje modela i šeme.

### Ostalo za sljedećeg

- 🔴 **Živi dokaz na admin ekranu nije odigran, ni na jednom tenantu.** Docker servis
  (`com.docker.service`) je pao usred taska i traži administratorske ovlasti za pokretanje, koje
  ova sesija nema. Sve što je dokazano je dokazano testovima i CI-jem.

  Nastavlja se ovako:

  ```sh
  # Docker Desktop mora biti pokrenut kao administrator
  npx supabase start && npx supabase db reset
  cd apps/admin
  eval "$(npx supabase status -o env)"
  flutter run -d chrome \
    --dart-define=SUPABASE_URL="$API_URL" \
    --dart-define=SUPABASE_ANON_KEY="$ANON_KEY"
  ```

  Prijava: `admin@barberstudiovitez.test` / `admin123456`, pa isto sa
  `admin@beautystudiotravnik.test` — drugi vlasnik, nijedan tuđi termin.

  **Šta treba vidjeti, jer testovi to ne mogu:** da se lista poslije akcije stvarno osvježi (a ne
  samo da `invalidate` bude pozvan), da ručni unos od pet koraka stane na ekran bez preliva, i da
  slotovi u koraku 5 nisu prazni — `adminServicesProvider` je nov i nijednom nije pogodio pravu
  bazu.

- 🟡 **Nijedan Deno REST test nije dodan** — `deno` nije instaliran na ovoj mašini. pgTAP glumi
  claimove kroz `set_config` i nikad ne prolazi kroz PostgREST, pa **prevod `PT400`/`PT409` u HTTP
  400/409 nije dokazan**. Isti rod rupe koji je task 23 našao sa GoTrue prijavom: cijela pgTAP suita
  je prolazila, a prijava je padala sa `500`.

- 🟡 **`cancel_reason` nosi obrazloženje svake akcije**, ne samo otkazivanja — odbijanje i no-show
  su isti podatak („zašto termin nije održan"). Ime kolone je sada usko. Alternativa je nova kolona,
  ali bi to značilo dva mjesta koja admin ekran mora čitati.
