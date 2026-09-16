# Market Research — Cutlio, Rezervo, Rezervacija i regionalna konkurencija

**Datum istraživanja:** 20.08.2026.
**Cilj:** razumjeti kako regionalni igrači operativno "štancaju" klijente, po kojim cijenama, i gdje je naš prostor.

> **Pouzdanost:** Cutlio nema javni pricing. Rezervo i Rezervacija imaju javne podatke. Sve što je označeno kao procjena je naša, ne njihov objavljeni podatak.

---

## 0. TL;DR — pet nalaza koji mijenjaju plan

1. **Naš model već postoji i ima cijenu od 25 EUR/mj.** Rezervo (HR) prodaje white-label brandiranu app za frizere, zubare, masere, nail i tattoo studije za 25 EUR/mjesečno bez ugovora, sa setupom u 24 sata. To je ~49 KM/mj. Naš draft od 99–179 KM/mj je 2–3,5× skuplji od direktnog konkurenta. **Ovo je najvažniji nalaz u dokumentu.**
2. **Cutlio dokazuje da model radi na native-u.** Njihovi package ID-evi (`com.cutlio.hairdo`, `com.cutlio.eden.hair.salon`, ...) su dokaz jednog codebase-a i N buildova. Točno naš plan.
3. **Zubari su već meta konkurencije, ali površno.** Rezervo i Rezervacija ih navode u listi, ali nijedan nema stomatološki workflow (recall na 6 mjeseci, pacijent vs. klijent, kartoteka). Tu je naša najveća neiskorištena prilika.
4. **Marketplace i white-label su dva različita biznisa** i u regiji su podijeljeni. Rezervacija (Brčko), SrediMe, Bookeraj, Booksy, Fresha su marketplace. Cutlio, Rezervo, Barberly su white-label. Ne miješaj ih — mi smo white-label.
5. **Svi bez izuzetka koriste isti reminder pattern:** dva podsjetnika, D-1 i par sati prije. To je industrijski default, ne diferencijator.

---

## 1. Cutlio — najbliži model, BiH/HR

Cutlio d.o.o. prodaje **personalizovanu native booking aplikaciju po salonu**. Ne prodaju SaaS pretplatu na zajedničku platformu — prodaju osjećaj "ovo je MOJA aplikacija".

Pozicioniranje sa sajta, verbatim:

> "cutting-edge personalized apps, that will be designed to match your brand and styles"

> "Custom applications designed to reflect your unique brand and logo with seamless user experience tailored specifically to your business needs"

### 1.1 Najvažniji nalaz — package naming

| Aplikacija | Package ID |
|---|---|
| Barberium Barbershop | `com.cutlio.barberium.barbershop` |
| Hairdo | `com.cutlio.hairdo` |
| Beauty Bar | `com.cutlio.beauty.bar` |
| Salon By Antonela Jukić | `com.cutlio.salon.antonela` |
| Frizerski Salon Uky | `com.cutlio.uky.barbershop` |
| Eden Hair Salon | `com.cutlio.eden.hair.salon` |

**Šta ovo dokazuje:** jedan codebase, jedan developer account, N buildova. Svaki salon dobija zasebnu native aplikaciju u storeu pod svojim imenom i ikonom, ali je to isti proizvod sa drugim configom.

**Šta ovo znači za nas:** ovo je operativna validacija našeg Sprint 0 plana. Flutter flavors daju isti rezultat. Detalji: [04-flutter-tenant-factory.md](04-flutter-tenant-factory.md).

### 1.2 Arhitektura koju koriste

```
                 ┌─────────────────────────┐
                 │   Cutlio backend        │
                 │   (multi-tenant)        │
                 └────────────┬────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
 ┌──────▼──────┐      ┌───────▼───────┐     ┌───────▼───────┐
 │ Eden Hair   │      │ Beauty Bar    │     │ Salon Antonela│  ← N brandiranih
 │ (klijenti)  │      │ (klijenti)    │     │ (klijenti)    │    client appova
 └─────────────┘      └───────────────┘     └───────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Cutlio Admin     │  ← JEDNA generička admin app
                    │  (vlasnici salona)│    za sve salone
                    └───────────────────┘
```

Ključna asimetrija: **client app je brandiran, admin app nije.** Vlasnik salona ne mari kako mu izgleda admin — mari kako izgleda ono što njegov klijent vidi. Jeftin i pametan cut, i mi ga preslikavamo.

### 1.3 Feature set (verbatim sa sajta)

| Feature | Naš komentar |
|---|---|
| Tailored Design and Branding | Core prodajna priča. Kod nas: theme + boje + logo + app ikona |
| Smart Scheduling | "clients see only available slots" — availability engine |
| VIP Appointments | Slot rezervisan za stalne klijente. Faza 3 upsell |
| Manage your staff and services | Standard. Faza 1 |
| Manage your working hours and vacations | Radno vrijeme + blocked slots. "Vacations" = multi-day blocked slot |
| Instant notifications | Push. Nama isto, FCM |
| Cancellation waitlist | Otkazani termin → notifikacija prvom na listi. **Jeftina feature, veliki wow** |
| Priority Slots for Regular Clients | Isto kao VIP |

Reminderi: "the day before and a few hours before appointments" — **D-1 i H-3**.

### 1.4 Šta Cutlio NEMA
- **Nema javni web booking link.** Sve ide kroz app install. Ogromna frikcija za klijenta koji te nađe na Instagramu.
- Nema javne cijene ni self-service onboarding.
- Nema POS, kartično plaćanje, depozite.
- Nema vertikalnu specijalizaciju — sve je "beauty".

---

## 2. Rezervo — direktni konkurent sa javnom cijenom ⚠️

**Ovo je konkurent kojeg moraš tretirati najozbiljnije.** Isti model kao mi, javna cijena, iste vertikale.

| | |
|---|---|
| **Tržište** | Hrvatska, interfejs na hrvatskom |
| **Model** | White-label brandirana app po salonu |
| **Cijena** | **25 EUR / salon / mjesec** — jedan tier, sve uključeno |
| **Ugovor** | Nema. Otkaz u bilo kojem momentu |
| **Setup** | "Kontaktirajte nas i postavite sustav u 24 sata" |
| **Vertikale** | **frizeri, zubari, maseri, nail studiji, tattoo studiji** |

Pozicioniranje: "za male poduzetnike koji žele manje kaosa i više organizacije". Brandiranje: "vaše ime, vaš logo, vaše boje — klijenti vide vaš brend, ne Rezervo".

### 2.1 Feature set
Brandirana mobilna app (ime, logo, boje) · neograničeni klijenti i termini · QR kod booking · odabir usluge i datuma · **odobrenje vlasnika za svaki zahtjev** · automatski push reminderi (dan prije i sat prije) · jutarnji dnevni pregled · više radnika · Google/Apple Calendar integracija · **glasovni zahtjevi za rezervaciju** · hrvatski interfejs.

### 2.2 Dvije njihove odluke koje vrijedi razmotriti

**a) Booking bez tačnog vremena.** Klijent bira uslugu i **datum**, ne tačan slot. Vlasnik onda dodijeli vrijeme i potvrdi.

Prednost: nema availability engine-a, nema race conditiona, nema "nema slobodnih termina" prazne stranice. Radikalno jednostavnije.
Mana: klijent ne zna kad treba doći dok mu vlasnik ne kaže. Za frizera je to korak nazad.

> **Naša odluka:** radimo tačne slotove kao default, ali dodajemo `bookingGranularity: exact_slot | date_only` u `SalonSettings`. Za zubare i salone koji rade "dođite ujutro" mode, `date_only` je bolji i jeftiniji. Ovo je konkretna feature koja dolazi iz njihovog proizvoda.

**b) Jedna cijena, jedan tier.** Nema Starter/Pro/Premium. Nema setup fee. Nema pregovaranja.

### 2.3 Šta Rezervo NEMA — naš prostor
- **Nema vertikalnu dubinu.** "Zubari" su na listi, ali nema recall-a na 6 mjeseci, nema kartoteke pacijenta, nema terminologije pacijent/pregled. To je marketing checkbox, ne proizvod.
- Nema web booking link (samo QR na app).
- Nema BiH lokalizaciju — KM, BiH gradovi, bosanski/srpski jezik, Viber (a Viber je u BiH dominantniji od WhatsAppa).
- Nema no-show tracking ni historiju klijenta.
- Nema iOS naveden eksplicitno.

### 2.4 Šta ovo znači za naš pricing — čitaj obavezno

Naš draft (99–179 KM/mj + 1.490–2.290 KM setup) je **2–3,5× skuplji od Rezerva** koji nudi isto na papiru. Svaki salon koji zna guglati će to naći.

Tri odgovora, izaberi svjesno:

| Strategija | Kako | Rizik |
|---|---|---|
| **A. Spusti cijenu** | 59–79 KM/mj bez setupa, takmiči se na cijeni | Nemaš maržu za support, štancanje postaje neisplativo pod 20 klijenata |
| **B. Opravdaj premium lokalnošću** | Isti pricing, ali prodaješ ono što Rezervo nema: BiH lokalizacija, Viber, KM, dolazim lično na obuku, tvoj broj u telefonu | Radi u SBK-u gdje je odnos lice-u-lice presudan. Ne skalira preko granice |
| **C. Opravdaj premium vertikalom** | Stomatološki paket sa recall-om i kartotekom po 249 KM/mj | Zubar plaća više jer mu je vrijeme vrjednije. Traži više razvoja |

**Preporuka: B za frizere/beauty (prvih 10 klijenata), C kao rast.** Ne idi u A — cjenovni rat sa firmom iz EU-a koja ima niže troškove je izgubljen.

---

## 3. Rezervacija (LeftJoin d.o.o., Brčko) — lokalni marketplace

**Relevantno jer je iz BiH i već cilja i frizere i zubare** — samo drugim modelom.

| | |
|---|---|
| **Developer** | LeftJoin d.o.o., Brčko Distrikt |
| **Model** | **Marketplace**, ne white-label |
| **Cijena za klijenta** | Besplatno za download |
| **Kategorija** | Business |
| **Vertikale** | frizerski saloni, stomatološke ordinacije, opšte uslužne djelatnosti |

Pozicioniranje: "univerzalno rješenje za sve rezervacije", tri tipa korisnika — obični korisnici, vlasnici biznisa, zaposlenici.

**Features:** geolokacijsko pretraživanje · filter po kategoriji, gradu, ocjeni, polu · pregled usluga sa cijenama · favoriti · booking kroz kalendar · notifikacije · historija rezervacija · profili biznisa.

### 3.1 Zašto ovo NIJE naša konkurencija (i zašto je ipak važno)

Marketplace i white-label rješavaju različit problem:

| | Marketplace (Rezervacija, SrediMe, Booksy) | White-label (mi, Cutlio, Rezervo) |
|---|---|---|
| Salon dobija | Nove klijente kroz discovery | Alat za postojeće klijente |
| Salon je | Jedan listing među stotinama | Jedina firma u svojoj app |
| Naplata | Često po rezervaciji ili freemium | Fiksna pretplata |
| Brand | Marketplace brand | Salonov brand |
| Salonov strah | "Konkurencija je jedan klik dalje" | Nema ga |

**Naš prodajni argument protiv marketplacea:** *"Na Rezervaciji je tvoj salon jedan od trideset u Travniku i klijent vidi konkurenciju ispod tebe. U tvojoj aplikaciji si samo ti."* To je jak argument kod vlasnika koji već ima klijentelu.

**Rizik kojeg moraš znati:** marketplace nudi ono što mi ne — **nove klijente**. Salon koji tek počinje ili mu treba promet radije će na marketplace. Ne pokušavaj njima prodati. Ciljaj salone koji su **puni ali neorganizovani**.

---

## 4. Ostatak regionalnog krajolika

| Igrač | Tržište | Model | Napomena |
|---|---|---|---|
| **SrediMe** (SrediMe doo) | BiH, HR, RS, ME | Marketplace | 326+ salona u HR. Kozmetika, frizeri, SPA, masaža. Verifikovane recenzije |
| **Bookeraj** | RS, BiH, ME | Marketplace | Frizeri, manikir, masaža. Pretraga po kategoriji i lokaciji |
| **Booksy** | Globalno | Marketplace + SaaS | Besplatni i neograničeni transakcijski SMS |
| **Fresha** | Globalno | Marketplace + SaaS | 100 besplatnih SMS po useru/mj, dalje se plaća |
| **Barberly** | Globalno | White-label | Bez setup fee-a, sve u pretplati, bez fee po rezervaciji |
| **theCut** | US | Marketplace za barbere | |
| **Zubar** (app.djordje.zubar) | Regija | Per-ordinacija app | Za samostalne zubare, ortodonte, dentalne higijeničare |
| **Stomatologija.me** | ME, RS, BiH, SI, HR | Portal + booking | 130+ klijenata. Najposjećeniji stomatološki portal u regiji |

### 4.1 Barberly — najbolje dokumentovan white-label onboarding

Njihov proces, 3 koraka:
1. **Registration** — 30-dnevni free trial, bez kartice
2. **Configuration** — lokacije, osoblje, usluge, raspored, plaćanje
3. **Launch** — deploy app, kreni primati rezervacije

Verbatim:
> "This is your own mobile app in the stores with your business name and icon and fully custom design."
> "no starting or one-off costs to have your mobile app on App Store and Google Play. Everything is included in the subscription."
> "no fee per booking"

**Lekcija:** i Barberly i Rezervo su bacili setup fee. Dva neovisna igrača, ista odluka. To je signal, ne slučajnost. Imaj Liniju B (0 KM setup, veći mjesečni) spremnu.

### 4.2 Booksy / Fresha — reminder ekonomija
- Booksy: besplatni i neograničeni transakcijski SMS
- Fresha: 100 besplatnih po useru/mjesečno, dalje usage-based
- Kanali: SMS, email, WhatsApp
- Depoziti i cancellation fee sa karticom on-file protiv no-showa

**Lekcija za BiH:** SMS je skup. Native push je besplatan — to je naša prednost i glavni argument za native. Za klijente koji nemaju app: **Viber deep link koji vlasnik pošalje jednim tapom** (`viber://chat?number=`). Nula infrastrukture.

### 4.3 Stomatologija.me — signal za dentalnu vertikalu
130+ klijenata i status najposjećenijeg stomatološkog portala u regiji dokazuje da **zubari plaćaju za digitalno prisustvo**. Ali to je portal (discovery), ne booking alat. Ordinacija koja hoće svoju app i svoj raspored nema kome otići osim generičkih rješenja.

---

## 5. Pozicioniranje — gdje smo mi

```
                     visoka personalizacija
                     (salonov brend)
                             ▲
                             │
              Cutlio ●       │  ● MI (cilj)
              Rezervo ●      │    native + web link + BiH lokalizacija
              Barberly ●     │    + vertikalna dubina (zubari)
                             │
   ──────────────────────────┼──────────────────────────►
   app-only                  │              web + app
   (install frikcija)         │              (bez frikcije)
                             │
     Rezervacija ●  SrediMe ●│● Booksy  ● Fresha
     Bookeraj ●              │
                             │
                     niska personalizacija
                     (marketplace, salon je broj)
```

**Naša niša u tri rečenice:**
1. Personalizacija na Cutlio/Rezervo nivou — native app sa imenom i ikonom salona.
2. Bez app-install frikcije — isti Flutter codebase daje web link za Instagram bio i QR.
3. Vertikalna dubina koju niko nema — stomatološki workflow, ne samo checkbox u listi.

---

## 6. Šta preslikavamo, šta odbacujemo

### Preslikavamo odmah (Faza 1)
- **Asimetrija brandinga** — client app brandiran do detalja, admin generički. Cutlio, Rezervo i Barberly rade isto
- **Jedan codebase, N flavora** — Cutlio package ID-evi su dokaz da model radi
- **D-1 i H-3 reminderi preko push-a** — industrijski default kod svih, i besplatan na native-u
- **Bez broja telefona od klijenta** — Cutlio ga ne traži; push pokriva potvrdu, odbijanje i podsjetnike
- **"Clients see only available slots"** — nikad ne prikazuj zauzeto pa reci "zauzeto"
- **Vlasnik odobrava svaki zahtjev** — Rezervo to naglašava kao feature ("ostajete u punoj kontroli"), ne kao ograničenje. Prodaj to isto tako
- **QR kod** — svi ga imaju, jeftin je, salon ga stavi na ogledalo
- **Setup u 24h kao obećanje** — Rezervo to prodaje. Naš tenant factory to mora moći

### Preslikavamo kasnije (Faza 2–3)
- **`bookingGranularity: date_only`** — Rezervo model bez tačnog slota. Idealno za zubare
- **Cancellation waitlist** (Cutlio) — najjeftinija feature sa najvećim wow efektom
- **VIP / Priority slots** (Cutlio) — opravdava skuplji paket
- **Google / Apple Calendar sync** (Rezervo) — vlasnici to traže
- **Jutarnji dnevni pregled push** (Rezervo) — "Danas imate 8 termina, prvi u 09:00". Trivijalno za implementaciju, vlasnici to vole
- **Native wrapper po salonu** — već je naš plan od Faze 1

### Ne radimo
- **Marketplace / discovery** — drugi biznis, treba likvidnost na obje strane
- **App-only distribucija** — greška Cutlia i Rezerva. Web link je naša prednost
- **POS, inventar, payroll** — enterprise scope, ubija MVP
- **SMS gateway** — push je besplatan i pokriva sve; Viber deep link ostaje samo za klijente koje salon ručno unese
- **Cjenovni rat** — Rezervo je iz EU-a sa nižim troškovima. Ne idi tamo
- **Glasovni booking** (Rezervo ga ima) — zvuči impresivno, rijetko se koristi, skupo za tačnost na bosanskom

---

## 7. Konkretne posljedice za specifikaciju

Izmjene koje ovo istraživanje uvodi:

| # | Izmjena | Gdje |
|---|---|---|
| 1 | `Customer` entitet umjesto samo imena/telefona na terminu — bez njega nema stalnog klijenta, VIP-a, waitliste, historije | [01 §11](01-mvp-spec.md) |
| 2 | `Device` entitet — most između "klijent nema account" i "klijent dobija push" | [01 §11](01-mvp-spec.md) |
| 3 | `SalonBuild` entitet — bez evidencije store pipeline-a gubiš kontrolu na 15 klijenata | [01 §11](01-mvp-spec.md) |
| 4 | `NotificationLog` — bez loga dupliraš remindere pri svakom restartu schedulera | [01 §11](01-mvp-spec.md) |
| 5 | **`bookingGranularity: exact_slot \| date_only`** — Rezervo model kao opcija za zubare | [01 §11](01-mvp-spec.md), [05](05-vertical-packs.md) |
| 6 | D-1 / H-3 reminderi kao eksplicitno pravilo, ne "kasnije notifikacije" | [01 §6.2](01-mvp-spec.md) |
| 7 | Viber/WhatsApp/tel deep link u detaljima termina | [01 §6.3](01-mvp-spec.md) |
| 8 | Jutarnji dnevni pregled push za vlasnika | Faza 2 |
| 9 | **Pricing: Linija B bez setup fee-a je obavezna**, ne opcija — dva konkurenta su ga bacila | [01 §15](01-mvp-spec.md) |
| 10 | **Vertikalni paketi kao diferencijator** — frizeri/beauty/zubari/ostalo sa svojom terminologijom i pravilima | [05-vertical-packs.md](05-vertical-packs.md) |
| 11 | Pending timeout — zaboravljeni zahtjev ne smije trajno blokirati kalendar | [01 §8](01-mvp-spec.md) |
| 12 | `bookingMode: auto` spreman za Fazu 2 — dio salona neće htjeti ručnu potvrdu | [01 §11](01-mvp-spec.md) |
| 13 | **Login: Apple, Google, Email + lozinka, Facebook** — na kraju booking flow-a, ne na ulazu | [06](06-auth-login-flow.md) |
| 14 | **Ne tražimo broj telefona od klijenta** — Cutlio ga ne traži, push zamjenjuje poziv i SMS | [06 §3.1](06-auth-login-flow.md) |
| 15 | **Rezervo model bez tačnog vremena** dostupan kao `date_only` granularnost | [05 §4](05-vertical-packs.md) |

---

## Izvori

**Cutlio**
- [Cutlio — official site](https://cutlio.com/)
- [Barberium Barbershop — Google Play (`com.cutlio.barberium.barbershop`)](https://play.google.com/store/apps/details?id=com.cutlio.barberium.barbershop&hl=en_US)
- [Hairdo — Google Play (`com.cutlio.hairdo`)](https://play.google.com/store/apps/details?id=com.cutlio.hairdo)
- [Beauty Bar — Google Play (`com.cutlio.beauty.bar`)](https://play.google.com/store/apps/details?id=com.cutlio.beauty.bar&hl=en_US)
- [Salon By Antonela Jukić — Google Play (`com.cutlio.salon.antonela`)](https://play.google.com/store/apps/details?id=com.cutlio.salon.antonela&hl=en_US)
- [Frizerski Salon Uky — Google Play (`com.cutlio.uky.barbershop`)](https://play.google.com/store/apps/details?id=com.cutlio.uky.barbershop&hl=en_US)
- [Eden Hair Salon — Google Play (`com.cutlio.eden.hair.salon`)](https://play.google.com/store/apps/details?id=com.cutlio.eden.hair.salon&hl=en)

**Direktni konkurenti — white-label**
- [Rezervo — Booking aplikacija za vaš salon](https://www.rezervo.uk/)
- [Barberly — How it works](https://www.barberly.com/how-it-works)
- [Barberly — Salon app](https://www.barberly.com/salon-app)

**Marketplace igrači**
- [Rezervacija — Google Play (`com.rezervacija.rezervacija_app`)](https://play.google.com/store/apps/details?id=com.rezervacija.rezervacija_app&hl=en_US)
- [Rezervacija — App Store (LeftJoin d.o.o., Brčko)](https://apps.apple.com/kw/app/rezervacija/id1616344992)
- [SrediMe — App Store (BiH)](https://apps.apple.com/ba/app/sredime-rezervacije-salona/id1338099934?l=hr)
- [SrediMe — web (326 salona)](https://www.sredime.hr/)
- [Bookeraj](https://bookeraj.com/)
- [Booksy vs Fresha — comparison](https://biz.booksy.com/en-gb/comparison/fresha-comparison)
- [Fresha — Best salon software 2026](https://www.fresha.com/for-business/salon/best-salon-software)
- [theCut — Barber features](https://thecut.co/barber-features)

**Dentalna vertikala**
- [Zubar — Google Play (`app.djordje.zubar`)](https://play.google.com/store/apps/details?id=app.djordje.zubar&hl=en_US)
- [Stomatologija.me — Google Play](https://play.google.com/store/apps/details?id=app.stomatologija.me&hl=en_SG)
