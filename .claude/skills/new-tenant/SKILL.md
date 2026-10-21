---
name: new-tenant
description: Novi klijent od tenant.yaml do zelenog CI-ja — svi koraci i provjere.
argument-hint: <flavor>
---

# Novi tenant

Cilj: `<flavor>` postoji kao instalabilna aplikacija sa svojim identitetom, imenom i ikonom, i CI
to ponavlja na svaki PR. Mehanika i zamke: `.claude/docs/tenant-factory.md`.

Flavor: **$ARGUMENTS**. Ako nije dat, traži ga (mora biti `[a-z][a-z0-9]*`).

## 0. Pravi salon: konzola radi korake 1–3

```sh
dart run apps/superadmin/bin/superadmin.dart                 # lokalni stack
dart run apps/superadmin/bin/superadmin.dart --env .env.prod # projekat (fajl sa SUPABASE_SERVICE_ROLE_KEY)
```

Otvori adresu koju ispiše i klikni „+ Novi salon". Konzola upiše salon u bazu, napiše `tenant.yaml`
sa istim UUID-om i pokrene sva tri generatora (i sama vrati `project.pbxproj` ako ga je
`flutter_launcher_icons` prepisao). Ako korak poslije baze padne: „Napiši tenant.yaml" ili
„Ponovi generatore". Onda u detalju salona „Napravi poziv" daje kod koji vlasnik unosi u Meluri na
„Imam poziv od salona"; novi poziv povlači prethodni, a „Povuci poziv" gasi otvoren kod. Ručni
nalog i SQL ne trebaju. Nastavi od **koraka 4** (CI matrica, konzola pokazuje šta fali). Koraci
1–3 ispod su za demo fixture u `seed.sql`. ADR-0032.

**Drugo okruženje, isti salon.** Salon nastaje jednom (UUID izmisli prvo okruženje) i UUID od tada
živi u `tenant.yaml`-u. Na produkciji, ili lokalno poslije `supabase db reset`, konzola fajl bez
reda pokaže pod „Tenanti bez reda u ovoj bazi": „Upiši u ovu bazu iz tenant.yaml" ga upiše sa
istim UUID-om, bez diranja fajla i generatora. Nikad ne pravi isti salon dva puta kroz „+ Novi
salon" — dobio bi drugi UUID, a folder koji postoji konzola ionako odbija.

## 1. Konfiguracija

```sh
cp -r tenants/_template tenants/<flavor>
```

Popuni `tenants/<flavor>/tenant.yaml`. Tri polja su tvrda:

- `tenant.flavor` **identično imenu foldera** — inače `google-services.json` završi na putanji koju
  build ne gleda.
- `tenant.flavor` mora biti `[a-z][a-z0-9]*` — crtica ne kompajlira u Gradleu.
- `tenant.flavor` ne počinje sa `test` i nije `lint`, `main`, `debug`, `profile` ni `release` —
  Gradle ga odbija i pada za sve tenante (`gen_flavors.dart` i baza ga ne puštaju).
- `tenant.salonId` je UUID i mora odgovarati redu u `supabase/seed.sql` — inače se app builda i ne
  nađe svoj salon.

Pitanje za svako drugo polje: **može li se promijeniti bez novog store reviewa?** Ako može, ne ide
ovdje nego u backend.

## 2. Salon u bazi

Dodaj red u `supabase/seed.sql` sa istim UUID-om, uključujući `primary_color`/`secondary_color`
koje se poklapaju sa `branding` blokom (fallback boje moraju biti iste kao u bazi).

## 3. Generiši

```sh
dart run tool/gen_flavors.dart
dart run tool/gen_placeholder_icons.dart      # dok nema dizajnerske ikone
cd apps/client && dart run flutter_launcher_icons && cd -
tool/gen_ios_flavors.sh                        # samo ako targets.ios: true, i samo na macOS-u
```

Ne otvaraj generisane fajlove da ih "dotjeraš" — sljedeće pokretanje ih prepisuje, a CI pada na
`--check`.

## 4. CI matrica — korak koji se najčešće zaboravi

`.github/workflows/flutter-build.yml` ima **eksplicitne** liste u `build-flavors`, `build-ios` i
`release-artifacts` (flavor, `salon_id`, za iOS i `bundle_id` i `display_name`). Tenant koji nije u
matrici se nikad ne buildа na CI-ju, i `--check` to ne hvata jer generisani fajlovi jesu ažurni.

## 5. Dokaz

```sh
dart run tool/gen_flavors.dart --check
tool/build_tenant.sh <flavor> apk debug
aapt2 dump badging apps/client/build/app/outputs/flutter-apk/*<flavor>*.apk | head -1
```

Traži se `ba.nasadomena.<flavor>` i ispravan `application-label`. Zatim instaliraj **uz** postojeći
tenant (`adb install -r` oba, pa `adb shell pm list packages | grep nasadomena`) — dvije aplikacije
na istom uređaju su jedini pravi dokaz da flavori rade.

iOS i ostali recepti: `/verify`.

## 6. Zatvori

- `tenants/README.md` i `.claude/docs/tenant-factory.md` ažuriraj samo ako se promijenio **postupak**,
  ne zbog samog dodavanja tenanta.
- Commit: `feat(client): novi tenant <flavor>` sa dokazom u tijelu.
- Ako je nešto ostalo (npr. iOS jer si na Windowsu) → `/handoff write`.
