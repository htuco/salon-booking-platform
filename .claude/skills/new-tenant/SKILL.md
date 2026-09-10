---
name: new-tenant
description: Novi klijent od tenant.yaml do zelenog CI-ja — svi koraci i provjere.
argument-hint: <flavor>
---

# Novi tenant

Cilj: `<flavor>` postoji kao instalabilna aplikacija sa svojim identitetom, imenom i ikonom, i CI
to ponavlja na svaki PR. Mehanika i zamke: `.claude/docs/tenant-factory.md`.

Flavor: **$ARGUMENTS**. Ako nije dat, traži ga (mora biti `[a-z][a-z0-9]*`).

## 1. Konfiguracija

```sh
cp -r tenants/_template tenants/<flavor>
```

Popuni `tenants/<flavor>/tenant.yaml`. Tri polja su tvrda:

- `tenant.flavor` **identično imenu foldera** — inače `google-services.json` završi na putanji koju
  build ne gleda.
- `tenant.flavor` mora biti `[a-z][a-z0-9]*` — crtica ne kompajlira u Gradleu.
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

`.github/workflows/flutter-build.yml` ima **eksplicitne** liste u `build-flavors` i `build-ios`
(flavor, `salon_id`, za iOS i `bundle_id` i `display_name`). Tenant koji nije u matrici se nikad ne
buildа na CI-ju, i `--check` to ne hvata jer generisani fajlovi jesu ažurni.

## 5. Dokaz

```sh
dart run tool/gen_flavors.dart --check
cd apps/client
flutter build apk --debug --flavor <flavor> --dart-define=SALON_ID=<uuid>
aapt2 dump badging build/app/outputs/flutter-apk/*<flavor>*.apk | head -3
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
