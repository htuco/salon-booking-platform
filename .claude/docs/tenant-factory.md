# Tenant factory — od `tenant.yaml` do aplikacije u storeu

Ovo je najosjetljiviji mehanički dio repoa: jedan codebase mora proizvesti N aplikacija koje se
instaliraju jedna pored druge, sa različitim identitetom, imenom i ikonom. Većina grešaka ovdje ne
pada — tiho proizvede pogrešan artefakt. Zato je sve generisano i sve provjereno na **gotovom
artefaktu**, ne na konfiguraciji iz koje je nastao.

Proizvodna strana priče (pricing, store politika, onboarding klijenta) je u
`docs/04-flutter-tenant-factory.md`. Ovdje je kako to radi u kodu.

## Lanac

```
tenants/<flavor>/tenant.yaml          ← jedini fajl koji pišeš
        │
        ├─ dart run tool/gen_flavors.dart
        │     ├─ Gradle productFlavors            apps/client/android/app/build.gradle.kts
        │     │                                   (samo između BEGIN/END GENERATED FLAVORS)
        │     ├─ google-services.json placeholder apps/client/android/app/src/<flavor>/
        │     ├─ iOS xcconfig                     apps/client/ios/flavors/<flavor>.xcconfig
        │     │                                   + <Debug|Profile|Release>-<flavor>.xcconfig
        │     ├─ flutter_launcher_icons config    apps/client/flutter_launcher_icons-<flavor>.yaml
        │     └─ Dart registar                    apps/client/lib/src/generated/tenants.g.dart
        │
        ├─ tool/gen_ios_flavors.sh  (macOS)
        │     └─ Xcode build konfiguracije Debug/Profile/Release-<flavor> + scheme <flavor>
        │
        ├─ dart run tool/gen_placeholder_icons.dart   (dok nema dizajna)
        └─ dart run flutter_launcher_icons            (mipmape + AppIcon-<flavor> setovi)
```

**Nijedan izlaz iz ovog lanca se ne edituje ručno.** Sve nosi marker
`GENERISANO — ne editovati ručno`, a `dart run tool/gen_flavors.dart --check` pada u CI-ju ako je
generisano zastarjelo.

## Pravila koja generator provjerava

- **`flavor` mora biti isto kao ime foldera.** Gradle traži `src/<flavor>/`, pa neslaganje znači da
  `google-services.json` završi na putanji koju build ne gleda — i FCM tiho ne radi.
- **`flavor` mora biti `[a-z][a-z0-9]*`.** `create("barber-vitez")` nije validan Gradle
  identifikator i ne kompajlira.
- **`salonId` mora biti UUID i odgovarati redu u `supabase/seed.sql`.** Ako ne odgovara, app se
  builda uredno i ne nađe svoj salon — najskuplja tiha greška u ovom lancu.
- **`branding.primaryColor` i `branding.secondaryColor` moraju biti `#RRGGBB`.** Provjera je ovdje,
  a ne u Dartu na uređaju: neispravan heks bi tamo bio izuzetak pri startu aplikacije, ovdje je pad
  generatora u CI-ju. U registar ulaze kao ARGB `int`, pa app ne parsira boju pri startu.

- **`auth.providers` prima samo `apple`, `google`, `facebook`, `email`**, i samo `true`/`false`.
  Nepoznat ključ ili `"da"` umjesto `true` obore generisanje. Isti razlog kao kod boja: tipfeler u
  konfiguraciji mora pasti u CI-ju, a ne završiti kao login ekran kojem fali dugme.
- **iOS build sa social providerom mora imati `apple: true`.** Generator pada ako ga nema —
  App Review odbija takav build po pravilu 4.8 (`docs/06 §7.2`), a to je jedino mjesto gdje
  se greška vidi prije submissiona. Izlazi tri: dodaj `apple`, isključi iOS
  (`targets.ios: false`), ili ostavi samo `email`. Android-only tenant smije Google bez
  Applea, jer Apple na Androidu nema ni implementaciju.
- **`auth.googleReversedClientId`** je Google `REVERSED_CLIENT_ID` za iOS — client ID sa
  obrnutim segmentima, koji ide u `CFBundleURLTypes` kroz `GOOGLE_REVERSED_CLIENT_ID` u
  xcconfigu. Prazno je ispravno stanje dok konzola ne da ID
  (`tasks/sprint-2/12-konzole-checklist.md`); tada je i URL shema prazna, što iOS ignoriše,
  a `signInWithGoogle` ionako baca prije dijaloga.

### Boje u `tenant.yaml` nisu dekoracija

`branding.primaryColor`/`secondaryColor` su **fallback dok backend ne odgovori**, i moraju biti iste
kao `salons.primary_color`/`secondary_color` u bazi. Runtime izvor istine je baza — vlasnik boju
mijenja iz admin aplikacije i promjena stiže bez novog builda.

Kad se razidju, aplikacija i dalje radi, ali korisnik vidi **treptaj boje na startu**: prvi frame u
boji iz `tenant.yaml`, pa skok na boju iz baze. Zato pri promjeni boje mijenjaj oba mjesta.

`branding.theme` (`modern_barber` | `elegant_beauty` | `clinical_calm`) bira svjetlinu i neutralnu
paletu. Nepoznato ime **ne ruši app** nego pada na `modern_barber` — tema dodana migracijom poslije
zadnjeg store submissiona ne smije biti izuzetak. Detalji: `.claude/docs/architecture.md`.

### Auth: lista je u `tenant.yaml`, client ID nije

`auth.providers` ide u `tenant.yaml`, jer je to podatak o tenantu i mijenja se rijetko:

```yaml
auth:
  providers: { apple: true, google: true, email: true, facebook: false }
  allowGuestBooking: false
```

Generator ga prenosi u `tenants.g.dart`, a `AuthConfig` ga filtrira po platformi — `apple: true` na
Androidu se **ignoriše, ne pada** ([ADR-0007](../../docs/adr/0007-authconfig-u-core-domain.md)).
`allowGuestBooking` je fallback; izvor istine je `salon_settings.allow_guest_booking`.

**Google client ID u `tenant.yaml` ne ide.** Mijenja se po okruženju (debug i release imaju različit
SHA-1, dev i prod različit projekat), pa ne pripada fajlu koji stoji u gitu. Prosljeđuje ga
`tool/build_tenant.sh` kao `--dart-define`, tražeći prvo vrijednost po flavoru:

```
GOOGLE_WEB_CLIENT_ID_<FLAVOR>   →   GOOGLE_WEB_CLIENT_ID
GOOGLE_IOS_CLIENT_ID_<FLAVOR>   →   GOOGLE_IOS_CLIENT_ID
```

**Client ID je po flavoru, ne po projektu** (`docs/06 §7.1`): jedan zajednički ID znači da korisnik
u Google dijalogu vidi tuđe ime salona. Skripta ispisuje da li je ID stigao i iz koje varijable, ali
nikad samu vrijednost.

## Zamke koje su nas već koštale

Ove su otkrivene radeći task 03 (`tasks/sprint-0/03-flavor-system.md`) i nijedna se ne vidi bez provjere na
artefaktu:

**Android**

- **AGP 9 gasi `buildFeatures.resValues` po defaultu**, a `resValue` je upravo ono što daje ime
  aplikacije po flavoru. Generator ga eksplicitno uključuje.
- Ime i ikona se moraju provjeriti u APK-u (`aapt2 dump badging`), ne u Gradle fajlu. Dva builda sa
  istim `applicationId` se ne bi mogla instalirati jedan pored drugog — to je test koji stvarno
  nešto dokazuje.

**iOS** (ovdje je bilo najviše skrivenog posla — generisani xcconfig je jedno vrijeme bio mrtav kod)

- **`buildSettings` Runner targeta nadjačava xcconfig.** Dok su `PRODUCT_BUNDLE_IDENTIFIER` i
  `PRODUCT_NAME` stajali tamo, tenant vrijednosti nikad nisu stizale. `gen_ios_flavors.rb` ih briše
  iz flavor konfiguracija.
- **`ASSET_CATALOG_APP_ICON_NAME` ne postoji** i tiho se ignoriše; prava postavka je
  `ASSETCATALOG_COMPILER_APPICON_NAME`.
- **`Info.plist` je imao hardkodiran `CFBundleDisplayName`**, pa ime nije moglo doći iz
  konfiguracije. Sada je `$(PRODUCT_NAME)`.
- **Tenant xcconfig mora uključiti Flutterov `Generated.xcconfig`** — zato postoje
  `<Mode>-<flavor>.xcconfig` wrapperi. Vezan direktno, build ne zna gdje je SDK.
- **Scheme se mora zvati tačno kao flavor.** Flutter traži `sentenceCase(flavor)` uz
  case-insensitive poklapanje, pa se `Runner-<flavor>` nikad ne bi poklopio.
- **`project.pbxproj` se ne edituje tekstualno.** Neispravan pbxproj ruši projekat za sve flavore
  odjednom, a greška se vidi tek kad se otvori Xcode. Zato Ruby + `xcodeproj` gem, koji ionako
  dolazi sa CocoaPodsom.
- **`pod` nije isti na svakoj mašini** (Homebrew wrapper naspram pravog gem binstuba), pa
  `gen_ios_flavors.sh` probava sve vjerodostojne `GEM_HOME` kandidate i uzima prvi u kojem
  `require "xcodeproj"` stvarno prođe.
- CI **ne poredi pbxproj bajt-po-bajt** sa svježe generisanim: različite verzije gema serijalizuju
  drugačije, pa bi takva provjera padala na razlici u alatu, ne na driftu. Provjerava se
  invarijanta: svaki iOS tenant ima scheme i sve tri konfiguracije.

**Ikone**

- Placeholder generator **nikad ne prepisuje postojeći fajl bez `--force`** — dizajnerska ikona ne
  smije nestati na sljedećem pokretanju. Pravi asset samo zamijeni PNG na istoj putanji;
  konfiguracija se ne mijenja.
- `flutter_launcher_icons` sam skenira `flutter_launcher_icons-*.yaml` u korijenu paketa; zato se
  config zove tako i zato ga generiše `gen_flavors.dart`.

## Novi tenant — redoslijed

Skill `/new-tenant` vodi kroz ovo korak po korak; ovo je referenca šta se sve mora dogoditi.

1. `cp -r tenants/_template tenants/<flavor>` i popuni `tenant.yaml`.
2. Dodaj salon u `supabase/seed.sql` sa **istim** UUID-om (ili potvrdi red u bazi).
3. `dart run tool/gen_flavors.dart`
4. `dart run tool/gen_placeholder_icons.dart` pa `dart run flutter_launcher_icons` (u `apps/client`).
5. Ako je `targets.ios: true` → `tool/gen_ios_flavors.sh` na macOS-u.
6. **Auth po flavoru** — Google OAuth klijenti, Sign In with Apple capability, redirect URL
   `ba.nasadomena.<flavor>://login-callback` u Supabase konzoli **i** u
   `supabase/config.toml`, pa `gh variable set GOOGLE_*_CLIENT_ID_<FLAVOR>`. Hodogram kroz konzole:
   [`tasks/sprint-2/12-konzole-checklist.md`](../../tasks/sprint-2/12-konzole-checklist.md).
   Redirect lista je *exact match* — flavor koji nije dobio svoj red završi na "requested path is
   invalid" umjesto u app-i.
7. **Dodaj flavor u sve tri CI matrice** u `.github/workflows/flutter-build.yml` —
   `build-flavors`, `build-ios` i `release-artifacts` imaju **eksplicitne liste**, ne izvedene iz
   `tenants/`. Tenant koji nije u matrici se nikad ne buildа na CI-ju, a `--check` to ne hvata.
8. Build i provjeri na artefaktu (v. `/verify`).

## Šta ide u `tenant.yaml`, a šta ne

Pitanje na koje se svodi svaka dilema: **može li se ovo promijeniti bez novog store reviewa?**

- **Da** → backend. Logo, cover, boje u app-u, usluge, radnici, radno vrijeme, tekstovi, vertikala
  u radu. Mijenja se kroz super admin konzolu.
- **Ne** → `tenant.yaml`. Ime aplikacije, ikona, `applicationId`/`bundleId`, splash, verzija.
- **Ni jedno ni drugo** → okruženje. Ključevi i client ID-evi se mijenjaju po okruženju, a ne po
  tenantu ni po verziji — idu kao `--dart-define` kroz `tool/build_tenant.sh`, u GitHub `vars` i
  `secrets`, i nikad u git.

Boje su u oba: u `tenant.yaml` kao **fallback dok backend ne odgovori** (sprječava bijeli flash), u
bazi kao izvor istine. Moraju biti iste vrijednosti; kad se razilaze, baza je u pravu.

`versionName` je zajednički za sve tenante, `androidVersionCode`/`iosBuildNumber` su po tenantu —
to direktno utiče na CI matricu (`docs/04 §8.1`).
