# iOS flavori se generišu kroz `xcodeproj` gem, ne tekstualnim pisanjem po pbxproj-u

## Status

prihvaćen

## Kontekst

Android flavori su lak dio: `productFlavors` blok u Gradleu je tekst koji se sigurno generiše
između markera. iOS traži build konfiguracije `<Debug|Profile|Release>-<flavor>` i scheme po
tenantu, a sve to živi u `Runner.xcodeproj/project.pbxproj` — formatu sa UUID referencama gdje
neispravna izmjena ruši projekat **za sve flavore odjednom**, i to se ne vidi dok se ne otvori
Xcode.

Prva verzija generatora pisala je xcconfig fajlove i ništa više. Ispostavilo se da su bili mrtav
kod: ne bi radili ni kad bi scheme postojali, iz četiri nezavisna razloga (v. Posljedice).

## Odluka

`project.pbxproj` se mijenja isključivo kroz Ruby `xcodeproj` gem (`tool/gen_ios_flavors.rb`,
pokrenut kroz `tool/gen_ios_flavors.sh`). Gem dolazi sa CocoaPodsom, koji je za Flutter iOS ionako
obavezan, pa ne uvodi novu zavisnost.

Scheme se zove **tačno kao flavor**: Flutter traži `sentenceCase(flavor)` uz case-insensitive
poklapanje, pa se `Runner-<flavor>` nikad ne bi poklopio.

Pošto `pod` nije isti na svakoj mašini — Homebrew formula daje bash wrapper koji iznutra postavlja
`GEM_HOME`, GitHub macOS runner daje pravi gem binstub — skripta probava sve vjerodostojne
`GEM_HOME` kandidate i uzima prvi u kojem `require "xcodeproj"` stvarno prođe, umjesto da
pretpostavi jedan oblik.

## Razmatrane opcije

- **Tekstualno pisanje po pbxproj-u** (kao za Gradle) — odbačeno: format sa UUID referencama,
  greška ruši sve flavore, i ne vidi se do otvaranja Xcodea.
- **Ručno održavanje konfiguracija u Xcodeu** — odbačeno: na 20 tenanata to je 60 konfiguracija i
  20 scheme-a koje niko ne može držati tačnim.
- **Zaseban Xcode projekat po tenantu** — odbačeno: gubi se jedan codebase, koji je cijela premisa
  proizvoda.
- **Pretpostaviti jedan oblik `pod` instalacije** — pokušano i palo na CI-ju; zamijenjeno probanjem
  kandidata.

## Posljedice

- iOS generisanje radi **samo na macOS-u**. Rad sa Windows mašine ne može dokazati iOS dio i to
  ide u predaju (`/handoff`), ne u tišinu.
- Četiri zamke koje su otkrivene ovim putem sada su dio generatora i moraju ostati: `buildSettings`
  Runner targeta nadjačava xcconfig (pa se `PRODUCT_BUNDLE_IDENTIFIER` i `PRODUCT_NAME` brišu iz
  flavor konfiguracija); prava postavka za ikonu je `ASSETCATALOG_COMPILER_APPICON_NAME`;
  `Info.plist` koristi `$(PRODUCT_NAME)` umjesto hardkodiranog imena; tenant xcconfig mora
  uključiti Flutterov `Generated.xcconfig` kroz `<Mode>-<flavor>.xcconfig` wrapper.
- CI provjerava iOS na **gotovom bundleu** (`CFBundleIdentifier`, `CFBundleDisplayName`, ikona), ne
  u konfiguraciji — jer je upravo konfiguracija bila ta koja je lagala.
