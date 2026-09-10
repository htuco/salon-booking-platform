# iOS flavors

Sve u ovom folderu je **generisano** iz `tenants/*/tenant.yaml`:

```sh
dart run tool/gen_flavors.dart     # xcconfig fajlovi
tool/gen_ios_flavors.sh            # build konfiguracije + scheme u pbxproj
dart run flutter_launcher_icons    # AppIcon-<flavor> setovi
```

Ne editaj ih ručno — sljedeće pokretanje generatora ih prepisuje.

## Šta koji fajl je

| Fajl | Uloga |
|---|---|
| `<flavor>.xcconfig` | tenant vrijednosti: bundleId, `PRODUCT_NAME`, verzije, ime AppIcon seta |
| `<Mode>-<flavor>.xcconfig` | wrapper koji Xcode build konfiguracija stvarno koristi |

Wrapper postoji jer Flutterov `Generated.xcconfig` (`FLUTTER_ROOT`, build mode)
mora ostati u lancu. Da je tenant fajl vezan direktno, build ne bi znao gdje je
SDK. Wrapper samo uključuje oba:

```
#include "../Flutter/Debug.xcconfig"
#include "barberstudiovitez.xcconfig"
```

## Imena koja Flutter zahtijeva

Iz `packages/flutter_tools/lib/src/ios/xcodeproj.dart`:

- **scheme** = `sentenceCase(flavor)`, uz case-insensitive poklapanje — dakle
  scheme se zove **tačno kao flavor**, npr. `barberstudiovitez`.
  Scheme nazvan `Runner-<flavor>` se **ne** poklapa i `--flavor` puca.
- **konfiguracija** = `<Debug|Profile|Release>-<scheme>`.

## Zamka: buildSettings nadjačava xcconfig

Flutterov template drži `PRODUCT_BUNDLE_IDENTIFIER`, `PRODUCT_NAME` i
`ASSETCATALOG_COMPILER_APPICON_NAME` u `buildSettings` Runner targeta, a te
vrijednosti imaju **veći prioritet** od xcconfiga. Zato `tool/gen_ios_flavors.rb`
te ključeve briše iz flavor konfiguracija — bez toga xcconfig je mrtav kod i svi
flavori dobiju bundleId iz templatea.

Iz istog razloga `Runner/Info.plist` koristi `$(PRODUCT_NAME)` za
`CFBundleName` i `CFBundleDisplayName`; prije je ime bilo hardkodirano.

Napomena: `ASSET_CATALOG_APP_ICON_NAME` nije Xcode postavka i tiho se ignoriše.
Prava je `ASSETCATALOG_COMPILER_APPICON_NAME`.

## Provjera

```sh
flutter build ios --flavor barberstudiovitez --no-codesign \
  --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
```

Puni provisioning (`fastlane produce` + `match`) nije dio ovoga — v.
[docs/04 §6.2](../../../../docs/04-flutter-tenant-factory.md#62-apple-app-store--sve-pod-tvojim-accountom).
