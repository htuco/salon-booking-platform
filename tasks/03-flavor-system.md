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
- [ ] Instalirana oba APK-a na isti uređaj/emulator **istovremeno**, bez konflikta (dokaz da su `applicationId` stvarno različiti)
- [ ] Svaki APK pokazuje svoje ime i ikonu u launcheru (dokaz da `flutter_launcher_icons` po flavoru radi)
- [ ] iOS: barem jedan flavor buildovan lokalno (`flutter build ios --flavor ... --no-codesign` je dovoljno za ovaj task — puni provisioning je task za kasnije)

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

## Status (2026-09-10)

Generator, tenant konfiguracije i oba Android builda su gotovi i dokazani.
Ostatak je namjerno ostavljen — traži emulator odnosno macOS.

### Dokazano lokalnim buildom

```
ba.nasadomena.barberstudiovitez    'Barber Studio Vitez'    1.0.0
ba.nasadomena.beautystudiotravnik  'Beauty Studio Travnik'  1.0.0
```

Oba APK-a builda `flutter build apk --flavor <flavor> --dart-define=SALON_ID=<uuid>`;
`aapt2 dump badging` potvrđuje različit applicationId i različit label po flavoru.
CI (`.github/workflows/flutter-build.yml`) ponavlja oba builda i provjeru na svaki PR.

Zamka na koju se naletjelo: **AGP 9 gasi `buildFeatures.resValues` po defaultu**, pa
prvi build pada sa `Product Flavor ... contains custom resource values, but the
feature is disabled`. Generator ga sada eksplicitno uključuje.

### Ostalo za sljedećeg (3 stavke)

1. **Istovremena instalacija oba APK-a na emulator.** AVD `pixel_9_-_api_36_0` je bio
   registriran bez system imagea; `system-images;android-36;google_apis_playstore;x86_64`
   je u međuvremenu instaliran, pa je korak odblokiran:

   ```sh
   flutter emulators --launch pixel_9_-_api_36_0
   adb install -r apps/client/build/app/outputs/apk/barberstudiovitez/debug/app-barberstudiovitez-debug.apk
   adb install -r apps/client/build/app/outputs/apk/beautystudiotravnik/debug/app-beautystudiotravnik-debug.apk
   adb shell pm list packages | grep nasadomena   # ocekuje se oba paketa
   ```

   Napomena: `sdkmanager` traži `JAVA_HOME` (`C:\Program Files\Android\Android Studio\jbr`).

2. **Ikone po flavoru** (`flutter_launcher_icons`). Zavisnost je već u
   `apps/client/pubspec.yaml`, ali `tenants/<flavor>/assets/icon.png` još ne postoji —
   treba pravi asset, ne placeholder. Ime u launcheru već radi kroz `resValue`.

3. **iOS build.** `xcconfig` fajlovi su generisani; scheme, build konfiguracije i
   AppIcon set traže Xcode. Razlozi i redoslijed: `apps/client/ios/flavors/README.md`.
