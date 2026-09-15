# Task 25 — FCM, `Device` registracija i push scenariji

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [14](14-identitet-i-klijent-upsert.md), [24](24-admin-akcije-nad-terminima.md) |
| **Blokira** | Sprint 3 (podsjetnici) |
| **Reference** | [01 §17](../../docs/01-mvp-spec.md#17-build-order) koraci 20–21 · [06 §3.1](../../docs/06-auth-login-flow.md) |

## Cilj
Push zamjenjuje poziv i SMS — to je razlog zbog kojeg app ne traži broj telefona. Dok ne radi,
ta odluka nije pokrivena.

## Definicija gotovog
- [ ] Firebase projekat **samo za FCM**, app po flavoru; pravi `google-services.json` ulazi kroz
      CI, ne kroz repo (placeholder ostaje u gitu)
- [ ] `devices` registracija vezana na `AuthIdentity`; **gost dobija push** preko `device_id`
      registrovanog prije prijave ([06 §3.1](../../docs/06-auth-login-flow.md))
- [ ] Novi zahtjev → push vlasniku salona
- [ ] Potvrda / odbijanje → push klijentu, otvara `/appointments`
- [ ] `NotificationLog` red po poslatoj poruci
- [ ] Dokaz **na uređaju**, ne u simulatoru — iOS push ne radi na simulatoru

## Koraci
1. `devices` tabela i politika, pa registracija u app-i, pa Edge Function za slanje
2. Scenariji jedan po jedan, svaki sa dokazom na uređaju
3. Commit: `feat(push): fcm registracija i scenariji`

## Zamke
- **`appointments.device_id` je FK na `devices.id`, ne na `devices.device_id`.** Zamjena prolazi
  tipove (oba su uuid) i tiho slomi push — zapisano u `Appointment` modelu.
- iOS traži pravi uređaj i APNs ključ. Planiraj da ovaj task ne može biti dokazan lokalno do kraja.
- Tajne u CI: `google-services.json` i APNs ključ nikad u repo.

## Status (2026-09-15)

U toku na grani `feat/push-notifikacije`, sa ažurnog `main`-a. Zavisnosti 14 i 24 su završene.
Pripremljeni su validirani device RPC-ovi, tajna instalacije u secure storage, token/session
životni ciklus oba app-a, `p_device_id` u rezervaciji, statusni trigger, FCM HTTP v1 worker i
minutni cron sa kratkotrajnim HMAC potpisom. Odjava uklanja token i zaustavlja poruke koje čekaju.
Firebase config se ubacuje privatnim define fajlom; generisani placeholder ostaje u gitu.

Dokaz:

```text
supabase test db: Files=9, Tests=255, Result: PASS
rest_push_devices.ts: 12 asercija, dva stvarna JWT-a, dva salona
deno test .../send-push/handler_test.ts: 6 passed, 0 failed
melos exec --dir-exists=test -- flutter test --no-pub --reporter compact: SUCCESS
melos run analyze: No issues found u svih pet paketa
dart run tool/gen_flavors.dart --check: ažurno za 2 tenanta
flutter build ios --simulator --debug --flavor barberstudiovitez: Built Barber Studio Vitez.app
```

Puna REST suite je djelimična: izolacija, javni katalog, upsert, cross-salon i brisanje naloga
prolaze uz push test (168 asercija ukupno). `rest_admin_login.ts` pada na `invalid_credentials`
za postojeći demo nalog lokalne baze; reset nije rađen.

**Nije dokazano:** Google/APNs slanje i prijem, stvarni token refresh, dozvole i tap na telefonu.
Korisnik je potvrdio da Firebase/APNs i fizički uređaj nisu spremni. Hodogram:
[25-push-konfiguracija.md](25-push-konfiguracija.md). Zato DoD o isporuci ostaje otvoren.
`sent` znači FCM prihvat; nepoznat ishod ne ponavljamo automatski. Klijentska historija obavijesti
ostaje prazno stanje. [Draft PR #44](https://github.com/htuco/salon-booking-platform/pull/44).
