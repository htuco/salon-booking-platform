# Task 67 — Pisanje recenzija

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [66](66-registracija-ime-telefon-tos.md) |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | ADR-0029 · `20260914090000_reviews.sql` · `/reviews` (samo čitanje) |

## Cilj
Klijent ocjenjuje termin koji je stvarno imao. Tabela `reviews` danas nije vezana ni za termin ni za
klijenta (`author_name` je slobodan tekst), a admin u njoj može sve — i mijenjati tuđi tekst.

## Definicija gotovog
- [x] Migracija: recenzija vezana za **završen termin** i identitet; najviše jedna po terminu
- [x] Klijent: ocjena 1–5 i opcionalan tekst, iz „Moji termini" i iz pusha poslije termina
- [x] Salon **sakriva**, ali **ne mijenja** recenziju (politika `staff_manage` suzena)
- [x] Prijava neprikladne recenzije ide platformi (isti put kao slike, ADR-0024)
- [x] Prosjek i broj na Početnoj iz `salon_rating_summary`
- [x] pgTAP: bez završenog termina nema recenzije, druga za isti termin pada, salon ne mijenja tekst
- [x] `security.md` dopuna

## Status (2026-10-20)

Kod gotov, grana `feat/pisanje-recenzija`, [PR #139](https://github.com/htuco/salon-booking-platform/pull/139).

- **Oblik:** migracija `20261020100000_pisanje_recenzija`. Recenzija nosi `appointment_id` i
  `auth_identity_id` (kompozitni FK na termin istog salona, jedna po terminu). Pisanje ide samo kroz
  `submit_review` (svoj `completed` termin, `x-salon-id`, ime autora daje baza). Salon samo
  `set_review_published`, a `authenticated` nema `insert/update/delete`. `salon_rating_summary`
  broji samo objavljene. Prijava ide kroz `report_review` u `content_reports`. Push
  `review_request` šalje se kad termin postane `completed`. Brisanje naloga ostavlja ocjenu bez
  imena i teksta.
- **Klijent:** „Ocijeni" na kartici završenog termina u „Moji termini" otvara sheet (pet zvjezdica,
  tekst do 1000 znakova); ocijenjen termin pokazuje „Vaša ocjena". Na `/reviews` uz svaku karticu
  stoji „Prijavi recenziju". Dugme „Ostavi recenziju" na `/reviews` i dalje ne postoji, jer je
  recenzija vezana za termin (`prototype/ui/README.md`).
- **Melura:** `/more/reviews` je deveta stavka navigacije, iza Klijenata. Ekran ima samo „Sakrij"
  / „Vrati", bez polja za izmjenu.
- **Dokaz:** `tool/test_supabase.sh` → pgTAP `Files=32, Tests=931 … Result: PASS`, a svi REST i
  Deno testovi prolaze („Sve prolazi"). `032` ima 43 asercije, a svaka od 8 mutacija obara bar
  jednu (status, vlasništvo termina, agregat bez filtera, `client_own` bez salona, anonimizacija,
  push, zadržan `staff_manage`, prijava sakrivene). `deno test` za `send-push` i
  `notify-content-reports`: 11 passed. `melos run test`: admin 689, client 673, `core_api` 148,
  `core_domain` 102, `core_ui` 146. `melos run analyze` SUCCESS, `dart format` 0 changed,
  `tenant_theme_test` prolazi za oba salona.
- **Uživo (lokalni stack, web, 402 px):** klijent Lejla (GoTrue signup, rezervacija kroz
  `book_appointment`) → Melura „Potvrdi" → „Označi kao završeno" → klijent „Prošli" → „Ocijeni"
  (4 + tekst). Baza bilježi `Lejla H.|4|Brzo i uredno…|t|<termin>`, a broj ocjena raste sa 25 na
  26 (zaokružen prosjek ostaje 4,8). U Meluri „Sakrij" → `is_published = f`, tekst i ocjena ostaju
  isti, a javni broj se vraća na 25. Snimci: `docs/screenshots/task-67-ocjena-sheet.png`,
  `task-67-melura-recenzije.png`.
- **Ostalo za sljedećeg:**
  - Hamza, deploy: `supabase db push` za `20261020100000`, pa
    `supabase functions deploy send-push notify-content-reports`.
  - Push `review_request` na uređaju (nema Android uređaja; dokazan je samo red u logu, kroz
    pgTAP).
  - Prijava recenzije koja stigne na webhook platforme (`REPORT_WEBHOOK_URL`, isto kao kod slike).
  - Svjesno van opsega: izmjena vlastite recenzije, rok za ocjenu poslije termina i odgovor salona
    na recenziju.
