# Trenutni task: 41 — Zakazivanje bez prijave se uklanja

Učitan 2026-09-23 iz [sprint-4/41](sprint-4/41-bez-zakazivanja-bez-prijave.md). Popravka,
procjena 1 dan, bez zavisnosti i bez taskova koje blokira.

## Status

U toku na grani `fix/zakazivanje-trazi-prijavu`.

## Ciljevi

- [ ] Ukloniti `AuthConfig.allowGuest`, `AuthRepository.continueAsGuest` i anonimne grane iz
      domenskog/API ugovora, implementacija, demo/fake repozitorija i testova
- [ ] Ukloniti `allowGuestBooking` iz tenant konfiguracije i generatora te regenerisati tenant
      registar; ne ostaviti neaktivni flag
- [ ] Novom migracijom ukloniti `salon_settings.allow_guest_booking`, prilagoditi potpis
      `update_salon_settings` bez paralelnog preopterećenja i zapisati odluku o uklanjanju kolone
- [ ] Ukloniti gost prekidač i pripadajuće stanje iz admin postavki, repozitorija i testova
- [ ] Učvrstiti `book_appointment` tako da odbija Supabase anonimni identitet i dokazati pgTAP
      testom da termin nije nastao
- [ ] Očistiti preostali guest ugovor (`appointment_source.guest`, `AuthSession.isAnonymous` i
      zavisne grane) ili dokumentovati nužni odbrambeni ostatak, bez puta za guest rezervaciju
- [ ] Sinhronizovati seed, REST/pgTAP testove i operativnu dokumentaciju sa obaveznom prijavom

## Napomene

- Guest tok nikad nije isporučen u produkcijskom UI-ju: login ekran nema akciju „Nastavi kao gost",
  `SupabaseAuthRepository.continueAsGuest` samo baca grešku, a oba tenanta i template nose
  `allowGuestBooking: false`. To nije dovoljno za ovaj task jer mrtvi ugovor i dalje prolazi kroz
  generator, modele i testove.
- `salon_settings.allow_guest_booking` je danas stvarno promjenjiv: task 36 ga je uključio u
  `update_salon_settings`, `SettingsRepository` i admin prekidač. Nova migracija mora zamijeniti
  RPC potpis i ukloniti staru overload verziju; izmjena već deployane migracije nije dovoljna.
- Sam grant nije zaštita od gosta. `book_appointment` jeste grantovan samo `authenticated`, ali
  Supabase anonimni korisnik dobija sesiju i tu rolu. Trenutni guard prihvata svakog klijenta koji
  posjeduje `auth_identity`, dok `private.sync_auth_identity` već bilježi `is_anonymous`; nova
  verzija RPC-a mora taj identitet eksplicitno odbiti.
- Anonimna semantika nije samo komentar: `AuthSession.isAnonymous` ulazi u jednakost i mapira se iz
  Supabase korisnika, a auth/customer provideri ga računaju kao prijavljenog. U repou nema poziva
  `signInAnonymously`, ali odbrana mora pokriti postojeću ili spolja kreiranu anonimnu sesiju.
- `appointment_source` još sadrži vrijednost `guest`, iako nijedan aktivni put ne upisuje takav
  termin. Po cilju „iz koda, postavki i ugovora" to je dio čišćenja; migracija mora sigurno obraditi
  eventualne stare redove prije zamjene enum-a.
- Uklanjanje kolone je čišće od trajnog `false`: odluka iz ADR-0011 za Facebook kaže da isključen
  flag i dalje naplaćuje održavanje, a task 41 izričito traži isti obrazac. Odluku treba zapisati uz
  migraciju/status, ne uvoditi novi flag ili drugi put pisanja.
- Stari dokumenti `docs/01`, `docs/02` i `docs/06` još opisuju guest flow. Oni su izvorni plan, ali
  `docs/06` je i operativni auth dokument i mora dobiti jasnu bilješku da ga task 41 poništava;
  ADR-0011 ostaje istorijski zapis da je gost tada bio samo odgođen.
- Procjena ostaje 1 dan: UI tok ne treba uklanjati, ali promjena presijeca šemu i RPC potpis,
  generator, oba Dart paketa, admin/klijent providere, seed i više pgTAP/REST ugovora.
- Kod taska 40 je spojen u `main` kroz PR #99, ali njegov task fajl i sprint tabela još nisu
  zatvoreni. Ta zatečena tracker nedosljednost nije dio taska 41 i nije prepisana u istoriju.

## Istorija

### FE-403 — Kalendar termina (gotov)

Spojen u `main` ([PR #72](https://github.com/htuco/salon-booking-platform/pull/72)). Zahtjev na
odobrenju nosi isprekidan rub na mreži, u listi i u legendi — razlika **oblikom**, ne samo bojom.
309 testova PASS, viđeno na 1440×900, 402×874 i u tamnoj temi. Prekidač dan/sedmica i realtime
osvježavanje ostali **imenovan dug** — oba traže ADR jer ih `prototype/admin/SPEC.md` izričito
izostavlja. Time je admin blok FE-401…FE-406 zatvoren.

### FE-404 — Usluge, osoblje i klijenti (gotov)

Spojen u `main` ([PR #71](https://github.com/htuco/salon-booking-platform/pull/71)).
Terminologija po vertikali umjesto „Majstor" iz canvasa, zelen CI na oba joba.

### 39 — Push obavijesti na Androidu (gotov)

Zatvoren uživo 2026-09-22 i spojen u `main`: migracija za `auto` mod je na hostovanom projektu,
admin Firebase aplikacija i staff uređaj su registrovani, a push je dokazan u oba smjera. Zvuk i
vlastiti Android kanal spojeni su zasebno kroz PR #80. iOS push ostaje imenovan dug do Apple
developer naloga.
