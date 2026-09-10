# iOS flavors

`*.xcconfig` fajlovi ovdje su **generisani** iz `tenants/*/tenant.yaml`:

```sh
dart run tool/gen_flavors.dart
```

Ne editaj ih ručno — sljedeće pokretanje generatora ih prepisuje.

## Šta je generisano, a šta nije

Generator pokriva korak 2 iz [docs/04 §5](../../../../docs/04-flutter-tenant-factory.md#5-ios--gdje-boli):
po-tenant `xcconfig` sa `PRODUCT_BUNDLE_IDENTIFIER`, `DISPLAY_NAME`, verzijama
i `ASSET_CATALOG_APP_ICON_NAME`.

**Nije generisano** i traži macOS + Xcode:

1. **Xcode scheme** (`Runner-<flavor>`) u `Runner.xcodeproj/xcshareddata/xcschemes/`
2. **Build configuration** po tenantu (`Debug-<flavor>`, `Release-<flavor>`) koja
   uključuje odgovarajući `xcconfig`
3. **App Icon set** (`AppIcon-<flavor>`) u `Assets.xcassets`
4. **`GoogleService-Info.plist`** po flavoru, kopiran u build fazi
5. **App ID + provisioning profil** u Apple Developer portalu

Koraci 1–3 znače izmjenu `project.pbxproj`. Generisati taj fajl naslijepo, bez
mogućnosti da se rezultat otvori u Xcodeu i builda, nosi veći rizik nego korist:
neispravan `pbxproj` ruši projekat za sve flavore odjednom, a greška se ne vidi
dok se ne otvori na Macu.

Zato je ovaj dio svjesno ostavljen za mašinu koja ima Xcode. Kad se prvi put radi
na macOS-u, redoslijed je:

```sh
dart run tool/gen_flavors.dart              # xcconfig fajlovi
# u Xcodeu: dupliraj Debug/Release u Debug-<flavor>/Release-<flavor>,
# veži ih na flavors/<flavor>.xcconfig, napravi scheme Runner-<flavor>
flutter build ios --flavor barberstudiovitez --no-codesign \
  --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
```

Tek kad taj build prođe, iOS dio DoD-a iz [taska 03](../../../../tasks/03-flavor-system.md)
smije biti čekiran. Do tada `targets.ios: true` u `tenant.yaml` znači samo namjeru,
ne dokazan build.
