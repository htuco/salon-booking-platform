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

## Dopuna 2026-10-21: raspon do prvog slobodnog termina

**Status:** prihvaćena (Hamza, 2026-10-21) — task 91. Mijenja tri pravila iznad: „Upis je dan +
usluga", „Upis važi do kraja svog dana" i „Upis se prima samo na pun dan". Ostalo važi kako je
napisano.

**Kontekst.** Upis na jedan pun dan tjera klijenta da se upisuje dan po dan, a limit od tri upisa
to brzo pojede. Klijent ne čeka „utorak", nego „bilo šta prije prvog slobodnog termina". Zenoti i
Acuity to nude kao „obavijesti me ako se oslobodi ranije"; Cutlio i drugi sistemi pravila javno ne
objavljuju.

**Odluka.**

- **Upis je usluga + raspon dana, a radnik je opcionalan.** Raspon se ne bira nego **računa u
  bazi**: od izabranog dana (bez njega od danas) do **dana prije prvog slobodnog termina** za tu
  uslugu i radnika („Bilo ko" = bilo koji radnik). „Slobodan" je isto pitanje koje postavlja
  `get_available_dates` (`private.candidate_slots` sa terminima), pa „Prvi slobodan termin" u
  aplikaciji i granica u bazi ne mogu reći dvije stvari. Nema slobodnog do kraja
  `max_advance_booking_days` → raspon ide do kraja prozora.
- **Upis se odbija** (`PT400`) kad izabrani dan već ima slobodnog vremena (tada se zakazuje), kad u
  rasponu nema nijednog punog dana (neradni dani, blokade, neaktivna usluga ili radnik — upis bi
  čekao obavijest koja nikad ne stigne), za prošli dan i dan van prozora, i u salonu koji zakazuje
  samo dan (`date_only`; do sada je to skrivala samo aplikacija).
- **Jedan upis po (identitet, usluga, radnik) u salonu.** Raspon je jedan upis, limit ostaje
  **tri**. Ponovljen upis vraća postojeći, neizmijenjen.
- **Granica se ne pomjera sama.** Ako se kasnije oslobodi nešto prije granice, to je ponuda, ne nova
  granica. Ako se granični termin zauzme, upis ostaje do svoje granice i ne produžava se.
- **Upis nestaje** kad se desi prvo od: klijent dobije **potvrđen** termin te usluge **bilo koji
  dan u rasponu** (`pending` i dalje ne gasi); prođe zadnji dan raspona; klijent ga ukloni. Termin
  na prvi slobodan dan (granicu) upis **ne** gasi: klijent koji ga je zakazao i dalje čeka da se
  oslobodi ranije. Dani koji prođu otpadaju sa početka raspona.
- **Ponuda pamti dan koji se oslobodio** (`notification_logs.waitlist_offer_date`). Okidač budi
  upis čiji raspon pokriva dan otkazivanja, uz isto pravilo kao ranije (slobodan slot kod radnika
  otkazanog termina koji se preklapa sa njim, jedna ponuda po klijentu). Istorija obavijesti
  pokazuje taj dan, ne raspon.
- **Salon i dalje vidi samo broj.** `waitlist_demand` broji upis na **svaki dan koji pokriva**,
  kao broj različitih klijenata.

**Istek: filter i cron, oba.** Svaki čitač (`my_waitlist`, limit, `waitlist_demand`) gleda samo
`date_to >= danas` po zoni salona, pa istek vrijedi odmah. `expire-waitlist` (pg_cron, svaki sat,
po obrascu `expire-pending` iz taska 64) briše istekle upise zajedno sa ponudama. Samo filter nije
dovoljan: istekao red bi držao ključ (jedan upis po usluzi i radniku), pa ga `join_waitlist` i sam
briše prije novog upisa, i ostao bi u istoriji kao ponuda na koju se više ne čeka. Samo cron nije
dovoljan: do prvog prolaza bi istekao upis još sat vremena trošio jedno od tri mjesta.

**Razmatrane opcije.**

- **Klijent bira raspon** (od–do u kalendaru) — odbačeno: dva izbora više, a jedini smislen kraj je
  prvi slobodan termin, koji baza ionako zna.
- **Granica se pomjera kad se oslobodi ranije** — odbačeno: oslobođeno mjesto je ponuda, a upis koji
  se sam skraćuje izgubio bi dane na koje klijent i dalje čeka ako ponudu ne iskoristi.
- **Više dana kao više upisa** (stari model) — odbačeno: limit od tri bi pojeo jedan tjedan čekanja.

**Posljedice.**

- `join_waitlist(usluga, radnik, od)` i `my_waitlist()` mijenjaju potpis (`drop` + `create`). Stari
  klijent koji šalje `p_date` dobija `404` od PostgREST-a dok se ne ažurira; booking flow i
  „Moji termini" rade dalje, samo upis na listu ne prolazi.
- Postojeći upisi postaju raspon od jednog dana. Više upisa istog klijenta za istu uslugu i radnika
  (različiti dani) spaja se u jedan raspon od najranijeg do najkasnijeg dana; njihove ponude prelaze
  na upis koji ostaje, a od više ponuda koje čekaju slanje istom uređaju ostaje jedna (ostale su
  `logged`, `waitlist_merged`).
- Push i dalje ne kaže koji je dan: `claim_push_notifications` se ne mijenja (task 56 ga
  redefiniše), a dan se vidi u Obavijestima i u kalendaru poslije tapa.
- Upis „Bilo ko" od danas broji se i na dane koji nisu puni (zatvorena nedjelja u rasponu): salon
  vidi koliko ljudi čeka u tom periodu, ne koliko ih čeka baš taj dan.
