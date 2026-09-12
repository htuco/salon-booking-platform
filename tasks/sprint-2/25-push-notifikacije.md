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
