# Task 61 — Moj profil u adminu

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | 46 (radnik i veza `employee_id`), 48–51 (bucket, trigger i sweep) |
| **Blokira** | — |
| **Reference** | `prototype/adminv2/profil/` (`4a`–`4e`, `README.md`) · `.claude/docs/security.md` §Moj profil |

## Cilj
Vlasnik i radnik uređuju **svoj** nalog: ime, telefon, profilnu sliku, lozinku i sesije. Profilnu
sliku mogu dati salonu kao sliku sebe kao radnika, pa je klijent vidi pri izboru majstora.

## Obim: jedan salon po nalogu
Handoff crta listu članstava („Barber Studio Vitez — Vlasnik", „Amko Barbershop — Zaposlen") i
glavni prekidač „Koristi svuda". Nalog osoblja ovdje pripada **jednom** salonu
(`public.users.salon_id`, ADR-0023 odbija email koji već ima nalog), pa je lista jedan red, a
„Koristi svuda" se ne crta. Više salona po nalogu znači tabelu članstava, preradu
`private.is_admin()` i RLS-a i izbor salona u adminu. To je zaseban posao sa ADR-om, ne ovaj
task.

## Definicija gotovog
- [x] Meni korisnika u sidebaru (`4a`): zaglavlje sa slikom, imenom i mailom, „Moj profil",
      „Promijeni sliku" (otvara izbor odmah), „Odjavi se" crveno; ▴ dok je otvoren, aktivan stil
      na `/profile`
- [x] `/profile` na desktopu (`4b`) i telefonu (`4d`), sheet slike na telefonu (`4e`), red osobe
      na vrhu „Još" (`4c`). Ruta je otvorena i radniku
- [x] Profilna slika: JPG/PNG/WebP, najmanje 400×400, krug, bez slike inicijali
- [x] Prekidač „Koristi u salonu" upisuje profilnu sliku u povezanog radnika i vraća salonsku kad
      se ugasi ili kad se slika ukloni. Vlasnik bez veze bira „Ja sam radnik…"
- [x] Ime i telefon na „Sačuvaj" (ugašeno dok nema izmjene), prekidač i slika odmah
- [x] Promjena lozinke uz ponovnu prijavu trenutnom; „Odjavi sve uređaje" uz potvrdu
- [x] Migracija + pgTAP sa negativnim slučajevima i sabotažom; sweep i trigger iz taska 51 znaju
      za nove kolone
- [x] Migracija na hostovanom projektu (`supabase db push`, 2026-10-01, prije merge-a — testirano na Amku)
- [ ] Viđeno na fizičkom telefonu (kamera, galerija)

## Odstupanja od handoffa
- **Ime i prezime su jedno polje** i na desktopu. Baza čuva `name`; rastavljanje bi pogađalo za
  svako ime od tri riječi.
- **Email „Promijeni"** nije link: promjena emaila traži potvrdu na novu adresu i SMTP (handoff to
  i sam stavlja van obima).
- **Kvadratni crop** se ne radi u aplikaciji. Slika se prikazuje kao krug sa `BoxFit.cover`; crop
  bi tražio novi paket.

## Zamke
- `users` ima grant za `update` od init šeme, ali nema politiku. Direktan update pogađa 0 redova
  bez greške. Politika „mijenjam svoj red" bi pustila i `role`; zato je sve RPC.
- Nova slikovna kolona mora i u `media_orphans` i u trigger (task 51). Bez toga sweep briše i
  profilnu sliku i sačuvanu salonsku dan poslije.
- `flutter test` demo prolaz kroz sve rute na 402 px je našao overflow koji ekran na pravom
  vlasniku nije pokazao: demo vlasnik nema vezu, pa „Ja sam radnik…" ne staje u red.

## Status
U toku (grana `feat/admin-moj-profil`, 2026-10-01).

Dokazano lokalno: `tool/test_supabase.sh` od nule, pgTAP 770 PASS (od toga 54 u `025`) i svi
REST/Deno testovi. Sabotaže u `025`: helper URL-a na `true` obara 7, politika bucketa samo na
`bucket_id` 6, `is_staff` na „bilo ko prijavljen" 4. Admin `flutter test` 479 PASS, `analyze`
čist. Uživo protiv lokalnog Supabasea na 1440 i 402: meni, upload kroz fajl dijalog, veza
vlasnik → Amar, prekidač (u bazi `employees.image_url` = profilna, `salon_photo_url` = stara),
snimanje telefona, pogrešna i ispravna lozinka (GoTrue hash promijenjen), odjava ostalih.

Poslije revizije (`rls-auditor`, `dart-reviewer`): host profilne slike iz `iss` claima, trigger
pri brisanju naloga, vraćanje salonske slike i kad je objekat obrisan, jedan regex nad imenom
objekta; `025` sada 74 asercije, pet novih sabotaža obara 2/1/2/2/6. Lozinka u dva koraka,
`membership()` čita `*` da build ne obori prijavu na bazi bez migracije.

Hostovani: `supabase db push` kroz Session pooler (`aws-1-eu-west-1`), samo `moj_profil`. Viđeno
uživo na Amko Barbershop: upload profilne slike, veza sa radnikom, prekidač.

**Ostaje:** telefon sa kamerom.
