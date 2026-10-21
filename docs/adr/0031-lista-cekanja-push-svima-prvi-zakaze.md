# Lista čekanja: push svima upisanima, termin dobija ko prvi zakaže

## Status

prihvaćen (2026-10-21) — razrađuje [ADR-0029](0029-opseg-do-lansiranja-zero-crisis.md) za task 68.
Predložen 2026-10-20; Hamza ga je prihvatio u reviewu PR-a #142 uz izmjene koje su ovdje već upisane:
„jednom po oslobađanju" znači da ponudu donosi samo otkazivanje koje upisu otvara vrijeme, jedna
ponuda po klijentu, upis gasi tek potvrđen termin, salon ne vidi redove ponuda ni u logu, i tri
posljedice (push dozvola, `waitlist_full_dates` i odsustvo radnika, deaktivirana usluga ili radnik).

## Kontekst

ADR-0029 uvodi listu čekanja do lansiranja: klijent se na pun dan upisuje, a kad se termin oslobodi
dobija push. Task 68 ostavlja otvorena tri pitanja (ko dobija oslobođen termin, šta je upis, koliko
važi), a kod je otvorio još tri:

- **Prazan dan nije nužno pun dan.** Korak 3 crta „dan je pun" kad `get_available_slots` vrati
  prazno, a prazno je i neradni dan, zatvoren radnik i dan na koji je prošlo radno vrijeme. Upis
  na listu čekanja za dan koji ne radi je obećanje koje se nikad ne ispuni.
- **Obavijest je vezana za termin.** `notification_logs.appointment_id` je `not null`, a
  `my_notifications` i `claim_push_notifications` provjeravaju vlasnika preko
  `appointments.auth_identity_id`. Oslobođeni termin je termin **drugog** klijenta.
- **Oslobođen termin ne mora otvoriti mjesto za svaku uslugu.** Otkazana brada od 15 minuta ne
  otvara mjesto za farbanje od dva sata.

Termin se u ovoj šemi oslobađa samo prelaskom u `cancelled` (salon, klijent ili istek iz taska
64), a `cancelled` je konačan (`set_appointment_status` ga ne vraća, `PT409`). Svaki termin se
dakle oslobodi najviše jednom.

## Odluka

**Push ide svima upisanima kojima se mjesto stvarno otvorilo, a termin dobija ko prvi zakaže.**
Upis ne daje prednost i ne drži termin. `book_appointment` ostaje jedina provjera, sa istim
`PT409` za onog ko zakasni. Poruka zato ne obećava termin: „Oslobodilo se mjesto".

**Upis je dan + usluga, a radnik je opcionalan.** Radnik je onaj iz koraka 2; „Bilo ko" je upis
bez radnika. Dijela dana (jutro, popodne) nema.

**Upis važi do kraja svog dana**, a nestaje i ranije, čim isti klijent ima **potvrđen** termin iste
usluge tog dana (termin koji nastaje potvrđen, ili zahtjev koji salon potvrdi). Zahtjev na čekanju
(`pending`) upis ne gasi: salon ga može odbiti ili pustiti da istekne, a klijent bi tada ostao i
bez termina i bez mjesta na listi. Jedan klijent ima najviše **tri** aktivna upisa u salonu
(`PT429`, kao limit iz taska 65); isti dan, usluga i radnik dva puta su jedan upis.

**Upis se prima samo na pun dan.** Pun dan je dan na koji bi bilo slobodnog vremena da nema
nijednog termina, a nema ga. Neradni dan, zatvoren radnik, salonska blokada cijelog dana, dan van
`max_advance_booking_days` i dan na koji je prošlo radno vrijeme nisu puni. Isto pravilo vraća
`waitlist_full_dates`. Po njemu kalendar u koraku 3 crta pun dan kao **treće stanje**: prigušen
i precrtan, ali se tapa (nedostupan dan se do sada nije tapao, pa pun dan nije ni mogao biti
izabran). Na izabranom punom danu stoji „Obavijesti me kad se oslobodi".

**Push ide jednom po oslobađanju, i samo upisu kojem je baš to otkazivanje otvorilo vrijeme.** Kad
termin budućeg dana pređe u `cancelled`, upis tog dana dobija ponudu samo ako za njegovu uslugu i
radnika sada postoji slobodno vrijeme koje je otkazani termin do tada blokirao: isti radnik i
interval slota koji se preklapa sa intervalom otkazanog termina (trajanje i bafer, istim pravilom
kojim `candidate_slots` termin poredi sa slotom). Termin bez radnika blokirao je svakog radnika, pa
ga oslobađa svakom. Ponuda ide na svaki uređaj vlasnika upisa u tom salonu. Bez uslova preklapanja
bi svako nepovezano otkazivanje tog dana ponovo slalo već poslanu ponudu, čim je dan imao ijedno
slobodno vrijeme. Ako prethodna ponuda istom upisu još čeka slanje, nova se ne dodaje.

**Jedna ponuda po klijentu po oslobađanju.** Kad isti klijent ima više upisa koje isto otkazivanje
budi („Bilo ko" i „kod Emira"), ponudu dobija najraniji upis. Poruka je „oslobodilo se mjesto", i
druga ponuda za isti dan ne bi rekla ništa novo.

**Obavijest liste čekanja je vezana za upis, ne za termin.** `notification_logs` dobija
`waitlist_entry_id`. Red nosi tačno jedno od ta dva. Oslobođeni termin se ne upisuje nigdje u red
upisanog klijenta, pa ni u push ni u `my_notifications`.

**Salon vidi samo broj upisanih po danu**, kroz `waitlist_demand`, ne imena ni usluge. Redove ponuda
ne vidi ni u logu obavijesti: `staff_notification_logs` ih isključuje, jer red ponude nosi
`device_id` klijenta, a admin čita termine sa `device_id`, pa bi spojem saznao ime i telefon onoga
ko čeka.

**Prekidača po salonu nema.** Lista čekanja radi u svakom salonu.

## Razmatrane opcije

- **Termin se drži prvom na listi X minuta** — odbačeno za lansiranje: traži novi status termina
  (ili rezervaciju bez termina), istek kao u tasku 64 i ekran za prihvatanje. Procjena taska raste
  sa 3–4 na 5+ dana, a pravednost koju donosi vidi se tek kad je lista duga. Vraća se ako saloni
  prijave da isti klijenti uvijek stignu prvi.
- **Push samo prvom na listi, bez držanja** — odbačeno: prvi koji ne vidi poruku na vrijeme
  ostavlja mjesto prazno, a ostali ni ne znaju da postoji.
- **Upis bez provjere punog dana** — odbačeno: klijent bi se upisao na neradnu nedjelju i čekao
  obavijest koja nikad ne stigne.
- **Okidač i na skinutu blokadu i promijenjeno radno vrijeme** — odgođeno: to su odluke salona u
  Meluri, ne oslobođen termin, i nijedna danas ne javlja klijentu ništa. Vraća se ako saloni prave
  mjesto ručno pa očekuju da lista to zna.
- **Salon vidi ko čeka** — odgođeno: za odluku „treba li dodati radnika subotom" dovoljan je broj.
  Imena traže ekran i politiku nad tuđim upisima, a nijedan salon ih nije tražio.
- **Prekidač „Lista čekanja" u postavkama** — odgođeno: traži novi potpis
  `update_salon_settings` (zamka iz taska 37). Red u admin postavkama ostaje kako jeste dok task
  54 ne odluči o njemu.

## Posljedice

- Dva klijenta sa iste liste mogu dobiti isti push i obojica otvoriti isti termin; drugi dobija
  „Termin je u međuvremenu zauzet". To je očekivano, ne kvar.
- Push za `waitlist_offer` nema `appointment_id`. Tap vodi na „Moji termini", gdje upis ima
  „Zakaži".
- Push ne javlja koje se vrijeme oslobodilo: do tapa ga je možda već neko uzeo, a vrijeme se
  ionako čita iz `get_available_slots`.
- `get_available_slots` je od ovog taska tanak omotač oko `private.candidate_slots`, koji zna
  računati i dan bez termina. Promjena pravila slotova ide u tu funkciju.
- Brisanje naloga briše upise na listu čekanja tog identiteta.
- **Bez push dozvole nema ponude.** Ponuda se pravi samo za uređaj sa `fcm_token`, a uređaj bez
  dozvole za notifikacije se registruje bez tokena. Panel punog dana tada kaže da obavijesti nisu
  uključene i da se uključuju u postavkama telefona, umjesto „Javićemo vam". Povratak u aplikaciju
  ponovo registruje uređaj, sada sa tokenom.
- **Svjesna cijena: javni `waitlist_full_dates` otkriva dane kad radnik ne radi.** Radno vrijeme je
  javno, a blokade nisu. Dan koji po radnom vremenu radi, a nema slobodnog vremena, do sada je
  izgledao isto bez obzira na razlog; sada ga `waitlist_full_dates` dijeli na pun (zauzet terminima)
  i ne-pun (blokiran). Upit sa `p_employee_id` tako pokazuje dane kad je taj radnik blokiran
  (bolovanje, godišnji). Bez te razlike kalendar ne bi znao na koji dan nudi listu čekanja, pa je
  cijena prihvaćena; razlog blokade (`reason`) se ne otkriva.
- **Deaktivirana usluga ili radnik brišu upise koji ih traže.** Takav upis ponudu nikad ne bi dobio
  (`candidate_slots` ih preskače), a trošio bi jedno od tri mjesta do kraja dana. Upis „Bilo ko"
  ostaje kad se deaktivira jedan radnik.
