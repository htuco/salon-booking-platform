# Flutter Tenant Factory — kako štancati klijente

Operativni playbook: od "salon je potpisao" do "app je u storeu" u jednom danu.

| | |
|---|---|
| **Verzija** | v1 |
| **Datum** | 20.08.2026. |
| **Prati** | [01-mvp-spec.md](01-mvp-spec.md) · [05-vertical-packs.md](05-vertical-packs.md) |

> **Zašto ovaj dokument postoji:** native model živi ili umire na ovome. Ako novi klijent traži dan tvog rada, na 20 klijenata si zaposlen 100% na održavanju i biznis staje. Cilj je **novi klijent = 30 minuta tvog vremena + 20 minuta CI-ja.**

---

## 1. Princip — tri sloja konfiguracije

```
┌─────────────────────────────────────────────────────────────┐
│ 1. BUILD-TIME (mijenja se samo novim buildom u storeu)      │
│    applicationId · bundleId · app ime · ikona · splash      │
│    SALON_ID (--dart-define) · FCM config · OAuth client ID  │
│    ⚠️ Sve što je ovdje traži store review kod promjene      │
├─────────────────────────────────────────────────────────────┤
│ 2. RUNTIME iz backenda (mijenja se instant, bez builda)     │
│    logo · boje · cover · galerija · tekstovi · usluge       │
│    radnici · radno vrijeme · terminologija · booking pravila│
│    ✅ Ovdje ide SVE što može ići ovdje                      │
├─────────────────────────────────────────────────────────────┤
│ 3. LOKALNO na uređaju                                        │
│    ime i telefon klijenta · deviceId · FCM token · cache    │
└─────────────────────────────────────────────────────────────┘
```

**Jedino pravilo koje moraš pamtiti:** sve što može biti runtime — **jest** runtime. Vlasnik koji hoće promijeniti primarnu boju ne smije čekati 3 dana Apple review-a. Build-time sloj je minimum koji store tehnički zahtijeva, ništa više.

---

## 2. Struktura repozitorija

```
salon_platform/
├── melos.yaml
├── apps/
│   ├── client/                      # aplikacija salona — N flavora
│   │   ├── lib/
│   │   │   ├── main.dart            # čita SALON_ID iz --dart-define
│   │   │   └── ...
│   │   ├── android/
│   │   │   └── app/build.gradle.kts # productFlavors, generisan skriptom
│   │   └── ios/
│   │       ├── Runner.xcodeproj     # schemes po flavoru
│   │       └── flavors/             # xcconfig po salonu
│   └── admin/                       # jedna admin app + Web build za super admin
├── packages/
│   ├── core_api/                    # dio klijent, repozitoriji, error mapping
│   ├── core_ui/                     # design system, theme factory, komponente
│   └── core_domain/                 # entiteti, Vertical, formatiranje
├── tenants/                         # ⬅ SRCE FABRIKE
│   ├── _template/
│   │   ├── tenant.yaml
│   │   └── assets/
│   ├── barberstudiovitez/
│   │   ├── tenant.yaml
│   │   └── assets/
│   │       ├── icon.png             # 1024×1024, bez alfe
│   │       ├── splash_logo.png
│   │       └── google-services.json
│   └── beautystudiotravnik/
│       └── ...
└── tool/
    ├── new_tenant.dart              # scaffold novog tenanta
    ├── gen_flavors.dart             # generiše gradle + xcconfig iz tenants/
    └── build_tenant.sh              # jedna komanda = jedan build
```

**Zašto `tenants/` u repou, a ne u bazi:** build config mora biti verzionisan i reproducibilan. Ako je u bazi, ne možeš rebuildati verziju od prije 3 mjeseca. Backend drži *runtime* branding; repo drži *build* config. `SalonBuild` tabela ([01 §11](01-mvp-spec.md)) samo prati **status**, ne sadržaj.

---

## 3. `tenant.yaml` — jedini fajl koji pišeš po klijentu

```yaml
# tenants/barberstudiovitez/tenant.yaml
tenant:
  flavor: barberstudiovitez
  salonId: 550e8400-e29b-41d4-a716-446655440000
  slug: barber-studio-vitez
  vertical: barber                       # v. docs/05-vertical-packs.md

app:
  displayName: "Barber Studio Vitez"
  shortName: "Barber Vitez"              # Android launcher, max ~12 znakova
  applicationId: ba.nasadomena.barberstudiovitez
  bundleId: ba.nasadomena.barberstudiovitez
  versionName: "1.0.0"
  androidVersionCode: 1
  iosBuildNumber: 1

branding:
  # fallback boje dok se backend ne odgovori — sprječava bijeli flash
  primaryColor: "#1A1A1A"
  secondaryColor: "#C9A227"
  splashBackground: "#1A1A1A"
  theme: modern_barber

store:
  # tekstovi za store listing — generišu se, ne pišu ručno
  shortDescription: "Zakažite termin u Barber Studio Vitez u par tapova."
  categoryAndroid: LIFESTYLE
  categoryIos: LIFESTYLE
  contentRating: everyone
  supportEmail: podrska@nasadomena.ba
  privacyPolicyUrl: https://nasadomena.ba/privatnost/barber-studio-vitez

targets:
  android: true
  ios: false                             # Starter paket = samo Android
  web: true
```

Sve ostalo — logo, cover, usluge, radnici, radno vrijeme, tekstovi — **nije ovdje.** To ide u backend kroz super admin konzolu.

---

## 4. Android flavors

`android/app/build.gradle.kts` se **generiše** iz `tenants/*/tenant.yaml` skriptom `tool/gen_flavors.dart`. Nikad ga ne editaj ručno — na 20 tenanata ručno održavanje gradle fajla je izvor grešaka.

```kotlin
// GENERISANO — ne editovati ručno. Pokreni: dart tool/gen_flavors.dart
android {
    flavorDimensions += "tenant"

    productFlavors {
        create("barberstudiovitez") {
            dimension = "tenant"
            applicationId = "ba.nasadomena.barberstudiovitez"
            resValue("string", "app_name", "Barber Studio Vitez")
            versionCode = 1
            versionName = "1.0.0"
        }
        create("beautystudiotravnik") {
            dimension = "tenant"
            applicationId = "ba.nasadomena.beautystudiotravnik"
            resValue("string", "app_name", "Beauty Studio Travnik")
            versionCode = 1
            versionName = "1.0.0"
        }
    }
}
```

Po-flavor asseti idu u `android/app/src/<flavor>/`:
```
android/app/src/barberstudiovitez/
├── google-services.json          # FCM, po applicationId
└── res/mipmap-*/ic_launcher.png  # generisano iz assets/icon.png
```

`google-services.json` **mora** biti po flavoru jer FCM veže token na `applicationId`. Jedan zajednički fajl znači da push ne radi.

> Firebase se koristi **samo za FCM push**. Auth, baza i storage su Supabase ([01 §16.1](01-mvp-spec.md)).

---

## 5. iOS — gdje boli

iOS nema `productFlavors`. Rješenje su **schemes + xcconfig**:

```
ios/flavors/barberstudiovitez.xcconfig
```
```
PRODUCT_BUNDLE_IDENTIFIER = ba.nasadomena.barberstudiovitez
PRODUCT_NAME = Barber Studio Vitez
DISPLAY_NAME = Barber Studio Vitez
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1
ASSET_CATALOG_APP_ICON_NAME = AppIcon-barberstudiovitez
```

Po tenantu treba:
1. Xcode **scheme** (`Runner-barberstudiovitez`) — generiše se skriptom u `.xcodeproj/xcshareddata/xcschemes/`
2. **Build configuration** koja uključuje xcconfig
3. **App Icon set** u `Assets.xcassets` po flavoru
4. `GoogleService-Info.plist` po flavoru, kopiran u build fazi
5. **App ID + provisioning profile** u Apple Developer portalu — ovo je ručno ili preko `fastlane produce`

> **Ovdje je najveći operativni trošak native modela.** Android flavor je 5 minuta skripte. iOS je Apple Developer portal, provisioning profili, certifikati i review. Zato je [iOS u Pro paketu, ne Starter](01-mvp-spec.md#15-pricing-model).

**Automatizuj sa `fastlane`:**
```ruby
lane :provision_tenant do |options|
  produce(app_identifier: options[:bundle_id], app_name: options[:app_name])
  match(type: "appstore", app_identifier: options[:bundle_id])
end
```

---

## 6. Store submission — realni troškovi i rizici

### 6.1 Google Play

| Korak | Vrijeme | Napomena |
|---|---|---|
| Kreiranje app-a u konzoli | 10 min | Automatizovati preko Play Developer API |
| Store listing (opis, screenshotovi, feature graphic) | 15 min | Screenshotovi se generišu automatski, v. §7 |
| Data safety formular | 10 min | Isti za sve tenante — sačuvaj kao template |
| Content rating questionnaire | 5 min | Isti za sve |
| Upload AAB + rollout | 5 min | `fastlane supply` |
| **Review** | **1–7 dana** | Prvi app novog developer accounta ide duže |

**Rizik: "repackaged/low-quality app".** Google odbija app-e koje izgledaju kao kopije. N gotovo identičnih app-a sa istog accounta je crvena zastava.

Mitigacija:
- **Različiti screenshotovi** po tenantu (pravi brand, prave boje, prave usluge)
- **Različit opis** — ne copy-paste. Generiši iz podataka salona, ne iz template-a sa zamijenjenim imenom
- Prava ikona salona, ne varijacija istog logotipa
- Popuni "This app is developed on behalf of..." gdje postoji
- **Ne submituj 5 app-a isti dan.** Razmakni ih

> Cutlio ovo očigledno prolazi sa 6+ app-a, tako da je izvedivo. Ali oni su to gradili godinama; novi account je pod većom lupom.

### 6.2 Apple App Store — sve pod tvojim accountom

**Odluka: iOS app-e idu sa tvog Apple Developer accounta, klijent ne otvara ništa.** Frizerki se ne prodaje developer nalog — prodaje se gotova aplikacija. Cutlio radi upravo to i ima 6+ app-a u storeu, tako da je izvedivo.

Ali to nije usklađenost s pravilima — to je **upravljanje rizikom**, i moraš znati čime.

| Korak | Vrijeme |
|---|---|
| App ID + provisioning (`fastlane produce` + `match`) | 5 min, skriptovano |
| App Store Connect zapis | 10 min |
| Metadata + screenshotovi (više veličina) | 20 min, generisano |
| App Privacy formular | 10 min |
| Upload IPA + submit (`fastlane pilot`) | 10 min |
| **Review** | **1–3 dana, sa realnom šansom odbijanja** |

#### Šta pravilo stvarno kaže

**Guideline 4.2.6:** *"Apps created from a commercialized template or app generation service will be rejected unless they are submitted directly by the provider of the app's content. These services should not submit apps on behalf of their clients..."*

**Guideline 4.3 (Spam):** koristi se kad Apple **ne može dokazati** da je app napravljen generatorom, ali mu N sličnih app-a sa istog accounta izgleda kao duplikati. U praksi je 4.3 češći uzrok odbijanja u našem scenariju od 4.2.6.

Formalno, Apple traži da klijent submituje sa svog accounta. Mi to nećemo raditi. Znači igramo na to da **enforcement cilja app-e koje izgledaju generisane** — minimalna funkcionalnost, nula jedinstvenog sadržaja, isti screenshotovi sa zamijenjenim logom. Naš zadatak je da svaka app **ne izgleda tako, jer stvarno nije takva.**

#### Tail risk koji moraš prihvatiti svjesno

Odbijanje jedne app-e je neugodnost. Opasnost je eskalacija: **ponovljena 4.2.6 / 4.3 odbijanja mogu dovesti do akcije na nivou cijelog developer accounta**, a to znači sve iOS app-e odjednom.

Zato disciplina ispod nije kozmetika. Ona je razlika između 20 app-a u storeu i ugašenog accounta.

#### Disciplina diferencijacije — obavezna, ne opciona

| Pravilo | Zašto |
|---|---|
| **Prave fotografije salona**, ne stock i ne isti render u drugoj boji | Prvo što review tim gleda |
| **Jedinstven opis po app-i** — generisan iz stvarnih podataka salona (usluge, grad, tim, priča), nikad template sa zamijenjenim imenom | Isti tekst na 5 app-a je automatski flag |
| **Screenshotovi iz stvarnog builda** sa stvarnim brandingom i stvarnim cjenovnikom | Zato je [§7](#7-automatizacija--šta-mora-biti-skriptovano) screenshot automatizacija kritična, ne udobnost |
| **Prava ikona salona** od njihovog dizajna, ne varijacija tvog logotipa | |
| **Feature mix se razlikuje** — galerija kod jednog, tim bio kod drugog, recall kod dentalnog | Različit funkcionalni otisak, ne samo boje |
| **Ne submituj više app-a isti dan.** Razmakni ih 5–7 dana | Bulk submission je najjači spam signal |
| **Developer name je studio, ne generator** — "Nasa Domena Studio", nikad "Salon App Builder" | Ime accounta se čita |
| App mora imati **sadržaj koji postoji samo u njoj** | 4.3 gleda ima li app razlog da bude zasebna app |
| Nikad ne pominji "template", "builder", "generator" ni u kodu ni u metadata | |

> Ovo je posao od ~30 min po klijentu koji **ne možeš skriptovati do kraja**. Uračunaj ga u cijenu. To je stvarni trošak odluke da sve ide pod tvojim accountom.

#### Ljestvica fallbackova — pripremi ih prije nego zatrebaju

Kad app bude odbijena (a bit će, jednom), imaš četiri opcije po redu:

**1. Appeal sa dokazima o custom razvoju.** Odgovori review timu: ovo nije generator, aplikacija je razvijena za konkretnog klijenta, evo jedinstvenog sadržaja i funkcionalnosti. Često prolazi prvi put. Drži pripremljen template odgovora.

**2. Pojačaj diferencijaciju i resubmit.** Dodaj sadržaj koji postoji samo u toj app-i — galeriju, tim bio, priču salona, specifičnu feature.

**3. Taj jedan klijent ide na svoj account.** Ne kao default, nego kao rješenje za problematičan slučaj. Klijent nikad ne mora znati da ta opcija postoji dok ne zatreba — i tada je to "Apple traži dodatnu verifikaciju za tvoju firmu", ne "moraš sam sve".

**4. iOS = PWA za tog klijenta.** Flutter Web build + "Dodaj na home screen". Ikona na telefonu, bez storea. Manje elegantno, ali radi i ništa ne košta.

**5. Nuklearna opcija — picker app.** Apple eksplicitno navodi kao prihvatljivu alternativu **jedan binary sa svim klijentima** (npr. app "Rezerviši" gdje korisnik izabere salon). To ubija white-label priču na iOS-u, ali je legitimno i ne može biti odbijeno po 4.2.6.

> Drži opciju 5 u fioci. Ako Apple ikad zatvori vrata za pojedinačne app-e, to je izlaz koji čuva iOS kanal — i tehnički je trivijalan jer je backend već multi-tenant. Isti Flutter kod, `salonId` iz picker-a umjesto iz `--dart-define`.

#### Praktična posljedica: Android je primarni kanal

Google je oko sličnih app-a mjerljivo tolerantniji (Cutlio ima 6+ na Playu bez problema), a u BiH je Android dominantan.

Zato:
- **Starter paket = Android + web link.** Pokriva većinu tržišta, nula Apple rizika
- **iOS je Pro paket** — ne zato što klijent plaća developer account (ne plaća ga), nego zato što nosi tvojih 30 min diferencijacije, 99 USD/god sa tvog accounta amortizovano, i realan rizik odbijanja
- Prva 2–3 iOS submissiona uradi **pažljivo i pojedinačno**, dok ne vidiš kako review tim reaguje na tvoj account

#### Jedna dobra vijest

Pošto je sve na tvom accountu, **Sign in with Apple je sad potpuno skriptovan** — App ID capability, Service ID i private email relay domen podešavaš `fastlane`-om bez čekanja na klijentove kredencijale ([06 §7.2](06-auth-login-flow.md)). To je 10 min ručnog rada po flavoru koji je nestao.

### 6.3 Dentalni klijenti — dodatni rizik
Zdravstvene app-e imaju stroži review, obaveznu politiku privatnosti na javnoj URL i mogući dodatni krug pitanja. Računaj +2–5 dana i realnu šansu jednog odbijanja. Detalji: [05 §7.2](05-vertical-packs.md).

---

## 7. Automatizacija — šta mora biti skriptovano

| Zadatak | Alat | Rezultat |
|---|---|---|
| Scaffold tenanta | `dart tool/new_tenant.dart --name "Barber Studio Vitez" --vertical barber` | `tenants/<flavor>/` sa `tenant.yaml` i praznim assetima |
| Generisanje flavora | `dart tool/gen_flavors.dart` | gradle + xcconfig + schemes |
| App ikone | `flutter_launcher_icons` po flavoru | Sve mipmap/Assets.xcassets veličine |
| Auth provideri | `tool/register_oauth.dart` + Supabase Management API | Novi client ID u comma-separated listu, bez ručnog klikanja |
| Splash screen | `flutter_native_splash` po flavoru | Android 12+ i iOS splash |
| **Store screenshotovi** | `integration_test` + `screenshot()` na demo podacima | Prave slike prave app-e sa pravim brandingom, u svim traženim veličinama |
| Store metadata | Generiši iz `tenant.yaml` + podataka salona iz backenda | `fastlane/metadata/` struktura |
| Android build + upload | `fastlane supply` | AAB u internal testing |
| iOS build + upload | `fastlane pilot` | IPA u TestFlight |
| Provisioning | `fastlane produce` + `match` | App ID + profil |

**Screenshot automatizacija je nedovoljno cijenjen dio.** Ručno pravljenje 5 screenshotova × 3 veličine × 20 tenanata = 300 slika. `integration_test` koji prođe kroz booking flow sa tenantovim brandingom i snimi ekrane rješava to u CI-ju, i **istovremeno ublažava rizik "repackaged app"** jer su screenshotovi stvarno različiti.

### 7.1 Jedna komanda

```bash
# tool/build_tenant.sh barberstudiovitez android release
#!/usr/bin/env bash
set -euo pipefail

TENANT=$1; PLATFORM=${2:-android}; MODE=${3:-release}
CFG="tenants/$TENANT/tenant.yaml"
[[ -f "$CFG" ]] || { echo "Nema tenanta: $TENANT"; exit 1; }

SALON_ID=$(yq '.tenant.salonId' "$CFG")

dart tool/gen_flavors.dart --tenant "$TENANT"
dart run flutter_launcher_icons -f "tenants/$TENANT/icons.yaml"
dart run flutter_native_splash:create --path "tenants/$TENANT/splash.yaml"

case "$PLATFORM" in
  android)
    flutter build appbundle \
      --flavor "$TENANT" \
      --"$MODE" \
      --dart-define=SALON_ID="$SALON_ID" \
      --dart-define=API_URL="$API_URL"
    ;;
  ios)
    flutter build ipa \
      --flavor "$TENANT" \
      --"$MODE" \
      --dart-define=SALON_ID="$SALON_ID" \
      --dart-define=API_URL="$API_URL" \
      --export-options-plist="tenants/$TENANT/export.plist"
    ;;
  web)
    flutter build web \
      --"$MODE" \
      --dart-define=SALON_ID="$SALON_ID" \
      --dart-define=API_URL="$API_URL" \
      --base-href="/s/$(yq '.tenant.slug' "$CFG")/"
    ;;
esac
```

---

## 8. CI/CD

**Codemagic** je preporuka — ima native podršku za Flutter flavore i store publishing, i `codemagic.yaml` može biti matrix po tenantu.

```yaml
# codemagic.yaml (skraćeno)
workflows:
  client-android:
    name: Client Android — po tenantu
    environment:
      groups: [google_play, api]
      flutter: stable
    scripts:
      - dart tool/gen_flavors.dart --tenant $TENANT
      - ./tool/build_tenant.sh $TENANT android release
      - dart tool/gen_screenshots.dart --tenant $TENANT
    publishing:
      google_play:
        credentials: $GCLOUD_SERVICE_ACCOUNT
        track: internal
```

**Alternativa:** GitHub Actions + fastlane. Jeftinije, više posla za iOS signing.

### 8.1 Pravila koja se ne pregovaraju

1. **Nijedan build ne ide u store sa lokalne mašine.** Samo CI. Inače za 6 mjeseci ne znaš šta je u kojoj verziji
2. **Verzionisanje:** `versionName` je zajednički za sve tenante (`1.4.0`), `versionCode`/`buildNumber` je po tenantu i inkrementira CI
3. **Rebuild svih tenanata pri promjeni core koda.** Bugfix u availability prikazu mora doći do svih 20 app-a. Napravi `melos run build:all` i pusti ga preko noći
4. **Backend je uvijek backward compatible.** Ne možeš prisiliti update. Klijent sa app verzijom 1.0.0 od prije 6 mjeseci mora raditi. API verzioniši (`/v1/`) i nikad ne uklanjaj polje bez deprecation perioda
5. **Minimalna podržana verzija app-a** — backend vraća `426 Upgrade Required` sa "Ažurirajte aplikaciju" ekranom kad app postane previše star. Bez ovoga vučeš legacy zauvijek

---

## 9. Onboarding checklist — novi klijent

Cilj: **30 minuta tvog vremena.**

### Prije (prodaja)
- [ ] Potpisan ugovor, izabran paket i vertikala
- [ ] Za iOS: prikupljene **prave fotografije salona** i priča salona za jedinstven store opis (v. §6.2 disciplina diferencijacije)
- [ ] Prikupljeno: logo (SVG/PNG visoke rezolucije), cover slika, lista usluga sa cijenama i trajanjem, radnici sa slikama, radno vrijeme, adresa, telefon, Instagram

### Backend (10 min, super admin konzola)
- [ ] Kreiraj salon: naziv, slug, vertikala, kontakt, društvene mreže
- [ ] Upload logo i cover
- [ ] Podesi primarnu/sekundarnu boju i temu
- [ ] Seed usluge (iz vertikalnog default-a, pa izmijeni)
- [ ] Dodaj radnike i dodijeli im usluge
- [ ] Radno vrijeme
- [ ] `SalonSettings` iz vertikalnih default-a
- [ ] Kreiraj `salon_admin` korisnika i pošalji privremenu lozinku

### Build config (10 min)
- [ ] `dart tool/new_tenant.dart --name "..." --vertical ...`
- [ ] Ubaci `assets/icon.png` (1024×1024, bez alfe) i `splash_logo.png`
- [ ] Firebase (samo FCM): dodaj Android app sa `applicationId` → skini `google-services.json`
- [ ] (iOS) Firebase iOS app → `GoogleService-Info.plist`
- [ ] (iOS) `fastlane produce` + `match` — sve na tvom accountu, bez klijentovih kredencijala
- [ ] Provjeri `tenant.yaml`, commit, push

### Auth provideri (10 min) — v. [06 §7](06-auth-login-flow.md)
- [ ] Google OAuth client za Android: `applicationId` + **debug I release SHA-1** ⚠️
- [ ] (iOS) Google OAuth client za bundle ID + `REVERSED_CLIENT_ID` URL scheme u `Info.plist`
- [ ] Supabase → Auth → Google → **Client IDs**: dodaj nove ID-eve u comma-separated listu (**web ID prvi**)
- [ ] (iOS) `Sign In with Apple` capability — automatski kroz `fastlane produce`
- [ ] (iOS) Supabase → Auth → Apple → **Client IDs**: dodaj bundle ID u listu
- [ ] Email + lozinka: confirmation/recovery callback za flavor na Supabase allow-listi
- [ ] Facebook: **samo ako je eksplicitno zatražen** — v. [06 §7.4](06-auth-login-flow.md)
- [ ] **Testiraj Google login na signed release buildu**, ne samo u debugu ⚠️

### Build i submission (10 min tvog vremena + CI)
- [ ] Trigger CI za tenanta
- [ ] Provjeri generisane screenshotove — **jesu li stvarno brandirani?**
- [ ] Play Console: kreiraj app, upload metadata, internal testing rollout
- [ ] (iOS) App Store Connect + TestFlight
- [ ] (iOS) **Jedinstven opis, prave fotografije, stvarni screenshotovi** — provjeri da ništa nije template
- [ ] (iOS) Provjeri da nijedan drugi klijent nije submitovan u zadnjih 5 dana
- [ ] Ažuriraj `SalonBuild` status
- [ ] Pošalji klijentu internal testing link za odobrenje
- [ ] Nakon "OK": promocija u production
- [ ] Web build + QR kod za salon

### Predaja klijentu
- [ ] Sastanak 30 min: kako potvrditi termin, kako dodati uslugu, kako blokirati vrijeme
- [ ] Odštampan QR kod za ogledalo/izlog
- [ ] Store link + tekst za Instagram bio
- [ ] Tvoj broj za podršku

---

## 10. Skaliranje — brojevi koje moraš znati

| Broj klijenata | Šta puca | Rješenje |
|---|---|---|
| 1–5 | Ništa. Sve ručno je OK | — |
| **5–15** | Ručno održavanje gradle/xcconfig fajlova | `gen_flavors.dart` **mora** postojati prije 5. klijenta |
| 15–30 | Store metadata i screenshotovi po tenantu | Automatizovani screenshotovi + generisan metadata |
| 15–30 | Rebuild svih pri core promjeni traje predugo | Paralelni CI, `melos run build:all` preko noći |
| 30–50 | Support poziva postaje pun radni dan | Baza znanja + video tutorijali + naplati support paket |
| **30–50** | iOS provisioning i certifikati | Obavezno `fastlane match` sa shared certifikatima |
| 20+ | Apple 4.3 "similar apps" na jednom accountu | Disciplina iz §6.2 + staggered submission. Picker app kao fallback |
| 50+ | Google Play "similar apps" flagovi | Različiti screenshotovi i opisi po tenantu su **obavezni** od početka |
| 50+ | Ne znaš koji tenant je na kojoj verziji | `SalonBuild` dashboard sa verzijama i store statusom |

**Realan kapacitet jedne osobe:** ~25–35 aktivnih klijenata, ako je sve iz §7 automatizovano. Bez automatizacije: ~8. To je razlika između biznisa i posla.

---

## 11. Ključne odluke

| Odluka | Obrazloženje |
|---|---|
| `tenants/` config je u gitu, ne u bazi | Build mora biti reproducibilan; DB drži runtime branding |
| Gradle i xcconfig se generišu, nikad ne editiraju ručno | Na 20 tenanata ručno održavanje je izvor grešaka |
| Sve što može biti runtime — jest runtime | Promjena boje ne smije tražiti store review |
| **iOS app-e idu pod tvojim accountom, klijent ne otvara ništa** | Frizerki se prodaje gotova app, ne developer nalog. Cutlio radi isto. Cijena je disciplina diferencijacije (§6.2) i realan rizik odbijanja |
| **Disciplina diferencijacije je obavezna, ne kozmetika** | Ponovljena 4.2.6/4.3 odbijanja mogu ugasiti cijeli account, ne samo jednu app |
| **Picker app ostaje u fioci kao nuklearna opcija** | Apple je eksplicitno navodi kao prihvatljivu; backend je već multi-tenant |
| iOS je Pro paket, Android + web je Starter | Google je tolerantniji, Android dominira u BiH, nula Apple rizika u Starteru |
| Nijedan build sa lokalne mašine u store | Reproducibilnost i sljedivost |
| Screenshotovi se generišu iz `integration_test` | 300 ručnih slika nije opcija, i ublažava "repackaged app" rizik |
| `google-services.json` po flavoru | FCM veže token na `applicationId`; zajednički fajl = push ne radi |
| **Firebase samo za FCM; Supabase za auth, bazu i storage** | Availability engine traži SQL; RLS i Auth su jedan sistem ([01 §16.1](01-mvp-spec.md)) |
| **Jedan Supabase projekat servira N flavora** | Comma-separated client ID-evi po provideru — novi flavor je jedan ID u listi, ne novi setup |
| Backend je zauvijek backward compatible + `426` za prestare verzije | Ne možeš prisiliti update na tuđem telefonu |
| Automatizacija prije 5. klijenta, ne poslije 15. | Poslije 15 je već tehnički dug koji te blokira |
