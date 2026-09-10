---
name: verify
description: Kako se u ovom repou dokazuje da promjena stvarno radi — po tipu promjene, sa komandama i zamkama.
---

# Verifikacija u Salon Booking Platformi

Pravilo repoa: **provjerava se artefakt, ne konfiguracija iz koje je nastao.** Gradle fajl sa
ispravnim `applicationId` ne dokazuje ništa — APK sa tim `applicationId` dokazuje. Isto važi za
iOS bundle, za RLS politiku i za temu.

Drugo pravilo: **reci šta nisi provjerio.** Nepotpun dokaz koji se predstavi kao potpun je gori
od "nije provjereno".

## Šta se u ovom okruženju ne može dokazati

| Ne radi | Zašto | Gdje se onda dokazuje |
|---|---|---|
| `supabase start`, `supabase db reset`, `supabase test db` | nema Dockera na razvojnoj mašini | CI workflow `Supabase tests` |
| iOS build, `tool/gen_ios_flavors.sh` | traži macOS + Xcode | macOS mašina ili CI job `build-ios` |
| instalacija APK-a, snimak ekrana | traži emulator/uređaj | lokalno sa `adb`, ili ručno |

Kad naiđeš na jedno od ovih, to nije razlog da se preskoči dokaz — to je razlog da se dokaz prebaci
na CI i da se u sažetku napiše "čeka CI job X".

## Dart / widget promjena

```sh
melos run format
melos run analyze
melos run test
```

Tema po tenantu se **ne vidi bez `--dart-define`** — prazan `SALON_ID` daje svijetlu temu u kojoj
neusklađenost boja ne postoji:

```sh
cd apps/client
for id in 550e8400-e29b-41d4-a716-446655440000 550e8400-e29b-41d4-a716-446655440001; do
  flutter test test/tenant_theme_test.dart --dart-define=SALON_ID=$id
done
```

Dodao si paket? Provjeri da je u `workspace:` listi root `pubspec.yaml`-a — paket van liste
`melos exec` preskače i sve gore "prolazi" bez da ga je iko pogledao.

## Flavor / build promjena

```sh
dart run tool/gen_flavors.dart --check     # generisano je ažurno
cd apps/client
flutter build apk --debug --flavor <flavor> --dart-define=SALON_ID=<uuid>
aapt2 dump badging build/app/outputs/flutter-apk/*<flavor>*.apk | head -3
```

Traži se `package: name='ba.nasadomena.<flavor>'` **i** ispravan `application-label`.

Pravi dokaz da flavori rade je **oba APK-a na istom uređaju istovremeno**:

```sh
adb install -r <apk-1>; adb install -r <apk-2>
adb shell pm list packages | grep nasadomena   # moraju se vidjeti oba
```

iOS (macOS):

```sh
flutter build ios --debug --no-codesign --flavor <flavor> --dart-define=SALON_ID=<uuid>
plist="build/ios/iphoneos/<Display Name>.app/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier"  "$plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$plist"
ls "build/ios/iphoneos/<Display Name>.app" | grep AppIcon-<flavor>
```

`buildSettings` nadjačava xcconfig, pa se bundleId i ime **moraju** čitati iz gotovog bundlea.
Ostale iOS zamke: `.claude/docs/tenant-factory.md`.

## Supabase / RLS promjena

Lokalno (ako ikad bude Dockera):

```sh
supabase db reset && supabase test db
eval "$(supabase status -o env)" && deno run --allow-env --allow-net supabase/tests/rest_isolation.ts
```

Bez Dockera — dokaz je CI:

```sh
gh run list --workflow "Supabase tests" --limit 3
gh run view <id> --log-failed
```

Šta se računa kao dokaz za RLS:

- pgTAP test koji **pada kad se politika ukloni**. Test koji prolazi u oba slučaja ne testira ništa.
- REST test sa **dva stvarna JWT-a**, gdje jedan pokuša pročitati red drugog i dobije prazno/403.
- Ako mijenjaš grantove: dokaz da `anon` i dalje ne može pisati.

Nikad ne piši "RLS radi" na osnovu čitanja SQL-a.

## CI promjena

Workflow se dokazuje tako što se pokrene, ne tako što se pročita:

```sh
gh run list --limit 5
gh run watch <id>
gh run view <id> --log-failed
```

Provjeri i **negativan slučaj** kad je provjera nova: nakratko pokvari ulaz (npr. obriši scheme) i
potvrdi da job stvarno padne. Provjera koja ne može pasti nije provjera.

## Web prototip

```sh
npm run dev     # pa otvori rutu koju si dirao
npm run build   # da ne prođe nešto što se ne builda
```

Prototip nije production kod — dokaz je "flow se vidi i klika", ne testovi.

## Kako se dokaz zapisuje

U `## Status (YYYY-MM-DD)` blok task fajla i u opis PR-a ide:

1. komanda,
2. **stvaran** izlaz (skraćen, ali ne prepričan),
3. šta iz toga slijedi,
4. šta ostaje nedokazano i ko to može dokazati.

Postojeći `tasks/03-flavor-system.md` je uzor kako to izgleda kad je dobro napisano.
