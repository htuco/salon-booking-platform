# Generisani fajlovi se commituju i provjeravaju sa `--check`

## Status

prihvaćen

## Kontekst

Iz `tenant.yaml` nastaje Gradle blok, iOS xcconfig i Xcode konfiguracije, `flutter_launcher_icons`
config i Dart registar tenanata. Ti fajlovi su ulaz u alate koje ne kontrolišemo (Gradle, Xcode,
`flutter_launcher_icons`), i dio njih (`project.pbxproj`) je fajl koji Xcode i sam mijenja.

Dvije loše krajnosti: generisati sve u build koraku (repo ne pokazuje šta se stvarno buildа, a
Xcode projekat se ne može otvoriti bez pokretanja generatora), ili ne generisati ništa (ručno
održavanje flavora na 20 tenanata).

## Odluka

Generisano se **commituje** u repo, ali se **nikad ne edituje ručno**. Svaki izlaz nosi marker
`GENERISANO — ne editovati ručno`, a CI na svaki PR pokreće
`dart run tool/gen_flavors.dart --check`, koji pada ako je generisano zastarjelo u odnosu na
`tenant.yaml`.

Izuzetak je iOS: CI **ne** poredi `project.pbxproj` sa svježe generisanim, nego provjerava
invarijantu — da svaki iOS tenant ima scheme i Debug/Profile/Release konfiguracije. Različite
verzije `xcodeproj` gema serijalizuju pbxproj drugačije, pa bi poređenje padalo na razlici u alatu,
ne na stvarnom driftu.

## Razmatrane opcije

- **Generisati u build koraku, ne commitovati** — odbačeno: Xcode projekat se ne može otvoriti bez
  prethodnog generisanja, `git diff` više ne pokazuje šta se mijenja u buildu, a greška generatora
  se vidi tek na CI-ju.
- **Commitovati bez `--check`** — odbačeno: generisano tiho odluta od `tenant.yaml` prvi put kad
  neko zaboravi pokrenuti generator, i to se otkrije kao pogrešan artefakt u storeu.
- **Poređenje pbxproj-a bajt-po-bajt** — odbačeno nakon što je u praksi padalo na razlici u verziji
  gema između lokalne mašine i runnera.

## Posljedice

- PR koji mijenja `tenant.yaml` mora sadržavati i regenerisane fajlove; CI ga inače odbija.
- Diff takvog PR-a je veći nego što promjena "izgleda" — recenzent generisane fajlove ne čita kao
  ručni kod (v. `/task explain`).
- Ručna izmjena generisanog fajla nestaje pri sljedećem pokretanju generatora. To je očekivano
  ponašanje, ne bug.
