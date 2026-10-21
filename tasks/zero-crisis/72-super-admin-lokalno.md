# Task 72 — Super admin konzola, lokalna i minimalna

| | |
|---|---|
| **Procjena** | 4–5 dana |
| **Zavisi od** | — |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | ADR-0029 · `docs/01` §6.1 · skill `/new-tenant` · `tenants/_template/` |

## Cilj
Novi salon bez ručnog `tenant.yaml` i SQL-a. Alat radi **samo na mašini developera**, nikad se ne
deploya, i ima mali ali jasan UI.

## Odluke prije koda (ADR)
- Tehnologija: Flutter desktop/web (dijeli `core_ui`) ili mali lokalni web alat
- Da li piše `tenants/<flavor>/tenant.yaml` i pokreće generatore, ili samo bazu (pa se fajl generiše)
- Gdje stoji service role ključ (`.env.live`, nikad u repo)

## Definicija gotovog
Dokaz za svaku stavku je u statusnim blokovima ispod (2026-10-20 Eniz, 2026-10-21 popravke iz
reviewa).

- [x] Lista salona sa statusom (aktivan, build, store) — uživo 1440 i 402 (10-20); uživo curl i
      Playwright poslije F5 (10-21)
- [x] Novi salon: ime, flavor, vertikala, tema, boje → red u bazi + `tenant.yaml` + generatori —
      uživo oba dana. **Logo** salona je po prihvaćenom ADR-0032 §2 van konzole (vlasnik ga
      stavlja u Meluri, task 50); konzola prima ikonu aplikacije
- [x] Admin nalog vlasnika kroz poziv (kod), ne ručni SQL — `accept-staff-invite` uživo (10-20);
      povlačenje i „novi poziv gasi stari" uživo i pgTAP (10-21)
- [x] Deaktivacija salona; promjena boja i teme — uživo (10-20); boje i tema sa `splashBackground`
      uživo (10-21)
- [x] Status store objave (`draft` → `in_review` → `live`) — uživo Play `in_review` (10-20)
- [x] Dokumentovano u `tenant-factory.md` i skillu `/new-tenant` — i tok „UUID po okruženju"

## Status (2026-10-21) — popravke iz reviewa

Hamza je pročitao review PR-a #143 i odlučio: popravke idu commitovima na istu granu, pa merge.
ADR-0032 je **prihvaćen**. Šta je promijenjeno i čime je dokazano:

- **UUID po okruženju (blokiralo).** `platform_create_salon(..., p_id uuid default null)`; konzola
  fajl bez reda u bazi nudi „Upiši u ovu bazu iz tenant.yaml" (isti UUID, fajl i generisano se ne
  diraju). Uživo: novi „Probni Salon" → `supabase db reset` → „Upiši" vratio isti
  `c8e8e9dd-…`, drugi put `409 Salon sa ovim UUID-om već postoji u ovoj bazi`, md5 fajla i
  `git status` isti, „fajl ≠ baza" prazno.
- **Poziv platforme se povlači**, a novi poziv povlači prethodni (`platform_revoke_owner_invite`,
  dugme „Povuci poziv"). Uživo: peek prvog koda poslije drugog poziva 0, drugog 1; poslije
  „Povuci" 0; ponovno povlačenje 404.
- **Flavor `test*`, `lint`, `main`, `debug`, `profile`, `release`** odbijaju baza i
  `gen_flavors.dart`. Uživo „Test Salon" → `400 Flavor ne smije počinjati sa „test"…`.
- **F5**: stranica se daje bez tokena (statičan HTML bez tajne), token je u `sessionStorage`, API
  bez tokena i dalje 403. Uživo (Playwright) F5 na `/` učita 7 salona, 0 grešaka u konzoli.
- `security.md` ispravljen: `super_admin` JWT **i dalje** pravi poziv vlasnika kroz
  `create_staff_invite` i piše `salon_builds` kroz `super_builds` — otvorena rupa, zatvara se
  zasebnim taskom; `034` je drži kao `lives_ok`.
- Sitnice: katalog-asercija za sve `platform_*`; `zamijeniBranding` (komentar uz `branding:`,
  komentar na kraju linije, samo direktna djeca, jednostruki navodnici, splash prati boju kojoj je
  bio jednak); kontrolni znakovi odbijeni u bazi (i u `update_salon_contact`) i escapeovani u
  fajlu; `private.new_invite_code()` dijele oba poziva; teme samo u bazi
  (`platform_list_themes`), sinhronizacija sa `core_ui` i defaulti generatora drže se testom koji
  pokreće pravi `gen_flavors.dart`; `--env` od trenutnog foldera; ime projekta je ref za
  `*.supabase.co`, inače cijeli host; pad ikone je svoj korak, plus „Ponovi generatore".

Dokaz: `supabase db reset && supabase test db` — `Files=33, Tests=1038, Result: PASS` (`034` 95
asercija, bilo 57; `020` zelen poslije redefinicije `create_staff_invite`). Mutacije u `034`:
grant `authenticated`-u na `platform_revoke_owner_invite` obara 2, grant na `new_invite_code` 1,
`is_reserved_flavor → false` 3, ignorisan `p_id` 2, bez povlačenja prethodnog poziva 5, bez
zabrane kontrolnih znakova 3, povlačenje bez `created_by is null` 1, bez filtera po salonu
(povlačenje prethodnog, lista) 2 i 2. REST: `rest_isolation` 24,
`rest_public_catalog` 59, `rest_pozivi_osoblja` 17, `rest_admin_login` 14 — svi PASS.
`apps/superadmin` 46 testova (bilo 28); mutacije generatora, defaulta i liste tema obaraju
`sinhronizacija_test`, a šest mutacija `zamijeniBranding`/`_navodnici` svaka svoj test.
`gen_flavors --check` zelen sa 6 tenanta (probni tenant obrisan).

**Ostalo za sljedećeg:**
- Hamza: merge, pa `supabase db push` (`20261020180000`) i provjere iz opisa PR-a.
- Zaseban task: zatvoriti `super_admin` JWT put kroz `create_staff_invite` i `super_builds`.
- Konzola i dalje nije pokrenuta na macOS-u sa iOS tenantom ni protiv hostovanog projekta.

## Status (2026-10-20)

U toku, grana `feat/super-admin-konzola`. Odluke prije koda su u
[ADR-0032](../../docs/adr/0032-super-admin-lokalni-dart-server.md) (tada **predložen**):
lokalni Dart server (`apps/superadmin`), baza prva pa `tenant.yaml` pa generatori, ključ iz
`supabase status` ili `--env` fajla, i samo u procesu servera.

DoD, stavka po stavku:

- [x] **Lista salona sa statusom** — baza (`platform_list_salons`: status, paket, oba storea,
      broj vlasnika i otvorenih poziva), fajl (postoji li `tenant.yaml`, slaže li se sa bazom) i CI
      (flavor u `build-flavors`, `build-ios`, `release-artifacts`). Viđeno uživo, 1440 i 402.
- [x] **Novi salon** — ime, grad, vertikala, tema, boje, ime aplikacije, flavor, slug, paket,
      ikona (PNG ≥ 1024, kvadrat), iOS. Uživo: red u bazi → `tenant.yaml` sa istim UUID-om →
      `gen_flavors`, placeholder ikona i `flutter_launcher_icons` zeleni → `gen_flavors --check` zelen.
      **Logo salona** namjerno nije ovdje: mijenja se bez store reviewa, pa ga vlasnik stavlja u
      Meluri (task 50). Konzola prima ikonu aplikacije, koja je build artefakt (ADR-0032 §2).
- [x] **Admin nalog vlasnika kroz poziv** — `platform_create_owner_invite` (`created_by = null`).
      Uživo: kod iz konzole → `accept-staff-invite` → prijava daje `salon_admin` za novi salon; isti
      kod drugi put odbijen.
- [x] **Deaktivacija; boje i tema** — uživo: salon `inactive`, anon ga više ne vidi; boje i tema u
      bazi, `tenant.yaml` (samo tri linije, komentari ostaju) i `tenants.g.dart`.
- [x] **Store status** — Play i App Store odvojeno; uživo Play `in_review`, App Store ostaje `draft`.
- [x] **Dokumentovano** u `tenant-factory.md` i `/new-tenant`, plus `security.md`,
      `IMPLEMENTATION.md`, `architecture.md`, `workflows.md`, `CONTEXT.md`, `tenants/README.md`.

Dokaz: pgTAP `034` 57 asercija (cijela suite 1000); tri mutacije (grant za `authenticated`,
provjera aktivnog salona, pre-provjera sluga) obaraju 2, 3 i 1. REST `rest_isolation`,
`rest_public_catalog`, `rest_pozivi_osoblja`, `rest_admin_login` zeleni. `apps/superadmin` 28
testova (host, token, origin, potvrda projekta, `tenant.yaml`, CRLF, CI matrica, ikona).

**Ostalo za sljedećeg:**
- Hamza: odluka o ADR-0032, pa `supabase db push` (`20261020180000`).
- Konzola nije pokrenuta na macOS-u ni sa iOS tenantom. `gen_ios_flavors.sh` ostaje ručni korak
  koji konzola samo navodi.
- Konzola nije pokrenuta protiv hostovanog projekta: `.env.live` nema service ključ (namjerno), a
  produkcijski env fajl je task 80. Potvrda imenom projekta je dokazana samo testom servera.
