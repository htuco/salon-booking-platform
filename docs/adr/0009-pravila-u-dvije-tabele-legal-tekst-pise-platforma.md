# Pravila u dvije tabele, a legal tekst piše samo platforma

## Status

prihvaćen

## Kontekst

DoD [taska 21](../../tasks/sprint-2/21-obavijesti-i-pravni-ekrani.md) traži da tekst pravila dolazi
**po tenantu** — „`salons` kolona ili `settings`, ne kao literal u app-i" — i da ekran `/terms`
prikaže šest numerisanih sekcija iz handoffa (`prototype/ui/screenshots/15-pravila-koristenja.png`).

Kad se tih šest sekcija pročita, vidi se da **nisu iste vrste**:

| Sekcija | Šta tvrdi | Koga obavezuje |
|---|---|---|
| Zakazivanje | zahtjev nije potvrda; potvrda stiže kroz app | ponašanje platforme (`book_appointment` pravi `pending`) |
| Cijene | cijene su informativne, konačna se dogovara u salonu | isto u svakoj brandiranoj app-i |
| Vaši podaci | šta se čuva, zašto, i da se ne prodaje | **firmu koja aplikaciju objavljuje** |
| Otkazivanje | rok prije početka, evidencija nedolazaka | salon (`salon_settings.min_cancel_hours`) |
| Kašnjenje | šta salon radi kad klijent kasni | salon |
| Kontakt | telefon i mail za nejasnoće | salon |

Tri sekcije su platformske i moraju biti identične u svakoj brandiranoj aplikaciji; tri su
salonske i moraju se razlikovati po tenantu. Ista lista, dvije vrste vlasništva.

Pritisak koji je tražio odluku: migracija je prvi korak taska, a ekran, seed, RLS i testovi se
pišu nad onim što migracija napravi. Pogrešan oblik ovdje se plaća prepisivanjem svega toga.

Drugi pritisak je pravni, i teži: tekst o obradi ličnih podataka je **izjava firme pod kojom
aplikacija stoji u storeu**. Ako salon može mijenjati tu sekciju, firma odgovara za rečenicu koju
nije napisala i ne vidi.

## Odluka

**Dvije tabele, i legal tekst piše isključivo platforma.**

- **`public.app_policies`** — **bez `salon_id`**, kao `vertical_packs`. Nosi platformske sekcije i
  cijelu politiku privatnosti. `anon` i `authenticated` je čitaju; piše **samo super admin**.
- **`public.salon_policies`** — sa `salon_id`. Nosi salonske sekcije **dokumenta `terms`**. `anon`
  čita za aktivan salon; `salon_admin` ima CRUD nad svojima.

Obje nose `document`, `sort_order`, `title` i `body`. Ekran spaja dvije liste u jednu, sortira po
`sort_order` i numeriše `01..NN` **redom kojim sekcije stignu** — broj je izračunat, ne upisan.
Kad tie postoji (isti `sort_order` u obje tabele), platformska sekcija ide prva; to je
deterministično, ne slučajno.

**`salon_policies` ne pokriva dokument `privacy`.** Politika privatnosti je u cijelosti
platformska; `check (document = 'terms')` to provodi u bazi, ne u komentaru.

### Placeholderi, jer bi slobodan tekst odlutao od koda

Tijelo sekcije smije sadržavati `{minCancelHours}`, `{phone}`, `{email}` i `{appointmentSingular}`,
koje **ekran popunjava iz živih podataka** prije ispisa. Razlog je konkretan: handoff piše
„najkasnije **2 sata** prije početka", a `salon_settings.min_cancel_hours` je **3** za barbera i
**6** za beauty — i `cancel_appointment` (task 16) taj rok stvarno provodi. Slobodan tekst bi značio
da salon promijeni rok u postavkama, a pravno obavezujući ekran i dalje piše staru cifru.

Isto vrijedi za kontakt: handoff nosi `030 711 220`, seed `030 711 000` — dva izvora za isti podatak
već su se razišla prije nego što je ijedan red napisan.

## Razmatrane opcije

- **Jedna tabela sa nullable `salon_id`** — odbačeno. Politika bi dobila `NULL` granu
  (`salon_id is null or private.salon_active(salon_id)`), a `.claude/docs/security.md` već bilježi
  da je **upravo `NULL` u guardu** pustio zahtjev bez `x-salon-id` headera (task 14: `not (A and B)`
  je rupa kad `B` može biti `NULL`). Isti oblik na tabeli koja se čita **bez prijave** nije mjesto
  za ponavljanje te greške.
- **`jsonb` kolona na `salon_settings`** — odbačeno. Tri stvari se gube: `sort_order` postaje
  redoslijed elemenata u nizu koji niko ne validira, sekcija ne može imati svoj `updated_at`
  (a `/terms` prikazuje „Zadnja izmjena"), i platformski tekst bi se **kopirao u svaki salon** —
  ispravka jedne rečenice bila bi `update` nad svakim tenantom. Uz to, `salon_settings` je tabela
  postavki koje čita availability engine; pravno tijelo teksta tu ne pripada.
- **`salons` kolona (`terms_text text`)** — odbačeno iz istog razloga plus jedan gori: jedna kolona
  znači jedan blok teksta, pa ekran ili crta zid teksta ili parsira markdown i sam izvodi sekcije.
  Handoff traži numerisane sekcije, dakle strukturu, a struktura izvedena parsiranjem je struktura
  koja pukne na prvom salonu koji zaboravi prazan red.
- **Literal u `.arb`-u** — odbačeno: DoD ga izričito zabranjuje, a i da ne zabranjuje, salon ne bi
  mogao promijeniti rok otkazivanja bez novog builda u storeu.
- **Salon smije mijenjati i legal sekcije, uz „approval" flag** — odgođeno, ne odbačeno. Vratiće ga
  na sto prvi tenant kojem pravnik traži svoju formulaciju sekcije „Vaši podaci". Tada treba i
  moderacija i evidencija ko je šta odobrio — dakle svoj task i svoj ADR, ne kolona dodana usput.
- **Sekcije bez brojeva u tekstu (bez placeholdera), pa broj stoji samo u postavkama** — odbačeno:
  pravila koja ne kažu rok otkazivanja ne govore korisniku ono zbog čega ekran postoji.

## Posljedice

- **Nova tabela bez `salon_id` je izuzetak koji traži obrazloženje**, a `supabase/CLAUDE.md` traži
  `salon_id` na svakoj novoj tabeli. `app_policies` je drugi takav slučaj u šemi (prvi je
  `vertical_packs`) i nosi isti oblik politike: javno čitanje, `private.is_super_admin()` za pisanje.
  Negativan test mora dokazati da `salon_admin` **ne može** pisati po njoj — inače bi tenant mogao
  promijeniti tekst koji obavezuje firmu.
- **Ekran mora podnijeti da salon nema nijednu svoju sekciju.** Tada `/terms` prikazuje samo
  platformske, numerisane `01..03` — to je uredno stanje, ne greška. Beauty tenant u seedu namjerno
  ima manje sekcija od barbera, da se to vidi u demou a ne tek kod prvog klijenta.
- **Broj sekcije nije podatak.** Ne upisuje se, ne čuva se i ne smije se pojaviti u tekstu tijela
  („v. tačku 3"), jer se pomjeri čim salon doda svoju sekciju iznad.
- **Placeholder koji ekran ne zna popuniti ostaje vidljiv kao `{ime}`.** To je namjerno: tiho
  brisanje nepoznatog placeholdera daje rečenicu bez roka („Termin možete otkazati najkasnije prije
  početka"), koja izgleda ispravno a ne znači ništa.
- **Politika privatnosti ovim ekranom nije riješena u cijelosti.** `docs/01` (§605, §617, korak 29)
  traži **javnu URL politiku po tenantu**, koju servira Next.js iz Sprinta 3. Isti `app_policies`
  red kasnije hrani i tu stranicu — zato tekst i stoji u bazi, a ne u app-u.
- **Ovo nije pravni savjet.** Seed tekst je pisan da bude tačan naspram koda i upotrebljiv za
  App Privacy i Data Safety formulare; prije submissiona ga mora pogledati neko ko za to odgovara.
