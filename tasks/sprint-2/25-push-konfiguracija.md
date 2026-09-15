# Task 25: Konfiguracija I Dokaz Na Uređaju

Kod i lokalni testovi mogu se pripremiti bez naloga. Sljedeći koraci zahtijevaju Firebase,
Apple Developer i fizičke uređaje. Ovaj dokument ne potvrđuje da su izvršeni.

## Firebase I Build

1. Napravi Firebase projekat samo za FCM. Registruj zasebnu Android/iOS app za svaki flavor
   (`ba.nasadomena.<flavor>`) i admin (`ba.nasadomena.admin`). Uključi FCM HTTP v1 API.
2. Za svaki iOS App ID uključi Push Notifications u Apple Developer konzoli i obnovi provisioning
   profile. APNs ključ dodaj u Firebase. `tool/gen_ios_flavors.sh` postavlja push i Keychain
   sposobnosti; klijentski entitlement ostaje po flavoru i zadržava Sign in with Apple.
3. Prave config fajlove drži van gita, npr. u ignorisanom `.firebase-config/`. Ne prepisuj
   `apps/client/android/app/src/<flavor>/google-services.json`: taj fajl ostaje placeholder.
4. Pretvori config u novi privatni define fajl. Alat provjerava bundle ID i odbija postojeći
   izlazni fajl i placeholder vrijednosti:

```sh
dart run tool/firebase_defines.dart .firebase-config/google-services.json \
  ba.nasadomena.barberstudiovitez .firebase-config/android-defines.json
# Na macOS-u isti alat čita GoogleService-Info.plist preko plutil:
dart run tool/firebase_defines.dart .firebase-config/GoogleService-Info.plist \
  ba.nasadomena.barberstudiovitez .firebase-config/ios-defines.json
```

`tool/build_tenant.sh` prima apsolutni `FIREBASE_DEFINES_FILE`. Za `flutter run` dodaj
`--dart-define-from-file=<apsolutna-putanja>`, uz postojeće Supabase i `SALON_ID` define-ove.
Admin koristi isti define fajl format, ali vlastiti Firebase app ID i nema `SALON_ID`.
Bez `PUSH_ENABLED=true` native FCM se ne pokreće; web push nije uključen ovim taskom.

Inicijalizacija ide kroz eksplicitni `FirebaseOptions`, pa pravi Google config ne mora biti
kopiran preko generisanog placeholdera niti dodat kao Xcode resource. Release AAB workflow čita
GitHub secret `FIREBASE_ANDROID_<FLAVOR>` (sadržaj JSON-a), pravi privremeni define fajl i
prosljeđuje ga buildu. iOS/administratorski release pipeline još treba svoje signing tajne i
config kada se ti buildovi puštaju.

## Server

1. Deployaj migracije uobičajenim staging postupkom, zatim Edge Function `send-push`.
2. Service account sa FCM pravom postavi kao `FCM_SERVICE_ACCOUNT_JSON` Edge secret.
3. Generiši nasumičnu tajnu od najmanje 32 bajta. Postavi je kao `PUSH_WORKER_SECRET` Edge secret
   i kao `push_worker_secret` u Vaultu. Ne šalji je u chat, git niti CI log.
4. U Vault postavi `push_worker_url`, puni URL funkcije. Cron job `send-push-queued` je već u
   migraciji i obrađuje red svake minute. Bez Vault konfiguracije ne šalje zahtjeve.

Detalji autentikacije, ishoda slanja i ograničenja ponavljanja:
`supabase/functions/send-push/README.md`.

## Dokaz

- Na fizičkom klijentskom uređaju prije prijave provjeri da je nastao `devices` red bez
  identiteta. Poslije prijave mora ostati isti `devices.id`, vezan na vlastiti identitet.
- Prijavi vlasnika u admin app. Njegov uređaj mora imati `staff_user_id`, bez klijentskog
  `auth_identity_id`. Drugi salon ne smije dobiti taj uređaj ni push.
- Rezerviši iz klijentske app: `appointments.device_id` mora odgovarati `devices.id`.
  Vlasnik mora dobiti novi zahtjev, i dok je admin app u pozadini.
- Potvrdi, zatim na zasebnom zahtjevu odbij. Klijentski tap na obavijest otvara `/appointments`
  iz pozadine i iz ugašene aplikacije. U foregroundu se lista osvježava; iOS prikazuje sistemsku
  obavijest, Android osvježava podatke bez dodatnog lokalnog notification plugina.
- Ponovi istu admin akciju i pokreni worker dvaput: isti događaj ne smije dobiti novi log.
- Odbij dozvolu, promijeni FCM token, odjavi se i prijavi drugim nalogom. Provjeri uklanjanje
  tokena i da poruke koje čekaju ne odlaze prethodnom nalogu.
- Provjeri otkazivanje potvrđenog termina i klijentsko otkazivanje prema vlasniku.
- `sent` u logu znači samo FCM prihvat. Zapiši platformu, app build, konkretan scenario i
  stvarno primljenu poruku. Do tada DoD o isporuci ostaje otvoren.

Reference: [Flutter FCM](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api),
[Supabase raspored funkcija](https://supabase.com/docs/guides/functions/schedule-functions).
