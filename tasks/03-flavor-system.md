# Task 03 — Flavor sistem: dokaz na 2 demo tenanta

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [01 — repo skeleton](01-repo-skeleton.md), [02 — schema](02-supabase-schema-rls.md) (treba `salonId` demo salona) |
| **Blokira** | [04 — CI pipeline](04-ci-pipeline.md) |
| **Reference** | [04 cijeli dokument](../docs/04-flutter-tenant-factory.md) |

## Cilj
Najveći nepoznati tehnički rizik u projektu dokazan rano: **dva različita installabilna builda** iz jednog Flutter koda, sa različitim `applicationId`, imenom i ikonom, prije nego što se napiše ijedan pravi ekran.

## Definicija gotovog
- [x] `tenants/_template/tenant.yaml` i `tenants/_template/assets/` postoje kao šablon
- [x] `tenants/barberstudiovitez/tenant.yaml` i `tenants/beautystudiotravnik/tenant.yaml` postoje, popunjeni po [04 §3](../docs/04-flutter-tenant-factory.md#3-tenantyaml--jedini-fajl-koji-pišeš-po-klijentu), sa `salonId` iz seed podataka (task 02)
- [x] `tool/gen_flavors.dart` čita `tenants/*/tenant.yaml` i generiše:
  - Android `productFlavors` u `apps/client/android/app/build.gradle.kts`
  - iOS `.xcconfig` po tenantu u `apps/client/ios/flavors/`
- [x] `apps/client/lib/main.dart` čita `SALON_ID` iz `--dart-define` i prikazuje ga na ekranu (placeholder UI — "Hello, {salonId}")
- [x] `flutter build apk --flavor barberstudiovitez --dart-define=SALON_ID=<uuid>` i isto za `beautystudiotravnik` **oba prolaze** i daju dva različita `.apk` fajla
- [x] Instalirana oba APK-a na isti uređaj/emulator **istovremeno**, bez konflikta (dokaz da su `applicationId` stvarno različiti)
- [x] Svaki APK pokazuje svoje ime i ikonu u launcheru (dokaz da `flutter_launcher_icons` po flavoru radi)
- [x] iOS: barem jedan flavor buildovan lokalno (`flutter build ios --flavor ... --no-codesign` je dovoljno za ovaj task — puni provisioning je task za kasnije)

## Koraci
1. Napiši `tenants/_template/tenant.yaml` prema šablonu iz [04 §3](../docs/04-flutter-tenant-factory.md#3-tenantyaml--jedini-fajl-koji-pišeš-po-klijentu)
2. Popuni `tenants/barberstudiovitez/` i `tenants/beautystudiotravnik/` sa stvarnim `salonId` vrijednostima iz `seed.sql`
3. Napiši `tool/gen_flavors.dart` — parsira YAML, generiše gradle `productFlavors` blok i `.xcconfig` fajlove ([04 §4](../docs/04-flutter-tenant-factory.md#4-android-flavors) i [§5](../docs/04-flutter-tenant-factory.md#5-ios--gdje-boli))
4. Dodaj `google-services.json` placeholder po flavoru u `android/app/src/<flavor>/` (pravi Firebase projekat dolazi kasnije — za sada dummy fajl da build ne puca)
5. Podesi `flutter_launcher_icons` config po tenantu (`tenants/<flavor>/icons.yaml`), pokreni generisanje
6. Builduj oba APK-a, instaliraj na isti emulator, provjeri da oba rade nezavisno
7. iOS: kreiraj scheme + xcconfig za barem jedan flavor, builduj bez code signinga da provjeriš da se target uopšte kompajlira
8. Commit: "feat(client): flavor system — 2 demo tenants proven"

## Šta NIJE u ovom tasku
- Puni iOS provisioning (`fastlane produce` + `match`) — to je task za Sprint 2/3 kad se sprema prvi store submission ([04 §6.2](../docs/04-flutter-tenant-factory.md#62-apple-app-store--sve-pod-tvojim-accountom))
- Pravi Firebase FCM setup — samo placeholder da build prođe
- Bilo kakav pravi ekran ili branding iz backenda — to je Sprint 1

## Zašto je ovo pravi test uspjeha Sprint-a 0
Ako ovaj task ne uspije glatko, cijeli native multi-tenant model je upitan **prije** nego što je uloženo mjeseci u ekrane. [04](../docs/04-flutter-tenant-factory.md) kaže da je iOS flavor sistem "najveći operativni trošak native modela" — bolje da to iznenađenje dođe sada, sa dva prazna ekrana, nego kasnije sa dvadeset punih.

## Status (2026-09-10) — ✅ zatvoren

Sve tri stavke koje su bile otvorene su odrađene na macOS-u sa Xcode 26.5.
Prethodni rad je bio na Windowsu, odakle iOS dio nije bio moguć.

### Android — dokazano

```
ba.nasadomena.barberstudiovitez    'Barber Studio Vitez'    1.0.0
ba.nasadomena.beautystudiotravnik  'Beauty Studio Travnik'  1.0.0
```

`aapt2 dump badging` potvrđuje različit applicationId i label. Oba APK-a
instalirana na isti emulator (API 36, x86_64) **istovremeno**:

```
$ adb shell pm list packages | grep nasadomena
package:ba.nasadomena.beautystudiotravnik
package:ba.nasadomena.barberstudiovitez
```

Zamka: **AGP 9 gasi `buildFeatures.resValues` po defaultu**, a `resValue` je
upravo ono što daje ime po flavoru. Generator ga eksplicitno uključuje.

### iOS — dokazano

```
$ flutter build ios --flavor barberstudiovitez --no-codesign
✓ Built build/ios/iphoneos/Barber Studio Vitez.app

CFBundleIdentifier   ba.nasadomena.barberstudiovitez
CFBundleDisplayName  Barber Studio Vitez
ikona                AppIcon-barberstudiovitez60x60@2x.png
```

Ovdje je bilo najviše skrivenog posla. Generisani xcconfig je bio **mrtav kod** —
ne bi radio ni kad bi scheme postojali, iz četiri razloga:

| problem | posljedica |
|---|---|
| `PRODUCT_BUNDLE_IDENTIFIER` i `PRODUCT_NAME` su u `buildSettings` Runner targeta | `buildSettings` nadjačava xcconfig, pa tenant vrijednosti nikad ne stignu |
| xcconfig je koristio `ASSET_CATALOG_APP_ICON_NAME` | ta postavka ne postoji; prava je `ASSETCATALOG_COMPILER_APPICON_NAME` |
| `Info.plist` je imao hardkodirano `CFBundleDisplayName = Client` | ime je bilo fiksno; `DISPLAY_NAME` iz xcconfiga nije referenciran nigdje |
| tenant xcconfig nije uključivao Flutterov `Generated.xcconfig` | vezan direktno, build ne zna gdje je SDK |

Rješeno: `tool/gen_ios_flavors.rb` (kroz `xcodeproj` gem, ne tekstualno) pravi
build konfiguracije i scheme i briše nadjačavajuće ključeve; generator emituje
`<Mode>-<flavor>.xcconfig` wrappere koji zadržavaju Flutterov config u lancu.

Također: scheme se mora zvati **tačno kao flavor**. Flutter traži
`sentenceCase(flavor)` uz case-insensitive poklapanje, pa se `Runner-<flavor>`
iz prve verzije README-a nikad ne bi poklopio.

### Ikone — dokazano

`tool/gen_placeholder_icons.dart` pravi privremenu ikonu iz boja u `tenant.yaml`,
i `flutter_launcher_icons` iz nje generiše Android mipmape i `AppIcon-<flavor>`
setove. Android ikone po flavoru se stvarno razlikuju, `src/main/res` je netaknut.

Boje se ne uzimaju naslijepo: `beautystudiotravnik` ima `splashBackground`
identičan `primaryColor`-u, pa je prva verzija dala praznu pločicu. Generator
sad bira pozadinu po izmjerenom kontrastu i ne prepisuje postojeći asset bez
`--force` — pravi dizajn samo zamijeni PNG na istoj putanji.

### Popravljeno usput

`Theme.of(context)` u `main.dart` je bio pozvan u `build` metodi koja tek gradi
`MaterialApp`, pa je vraćao Flutterov default (svijetlu) temu. Naziv salona se
iscrtavao u `#1D1B20` na tamnoj tenant pozadini — kontrast **1.08:1**, nevidljivo.
Tijelo je izvučeno u `TenantHome` widget. `test/tenant_theme_test.dart` je
regresija i pada na starom kodu.

### Reprodukcija

```sh
dart run tool/gen_flavors.dart --check       # generisano je ažurno
tool/gen_ios_flavors.sh                      # Xcode konfiguracije i scheme
dart run tool/gen_placeholder_icons.dart     # ikone koje fale
dart run flutter_launcher_icons              # mipmape + AppIcon setovi

cd apps/client
flutter build apk --debug --flavor barberstudiovitez \
  --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
flutter build ios --debug --no-codesign --flavor barberstudiovitez \
  --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
```

CI (`.github/workflows/flutter-build.yml`) ponavlja sve navedeno na svaki PR,
uključujući provjeru bundleId-a i imena u gotovom iOS bundleu.

### Ostaje za kasnije (nije dio ovog taska)

- Pravi dizajn ikona — placeholder dokazuje pipeline, ne zamjenjuje art
- Puni iOS provisioning (`fastlane produce` + `match`) — Sprint 2/3
- Pravi Firebase projekat po tenantu — `google-services.json` je placeholder
