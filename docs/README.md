# Salon Booking Platform — Dokumentacija

Personalizovane **native** booking aplikacije za frizere, beauty salone, masere, stomatološke ordinacije i ostale uslužne djelatnosti.

**Model:** jedan Flutter codebase + jedan multi-tenant backend → N brandiranih aplikacija u storeovima. Novi klijent = novi flavor i config, ne novi projekat.

| | |
|---|---|
| **Autor** | Hamza Tuco |
| **Zadnje ažuriranje** | 20.08.2026. |
| **Status** | Faza 2 završena — dokumentacija i wireframei. Sljedeće: Sprint 0 |
| **Verzija** | v4 — native (Flutter) + auth · Supabase + FCM |
| **Tržište** | SBK / BiH, početno Vitez i Travnik |

---

## Dokumenti — čitaj u ovom redoslijedu

| # | Dokument | Šta sadrži |
|---|---|---|
| **01** | [MVP Specifikacija](01-mvp-spec.md) | Proizvod, korisničke role, feature set, booking pravila, DB shema, pricing, tech stack, build order |
| **02** | [User Flows & Wireframes](02-user-flows-wireframes.md) | Svi ekrani sa wireframeima, flow dijagrami, push notifikacije, UX copy, design system |
| **03** | [Market Research](03-market-research-cutlio.md) | Cutlio, Rezervo, Rezervacija, SrediMe, Barberly, Booksy/Fresha — modeli, cijene, šta kopiramo |
| **04** | [Flutter Tenant Factory](04-flutter-tenant-factory.md) | Kako štancati klijente: flavors, CI/CD, store submission, onboarding checklist, skaliranje |
| **05** | [Vertikalni paketi](05-vertical-packs.md) | Frizeri, beauty, **zubari**, health, generic — terminologija, pravila, dentalni recall, GDPR |
| **06** | [Auth & Login Flow](06-auth-login-flow.md) | Apple, Google, Email + lozinka, Facebook — identity model, per-flavor config, store zahtjevi |
| **07** | [Tehnička arhitektura](07-tech-architecture.md) | Puna struktura repoa, konkretan izbor Flutter/Next.js/Supabase paketa, monorepo alati, observability |
| **08** | [Vitez + admin demo zahtjevi](08-vitez-admin-demo-requirements.md) | Dogovoreni demo scope, auth ponašanje, konfiguracija, van-scope stavke i kriteriji prihvata |
| — | [Team Handbook](TEAM_HANDBOOK.md) | Uloge u proizvodu, kako se doprinosi repou, rad sa Claude Code, razlike među mašinama |
| — | [ADR-ovi](adr/) | Donesene odluke sa obrazloženjem i odbačenim opcijama |

---

## Šta moraš pročitati prije prvog sastanka sa klijentom

Tri stvari mijenjaju odluke i nisu očigledne:

### 1. Konkurent prodaje isto za 25 EUR/mjesečno
[Rezervo](https://www.rezervo.uk/) (HR) prodaje white-label brandiranu app za frizere, zubare, masere, nail i tattoo studije za **25 EUR/mj bez ugovora, setup u 24h**. Naš pricing je 2–3× viši. To je izvedivo, ali samo sa jasnim argumentima: BiH lokalizacija, Viber, lokalna podrška, web link uz app.
→ [03 §2.4](03-market-research-cutlio.md)

### 2. Sve iOS app-e idu pod tvojim accountom — i to nosi tail risk
Klijent ne otvara nikakav Apple nalog; frizerki se prodaje gotova aplikacija, kao što Cutlio radi. Ali Guideline **4.2.6** formalno traži da provider ne submituje u ime klijenta, a **4.3 (Spam)** je u praksi češći uzrok odbijanja kod N sličnih app-a. Odbijanje jedne app-e je neugodnost — **ponovljena odbijanja mogu ugasiti cijeli account.**

Zato disciplina diferencijacije (prave fotografije, jedinstveni opisi, stvarni screenshotovi, staggered submission) nije kozmetika, i pripremi ljestvicu fallbackova prije prvog odbijanja.
→ [04 §6.2](04-flutter-tenant-factory.md)

### 3. Facebook login je najgori odnos vrijednosti i troška
Metina dokumentacija je protivrječna: jedan App ID *radi* za više bundle-ova, ali politika kaže "one approved iOS and Android bundle per app ID", a deep linking podržava samo jedan package name. Uz to Facebook Login traži Meta app review po FB App-u. Implementiran je, ali **default off i iza flaga** — Google + Apple + Email pokriva praktično sve u BiH.
→ [06 §7.4](06-auth-login-flow.md)

### 4. Zubari su najvrjednija vertikala, ali ne prva
Izgubljeni sat vrijedi 80–300 KM protiv 15–25 KM kod frizera, a recall na 6 mjeseci je feature koja **donosi prihod**. Ali `customerNote` u ordinaciji je zdravstveni podatak — traži pristanak, enkripciju, retenciju i DPA. Kreni sa frizerima.
→ [05 §6–7](05-vertical-packs.md)

---

## Arhitektura u jednoj slici

```
┌──────────────────────────────────────────────────────────────┐
│  Flutter monorepo — jedan codebase                           │
│  apps/client (N flavora) · apps/admin · packages/core_*      │
└────────────────────────┬─────────────────────────────────────┘
                         │  flutter build --flavor <salon>
     ┌───────────────────┼───────────────────┬─────────────────┐
     ▼                   ▼                   ▼                 ▼
┌──────────┐      ┌──────────┐        ┌──────────┐      ┌──────────┐
│ Barber   │      │ Beauty   │        │ Dr.      │      │ Admin    │
│ Vitez    │      │ Travnik  │  ...   │ Kovač.   │      │ (jedna   │
│ Android/ │      │ Android/ │        │ Android/ │      │  za sve) │
│ iOS/Web  │      │ iOS/Web  │        │ iOS/Web  │      │          │
└─────┬────┘      └─────┬────┘        └─────┬────┘      └─────┬────┘
      └─────────────────┴───────────────────┴─────────────────┘
                              │
                  ┌───────────▼────────────┐
                  │  Supabase              │
                  │  Postgres + RLS        │
                  │  Auth · Storage        │
                  │  availability · pg_cron│
                  └───────────┬────────────┘
                              │
                  ┌───────────▼────────────┐
                  │  Firebase FCM          │
                  │  (samo push, bez auth) │
                  └────────────────────────┘

  + Next.js web: super admin konzola · politika privatnosti po tenantu · QR stranice
```

**Ključna asimetrija:** client app je brandiran do detalja, admin app je generički za sve salone. Vlasnik ne mari kako mu izgleda admin — mari kako izgleda ono što njegov klijent vidi.

---

## Interaktivni mockup

React/web prototip za validaciju flowa i vizuala **prije** prvog Dart fajla.

```bash
npm i
npm run dev
```

Otvori `/` za pregled svih ekrana. Mapiranje mockup → Flutter screen: [02 §2](02-user-flows-wireframes.md).

> Mockup **nije** production kod. Njegova jedina svrha je da vidiš flow i vizuelni jezik prije implementacije.

---

## Odluke koje su već donesene

Ne otvaraj ih ponovo bez novog podatka:

| Odluka | Gdje |
|---|---|
| Native od početka, Flutter (Android + iOS + Web iz jednog koda) | [01 §1.1](01-mvp-spec.md) |
| Web build je sekundarni kanal (Instagram bio, QR), ne zamjena za app | [01 §1.1](01-mvp-spec.md) |
| Social login je jedan tap; email korisnik ima kratku registraciju i recovery | [ADR-0010](adr/0010-email-lozinka-umjesto-otp-a.md) |
| **Facebook login se ne implementira** — provideri su Apple, Google i email | [ADR-0011](adr/0011-facebook-login-se-ne-implementira.md) |
| **Admin navigacija nosi i nenapisane module**, a „Zahtjevi" su filter u adresi, ne svoja ruta | [ADR-0012](adr/0012-admin-navigacija-nosi-i-nenapisane-module.md) |
| **Radnik dobija sužen pristup svojim terminima**, ne umanjenu admin ulogu | [ADR-0013](adr/0013-radnik-dobija-suzen-pristup-svojim-terminima.md) |
| Korak rezervacije je **po usluzi**, uz salonski kao podrazumijevani | [ADR-0014](adr/0014-korak-rezervacije-je-po-usluzi.md) |
| Slike idu u **Supabase Storage**, javni bucket sa upisom po salonu | [ADR-0015](adr/0015-slike-idu-u-supabase-storage-javni-bucket.md) |
| Availability logika je na backendu, nikad u app-u | [01 §8.1](01-mvp-spec.md) |
| Termin ide kao `pending`, salon ručno potvrđuje | [01 §18](01-mvp-spec.md) |
| Branding je runtime gdje god može biti — promjena boje ne traži store review | [04 §1](04-flutter-tenant-factory.md) |
| Vertikala je config, ne fork koda | [05 §2](05-vertical-packs.md) |
| Login: Apple (iOS), Google, Email + lozinka — na **kraju** booking flow-a | [06 §1.1](06-auth-login-flow.md) |
| Pregled salona i slobodnih termina nikad ne traži login | [06 §1.1](06-auth-login-flow.md) |
| **Supabase** za bazu, auth, storage i cron; **Firebase samo za FCM push** | [01 §16.1](01-mvp-spec.md) |
| Jedan Supabase projekat; `AuthIdentity` globalan, `Customer` per-salon | [06 §4](06-auth-login-flow.md) |
| Client app i admin app su Flutter native; super admin je Next.js | [01 §16.2](01-mvp-spec.md) |
| Monorepo (melos) za Flutter; Next.js u istom git repou, van melosa | [01 §16.3](01-mvp-spec.md) |
| **Broj telefona se ne traži od klijenta** — push zamjenjuje poziv i SMS | [06 §3.1](06-auth-login-flow.md) |
| iOS app-e pod našim Apple accountom, klijent ne otvara ništa | [04 §6.2](04-flutter-tenant-factory.md) |
| iOS je Pro paket, ne Starter | [01 §15](01-mvp-spec.md) |
| Linija B (0 KM setup) je obavezna, ne opciona | [01 §15](01-mvp-spec.md) |
| Frizeri/beauty prvi, zubari drugi | [05 §7.3](05-vertical-packs.md) |
| Nema marketplace/discovery — to je drugi biznis | [03 §6](03-market-research-cutlio.md) |

---

## Sljedeći korak

**Sprint 0** — temelj bez kojeg ništa ne skalira:

1. Flutter monorepo sa melos: `apps/client`, `apps/admin`, `packages/core_*`
2. **Flavor sistem** za Android + iOS, dokazan na dva demo salona
3. CI pipeline: jedna komanda → AAB artefakt
4. Backend shema po [01 §11](01-mvp-spec.md) + tenant izolacija + policy testovi
5. Supabase projekat: Auth provideri + RLS policy + policy testovi ([06 §4](06-auth-login-flow.md))
6. Firebase projekat samo za FCM, app po flavoru

Puni build order: [01 §17](01-mvp-spec.md).

---

## Izvorni dokumenti

`.docx` fajlovi u `docs/source/` su originalni v1 draftovi (maj 2026, web-first model). Konvertovani su u markdown i značajno dorađeni u `docs/`. Zadržani su za referencu:

- `source/Salon_Booking_Platform_MVP_Spec_v1.docx` → [01-mvp-spec.md](01-mvp-spec.md)
- `source/Salon_Booking_Platform_Faza_2_User_Flows_Wireframes.docx` → [02-user-flows-wireframes.md](02-user-flows-wireframes.md)

Vizuelna specifikacija ekrana nije ovdje nego u [`prototype/ui/`](../prototype/ui/README.md) — dizajnerski
handoff sa 17 ekrana, tokenima i komponentama.
