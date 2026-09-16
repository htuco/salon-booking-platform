# Salon Booking Platform — MVP Specifikacija

Personalizovane **native** booking aplikacije za frizerske, barber i beauty salone u SBK/BiH.

| | |
|---|---|
| **Verzija** | v4 — native-first (Flutter) + auth |
| **Autor** | Hamza Tuco |
| **Datum** | 20.08.2026. (v1: Maj 2026., web-first) |
| **Status** | Spec za razvoj Faze 1 |
| **Prati** | [02 — Flows & wireframes](02-user-flows-wireframes.md) · [03 — Market research](03-market-research-cutlio.md) · [04 — Tenant factory](04-flutter-tenant-factory.md) · [05 — Vertikalni paketi](05-vertical-packs.md) · [06 — Auth & login](06-auth-login-flow.md) |

---

## 1. Product idea

Platforma omogućava salonima da dobiju **svoju native mobilnu aplikaciju** u App Storeu i Google Playu — sa svojim imenom, ikonom, bojama i uslugama.

Klijent salona skine aplikaciju salona, izabere uslugu, radnika i termin, prijavi se i pošalje
zahtjev. Social login je jedan tap; email korisnik se prvi put kratko registruje emailom i lozinkom.
Broj telefona se ne traži. Vlasnik salona kroz admin aplikaciju upravlja terminima, uslugama,
radnicima i rasporedom.

Iako svaki salon ima svoju aplikaciju u storeu, tehnički je to **jedan Flutter codebase, jedan multi-tenant backend, N buildova**. Novi klijent = novi flavor + config, ne novi projekat.

### 1.1 Zašto native, i zašto Flutter

Native je odluka o **pozicioniranju, ne o tehnologiji**. Ikona salona na home screenu klijentovog telefona je proizvod koji prodajemo. Web link to ne može dati — a upravo to Cutlio naplaćuje ([research §1.1](03-market-research-cutlio.md)).

Flutter je izbor jer je jedini stack koji daje sva tri kanala iz jednog koda:

| Kanal | Flutter build | Čemu služi |
|---|---|---|
| Android | `flutter build appbundle --flavor <salon>` | Glavni kanal u BiH |
| iOS | `flutter build ipa --flavor <salon>` | Manji, ali prestižniji dio klijentele |
| Web | `flutter build web --dart-define=SALON=<salon>` | **Link za Instagram bio i QR kod** — klijent koji ne želi instalirati app |

Ovo je ključno: **native ne isključuje web link.** Isti codebase daje i jedno i drugo. Salon dobija ikonu u storeu *i* link koji radi bez instalacije.

**Iskrena zamjerka koju moraš znati:** Flutter Web ima težak prvi load (~1.5–2 MB) i renderuje na canvasu, pa nije idealan za "kliknem sa Instagrama i naručim se u 60 sekundi". Za Fazu 1 je prihvatljiv jer je web sekundarni kanal. Ako mjerenja pokažu da web konverzija pada, rješenje je tanka statična booking stranica (Next.js) koja gura na isti API — ne prepisivanje app-a. Odluku odgađamo do podataka.

**Alternative koje smo odbacili:**

| Stack | Zašto ne |
|---|---|
| React Native | Radi, ali flavors/build varijante su bolne, a Flutter Web nam daje treći kanal besplatno |
| Native Android + native iOS | Dva codebase-a po feature-u. Ubija ekonomiju štancanja |
| Web-only PWA | Nema ikone u storeu — nema onoga što prodajemo |
| Capacitor / WebView wrapper | Store review timovi to prepoznaju i odbijaju kao "repackaged website" |

---

## 2. Target customers

Sistem opslužuje više industrija iz jednog codebase-a kroz **vertikalne pakete** — terminologija, booking pravila i tema su konfiguracija, ne fork koda. Detalji: [05-vertical-packs.md](05-vertical-packs.md).

| Vertikala | Ko | Faza |
|---|---|---|
| `barber` | Barber shopovi, muški frizerski saloni | **Faza 1** |
| `beauty` | Ženski frizerski, beauty, nokti, obrve/trepavice, kozmetika | **Faza 1** |
| `dental` | **Stomatološke ordinacije** | Faza 2 |
| `health` | Masaža, SPA, fizioterapija, veterinari | Faza 2 |
| `generic` | Tattoo studiji, auto-servisi, advokati, knjigovođe | Faza 3 |

**Početni geografski fokus:** SBK / Srednjobosanski kanton — Vitez, Travnik, Novi Travnik, Bugojno, Jajce, Kiseljak, Busovača.

**Idealni prvi klijent:** salon koji već prima narudžbe preko Vibera, WhatsAppa, Instagrama ili telefona, ima **stalnu klijentelu**, ali nema organizovan booking.

> Native model traži klijenta sa stalnom klijentelom. App install se isplati salonu kojem se klijenti vraćaju svake 3 sedmice. Salonu koji živi od prolaznika prvo prodaj web link.

### 2.1 Zašto zubari nisu u Fazi 1 iako su vrijedniji

Zubar plaća više — vrijednost izgubljenog sata mu je 80–300 KM protiv 15–25 KM kod frizera, a prosječan interval posjeta je 6 mjeseci, što znači da **treba sistem koji mu vraća pacijente**. To je najvrjednija vertikala i nijedan regionalni konkurent je ne pokriva ozbiljno ([research §2.3](03-market-research-cutlio.md)).

Ali nosi teret koji nedokazan sistem ne treba:
- `customerNote` u ordinaciji je **podatak o zdravlju** — traži pristanak, enkripciju, retencijsku politiku i DPA sa klijentom
- Store review za zdravstvene app-e je stroži i traži javnu politiku privatnosti
- Treba `DentalRecall` entitet, novi ekran i `clinical_calm` temu

**Odluka:** frizeri i beauty prvi — na njima iznesi tenant factory i availability engine. Zubari kao Faza 2, sa pripremljenim DPA i politikom privatnosti. Detalji i pravni minimum: [05 §6–7](05-vertical-packs.md).

## 3. Problem

- Termini se zakazuju preko više kanala: Viber, WhatsApp, Instagram, pozivi
- Vlasnik ili radnici stalno odgovaraju na ista pitanja ("Ima li slobodno sutra?")
- Termini se ručno upisuju u svesku, Google Calendar ili poruke
- Lako se desi **dupli termin**
- Klijenti zaborave termin → **no-show**
- Salon nema profesionalno prisustvo — nema app, nema booking link u Instagram bio
- Vlasnik nema centralizovan pregled termina

---

## 4. Solution

Native aplikacija salona (Android + iOS) · web booking link i QR kod iz istog koda · push notifikacije · admin aplikacija · kalendar termina · upravljanje uslugama i radnicima · radno vrijeme · blokiranje termina · potvrđivanje/odbijanje zahtjeva · branding (logo, ikona, boje, slike, tekstovi).

> **Glavna vrijednost:** salon ima svoju aplikaciju u storeu, klijenti se naručuju bez poziva, vlasnik ima manje poruka i potpunu kontrolu termina.

---

## 5. User roles

### 5.1 Super Admin — vlasnik platforme (ti)
Kreira i uređuje salon · podešava logo, ikonu, boje, temu · dodaje vlasnika salona · aktivira/deaktivira salon · vidi sve salone i telemetriju · **pokreće build i store submission za novi salon**.

Radi kroz **Next.js web konzolu** — gusti desktop admin UI, bez potrebe za push-om. Ne treba mu mobilna app ([§16.2](#162-frontend--šta-u-čemu)).

### 5.2 Salon Admin / Owner
Login u admin app · pregled današnjih termina · kalendar · potvrda/odbijanje/otkazivanje termina · ručno dodavanje termina · uređivanje usluga (cijena, trajanje) · dodavanje/uređivanje radnika · radno vrijeme · blokiranje vremena · pregled podataka klijenta.

Radi kroz **jednu generičku admin aplikaciju** za sve salone (v. §10 asimetrija).

### 5.3 Employee / Radnik
**Faza 1: nema zaseban login.** Salon Admin upravlja svim radnicima. Radnik postoji kao *resurs* (ima usluge, raspored, termine), ne kao *korisnik*.

Faza 2: radnik dobija login u istu admin app i vidi samo svoje termine.

### 5.4 End Customer / Klijent salona
Skine app salona (ili otvori web link) · vidi salon i usluge · bira uslugu, radnika (ili "bilo koji"), datum i slobodan termin · **prijavi se** · šalje zahtjev · **dobija push kad salon potvrdi** · vidi i otkazuje svoje termine.

**Prijava:** Apple (iOS), Google, Email + lozinka i Facebook. Social login je jedan tap; email ima
eksplicitnu registraciju, potvrdu adrese i oporavak lozinke.

**Login se traži na kraju booking flow-a**, nakon što je klijent izabrao termin — nikad na ulazu u app. Pregled salona, usluga, cijena, tima i slobodnih termina **nikad** ne traži prijavu. Puni dizajn: [06-auth-login-flow.md](06-auth-login-flow.md).

**Broj telefona se ne traži.** Push notifikacija zamjenjuje i poziv i SMS — potvrda, odbijanje, podsjetnici i izmjene termina idu preko push-a ([06 §3.1](06-auth-login-flow.md)).

---

## 6. MVP features

### 6.1 Super Admin (web konzola)

**Kreiranje salona** — naziv, slug, adresa, grad, telefon, Instagram, Facebook, logo, **app ikona**, cover slika, primarna boja, sekundarna boja, tema, status (`active`/`inactive`), paket (`starter`/`pro`/`premium`).

**Build artefakti po salonu** (v. [04-flutter-tenant-factory.md](04-flutter-tenant-factory.md)):
- `flavor` naziv — `barberstudiovitez`
- `applicationId` — `ba.nasadomena.barberstudiovitez`
- `bundleId` — `ba.nasadomena.barberstudiovitez`
- App display name — "Barber Studio Vitez"
- App ikona (1024×1024) + splash logo
- Web slug — `/s/barber-studio-vitez`

**Upravljanje salonima** — lista · pregled · uređivanje · deaktivacija · promjena teme, boja i paketa · **status store submissiona** (`draft` → `in_review` → `live`).

### 6.2 Client app (aplikacija salona)

Mobile-first, jedan salon po buildu. `salonId` je **ukucan u build** kroz `--dart-define`, app ne bira salon.

**Home screen** — logo, naziv, cover/hero slika, kratki opis, CTA "Zakaži termin", popularne usluge, radno vrijeme, lokacija sa linkom na mapu, kontakt, Instagram/Facebook.

**Usluge** — naziv, opis, trajanje, cijena, kategorija.
> Primjer: *Muško šišanje · 30 min · 15 KM*

**Booking flow** — 4 koraka + potvrda:
1. Izaberi uslugu
2. Izaberi radnika (ili "bilo koji dostupan")
3. Izaberi datum i slobodan termin
4. Unesi ime i telefon
5. Vidi potvrdu

**Confirmation screen** — status je `pending`, ne `confirmed`. Copy to mora reflektovati:

> **Zahtjev za termin je poslan.** Salon će potvrditi termin uskoro.
> Usluga: Muško šišanje · Radnik: Emir · Datum: 20.05.2026. · Vrijeme: 14:30

**Moji termini** *(novo — omogućeno native-om)* — lista termina sa ovog uređaja, sortirana po datumu, sa statusom. Klijent može otkazati termin do `minCancelHours` prije početka. Bez naloga: termini se vežu na `deviceId` + telefon.

**Prijava** *(novo u v4)* — Apple (iOS) · Google · Email + lozinka · Facebook (iza flaga).
Login se pojavljuje između koraka 3 i 4 booking flow-a. **Bez broja telefona.** Email korisnik bira
prijavu ili kratku registraciju, potvrđuje adresu i može vratiti zaboravljenu lozinku. Opcioni guest
mod po salonu (`allowGuestBooking`, default off). Detalji: [06-auth-login-flow.md](06-auth-login-flow.md).

**Moj račun** *(obavezno za store)* — pregled podataka, odjava i **brisanje računa iz same app-e**. Bez ekrana za brisanje računa iOS submission pada ([06 §8.2](06-auth-login-flow.md)).

**Push notifikacije** *(novo — omogućeno native-om)*:

| Trigger | Poruka |
|---|---|
| Salon potvrdio termin | "Vaš termin je potvrđen — 20.05. u 14:30" |
| Salon odbio termin | "Termin nije moguć. Probajte drugi." |
| D-1 od termina | "Sutra u 14:30 — Muško šišanje kod Emira" |
| H-3 od termina | "Termin za 3 sata — Muško šišanje" |

D-1 / H-3 pattern je Cutliov dokazani default ([research §2](03-market-research-cutlio.md)). Push je besplatan — ovo je feature koju web verzija ne može dati i glavni argument za native.

### 6.3 Admin app (jedna app za sve salone)

**Login** — email + lozinka. Nakon logina app zna kojem salonu korisnik pripada.

**Dashboard** — današnji termini · **novi zahtjevi (najvažniji blok)** · broj termina danas · broj termina ove sedmice · najbliži naredni termin · brze akcije (dodaj termin, dodaj uslugu, blokiraj vrijeme).

**Push za vlasnika** — "Novi zahtjev za termin: Amina Hadžić, Feniranje, 13:30". Ovo je feature koja mijenja ponašanje — vlasnik potvrđuje termin za 30 sekundi, a ne za 4 sata.

**Appointments / Termini** — lista, filteri (datum, status, radnik, usluga), detalji, akcije: potvrdi · odbij · otkaži · označi kao završeno · označi kao no-show · ručno dodaj.

| Status (DB) | UI prikaz |
|---|---|
| `pending` | Na čekanju |
| `confirmed` | Potvrđeno |
| `cancelled` | Otkazano |
| `completed` | Završeno |
| `no_show` | Nije došao/la |

**Calendar view** — dnevni prikaz, termini po vremenu, boje po statusu, tap otvara detalje. Sedmični prikaz i drag-and-drop: Faza 2.

**Services** — dodaj/uredi/deaktiviraj uslugu, cijena, trajanje, opis, kategorija.
Polja: `name`, `description`, `category`, `price`, `durationMinutes`, `isActive`

**Employees** — dodaj/uredi/deaktiviraj radnika, dodijeli usluge, slika.
Polja: `name`, `role`, `imageUrl`, `bio`, `isActive`

**Working hours** — Faza 1: radno vrijeme na nivou salona. Faza 2: po radniku.

| Dan | Vrijeme |
|---|---|
| Pon – Pet | 09:00 – 17:00 |
| Subota | 09:00 – 14:00 |
| Nedjelja | Zatvoreno |

**Blocked slots** — blokiranje vremena kad salon ili radnik nije dostupan. Blokirano se **ne prikazuje** klijentu kao slobodno.

**Kontakt klijenta jednim tapom** — `tel:`, `viber://chat?number=`, `https://wa.me/` iz detalja termina, **za klijente koji imaju upisan telefon** (oni koje je salon ručno unio). Klijenti iz app-a se dobijaju push-om, ne pozivom.

---

## 7. Out of scope za Fazu 1

Online plaćanje · depoziti/avansi · **SMS gateway i SMS podsjetnici** (push ih zamjenjuje) · **prikupljanje broja telefona od klijenta** · manuelno spajanje računa (account linking) · WhatsApp Business API · loyalty program · marketplace · recenzije · kuponi · gift cards · napredna analitika · više lokacija po salonu · payroll · inventar · offline mode sa sinkronizacijom · kompleksni permission sistemi · radnički login · sedmični kalendar · drag-and-drop.

> **Faza 1 mora dokazati samo jedno:** salon dobija svoju aplikaciju u storeu, klijent kroz nju pošalje zahtjev za termin, salon ga potvrdi, i niko ne dobije dupli termin.

---

## 8. Booking rules

1. Termin ne može biti van radnog vremena.
2. Termin ne može preklapati postojeći `confirmed` termin.
3. Trajanje termina određuje usluga.
4. `pending` termini **privremeno blokiraju slot** dok ih salon ne potvrdi ili odbije.
5. Ako salon odbije `pending` termin, slot se vraća kao slobodan.
6. `bufferMinutes` je minimalni razmak između termina.
7. `minAdvanceBookingHours` — ne može se naručiti za manje od N sati unaprijed.
8. `maxAdvanceBookingDays` — ne može se naručiti dalje od N dana.
9. **Pending timeout** — `pending` stariji od `pendingExpiryHours` automatski pada u `cancelled` i oslobađa slot. Bez ovoga zaboravljeni zahtjevi trajno blokiraju kalendar.
10. **Klijent može otkazati** do `minCancelHours` prije termina. Poslije toga samo salon.

> Primjer: Farbanje traje 120 min. Termin u 10:00 rezerviše 10:00 – 12:00, plus buffer.

### 8.1 Availability algoritam

Ovo je **jedini dio sistema koji mora biti tačan**. Sve ostalo je CRUD.

```
ulaz:  salonId, serviceId, employeeId | null, date
izlaz: lista slobodnih startTime vrijednosti

1. duration = service.durationMinutes
2. radnici = employeeId ? [employeeId] : radnici_koji_rade(serviceId)
3. za svakog radnika:
     a. window = working_hours(salon, radnik, dayOfWeek(date))
        ako isClosed → preskoči
     b. kandidati = window podijeljen na korake od slotStepMinutes
     c. izbaci kandidate gdje [start, start+duration+buffer) siječe:
          - appointment sa statusom pending | confirmed
          - blocked slot
          - pauzu iz working hours
     d. izbaci kandidate u prošlosti
     e. izbaci kandidate bliže od minAdvanceBookingHours
4. unija po radnicima, deduplikacija, sortiraj
```

**Gdje ovo živi:** na **backendu**, ne u Flutter app-u. App samo prikazuje listu koju dobije. Razlog: klijent ne smije moći poslati zahtjev za slot koji ne postoji, a app verzije na telefonima kasne mjesecima. Availability logika u app-u = bug koji ne možeš hotfixati.

Backend takođe **ponovo validira** slot pri kreiranju termina — između `GET /availability` i `POST /appointments` prođe 30 sekundi u kojima neko drugi može uzeti isti slot. Vrati `409 Conflict` i app prikaže "Ovaj termin je upravo zauzet. Izaberite drugi."

---

## 9. Core user flows

Wireframei i detaljni flowovi: [02-user-flows-wireframes.md](02-user-flows-wireframes.md).

### 9.1 Klijent zakazuje termin
Otvori app → home → "Zakaži termin" → usluga → radnik → datum → slobodan termin → ime/telefon/napomena → "Pošalji zahtjev" → backend kreira appointment `pending` → confirmation screen → **vlasnik dobija push**.

### 9.2 Salon potvrđuje termin
Push "Novi zahtjev" → tap → detalji → "Potvrdi" → status `confirmed` → **klijent dobija push "Termin je potvrđen"** → termin ostaje blokiran u kalendaru.

### 9.3 Salon odbija termin
Otvori `pending` → "Odbij" → opcionalni razlog → status `cancelled` → slot se oslobađa → klijent dobija push.

### 9.4 Salon ručno dodaje termin
"Dodaj termin" → usluga → radnik → datum i vrijeme → ime i telefon → backend provjerava dostupnost → ako je slobodno, kreira `confirmed` termin sa `source: manual`.

### 9.5 Salon blokira vrijeme
Kalendar → "Blokiraj vrijeme" → radnik ili cijeli salon → datum → od–do → razlog → slot blokiran.

### 9.6 Klijent otkazuje termin
"Moji termini" → tap na termin → "Otkaži termin" → potvrda → status `cancelled` → slot slobodan → **vlasnik dobija push**.

---

## 10. Customization / white-label

Svaki salon ima svoju aplikaciju u storeu. U pozadini je isti codebase, ali pred klijentom salona mora biti potpuno njegova.

### Šta se personalizuje po salonu

**Build-time (ukucano u app, mijenja se samo novim buildom):**
app ime · app ikona · splash screen · `applicationId` / `bundleId` · `salonId` · osnovna paleta

**Runtime (iz backenda, mijenja se bez novog builda):**
logo · primarna i sekundarna boja · cover slika · galerija · tekst dobrodošlice · usluge · radnici · radno vrijeme · kontakt · društvene mreže

> **Pravilo:** sve što se može čitati iz backenda — čita se iz backenda. Build-time config je minimum koji store zahtijeva. Vlasnik koji hoće promijeniti boju ne smije čekati store review od 3 dana.

### Teme za Fazu 1

| Tema | Za koga | Karakter |
|---|---|---|
| **Modern Barber** | barber shopovi, muški saloni | Tamni background, jači kontrast, velike slike, jednostavan CTA, premium muški osjećaj |
| **Elegant Beauty** | ženski frizerski, beauty, nokti, obrve | Svijetliji background, elegantne kartice, mekši spacing, fokus na slike i usluge |

Tema je `ThemeData` factory u Flutteru koji prima `primaryColor` / `secondaryColor` iz backenda. Dvije teme × N boja = svaki salon izgleda drugačije bez novog koda.

### Ključna asimetrija

**Client app je brandiran do detalja. Admin app je generički za sve salone.**

Vlasnik ne mari kako mu izgleda admin — mari kako izgleda ono što njegov klijent vidi. Cutlio i Barberly rade isto ([research §1.2](03-market-research-cutlio.md)). Ne troši ni dan na admin dizajn.

---

## 11. Database entities

### Salon
`id` · `name` · `slug` · `description` · `logoUrl` · `coverImageUrl` · `primaryColor` · `secondaryColor` · `theme` · `address` · `city` · `phone` · `email` · `instagramUrl` · `facebookUrl` · `status` · `plan` · `createdAt` · `updatedAt`

### SalonBuild — **novo u v3 (native)**
`id` · `salonId` · `flavor` · `applicationId` · `bundleId` · `appDisplayName` · `appIconUrl` · `androidVersionCode` · `iosBuildNumber` · `playStoreStatus` · `appStoreStatus` · `playStoreUrl` · `appStoreUrl` · `lastBuiltAt`

> Native model traži da negdje pišeš gdje je koji salon u store pipeline-u. Bez ovoga ćeš na 15 klijenata gubiti kontrolu. Detalji: [04-flutter-tenant-factory.md](04-flutter-tenant-factory.md).

### VerticalPack — **novo u v3**
`id` · `key` (`barber` \| `beauty` \| `dental` \| `health` \| `generic`) · `displayName` · `terminology` (JSONB) · `defaultSettings` (JSONB) · `defaultTheme` · `defaultServices` (JSONB) · `featureFlags` (JSONB) · `requiredConsents` (JSONB)

Na `Salon` dodaj: `verticalPackKey` · `terminologyOverride` (JSONB, nullable)

> Vertikala je red u bazi i JSON config, **nikad branch u kodu**. Nijedan vertikalno-zavisan string ne smije biti u Flutter ekranu — inače promjena terminologije traži store review. Detalji: [05-vertical-packs.md](05-vertical-packs.md).

### User
`id` · `salonId` (nullable) · `name` · `email` · `passwordHash` · `role` (`super_admin` \| `salon_admin` \| `employee`) · `createdAt` · `updatedAt`

### Service
`id` · `salonId` · `name` · `description` · `category` · `price` · `durationMinutes` · `isActive` · `createdAt` · `updatedAt`

### Employee
`id` · `salonId` · `name` · `role` · `bio` · `imageUrl` · `isActive` · `createdAt` · `updatedAt`

### EmployeeService
`id` · `employeeId` · `serviceId`

### WorkingHour
`id` · `salonId` · `employeeId` (nullable) · `dayOfWeek` · `startTime` · `endTime` · `breakStartTime` (nullable) · `breakEndTime` (nullable) · `isClosed`

### AuthIdentity — **novo u v4 (login)**
`id` · `supabaseUserId` (unique) · `providers` (`['apple','google','facebook','email']`) · `email` (nullable) · `emailVerified` · `displayName` (nullable) · `isAnonymous` · `deletedAt` (nullable) · `createdAt` · `lastLoginAt`

> **Nema `phone` polja.** Ne tražimo broj telefona od klijenta — push zamjenjuje poziv i SMS ([06 §3.1](06-auth-login-flow.md)).

> **Globalan, nije vezan na salon.** Jedan Supabase projekat za sve tenante znači da klijent koji se prijavi u dva naša salona ima isti identitet. Ali `Customer` ostaje strogo per-salon — **salon A ne smije nikad vidjeti da klijent ide i u salon B** ([06 §4.3](06-auth-login-flow.md)).

### Customer — **novo u v2**
`id` · `salonId` · **`authIdentityId`** (nullable) · `name` · `phone` (nullable) · `note` (nullable) · `visitCount` · `noShowCount` · `isVip` · `firstSeenAt` · `lastVisitAt`

> `authIdentityId` je nullable namjerno — salon admin ručno unosi klijente koji zovu telefonom i nikad neće imati app. **`phone` upisuje samo salon admin** za takve klijente; klijent iz app-a ga nikad ne unosi. `visitCount`, `noShowCount` i `isVip` su **per-salon**, nikad globalni.

> Bez `Customer` entiteta nema stalnog klijenta, VIP-a, cancellation waitliste ni historije posjeta — a to su feature koje opravdavaju Pro i Premium paket. **Ključ za dedupliciranje je `(salonId, authIdentityId)`** za app klijente, a `(salonId, phone)` za one koje salon ručno unese.

### Device — **novo u v3 (native)**
`id` · `salonId` · `deviceId` · `fcmToken` · `platform` (`android` \| `ios` \| `web`) · **`authIdentityId`** (nullable) · `appVersion` · `lastSeenAt`

> App se registruje na prvom otvaranju sa anonimnim `deviceId` i FCM tokenom — to omogućava push i prije prijave. Nakon prijave `deviceId` se veže na `authIdentityId`, pa termini prate korisnika kroz uređaje i reinstalacije. Jedan korisnik može imati N uređaja.

### Appointment
`id` · `salonId` · `serviceId` · `employeeId` (nullable) · `customerId` · **`authIdentityId`** (nullable) · `deviceId` (nullable) · `customerName` · `customerPhone` · `customerNote` (nullable) · `date` · `startTime` · `endTime` · `status` (`pending` \| `confirmed` \| `cancelled` \| `completed` \| `no_show`) · `source` (`app` \| `web` \| `manual` \| `guest`) · `cancelReason` (nullable) · `cancelledBy` (`customer` \| `salon` \| `system`) · `createdAt` · `updatedAt`

> `customerName`/`customerPhone` ostaju denormalizovani kao historijski snapshot — ako klijent promijeni broj, stari termini ostaju tačni.

### BlockedSlot
`id` · `salonId` · `employeeId` (nullable) · `date` · `startTime` · `endTime` · `reason` · `createdAt`

### NotificationLog — **novo u v3**
`id` · `salonId` · `appointmentId` · `deviceId` · `type` (`confirmed` \| `rejected` \| `reminder_d1` \| `reminder_h3` \| `new_request` \| `cancelled`) · `sentAt` · `status` (`sent` \| `failed`)

> Bez loga ćeš duplirati remindere pri svakom restartu schedulera i klijent će dobiti 4 iste notifikacije. Provjeri log prije slanja.

### SalonSettings
`id` · `salonId` · `bookingMode` (`manual` \| `auto`) · **`bookingGranularity`** (`exact_slot` \| `date_only`) · `bufferMinutes` · `slotStepMinutes` · `minAdvanceBookingHours` · `maxAdvanceBookingDays` · `pendingExpiryHours` · `minCancelHours` · **`requireStaffChoice`** · **`showPricesInApp`** · **`allowGuestBooking`** · `remindersEnabled` · `notifyOnCancellation` · `timezone` · `language` · `createdAt` · `updatedAt`

> Default vrijednosti dolaze iz `VerticalPack.defaultSettings` pri kreiranju salona, pa ih vlasnik može mijenjati. `bookingGranularity: date_only` je Rezervo model — klijent bira samo datum, ordinacija dodijeli vrijeme. Idealno za zubare ([05 §4](05-vertical-packs.md)).

---

## 12. Screens

### Client app (`apps/client`)

Zadnja dva reda dolaze iz dizajnerskog handoffa (`prototype/ui/SPEC.md` 5j i 5k), ne iz prve
verzije ove tabele: donja navigacija ima pet ćelija, pa Obavijesti i Postavke moraju imati
svoju rutu. "Postavke" je širi ekran od "Moj račun" — `/account` ostaje zaseban i otvara se
iz njega.

`/privacy` je dodan u tasku 21. Handoff (`14-o-aplikaciji.png`) crta red "Politika privatnosti"
pored "Pravila korištenja", a do tada su oba reda vodila na isti ekran. **Ekran u aplikaciji ne
zamjenjuje javni URL** koji §17 korak 29 traži po tenantu — isti `app_policies` red kasnije
servira i tu stranicu.

| Screen | Ruta | Prioritet |
|---|---|---|
| Home / salon landing | `/` | Must |
| Sve usluge | `/services` | Must |
| Booking — usluga | `/book/service` | Must |
| Booking — radnik | `/book/employee` | Must |
| Booking — termin | `/book/slot` | Must |
| Booking — podaci | `/book/details` | Must |
| Booking — potvrda | `/book/success` | Must |
| **Login (Apple/Google/Email/Facebook)** | `/auth/login` | Must |
| **Moj račun + brisanje računa** | `/account` | Must |
| Moji termini | `/appointments` | Must |
| Detalji termina + otkazivanje | `/appointments/:id` | Should |
| Tim / radnici | `/team` | Should |
| Galerija + lightbox | `/gallery` | Should |
| Recenzije | `/reviews` | Should |
| O salonu / kontakt | `/about` | Should |
| Obavijesti | `/notifications` | Should |
| Postavke | `/settings` | Should |
| O aplikaciji | `/about-app` | Should |
| Pravila korištenja | `/terms` | Must |
| Politika privatnosti | `/privacy` | Must |

### Admin app (`apps/admin`)

| Screen | Ruta | Prioritet |
|---|---|---|
| Login | `/login` | Must |
| Dashboard | `/dashboard` | Must |
| Termini + filteri | `/appointments` | Must |
| Detalji termina (bottom sheet) | `/appointments/:id` | Must |
| Dodaj termin | `/appointments/new` | Must |
| Kalendar (dnevni) | `/calendar` | Should |
| Usluge | `/services` | Must |
| Radnici | `/employees` | Must |
| Radno vrijeme | `/working-hours` | Should |
| Blokiraj vrijeme (modal) | `/calendar/block` | Should |
| Postavke | `/settings` | Should |
| O aplikaciji | `/about-app` | Should |
| Pravila korištenja | `/terms` | Must |

### Super admin (Next.js konzola — `web/app/super-admin`)

| Screen | Ruta |
|---|---|
| Lista salona | `/super-admin/salons` |
| Novi salon | `/super-admin/salons/new` |
| Detalji salona + branding + build status | `/super-admin/salons/:id` |

### Web build client app-a

Isti kod, `--dart-define=SALON=<slug>`, served na `salon.nasadomena.ba/s/:slug`. Screenovi identični, bez push notifikacija i bez "Moji termini" vezanih na device (koristi `localStorage`).

---

## 13. MVP success criteria

Faza 1 je gotova kad možeš, bez diranja koda, uraditi sve ovo:

1. Kreirati salon kroz super admin konzolu
2. Podesiti logo, boje, usluge i radnike
3. **Pokrenuti build za taj salon jednom komandom i dobiti AAB + IPA**
4. **Objaviti aplikaciju u Google Play internal testing**
5. Skinuti tu aplikaciju na telefon i vidjeti ime i ikonu salona
6. Zakazati termin kao klijent
7. Vlasnik dobija push za novi zahtjev
8. Potvrditi termin, klijent dobija push
9. **Dokazati da sistem sprječava duple termine** (dva telefona, isti slot, jedan dobija 409)
10. Blokirati vrijeme i vidjeti da slot nestaje u app-u
11. Demonstrirati sistem pravom salonu i dobiti "da"

> Kriterij 3 i 4 su novi i najvažniji. Ako build po salonu nije jednokomandan, native model ne skalira i biznis ne radi.

---

## 14. Demo saloni

| | Demo 1 | Demo 2 |
|---|---|---|
| **Naziv** | Barber Studio Vitez | Beauty Studio Travnik |
| **Tema** | Modern Barber | Elegant Beauty |
| **Slug / flavor** | `barberstudiovitez` | `beautystudiotravnik` |
| **applicationId** | `ba.nasadomena.barberstudiovitez` | `ba.nasadomena.beautystudiotravnik` |
| **Radnici** | Emir, Amar | Amina, Lejla |
| **Usluge** | Muško šišanje 30min/15KM · Brada 20min/10KM · Šišanje + brada 45min/25KM · Fade 40min/20KM | Žensko šišanje 45min/25KM · Feniranje 40min/20KM · Farbanje 120min/70KM · Pramenovi 150min/100KM |

Ova dva salona su i **test flavora** — ako oba builda prolaze kroz CI i izgledaju različito, tenant factory radi.

---

## 15. Pricing model

> ⚠️ **Pročitaj prvo:** [Rezervo](https://www.rezervo.uk/) prodaje isto što i mi — white-label brandiranu app za frizere, zubare, masere, nail i tattoo studije — za **25 EUR/mjesečno (~49 KM), bez ugovora, sa setupom u 24h**. Cijene ispod su 2–3× više. To je svjesna odluka, ne greška, ali moraš znati čime je opravdavaš. Analiza i tri strategije: [research §2.4](03-market-research-cutlio.md).

**Naša tri argumenta protiv Rezerva** — koristi ih na svakom sastanku:
1. **BiH lokalizacija** — KM, bosanski/srpski, BiH gradovi, **Viber** (dominantniji od WhatsAppa u BiH). Rezervo je hrvatski proizvod
2. **Lokalna podrška** — dolaziš lično na obuku, tvoj broj je u telefonu vlasnika. Rezervo je email adresa
3. **Web link + app**, ne samo app — QR i Instagram bio rade bez instalacije. Rezervo je app-only

### Linija A — setup + održavanje

| Paket | Izrada | Održavanje | Uključuje |
|---|---|---|---|
| **Starter** | 1.490 KM | 99 KM/mj | Android app u Google Playu, web booking link + QR, do 2 radnika, do 15 usluga, admin app, push notifikacije, osnovni branding, održavanje |
| **Pro** | 2.290 KM | 179 KM/mj | Sve iz Startera + **iOS app u App Storeu**, do 6 radnika, do 50 usluga, naprednije teme, galerija, prioritetna podrška |
| **Premium** | od 3.990 KM | od 299 KM/mj | Custom dizajn, custom domen, custom feature, VIP slotovi, waitlist, prioritetna podrška |

### Linija B — bez setup fee-a (obavezna, ne opciona)

**Cijena je po vertikali**, a iOS je doplata od 60 KM/mj. Minimalno trajanje 12 mjeseci.

| Vertikala | Starter (Android + web) | Pro (+ iOS) |
|---|---|---|
| Barber / frizer | **149 KM/mj** | 209 KM/mj |
| Beauty / nokti / obrve | **149 KM/mj** | 209 KM/mj |
| Masaža / fizio / SPA | **179 KM/mj** | 239 KM/mj |
| **Stomatologija** | **279 KM/mj** | 339 KM/mj |
| Generic (ostalo) | 149–199 KM/mj | +60 KM/mj |

> **Zašto je Linija B obavezna:** i Rezervo i Barberly su bacili setup fee — dva neovisna igrača, ista odluka. To je signal, ne slučajnost. Imaj je spremnu **prije** prvog sastanka; 1.490 KM unaprijed je za većinu malih salona u SBK-u prevelik zalogaj. Min. 12 mjeseci je obavezan jer prvi build ima realan trošak.

Detaljno obrazloženje po vertikali i prodajni argument za zubare: [05 §9](05-vertical-packs.md).

### iOS je namjerno tek u Pro paketu

**Klijent ne otvara nikakav Apple nalog** — sve ide pod našim Developer accountom, kao što Cutlio radi. Frizerki se prodaje gotova aplikacija, ne administracija.

Ali to nosi cijenu koju Starter ne može pokriti:
- **~30 min po klijentu na disciplinu diferencijacije** — prave fotografije salona, jedinstven store opis, stvarni screenshotovi. Bez toga Apple odbija po 4.2.6 ili 4.3
- **Realan rizik odbijanja** i appeal ciklusa po app-i
- Staggered submission — ne više app-a isti dan, što znači da iOS kanal ima propusnost

Starter dobija **Android + web link**, i to pokriva većinu BiH tržišta bez ikakvog Apple rizika. Puna strategija, ljestvica fallbackova i tail risk: [04 §6.2](04-flutter-tenant-factory.md).

### Trošak po klijentu koji moraš pokriti
Google Play developer account: **25 USD jednokratno, jedan za sve** · Apple Developer Program: **99 USD/god, jedan za sve** (amortizovano preko svih klijenata) · CI build minute: ~2–5 KM po buildu · **tvoje vrijeme: 30 min diferencijacije + 1–2h submission po iOS klijentu** · backend hosting: dijeljen, marginalno.

## 16. Tech stack

### 16.1 Odluka: Supabase, ne Firebase ✅

**Supabase za bazu, auth, storage i cron. Firebase samo za FCM push.**

| Sloj | Izbor |
|---|---|
| Baza | **Supabase Postgres** |
| Auth | **Supabase Auth** — Apple, Google, Facebook, Email + lozinka |
| Tenant izolacija | **RLS policy** po `salon_id` |
| Availability engine | Postgres funkcija ili Edge Function |
| Storage | Supabase Storage — logo, cover, galerija, app ikone |
| Scheduled poslovi | `pg_cron` + Edge Functions — reminderi, pending expiry, recall |
| Realtime | Supabase Realtime — admin dashboard se osvježava sam |
| **Push** | **Firebase FCM** — Edge Function poziva FCM HTTP v1 API |

#### Zašto Supabase, a ne Firebase

1. **Availability engine traži SQL.** "Nađi slotove koji se ne preklapaju sa terminima, uzimajući u obzir radno vrijeme, pauze, blokirane slotove i buffer" je relacioni problem — rangeovi, joinovi, exclusion constraints. Postgres to radi u jednom queryju. Firestore bi tražio denormalizaciju i logiku u klijentu, a [availability logika ne smije biti u app-u](#81-availability-algoritam). **Ovo je odlučujući argument** — to je srce proizvoda.

2. **RLS daje tenant izolaciju deklarativno**, i Supabase JWT claimovi se čitaju direktno u policy. Auth i autorizacija su jedan sistem. Firestore security rules bi to radile ručno i teže se testiraju.

3. **Nema premoštavanja tokena.** Da je Auth u Firebase-u a baza u Supabase-u, morao bi konvertovati Firebase ID tokene u Supabase JWT-ove. Dodatni pokretni dio i realan izvor bugova bez ikakve koristi.

4. **Jedan Supabase projekat servira N flavora.** Supabase Auth prima **comma-separated listu client ID-eva** po provideru, pa novi flavor znači dodavanje jednog ID-a u listu, ne novi auth setup ([06 §7](06-auth-login-flow.md)).

5. **Relacioni model nam ionako treba** — `Salon`, `Service`, `Employee`, `EmployeeService`, `WorkingHour`, `Appointment`, `Customer` su klasične relacije sa stranim ključevima i constraintima. Firestore je za drugačiji oblik podataka.

#### Zašto Firebase ipak ostaje u igri

**FCM je jedini pravi cross-platform push** koji radi i na Androidu i na iOS-u (preko APNs). Supabase ne nudi push servis. Zato:

- Firebase projekat postoji, sa po jednom **app** registracijom za svaki `applicationId`
- Iz njega koristimo **samo Cloud Messaging** — `google-services.json` / `GoogleService-Info.plist` po flavoru
- **Firebase Auth se ne koristi.** Nula.

> Ako ti se ovo čini kao dva sistema — jest, ali granica je čista: Supabase drži stanje i identitet, Firebase je dostavna cijev za notifikacije. Ne dodiruju se.

#### Rizik koji moraš znati

RLS sa **neautentikovanim** javnim pregledom (klijent gleda usluge prije logina) traži pažljive policy. `anon` rola mora moći čitati `services`, `employees` i availability **samo za aktivne salone**, i pisati **ništa**. Napiši policy testove ([06 §4.4](06-auth-login-flow.md)) i test izolacije iz [06 §4.3](06-auth-login-flow.md).

#### Kad bi prešao na .NET

Sav pristup podacima u Flutteru ide kroz `core_api` repository sloj sa apstraktnim interfejsima. Ako sistem izraste iz Supabasea ili zatreba puna kontrola (depoziti, plaćanja, kompleksni domain model), mijenjaš implementaciju repozitorija — ne app.

**Ne dopusti da Supabase tipovi procure iznad `core_api`.** To je jedina stvar koja ovu opciju drži otvorenom.

---

### 16.2 Frontend — šta u čemu

Ovo je odgovor na "je li monorepo najbolji, i šta za admina i superadmina".

| Dio | Tehnologija | Zašto |
|---|---|---|
| **Client app** (klijenti salona) | **Flutter** — Android + iOS, N flavora | Jedan kod za obje platforme, flavors za štancanje, native push |
| **Admin app** (vlasnik salona) | **Flutter** — Android + iOS, **jedna generička app** | Vlasnik je na telefonu 20× dnevno i **mora dobiti push za novi zahtjev**. Web to na iOS-u ne može pouzdano. Nema flavora, nema 4.2.6 rizika |
| **Client web fallback** (`/s/:slug`) | **Flutter Web build** client app-a | Nula dodatnog rada — isti kod. Za Instagram bio i QR |
| **Super admin konzola** (ti) | **Next.js + shadcn/ui** | Gusti formulari i tabele, desktop, bez push-a. React je za to bolji od Flutter Weba, i **već imaš mockup i komponente** |
| **Javne stranice** | **Isti Next.js** | Politika privatnosti po tenantu (**obavezna za store**), QR landing stranice, marketing |

#### Zašto je admin native, a ne web

Vrijednost admin app-a je *"vlasnik potvrdi termin za 30 sekundi, a ne za 4 sata"*. To zahtijeva **push notifikaciju**. Web push na iOS-u radi samo za PWA dodanu na home screen i nepouzdan je. Native admin app je jedini način da ta vrijednost postoji.

I jeftin je: **jedna app, jedan store listing, nula flavora**, jer je namjerno generička ([10 asimetrija](#10-customization--white-label)).

#### Zašto je super admin Next.js, a ne Flutter Web

- Koristiš ga samo ti, na desktopu — nula potrebe za native-om
- Gusti admin UI (tabele, filteri, forme, build triggeri) je u React + shadcn brže napravljen i prijatniji za korištenje od Flutter Weba
- **Politika privatnosti po tenantu ti ionako treba na webu** za store submission — isti Next.js to servira
- Wireframe mockup u ovom repou je već React + shadcn: to je startna točka, ne bačen rad

> Trade-off: dva jezika u projektu. Ali granica je čista — Flutter je proizvod, Next.js je alat i javne stranice. Nema dijeljene logike koja bi to bolila, jer je availability engine na backendu.

#### Zašto Flutter Web za klijentski fallback, a ne Next.js

Flutter Web build client app-a je **nula dodatnog rada** — isti kod, drugi target. Next.js booking stranica bi bila brža na prvom loadu, ali znači **duplirati cijeli 4-koračni booking flow**.

**Odluka:** kreni sa Flutter Web buildom. Ako mjerenja pokažu da web konverzija mjerljivo pada zbog prvog loada, tada napravi tanku Next.js booking stranicu — u istoj Next.js aplikaciji koja već postoji za super admina. Odluku odgađamo do podataka, ne do mišljenja.

---

### 16.3 Repozitorij i monorepo

**Da, monorepo — ali samo za Flutter dio.**

```
salon_platform/                     # jedan git repo
├── melos.yaml                      # ⬅ monorepo SAMO za Dart/Flutter
├── apps/
│   ├── client/                     # Flutter — N flavora
│   └── admin/                      # Flutter — jedna generička app
├── packages/
│   ├── core_api/                   # Supabase klijent, repozitoriji, modeli
│   ├── core_ui/                    # design system, theme factory, komponente
│   └── core_domain/                # entiteti, Vertical, AuthConfig, formatiranje
├── tenants/                        # config po salonu (docs/04 §3)
├── tool/                           # new_tenant, gen_flavors, build_tenant
└── web/                            # ⬅ Next.js — svoj toolchain (pnpm), van melosa
    ├── app/super-admin/
    └── app/privatnost/[slug]/
```

**Zašto monorepo za Flutter:** dijeljenje je stvarno i stalno. `client` i `admin` dijele modele, API klijent, design tokene, vertikalnu terminologiju i auth sloj. Bez monorepa bi to bila tri paketa u tri repoa sa verzionisanjem između njih — čist gubitak za tim od jedne osobe.

**Zašto je Next.js van melosa:** melos je Dart alat i ne zna za Node. Drži ih u istom **git repou** (jedan PR može mijenjati i shemu i konzolu), ali sa odvojenim toolchainima. Ne postoji alat koji Dart i Node smisleno ujedinjuje, i ne treba ti.

**Zašto ne dva repoa:** shema, Flutter modeli i super admin konzola se mijenjaju zajedno. Dva repoa znače dva PR-a za jednu promjenu i neizbježan drift.

## 17. Build order

### Sprint 0 — temelj (bez ovoga ništa ne skalira)
1. Flutter monorepo sa melos, `apps/client`, `apps/admin`, `packages/*`
2. **Flavor sistem za Android + iOS** i dokaz da dva demo salona daju dva različita builda ([doc 04](04-flutter-tenant-factory.md))
3. CI pipeline: `melos run build:client -- --flavor <x>` → AAB artefakt
4. Backend: Supabase projekat, shema po §11, **RLS policy + policy testovi**

### Sprint 1 — availability, vertikale i booking
5. **Availability engine na backendu + unit testovi** (srce sistema, izoluj ga)
6. **`VerticalPack` + `Vertical` klasa u `core_domain`** — seed za `barber`, `beauty`, `generic`; svi stringovi kroz `vertical.terms.*` od prvog ekrana ⚠️
7. `core_api` repository sloj + freezed modeli
8. `core_ui` theme factory — Modern Barber i Elegant Beauty iz `primaryColor`/`secondaryColor`, sa **automatskim izborom `onPrimary`** po luminanciji
9. Client: home screen sa runtime brandingom
10. Client: booking flow (4 koraka + success), sa 409 conflict handlingom
11. Backend: `POST /appointments` sa re-validacijom slota

> Korak 6 je 2–3 dana rada. Ako se odgodi, kasnije je prepisivanje svakog ekrana. Uradi ga odmah, čak i ako je prvi klijent frizer.

### Sprint 2 — auth, admin i notifikacije
12. **Supabase Auth provideri** (Apple, Google, Email + lozinka) + confirmation/recovery callbacki i comma-separated client ID-evi po flavoru
13. **Client login screen** sa `AuthConfig` filtriranjem po platformi
14. **Backend: verifikacija tokena, `AuthIdentity` upsert, `Customer` upsert po `(salonId, authIdentityId)`**
15. **Test izolacije: klijent u dva salona — dokaži da salon A ne vidi salon B** ⚠️
16. **Ekran "Moj račun" + brisanje računa** (bez njega iOS submission pada)
17. Admin: login + dashboard + lista termina
18. Admin: confirm / reject / cancel / no-show
19. Admin: ručno dodavanje termina (sa search po `Customer`)
20. **Firebase projekat samo za FCM** — app po flavoru + `Device` registracija vezana na `AuthIdentity`
21. Push: novi zahtjev → vlasnik, potvrda/odbijanje → klijent
22. Client: "Moji termini" + otkazivanje
23. Guest flow za `allowGuestBooking: true`
24. Facebook login — **iza flaga**, testiraj scenario iz [06 §7.4](06-auth-login-flow.md) na dva flavora

> Koraci 15 i 16 se najčešće preskaču. 15 je poslovni rizik (salon otkrije da mu vidiš klijentelu kod konkurencije), 16 je odbijeni submission.

### Sprint 3 — kompletiranje i prvi store submission
25. Admin: usluge, radnici, radno vrijeme, blocked slots CRUD
26. Super admin web konzola: kreiranje salona + vertikala + branding + build status
27. Scheduled remindery D-1 / H-3 + `NotificationLog`
28. Web build client app-a + QR generator
29. **Politika privatnosti po tenantu** (javna URL) + Data safety / App Privacy formulari
30. **Prvi Google Play submission** za Barber Studio Vitez
31. Demo pravom salonu

### Sprint 4 — dentalna vertikala (nakon 3+ zadovoljna beauty klijenta)
`VerticalPack` za `dental` · tema `clinical_calm` · `requireStaffChoice` · `bookingGranularity: date_only` · `DentalRecall` + scheduler · admin ekran "Pacijenti za recall" · **consent flow, enkripcija `customerNote`, politika privatnosti, DPA** · prvi dentalni store submission.

Detaljno: [05 §10](05-vertical-packs.md).

> Sprintovi 0–1 su rizik. Ako flavor sistem, availability engine ili vertikalni sloj zapnu, sve ostalo staje. Uradi ih prvo i uradi ih dobro.

---

## 18. Ključne odluke

| Odluka | Obrazloženje |
|---|---|
| **Native od početka, Flutter** | Ikona salona u storeu je proizvod koji prodajemo. Flutter daje Android + iOS + web iz jednog koda |
| **Web build je sekundarni kanal, ne zamjena** | Instagram bio i QR trebaju link. Isti codebase ga daje besplatno |
| **Login se traži tek na kraju flow-a** | Social login je jedan tap; samo novi email korisnik ispunjava kratku registraciju |
| **Ne tražimo broj telefona od klijenta** | Push zamjenjuje poziv i SMS. Jedan ekran manje, nula troška po poruci, manji GDPR teret. Cutlio radi isto |
| Identitet je `AuthIdentity` + `deviceId` za push | Omogućava "Moji termini", push, VIP, waitlist, recall |
| **Availability logika je na backendu, nikad u app-u** | Verzije app-a na telefonima kasne mjesecima. Bug u app-u ne možeš hotfixati |
| **Backend re-validira slot pri kreiranju** | Race condition između `GET /availability` i `POST /appointments` je realan |
| Termin ide kao `pending`, salon ručno potvrđuje | Vlasnik ne želi izgubiti kontrolu nad kalendarom |
| Pending termin privremeno blokira slot | Sprječava dupli booking dok salon ne odgovori |
| Pending ističe automatski | Sprječava trajno blokiran kalendar |
| **Branding je runtime gdje god može biti** | Promjena boje ne smije tražiti store review |
| Jedan multi-tenant backend, N flavora | Nula troška po klijentu u kodu — to je cijeli biznis model |
| Client app brandiran, admin generički | Novac je u tome kako izgleda pred klijentom salona |
| **iOS je Pro paket, Android + web je Starter** | Google je tolerantniji, Android dominira u BiH, Starter nema Apple rizika |
| **Vertikala je config, ne fork koda** | Fork znači N codebase-ova i smrt štancanja |
| **Login: Apple (iOS), Google, Email + lozinka, Facebook** | Social login jedan tap; email ima registraciju, confirmation i recovery |
| **Login se traži na kraju booking flow-a, ne na ulazu** | Klijent koji je izabrao termin prihvata login; onaj na ulazu odlazi |
| **Pregled salona i slobodnih termina nikad ne traži login** | Inače je web kanal (Instagram, QR) mrtav |
| **Supabase za bazu, auth i cron; Firebase samo za FCM** | Availability engine traži SQL. RLS i Auth su jedan sistem. FCM je jedini pravi cross-platform push |
| **Jedan Supabase projekat, `AuthIdentity` globalan, `Customer` per-salon** | Jedan identitet kroz N salona, ali salon A ne vidi salon B |
| **Admin app je native Flutter, ne web** | Vlasnik mora dobiti push za novi zahtjev; web push na iOS-u je nepouzdan |
| **Super admin je Next.js, ne Flutter Web** | Gusti desktop admin UI; i politika privatnosti po tenantu ionako treba web |
| **Monorepo za Flutter (melos), Next.js van melosa u istom git repou** | Dijeljenje modela i design sistema je stvarno; melos ne zna za Node |
| **iOS app-e idu pod našim Apple accountom, klijent ne otvara ništa** | Frizerki se prodaje gotova app, ne developer nalog. Cutlio radi isto. Cijena je disciplina diferencijacije i realan rizik odbijanja |
| **Frizeri/beauty prvi, zubari drugi** | Zdravstveni podaci nose pravni teret koji nedokazan sistem ne treba |
| **Linija B (0 KM setup) je obavezna** | Rezervo i Barberly su oba bacili setup fee — to je signal |

---

## 19. Sljedeći korak

1. Pročitaj **[03 §2.4 — pricing protiv Rezerva](03-market-research-cutlio.md)**. Ta odluka mora biti donesena prije prvog sastanka, ne poslije
2. Pročitaj **[04 §6.2 — Apple strategija](04-flutter-tenant-factory.md)**. Sve iOS app-e idu pod tvojim accountom (kao Cutlio) — ali disciplina diferencijacije nije opciona, i pripremi ljestvicu fallbackova prije prvog odbijanja
3. Pročitaj **[06 — Auth & login flow](06-auth-login-flow.md)**, posebno §7.4 o Facebooku prije nego ga obećaš klijentu
4. Validiraj ekrane i flowove u [02-user-flows-wireframes.md](02-user-flows-wireframes.md) i u interaktivnom mockupu (`npm run dev`)
5. Odluči vertikalni redoslijed — preporuka: `barber` + `beauty` u Fazi 1, `dental` u Fazi 2 ([05 §7.3](05-vertical-packs.md))
6. Sprint 0: monorepo + flavors + CI, sa Barber Studio Vitez i Beauty Studio Travnik kao dokazom
7. Sprint 1: availability engine + vertikalni sloj + booking flow
8. Sprint 2: auth + admin + push
9. Demo pravom salonu u Vitezu

> Wireframe demo u `prototype/wireframe/src/app/` je React/web — to je **prototip za validaciju flowa**, ne production kod, i zamrznut je otkako vizual nosi [`prototype/ui/`](../prototype/ui/README.md). Mapiranje ekrana na Flutter screenove je u [02, §1.1](02-user-flows-wireframes.md).
