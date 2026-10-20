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
- [ ] Lista salona sa statusom (aktivan, build, store)
- [ ] Novi salon: ime, flavor, vertikala, tema, boje, logo → red u bazi + `tenant.yaml` + generatori
- [ ] Admin nalog vlasnika kroz poziv (kod), ne ručni SQL
- [ ] Deaktivacija salona; promjena boja i teme
- [ ] Status store objave (`draft` → `in_review` → `live`)
- [ ] Dokumentovano u `tenant-factory.md` i skillu `/new-tenant`

## Status (2026-10-20)

U toku, grana `feat/super-admin-konzola`. Odluke prije koda su u
[ADR-0032](../../docs/adr/0032-super-admin-lokalni-dart-server.md) (**predložen**, odobrava Hamza):
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
