# Taskovi — Sprint 1: prvi ekrani

Nastavak [Sprinta 0](../README.md). Redoslijed prati [01 §17](../../docs/01-mvp-spec.md#17-build-order), uz jednu dopunu: task 07 nije u build orderu, ali koraci 9–11 pretpostavljaju kičmu aplikacije koju nijedan raniji task ne postavlja.

| # | Task | Blokira | Procjena |
|---|---|---|---|
| [07](07-app-plumbing.md) ✅ | App plumbing — Riverpod, go_router, env, Supabase klijent | sve ostalo | 2 dana |
| [08](08-core-api-repozitoriji.md) | `core_api` — freezed modeli + repozitoriji | 10, 11, admin | 2–3 dana |
| [09](09-core-ui-theme-factory.md) | `core_ui` — theme factory po tenantu + tokeni | 10, 11 | 2 dana |
| [10](10-client-home-runtime-branding.md) | Client home sa runtime brandingom | 11 | 1–2 dana |
| [11](11-booking-flow.md) | Booking flow (4 koraka + success) | Sprint 2 | 3–4 dana |

**Ukupno: ~10–13 radnih dana**, uz preduslov da su [05](../05-availability-engine.md) i [06](../06-vertical-pack.md) iz Sprinta 0 gotovi — 11 bez 05 nema šta prikazati, a 10 bez 06 piše tekst koji se kasnije prepisuje.

> **Task 07 je zatvoren** (✅) — oba app-a imaju kičmu: `AppEnv`/`AdminEnv`, `bootstrap()` sa
> `Supabase.initialize`, `go_router` sa rutama iz [01 §12](../../docs/01-mvp-spec.md#12-screens)
> i `.arb` lokalizacije u klijentu. Ekrani se i dalje ne pišu — sve rute imaju placeholder
> tijela, kako task i traži.
>
> Dokazano: `melos run analyze` čist, **44 testa PASS**, plus provjera u **pravom Chromiumu**
> nad `flutter build web` artefaktom — `/book/slot` i `/appointments/abc-123` otvoreni direktno
> zadržavaju putanju i prikazuju svoj ekran, browser Back radi.
>
> **Browser je našao dvije greške koje je zelena test suite propustila:** web build je padao
> prije `runApp` i davao praznu bijelu stranicu (env je tražio `SUPABASE_*`, a widget testovi
> uvijek ubacuju env kroz override), i deep link tiho nije radio (`initialLocation` plus
> izostanak `usePathUrlStrategy()`) dok je URL izgledao ispravno. Obje su sad pokrivene testom.
> Detalji: [07-app-plumbing.md](07-app-plumbing.md#status-2026-09-11--✅-zatvoren).
>
> Ostaje za sljedećeg: `riverpod_generator` je svjesno izostavljen, Supabase je dignut ali nije
> pozvan protiv pravog backenda (nema naloga — prvi pravi poziv ide uz task 08), i `.arb`
> stringove još nijedan ekran ne koristi.

## Redoslijed koji nije očigledan

- **07 → 08 → 09 → 10 → 11** je lanac, ne prijedlog. Svaki sljedeći koristi ono što prethodni postavi, i preskakanje znači da prvi ekran postane šablon sa prečicama koje se kopiraju petnaest puta.
- **06 prije 10.** Prvi ekran koji ima tekst je prvi ekran koji može hardkodirati terminologiju.
- **05 prije 11.** Availability logika koja "privremeno" sklizne u Dart tamo i ostane.

## Sljedeće (Sprint 2 — nije raspisano)

Namjerno: taskovi se pišu jedan sprint unaprijed, jer detaljna specifikacija napisana tri sprinta ranije zastari prije nego što je iko otvori. Redoslijed i obim su u [01 §17](../../docs/01-mvp-spec.md#17-build-order), koraci 12–24:

- Supabase Auth provideri (Apple, Google, Email OTP) + login ekran na kraju booking flowa
- `AuthIdentity` upsert i `Customer` upsert po `(salonId, authIdentityId)` kroz validiranu funkciju
- **Test izolacije: isti klijent u dva salona** — poslovni rizik, ne tehnička formalnost
- **"Moj račun" + brisanje računa** — bez toga iOS submission pada
- Admin app: login, dashboard, lista termina, confirm/reject/cancel
- FCM po flavoru + `Device` registracija vezana na `AuthIdentity`
- Client: "Moji termini" + otkazivanje

Kad Sprint 1 bude gotov, ovi se raspisuju u `tasks/sprint-2/` sa nastavkom numeracije.
