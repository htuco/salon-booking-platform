# Vertikalni paketi — frizeri, beauty, zubari i ostalo

Kako jedan Flutter codebase i jedan backend opslužuju više industrija bez forkanja koda.

| | |
|---|---|
| **Verzija** | v1 |
| **Datum** | 20.08.2026. |
| **Prati** | [01-mvp-spec.md](01-mvp-spec.md) · [03-market-research-cutlio.md](03-market-research-cutlio.md) · [04-flutter-tenant-factory.md](04-flutter-tenant-factory.md) · [06-auth-login-flow.md](06-auth-login-flow.md) |

---

## 1. Zašto vertikale, a ne "univerzalna booking app"

Konkurencija ide širinom. Rezervo navodi *"frizeri, zubari, maseri, nail studiji, tattoo studiji"* — ali proizvod je isti za sve. Zubar dobija app koja mu klijenta zove "klijent", uslugu "usluga", i nema pojma što je recall na 6 mjeseci.

To je marketing checkbox, ne proizvod. **Tu je naš prostor** ([research §2.3](03-market-research-cutlio.md)).

Naša teza: **80% sistema je identično za sve vertikale, 20% je terminologija i par pravila.** Ako to 20% izvučeš u konfiguraciju, dobiješ pet proizvoda po cijeni jednog — i možeš zubaru naplatiti duplo jer mu app govori njegovim jezikom.

```
┌─────────────────────────────────────────────────────────┐
│  ZAJEDNIČKO JEZGRO (80%)                                │
│  availability engine · booking flow · statusi termina   │
│  radnici · radno vrijeme · blocked slots · push         │
│  admin dashboard · kalendar · tenant izolacija          │
└──────────────────────────┬──────────────────────────────┘
                           │
     ┌──────────┬──────────┼──────────┬──────────┐
     ▼          ▼          ▼          ▼          ▼
 ┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐
 │ BARBER ││ BEAUTY ││ DENTAL ││ HEALTH ││ GENERIC│
 │        ││        ││        ││ (fizio)││ (ostalo│
 └────────┘└────────┘└────────┘└────────┘└────────┘
  terminologija · pravila · tema · default usluge
```

---

## 2. Model — `VerticalPack`

Vertikala nije branch u kodu. Vertikala je **red u bazi** i **JSON config** koji app pročita na startu.

### 2.1 DB entitet

```
VerticalPack
  id
  key                  # barber | beauty | dental | health | generic
  displayName          # "Stomatologija"
  terminology          # JSONB — v. §3
  defaultSettings      # JSONB — booking pravila, v. §4
  defaultTheme         # modern_barber | elegant_beauty | clinical_calm
  defaultServices      # JSONB — seed usluge za onboarding
  featureFlags         # JSONB — v. §5
  requiredConsents     # JSONB — GDPR/ZZOP, v. §7
```

Na `Salon` dodaj:
```
Salon.verticalPackKey   # FK na VerticalPack.key
```

### 2.2 Kako se to koristi u Flutteru

```dart
// packages/core_domain/lib/vertical.dart
class Vertical {
  final String key;
  final Terminology terms;
  final BookingRules rules;
  final Set<Feature> features;
}

// Terminologija se NIKAD ne hardkodira u UI
Text(vertical.terms.customerSingular)   // "Klijent" ili "Pacijent"
Text(vertical.terms.serviceSingular)    // "Usluga" ili "Tretman" ili "Pregled"
Text(vertical.terms.bookCta)            // "Zakaži termin" ili "Zakaži pregled"
```

**Pravilo:** nijedan string koji se razlikuje po vertikali ne smije biti u `.dart` fajlu ekrana. Ako je u ekranu, ne može se promijeniti bez novog store submissiona.

---

## 3. Terminologija po vertikali

Ovo je 60% posla za novu vertikalu i najveći dio percipirane vrijednosti.

| Ključ | barber | beauty | dental | health | generic |
|---|---|---|---|---|---|
| `businessSingular` | Barbershop | Salon | Ordinacija | Ordinacija | Firma |
| `customerSingular` | Klijent | Klijentica | **Pacijent** | Pacijent | Klijent |
| `customerPlural` | Klijenti | Klijentice | **Pacijenti** | Pacijenti | Klijenti |
| `serviceSingular` | Usluga | Usluga / Tretman | **Pregled / Intervencija** | Terapija | Usluga |
| `servicePlural` | Usluge | Usluge | **Usluge / Cjenovnik** | Terapije | Usluge |
| `staffSingular` | Barber | Radnica / Stilistica | **Doktor / Doktorica** | Terapeut | Radnik |
| `staffPlural` | Naš tim | Naš tim | **Naši doktori** | Naš tim | Naš tim |
| `appointmentSingular` | Termin | Termin | **Termin / Pregled** | Termin | Termin |
| `bookCta` | Zakaži termin | Rezerviši termin | **Zakaži pregled** | Zakaži termin | Zakaži termin |
| `noteLabel` | Napomena | Napomena | **Razlog dolaska** | Razlog dolaska | Napomena |
| `myAppointments` | Moji termini | Moji termini | **Moji pregledi** | Moji termini | Moji termini |
| `priceLabel` | Cijena | Cijena | Cijena | Cijena | Cijena |
| `durationLabel` | Trajanje | Trajanje | Trajanje | Trajanje | Trajanje |

**Rod je bitan u bosanskom.** Beauty salon koji ima samo ženske klijentice a app kaže "Klijent je otkazao" izgleda nemarno. Zato `customerSingular` ima i grammatičku varijantu po salonu, ne samo po vertikali — `Salon.terminologyOverride` (JSONB) prebija vertikalu.

---

## 4. Booking pravila po vertikali

| Pravilo | barber | beauty | dental | health | generic |
|---|---|---|---|---|---|
| `bookingGranularity` | `exact_slot` | `exact_slot` | **`date_only` ili `exact_slot`** | `exact_slot` | `exact_slot` |
| `slotStepMinutes` | 15 | 15 | 30 | 30 | 30 |
| `bufferMinutes` | 5 | 10 | **15** (sterilizacija) | 10 | 10 |
| `minAdvanceBookingHours` | 2 | 4 | **24** | 12 | 4 |
| `maxAdvanceBookingDays` | 30 | 45 | **180** | 90 | 60 |
| `minCancelHours` | 3 | 6 | **24** | 12 | 6 |
| `bookingMode` default | `manual` | `manual` | `manual` | `manual` | `manual` |
| `allowStaffChoice` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `requireStaffChoice` | ❌ | ❌ | **✅** | ✅ | ❌ |
| `pendingExpiryHours` | 12 | 12 | 48 | 24 | 24 |

### 4.1 Zašto se zubari ponašaju drugačije

**`bufferMinutes: 15`** — sterilizacija instrumenata i priprema kabineta između pacijenata nije opcija, to je propis. Buffer nije "ljubaznost", to je poslovno pravilo.

**`maxAdvanceBookingDays: 180`** — kontrolni pregled je za 6 mjeseci. Ako sistem ne dopušta booking 6 mjeseci unaprijed, recall ne radi.

**`requireStaffChoice: true`** — pacijent ide **svom** doktoru. "Bilo koji dostupan" je za frizera prihvatljivo, za zubara je uvreda. Ovo je jedan boolean koji vertikalu čini uvjerljivom.

**`date_only` opcija** — mnoge ordinacije rade "dođite ujutro, primit ćemo vas". Rezervo je cijeli proizvod izgradio na tom modelu ([research §2.2](03-market-research-cutlio.md)). Ponudi ga zubaru kao izbor pri onboardingu.

**`minAdvanceBookingHours: 24`** — ordinacija priprema kartoteku i materijal. Termin za 2 sata je nerealan.

---

## 5. Feature flagovi po vertikali

| Feature | barber | beauty | dental | health | Napomena |
|---|---|---|---|---|---|
| Galerija radova | ✅ | ✅ | ❌ | ❌ | Zubar ne stavlja "before/after" u booking app |
| Cjenovnik na home screenu | ✅ | ✅ | ⚠️ | ⚠️ | Ordinacije često nemaju fiksne cijene — "cijena po pregledu" |
| Odabir "bilo koji dostupan" | ✅ | ✅ | ❌ | ❌ | v. `requireStaffChoice` |
| **Recall / kontrolni pregled** | ❌ | ⚠️ | **✅** | ✅ | Najvažnija dentalna feature, v. §6 |
| **Kartoteka / historija posjeta** | ⚠️ | ⚠️ | **✅** | ✅ | Zdravstveni podaci — v. §7 |
| VIP / prioritetni slotovi | ✅ | ✅ | ❌ | ❌ | Ne prodaje se u zdravstvu |
| Cancellation waitlist | ✅ | ✅ | ✅ | ✅ | Radi svugdje |
| No-show tracking | ✅ | ✅ | ✅ | ✅ | Zubarima najvažnije — izgubljen sat je izgubljen novac |
| Loyalty / popusti | ✅ | ✅ | ❌ | ❌ | Neprikladno u zdravstvu |
| Tim / "naši doktori" sekcija | ⚠️ | ✅ | **✅** | ✅ | Zubar prodaje kredibilitet: diplome, specijalizacije |
| **Obavezni pristanak na obradu** | ❌ | ❌ | **✅** | ✅ | v. §7 |
| Društvene mreže na home | ✅ | ✅ | ⚠️ | ⚠️ | |

✅ uključeno · ⚠️ opcionalno, salon bira · ❌ isključeno

---

## 6. Dentalna vertikala — detaljno

Ovo je vertikala koja opravdava premium cijenu. Razrađujem je jer je najdalja od frizera.

### 6.1 Zašto zubari plaćaju više

| Faktor | Frizer | Zubar |
|---|---|---|
| Vrijednost izgubljenog sata | 15–25 KM | 80–300 KM |
| Trošak no-showa | Nizak | **Visok** — sterilizacija je već obavljena |
| Prosječan interval posjeta | 3–4 sedmice | 6 mjeseci |
| Da li klijent sam inicira ponovni dolazak | Da | **Ne** — treba ga zvati |
| Osjetljivost na profesionalan izgled | Srednja | **Visoka** |

Zadnja dva reda su cijeli argument. **Zubar ne gubi novac na neorganizovanom kalendaru — gubi ga na pacijentima koji se nikad ne vrate.** Recall je feature koja donosi novac, ne štedi vrijeme, i za nju se plaća drugačije.

### 6.2 Recall — najvažnija dentalna feature

```
DentalRecall
  id
  salonId
  customerId
  lastVisitDate
  recallIntervalMonths      # 6 default, 3 za perio pacijente, 12 za odrasle bez rizika
  dueDate                   # lastVisitDate + interval
  status                    # scheduled | notified | booked | declined | lapsed
  notifiedAt
  bookedAppointmentId
```

**Flow:**
1. Doktor označi termin `completed` i unese `recallIntervalMonths` (default iz usluge)
2. Sistem kreira `DentalRecall` sa `dueDate`
3. `dueDate - 14 dana` → push pacijentu: *"Vrijeme je za kontrolni pregled. Zakažite u par tapova."*
4. Tap na push vodi direktno u booking flow sa preselektovanim doktorom i tipom pregleda
5. Ako pacijent ne reaguje: drugi push nakon 7 dana, pa `lapsed`
6. Admin ima ekran **"Pacijenti za recall"** — lista sa dugmetom "Pozovi" (`tel:`) i "Viber"

> Ovo je jedina feature u cijelom sistemu koja **direktno generiše prihod** za klijenta. Prodaj je tako: *"Ako ti ovo vrati troje pacijenata mjesečno, platio si pretplatu deset puta."*

### 6.3 Dentalne default usluge (seed pri onboardingu)

| Usluga | Trajanje | Recall interval |
|---|---|---|
| Prvi pregled i konsultacija | 30 min | 6 mj |
| Kontrolni pregled | 20 min | 6 mj |
| Uklanjanje kamenca | 45 min | 6 mj |
| Plomba (kompozitna) | 45 min | 6 mj |
| Vađenje zuba | 45 min | 6 mj |
| Liječenje kanala | 90 min | 3 mj |
| Izbjeljivanje | 60 min | 12 mj |
| Protetika — konsultacija | 30 min | — |
| Ortodoncija — kontrola | 20 min | 1 mj |
| Hitna intervencija | 30 min | — |

### 6.4 Dentalna tema — `clinical_calm`

Treća tema pored Modern Barber i Elegant Beauty:

- Svijetla pozadina, plavo-tirkizni akcent (industrijski standard za zdravstvo — pacijenti to čitaju kao "čisto i sigurno")
- Bez velikih emotivnih fotografija, bez "before/after"
- Fokus na **kredibilitet**: imena doktora, specijalizacije, godine iskustva
- Vidljiv kontakt za hitne slučajeve na home screenu
- Mirni prijelazi, bez animacija koje "prodaju"
- Veći font — dio pacijenata je stariji

### 6.5 Šta zubarima NE nudimo u Fazi 1

Kartoteka sa dijagnozama · RTG snimci · e-recepti · fakturisanje · integracija sa HZZO/fondom · digitalni potpis pristanka · zubna shema (odontogram).

> To je **dentalni informacioni sistem**, ne booking app. Ako klijent to traži, to je drugi proizvod i druga cijena. Ne obećavaj ga da bi zatvorio prodaju — to je najsigurniji način da izgubiš klijenta na trećem mjesecu.

---

## 7. Zdravstvene vertikale i zaštita podataka ⚠️

**Ovo moraš riješiti prije prvog stomatološkog klijenta, ne poslije.**

`customerNote` u dentalnoj vertikali nije "napomena" — to je **podatak o zdravlju**. Pacijent koji upiše "boli me gornji desni kutnjak, alergičan na penicilin" je predao zdravstveni podatak. To je posebna kategorija podataka i po BiH Zakonu o zaštiti ličnih podataka i po GDPR-u (relevantno ako ideš u HR).

### 7.1 Minimum koji Faza 1 mora imati

| Obaveza | Implementacija |
|---|---|
| Pristanak na obradu | Checkbox u booking flow-u za `dental`/`health` vertikale, sa linkom na politiku privatnosti. Bez checkboxa nema "Pošalji zahtjev". Logira se `consentVersion` i `consentAt` |
| Politika privatnosti | Zaseban ekran u app-u + javna URL. Store review to **traži** za zdravstvene app-e |
| Minimizacija podataka | Za `dental` promijeni label sa "Razlog dolaska" i **eksplicitno napiši**: "Ne upisujte detalje o zdravstvenom stanju." Manje podataka = manji rizik. **Broj telefona se ne prikuplja od pacijenta** — push zamjenjuje poziv ([06 §3.1](06-auth-login-flow.md)), što ovaj teret dodatno smanjuje |
| Enkripcija u tranzitu i mirovanju | HTTPS obavezno; `customerNote` enkriptovan na nivou kolone za `dental`/`health` |
| Retencija | `pendingExpiryHours` + auto-anonimizacija `customerNote` nakon N mjeseci od `completed` |
| Pravo na brisanje | Admin akcija "Izbriši podatke pacijenta" koja anonimizira `Customer` i `customerNote`, ali čuva `Appointment` za statistiku |
| Ugovor sa klijentom | Aneks o obradi podataka (DPA) — ti si processor, ordinacija je controller. **Traži pravni pregled** |
| Audit log | Ko je i kada pristupio podacima pacijenta |

### 7.2 Store review implikacija

Apple i Google imaju stroža pravila za app-e koje obrađuju zdravstvene podatke. Očekuj:
- Obavezna politika privatnosti na javnoj URL prije submissiona
- Popunjen "Data safety" / "App Privacy" formular — i **mora biti tačan**
- Moguć dodatni krug pitanja od review tima

To znači **duži i rizičniji review po dentalnom klijentu** ([04, §6](04-flutter-tenant-factory.md)). Uračunaj to u cijenu.

### 7.3 Iskrena preporuka o redoslijedu

Kreni sa **frizerima i beauty salonima**. Oni ne nose ovaj pravni teret, brže se prodaju, i na njima ćeš iznijeti tenant factory i availability engine.

Zubare uzmi kao **drugu fazu, sa pripremljenim DPA i politikom privatnosti**. Nemoj prvog klijenta u životu tražiti u ordinaciji — rizik je nesrazmjeran nagradi dok sistem nije dokazan.

---

## 8. Ostale vertikale — `generic` pack

Vertikale koje se pokrivaju bez novog paketa, samo drugom terminologijom i default uslugama:

| Vertikala | Pack | Napomena |
|---|---|---|
| Nail studio | `beauty` | Duži tretmani, `bufferMinutes: 10` |
| Obrve / trepavice | `beauty` | Kratki tretmani, čest recall — koristi dentalni recall mehanizam |
| Masaža / SPA | `health` | `requireStaffChoice: true` — klijenti imaju svog terapeuta |
| Fizioterapija | `health` | Serije termina (10 tretmana) — Faza 3 feature |
| Tattoo studio | `generic` | Vrlo dugi termini (4h+), depozit je stvaran problem → Faza 3 |
| Kozmetički salon | `beauty` | |
| Veterinar | `health` | Pacijent je životinja, vlasnik je kontakt — traži dodatno polje |
| Auto-servis | `generic` | `date_only` granularnost, vozilo kao dodatno polje |
| Advokat / knjigovođa | `generic` | `requireStaffChoice: true`, duži slotovi |

**Pravilo za nove vertikale:** ako se rješava sa terminologijom + default uslugama + booking pravilima, to je `generic` sa overrideom. Novi `VerticalPack` pravi se **samo** kad vertikala traži novi entitet (kao `DentalRecall`) ili novi ekran.

---

## 9. Pricing po vertikali

Vertikala mijenja vrijednost, pa mijenja i cijenu. Cijene su za Liniju B (bez setup fee-a, min. 12 mjeseci) — v. [01 §15](01-mvp-spec.md).

| Vertikala | Starter (Android + web) | Pro (+ iOS) | Obrazloženje |
|---|---|---|---|
| **Barber / frizer** | 149 KM | 209 KM | Baseline. Konkuriše Rezervu (~49 KM) lokalnom podrškom, ne cijenom |
| **Beauty / nail / obrve** | 149 KM | 209 KM | Isto, više usluga i galerija |
| **Masaža / fizio** | 179 KM | 239 KM | `requireStaffChoice`, duži termini, serije |
| **Stomatologija** | **279 KM** | **339 KM** | Recall generiše prihod. Viši trošak review-a i compliance-a. Vrijednost izgubljenog sata je 10× frizerska |
| **Generic (ostalo)** | 149–199 KM | +60 KM | Po dogovoru |

iOS je doplata od 60 KM/mj jer nosi ~30 min diferencijacije po klijentu i realan rizik odbijanja ([04 §6.2](04-flutter-tenant-factory.md)).

> **Kako prodati 279 KM zubaru:** ne prodaješ booking. Prodaješ *"sistem koji ti vraća pacijente koji se inače ne bi vratili"*. Jedan vraćen pacijent na kontrolni pregled + uklanjanje kamenca je 80–120 KM. Tri mjesečno i sistem se plaća trostruko. Recall je jedina feature koju treba pominjati na prvom sastanku.

---

## 10. Uticaj na build order

Ovo NE mijenja Sprint 0–2 iz [01 §17](01-mvp-spec.md). Mijenja Sprint 3+ i uvodi Sprint 4.

### Dodaci u Sprint 1
- `VerticalPack` entitet i seed za `barber`, `beauty`, `generic`
- `Vertical` klasa u `core_domain`
- **Zabrana hardkodiranih stringova** — lint pravilo ili code review checklist
- Terminologija kroz `vertical.terms.*` od prvog ekrana

> Ovo je 2–3 dana rada u Sprintu 1. Ako se odgodi, kasnije je prepisivanje svakog ekrana. Uradi odmah, čak i ako je prvi klijent frizer.

### Sprint 4 — dentalna vertikala (nakon 3+ zadovoljna beauty klijenta)
1. `VerticalPack` seed za `dental` + terminologija + pravila
2. Tema `clinical_calm`
3. `requireStaffChoice` u booking flow-u
4. `bookingGranularity: date_only` mod
5. `DentalRecall` entitet + scheduler + push
6. Admin ekran "Pacijenti za recall"
7. **Consent flow + politika privatnosti + enkripcija `customerNote`**
8. Enkripcija i retencijska politika
9. DPA template — pravni pregled
10. Prvi dentalni store submission

---

## 11. Ključne odluke

| Odluka | Obrazloženje |
|---|---|
| Vertikala je config, ne fork koda | Fork znači N codebase-ova i smrt štancanja |
| Nijedan vertikalno-zavisan string nije u ekranu | Promjena terminologije ne smije tražiti store review |
| **Kreni sa frizerima/beauty, zubari drugi** | Zubari nose pravni teret koji nedokazan sistem ne treba |
| `requireStaffChoice: true` za zdravstvo | "Bilo koji dostupan" je za frizera OK, za zubara uvreda |
| Recall je dentalni proizvod, ne feature | To je jedino što direktno donosi prihod klijentu |
| Ne obećavamo dentalni informacioni sistem | Odontogram, RTG, e-recepti su drugi proizvod |
| `date_only` granularnost je opcija, ne default | Rezervo model — dobar za ordinacije, korak nazad za frizere |
| Zdravstvene vertikale = enkripcija + consent + DPA od dana jedan | Nije opcija, zakonska je obaveza |
| Novi `VerticalPack` samo za novi entitet ili ekran | Sve ostalo je `generic` + override |
