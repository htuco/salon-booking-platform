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
- **Pregled u grani (2026-10-20):** `rls-auditor`, `dart-reviewer`, `flutter-ui-reviewer`.
  - **[VISOKO] popravljeno:** `auth_identity_id` i `appointment_id` su bili javni kroz
    tabelarni grant. Vlasnik salona A je po identitetima svojih klijenata mogao naći njihove
    recenzije u salonu B. Grant je sada kolonski, bez te dvije kolone. „Moje ocjene" idu kroz
    `my_review_ratings()`, a politika `client_own` je uklonjena. `rest_public_catalog.ts` bez
    tokena dobija 401/403 za obje kolone.
  - **Testovi:** brisanje naloga ne dira tuđu recenziju ni seed; radnik ne vidi sakrivenu i ne
    vraća je.
  - **Klijent:** javna lista filtrira `is_published` (vlasnik u klijentskoj app-i). Sirova poruka
    baze ne ide na ekran: `PT400` je „Ovaj posjet još nije označen završenim.", `42501` ima svoju
    rečenicu, a u obje prijave ide `displayMessage`. Zvjezdice imaju stanje izbora za čitač
    ekrana, „Prijavi" nosi autora, a sheet prijave ima skrol.
  - **Tekstovi bez „termin" / „klijent":** push „Ocijenite posjet u aplikaciji." i prijava
    „stvarna osoba".
  - **Melura:** kartice imaju ključ po recenziji, a dugme labelu sa autorom.
  - **Svjesno ostavljeno:** „ne salonu" u tekstu prijave (isto kao kod slike), „Klijent" u
    Meluri (cijeli admin tako piše), zvjezdice ★ u Meluri (admin nema `core_ui`), snimci na beauty
    i health temi.
- **Dokaz:** `tool/test_supabase.sh` → pgTAP `Files=32, Tests=943 … Result: PASS`, katalog 59
  provjera, svi REST i Deno testovi („Sve prolazi"). `032` ima 55 asercija, a svaka od 11
  mutacija obara bar jednu (tabela u `security.md`). `deno test` za `send-push` i
  `notify-content-reports`: 11 passed. `melos run test`: admin 689, client 676, `core_api` 151,
  `core_domain` 102, `core_ui` 146. `melos run analyze` SUCCESS, `dart format` bez izmjena,
  `tenant_theme_test` prolazi za oba salona. Admin upit iz aplikacije pod pravim JWT-om: `HTTP
  200, 26 redova, sakrivenih 1`, a `select=auth_identity_id` daje `403`.
- **Uživo (lokalni stack, web, 402 px):** klijent Lejla (GoTrue signup, rezervacija kroz
  `book_appointment`) → Melura „Potvrdi" → „Označi kao završeno" → klijent „Prošli" → „Ocijeni"
  (4 + tekst). Baza bilježi `Lejla H.|4|Brzo i uredno…|t|<termin>`, a broj ocjena raste sa 25 na
  26 (zaokružen prosjek ostaje 4,8). U Meluri „Sakrij" → `is_published = f`, tekst i ocjena ostaju
  isti, a javni broj se vraća na 25. Snimci: `docs/screenshots/task-67-ocjena-sheet.png`,
  `task-67-melura-recenzije.png`.
- **Pregled (Hamza, 2026-10-20):**
  - **Melura nije vidjela dio javnih recenzija.** Admin je uzimao 50 najnovijih svih vrsta, a
    klijent 50 najnovijih objavljenih sa tekstom; nove gole ocjene su potiskivale starije javne
    tekstove, koje salon onda nije mogao sakriti. `StaffReviewRepository.forSalon` sada spaja
    klijentski upit (`ReviewRepository.forSalon`, isti filter i granica) i 50 najnovijih ostalih,
    pa je svaki javno prikazan red u Meluri po konstrukciji. Test u `review_repository_test.dart`
    pada na starom upitu.
  - **Dužina teksta se broji kao u bazi.** `maxLength` je brojao grafeme, a `char_length` kodne
    tačke; „👍🏽" × 600 je prolazio ekran i vraćao `PT400`, koji sheet čita kao „nije završen".
    Sheet sada reže u kodnim tačkama i brojač pokazuje isti broj; test pada sa `maxLength`.
  - **Jedna prijava sadržaja.** `features/moderation/report_content_action.dart`
    (`prijaviSadrzaj`) nosi tok za sliku i recenziju; skrol za veliki font sada ima i prijava
    slike (test na 200 % fonta pada bez skrola).
  - **Dokumenti:** redoslijed deploya ispravljen (funkcije prije migracije, pravilo u
    `workflows.md`), recenzije u `docs/06` §8.2–8.3 i u lokalnom seed tekstu privatnosti (uz
    telefon iz taska 66), `security.md` broji 11 mutacija kao tabela.
- **Ostalo za sljedećeg:**
  - Hamza, deploy, **ovim redom**:
    0. `select count(*) from public.reviews where char_length(comment) > 1000;` → `0` (inače
       `reviews_comment_duzina` obara migraciju).
    1. `supabase functions deploy send-push notify-content-reports`. Nove funkcije rade i nad
       starom šemom: `notify-content-reports` red bez `review_id` šalje granom slike. Obrnuto
       (migracija prva) stari `send-push` na `review_request` baci `unsupported_type`, red
       završi `failed` bez ponavljanja i „Kako je bilo?" je izgubljen.
    2. `supabase db push` za `20261020100000`.
    3. `select has_column_privilege('anon','public.reviews','auth_identity_id','select');` → `f`
       i `select has_function_privilege('anon','public.submit_review(uuid,integer,text)','execute');`
       → `f`.
    4. Ručno: tekst politike privatnosti u hostovanom `app_policies` (recenzije, telefon — v.
       `supabase/seed.sql`) i store Data safety / App Privacy (`docs/06` §8.3).
  - Push `review_request` na uređaju (nema Android uređaja; dokazan je samo red u logu, kroz
    pgTAP).
  - Prijava recenzije koja stigne na webhook platforme (`REPORT_WEBHOOK_URL`, isto kao kod slike).
  - Svjesno van opsega: izmjena vlastite recenzije, rok za ocjenu poslije termina i odgovor salona
    na recenziju.
  - Van opsega iz pregleda (Hamza):
    - push `review_request` vodi na `/appointments`, ne direktno na tab „Prošli";
    - recenzija ostaje kad termin izađe iz `completed` (salon vrati status);
    - „Klijent" kao ime autora dolazi iz baze (`review_author`), ne iz `vertical.terms`;
    - `content_reports.review_id` nema kompozitni FK sa `salon_id`;
    - test anonimizacije sa istim identitetom u dva salona.
  - Admin lista ide do 50 javnih + 50 ostalih; starije gole i sakrivene van toga traže
    straničenje kad salon dođe do toga.
  - Apple 1.2 navodi i blokiranje korisnika; nemamo ga (`docs/06` §8.3).
