# Domenski rječnik

Kanonski termin za svaki pojam, da kod, taskovi i dokumentacija koriste istu riječ za istu stvar.
Ovo je **glosar, ne specifikacija** — pravila i brojevi žive u `docs/01-mvp-spec.md`, arhitektura u
`.claude/docs/architecture.md`. Ovdje stoji samo ono što se u razgovoru stvarno miješalo.

Kad piše _Izbjegavaj_, to nije stilska preporuka: te riječi su već izazvale nesporazum.

## Tenant i flavor

**Tenant**
Jedan klijent platforme — jedan salon i sve što uz njega ide: red u `salons`, folder u `tenants/`,
brandirana aplikacija u storeu. Riječ pokriva i poslovni i tehnički kraj, pa se koristi kad se
misli na oba.
_Izbjegavaj_: instanca, deployment, organizacija.

**Flavor**
Build varijanta jednog tenanta — Android `productFlavor` i iOS scheme + konfiguracije istog imena.
Ime flavora je `[a-z][a-z0-9]*`, **identično imenu foldera** u `tenants/`, jer Gradle traži
`src/<flavor>/` a Flutter traži scheme koji se poklapa sa imenom flavora. Crtica ili donja crta
nisu validan Gradle identifikator.
_Izbjegavaj_: varijanta, build tip (`buildType` je Debug/Profile/Release — druga osa), brand.

**`tenant.yaml`**
Jedini fajl koji se piše po klijentu. Sve ostalo o salonu — logo, cover, usluge, radnici, radno
vrijeme, tekstovi — živi u backendu i mijenja se bez novog builda. `tenant.yaml` drži samo ono što
se **ne može** mijenjati runtime: identitet u storeu, ime, ikonu, fallback boje.
_Izbjegavaj_: config klijenta (previše široko — backend je isto config klijenta).

**`SALON_ID`**
UUID salona, jedini `--dart-define` koji build prosljeđuje. Ime, vertikala i fallback boje se traže
u generisanom registru (`tenants.g.dart`) po tom UUID-u, pa se ne prosljeđuje svako polje posebno.
Mora odgovarati redu u `supabase/seed.sql` (i kasnije pravom redu u bazi) — neslaganje daje app
koja se builda ali ne nalazi svoj salon.
_Izbjegavaj_: tenantId, salonSlug (slug je za URL, ne za identitet u kodu).

**Generisano**
Izlaz iz `tenant.yaml` kroz generatore u `tool/`: Gradle blok između markera, iOS xcconfig i
Xcode konfiguracije/scheme, `tenants.g.dart`, placeholder ikone. Commituje se u repo, ali se
**nikad ne edituje ručno** — sljedeće pokretanje generatora prepisuje izmjenu, a CI pada prije toga.
_Izbjegavaj_: build artefakt (artefakt je APK/AAB/IPA i ne commituje se).

## Brendiranje

**Runtime branding**
Sve što app pročita iz backenda pri pokretanju — logo, boje, tekstovi, usluge, tim. Promjena ne
traži store review. Pravilo: brendiranje je runtime **gdje god može biti**.
_Izbjegavaj_: dinamički config, remote config (Firebase Remote Config se ne koristi).

**Build-time branding**
Ono što fizički mora ući u binarni fajl: ime aplikacije, ikona, bundle/application ID, splash.
Promjena traži novi build i novi store review. Ovo je jedini razlog zašto `tenant.yaml` postoji.
_Izbjegavaj_: statički branding.

**Fallback boje**
Boje u `tenant.yaml` koje app koristi dok backend ne odgovori. Postoje da nema bijelog flasha na
startu, i moraju biti iste kao `salons.primary_color`/`secondary_color`. Nisu izvor istine — backend jeste.
_Izbjegavaj_: default tema (tema je `branding.theme`, druga stvar).

## Vertikala

**Vertikala** (`VerticalPack`)
Djelatnost kojoj salon pripada — `barber | beauty | dental | health | generic`. **Red u bazi i
config, nikad grana u kodu.** Nosi terminologiju, default booking pravila, feature flagove, temu i
tražene pristanke.
_Izbjegavaj_: niša, segment, tip salona, industrija.

**Terminologija**
Skup stringova koje vertikala mijenja — "Klijent" naspram "Pacijent", "Usluga" naspram "Pregled".
Pravilo bez izuzetka: **nijedan string koji se razlikuje po vertikali ne smije biti u `.dart` fajlu
ekrana.** Ako je u ekranu, ne može se promijeniti bez store submissiona. Salon može prebiti
vertikalu preko `Salon.terminologyOverride` — rod je u bosanskom stvaran problem, ne kozmetika.
_Izbjegavaj_: prijevod (`.arb` lokalizacija je odvojena stvar — jezik aplikacije, ne rječnik djelatnosti).

## Termini i dostupnost

**Termin** (`appointment`)
Jedna rezervacija: salon, klijent, usluga, radnik, datum, vrijeme početka. Trajanje ne stoji na
terminu — određuje ga usluga.
_Izbjegavaj_: rezervacija (koristi se u UI copy-ju, ali u kodu i dokumentaciji je termin), booking
(engleski se zadržava samo u "booking flow" i "booking pravila").

**`pending`**
Poslan zahtjev koji salon još nije potvrdio. **Blokira slot** dok stoji, i automatski pada u
`cancelled` nakon `pendingExpiryHours` — bez toga zaboravljeni zahtjevi trajno zauzmu kalendar.
Odbijanje odmah vraća slot kao slobodan.
_Izbjegavaj_: neodobren, na čekanju kao statusna vrijednost (kao UI tekst je u redu), rezervisan.

**Slot**
Jedno moguće vrijeme početka na koraku od `slotStepMinutes`. Slot je kandidat, ne zapis — ne postoji
tabela slotova. Ono što se čuva je termin, blokada ili radno vrijeme.
_Izbjegavaj_: termin (to je već zauzeto), interval.

**Blokada** (`blocked_slot`)
Vrijeme koje salon ručno zatvori (pauza, odsustvo, praznik). Nije termin i nema klijenta, ali
jednako izbacuje kandidate iz dostupnosti.
_Izbjegavaj_: blokiran termin, off-time.

**Dostupnost** (availability)
Lista slobodnih vremena početka za zadani salon/uslugu/radnika/datum. **Računa se na backendu,
nikad u aplikaciji** — verzije na telefonima kasne mjesecima, pa je availability u app-u bug koji se
ne može hotfixati. Backend **ponovo validira** slot pri kreiranju termina i vraća `409` ako je u
međuvremenu zauzet.
_Izbjegavaj_: slobodni termini (miješa slot i termin), raspored (to je radno vrijeme).

**Buffer** (`bufferMinutes`)
Minimalni razmak između dva termina. Ulazi u provjeru presjeka kao dio zauzetog intervala
(`[start, start + trajanje + buffer)`), ne kao zaseban zapis.
_Izbjegavaj_: pauza (pauza je u radnom vremenu i pripada rasporedu).

## Identitet

**`AuthIdentity`**
Globalan identitet jedne osobe na platformi, vezan za Supabase Auth korisnika. Živi **iznad**
salona: ista osoba u tri salona ima jedan `auth_identities` red.
_Izbjegavaj_: korisnik (`users` je tabela osoblja — druga stvar), nalog.

**`Customer`**
Ista osoba **unutar jednog salona**: njena istorija, napomene i termini u tom salonu. Per-salon je
namjerno — salon ne smije vidjeti da klijent ide i kod konkurencije.
_Izbjegavaj_: klijent kao naziv tabele (u tekstu je "klijent" u redu; u kodu je `customer`),
profil.

**`users`**
Osoblje: `super_admin` i `salon_admin`. Klijenti **nisu** ovdje. Radnik (`employees`) u Fazi 1 nije
korisnik nego resurs — ima usluge, raspored i termine, ali nema login.
_Izbjegavaj_: osoblje kao ime tabele, staff.

**`x-salon-id`**
Header kojim klijentska app kaže *u kojem salonu trenutno radi*. Bira kontekst i sužava čitanje —
**nikad ne daje članstvo, vlasništvo ni admin prava**. Nevažeći ili neaktivan salon daje `NULL`,
što znači "nema konteksta", ne "svi saloni".
_Izbjegavaj_: tenant header kao sinonim za autorizaciju.

**Uloga** (`app_metadata.role`)
`super_admin | salon_admin | client`. Uloga u JWT-u **sama po sebi ne znači ništa** — svaka
provjera traži i odgovarajući red u bazi (`public.users` sa istim `salon_id`). Tvrdnja iz tokena i
članstvo u bazi moraju se poklopiti.
_Izbjegavaj_: permisija, claim (claim je nosilac, uloga je vrijednost).

## Isporuka

**`SalonBuild`**
Zapis o buildu jednog tenanta — status i URL. Prati **naš** build pipeline, ne stvarni status u
storeu; ništa u seedu nije označeno kao objavljeno.
_Izbjegavaj_: release, deployment.

**Prototip**
React/Vite ekrani u `prototype/wireframe/`. Postojao je da se flow i vizual validiraju prije prvog Dart
fajla; **zamrznut** je otkako `prototype/ui/` nosi vizual.
Nije production kod i ne postaje — proizvod je Flutter.
_Izbjegavaj_: web app (web build **klijent app-e** iz Fluttera je stvarna stvar i drugi kanal),
frontend.

**Super admin konzola**
Next.js web aplikacija za vlasnika platforme (kreiranje salona, branding, build). Odvojena od
Flutter admin app-e koju koristi vlasnik salona.
_Izbjegavaj_: dashboard (i admin app ima dashboard ekran), backoffice.
