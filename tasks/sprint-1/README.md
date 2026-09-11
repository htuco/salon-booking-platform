# Taskovi — Sprint 1: prvi ekrani

Nastavak [Sprinta 0](../README.md). Redoslijed prati [01 §17](../../docs/01-mvp-spec.md#17-build-order), uz jednu dopunu: task 07 nije u build orderu, ali koraci 9–11 pretpostavljaju kičmu aplikacije koju nijedan raniji task ne postavlja.

| # | Task | Blokira | Procjena |
|---|---|---|---|
| [07](07-app-plumbing.md) ✅ | App plumbing — Riverpod, go_router, env, Supabase klijent | sve ostalo | 2 dana |
| [08](08-core-api-repozitoriji.md) ✅ | `core_api` — freezed modeli + repozitoriji | 10, 11, admin | 2–3 dana |
| [09](09-core-ui-theme-factory.md) ✅ | `core_ui` — theme factory po tenantu + tokeni | 10, 11 | 2 dana |
| [10](10-client-home-runtime-branding.md) ✅ | Client home sa runtime brandingom | 11 | 1–2 dana |
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

> **Task 08 je zatvoren** (✅) — `core_api` je sada stvarni sloj, ne skeleton. Pet repozitorija
> (`Salon`, `Service`, `Employee` + veze, `WorkingHours`, `Settings`), sedam modela u `core_domain`,
> i `ApiError` kao `sealed` hijerarhija koju ekran može razlikovati.
>
> Dokazano na CI-ju: [`Flutter` run 34620424824](https://github.com/htuco/salon-booking-platform/actions/runs/34620424824)
> (analiza, format, **97 testova**, oba Android APK-a, oba iOS builda) i
> [`Supabase tests` run 34619433879](https://github.com/htuco/salon-booking-platform/actions/runs/34619433879),
> gdje novi `rest_public_catalog.ts` sa **26 asercija bez korisničkog tokena** dokazuje da javni
> katalog stvarno radi prije prijave — to je jedina DoD stavka koju lokalna suita ne može dokazati.
>
> **Odluka koja je morala pasti prije prvog modela:** task, `architecture.md` i presedan iz taska 06
> davali su tri različita odgovora na pitanje gdje modeli žive. Odlučeno — jedan model po entitetu,
> u `core_domain`, sa `fromJson` ([ADR-0006](../../docs/adr/0006-modeli-u-core-domain.md)).
> `architecture.md` je ispravljen u istoj promjeni.
>
> **Codegen ulazi prvi put u repo** i `*.freezed.dart`/`*.g.dart` **nisu** u gitu — suprotno od
> `tenants.g.dart`, koji jeste (ADR-0002). `.gitignore` to razdvaja eksplicitno. CI je odmah uhvatio
> grešku koju lokalna suita nije: codegen treba **svakom** jobu koji kompajlira, ne samo `analyze`-u
> — bez toga prođu analiza i svih 97 testova, a padnu sva četiri builda.
>
> Ostaje za sljedećeg: nema `AppointmentRepository` (nema `anon` politike nad `appointments` — ide uz
> Auth u Sprintu 2), nema nijednog upisa (`book_appointment` se zove u tasku 11), i testovi ne
> dodiruju mrežu — mapiranje je dokazano lokalno, transport samo na CI-ju.

> **Task 09 je zatvoren** (✅) — `core_ui` više nije skeleton. `buildAppTheme` je jedina funkcija koja
> pravi `ThemeData` u sistemu, tokeni pokrivaju razmake, radijuse, trajanja i statusne boje, a šest
> komponenti (`AppButton`, `ServiceCard`, `TimeSlotChip`, `StatusBadge`, `EmptyState`,
> `SkeletonLoader`) čeka prvi pravi ekran.
>
> Dokazano na CI-ju: [`Flutter` run 34630719984](https://github.com/htuco/salon-booking-platform/actions/runs/34630719984)
> — **140 testova** (od toga 38 novih u `core_ui`), oba Android APK-a, oba iOS builda.
>
> **Tema je runtime podatak.** Boje dolaze iz `salons.primary_color`, pa iz `tenant.yaml`, pa tek
> onda iz defaulta; `main.dart` više nema nijedan heks. Prvi frame nosi `tenant.yaml` boju — da tema
> čeka `salonProvider`, tamni barber bi se otvorio bijelim bljeskom. Zato boje u `tenant.yaml` moraju
> pratiti bazu: kad se raziđu, korisnik vidi treptaj na startu.
>
> **`onPrimary` se računa poređenjem WCAG odnosa, ne pragom luminancije** — zlatna `#C6A667` ima
> luminanciju 0.42, pa bi prag 0.5 stavio bijeli tekst i dao 2.6:1. Test je usput našao stvarnu
> grešku koju oko ne bi: roze cijena sa 4.12:1, jer je brand tekst bio mjeren na `surface`, a kartica
> stoji na `surfaceContainer`.
>
> Ostaje za sljedećeg: **ništa nije pokrenuto na uređaju ni u browseru** (dokaz je widget-test nivo,
> a task 07 je pokazao da browser nalazi ono što suite propusti), `clinical_calm` nema tenanta, i
> sedam komponenti iz [02 §16](../../docs/02-user-flows-wireframes.md) namjerno nije napisano dok ih
> ekran ne zatraži. Detalji: [09-core-ui-theme-factory.md](09-core-ui-theme-factory.md#status-2026-09-11--✅-zatvoren).


> **Task 10 je zatvoren** (✅) — `/` je prvi pravi ekran. `HomeScreen` u
> `apps/client/lib/src/features/home/` slaže hero, usluge, tim, radno vrijeme, kontakt i sticky
> CTA iz `core_ui` komponenti; čita isključivo providere, nigdje repozitorij.
>
> **Dokazano slikom, po prvi put u projektu:** isti web build, dva `SALON_ID`-a, razlika u sve tri
> dimenzije — ime, boje (zlatna tamna naspram roze svijetle) i terminologija ("Zakaži termin"
> naspram "Rezerviši termin"). Screenshotovi su u
> [`docs/screenshots/`](../../docs/screenshots/) i u status bloku taska. Uz to, na CI-ju
> ([`Flutter` run 34637330417](https://github.com/htuco/salon-booking-platform/actions/runs/34637330417)):
> **165 testova PASS** (bilo 140), čista analiza, oba Android APK-a i oba iOS builda — što pokriva
> ono što lokalni web build ne može, jer su `cached_network_image` i `url_launcher` nove zavisnosti.
>
> **Screenshot je našao grešku koju nijedan test nije mogao:** živi status u heroju je koristio
> `StatusBadge(tone: info)`, a statusne boje su namjerno brand-neutralne — fiksna plava preko
> zlatnog i roze brenda. Status sada ide u `primaryContainer` i prati tenanta. To je isti obrazac
> kao u tasku 07: zelena suita, a greška se vidi tek kad se stvar otvori.
>
> **Kontrast test je usput ispravljen na dva mjesta** gdje je mjerio pogrešne parove: tekst na
> obojenoj površini poređen sa `surface`-om (inicijali salona, živi status) i CTA mjeren usred
> Material prelaza — 2.13:1 na dugmetu koje je zapravo 8.07:1. Sada traži stvarnu pozadinu iza
> svakog teksta i čeka kraj animacije.
>
> **`pumpAndSettle` više ne radi na ekranu sa skeletonom** — pulsira dok je vidljiv, pa test
> istekne i kad je sve ispravno. Svi testovi koji podižu `/` prešli su na `pump()`; ista zamka
> čeka svaki sljedeći ekran.
>
> Ostaje za sljedećeg: **ništa nije pokrenuto na uređaju ni emulatoru** (dokaz je web build u
> Chromiumu), **nijedan podatak nije došao sa stvarnog backenda** — `demo_main.dart` ih nosi
> prepisane iz `seed.sql`, jer Supabase vrijednosti i dalje blokira isti nalog kao u tasku 04 —
> i tap na uslugu vodi na `/book/service?serviceId=<id>`, koji task 11 mora pročitati, inače
> preselekcija usluge tiho ne radi. Detalji:
> [10-client-home-runtime-branding.md](10-client-home-runtime-branding.md#status-2026-09-11--✅-gotovo).
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
