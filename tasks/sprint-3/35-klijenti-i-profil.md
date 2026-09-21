# Task 35 — Klijenti i profil

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [29](29-responsive-shell.md) |
| **Blokira** | — |
| **Reference** | `SPEC.md` prikazi `3e` `3o` · [15](../sprint-2/15-izolacija-klijent-u-dva-salona.md) |

## Cilj
Salon vidi svoje klijente i istoriju dolazaka. Modul još ne postoji ni kao ruta.

## Definicija gotovog
- [x] `/clients` po `3e`, mobilno `3o`; ruta, repozitorij i ugovor su novi
- [x] Profil: dolasci, otkazivanja, `no_show_count`, `visit_count`
- [x] Pretraga po imenu, bez ijednog upita koji prelazi granicu salona
- [x] **Isti čovjek u dva salona ostaje dva `Customer` reda.** Admin salona A ne smije doći do reda
      salona B ni po `id`, ni po `auth_identity_id`, ni kroz embed
- [x] REST/pgTAP test koji to dokazuje, uz postojeći `rest_cross_salon_isolation.ts`
- [x] `no_show` prag se i dalje **ne provodi** — to je pravilo vertikale, ne admin ekran

## Koraci
1. Repozitorij + izolacioni test prije ekrana
2. Lista, pa profil
3. Commit: `feat(admin): klijenti i profil klijenta`

## Zamke
- **Ovo je modul sa najvećim rizikom curenja u sprintu.** Klijent je jedini entitet koji stvarno
  postoji u dva salona. Task 15 je pokazao da embed na `appointments` zna postati dvosmislen
  (`PGRST201`, HTTP **300**) — test koji `300` ne tretira kao grešku prolazi lažno.
- Brisanje naloga (task 17) anonimizira i `appointments.customer_name`. Profil mora podnijeti
  klijenta bez imena.
- Telefonski klijent iz ručnog unosa nema `auth_identity_id`. To je ispravno stanje, ne greška.

## Status (2026-09-21)

Urađeno. Grana `feat/klijenti-i-profil`, [PR #58](https://github.com/htuco/salon-booking-platform/pull/58).

`/clients` je prestao biti placeholder: desktop `3e` je adresar sa profilom uz listu, telefon `3o`
iste redove kao kartice, sa profilom preko liste. Šest DoD stavki je čekirano dokazom, ne kodom.

### Test je pisan prije ekrana, i to je promijenilo šta testira

Korak 1 je tražio repozitorij i izolacioni test prije ekrana. Nalaz iz tog redoslijeda:
`rest_cross_salon_isolation.ts` je **već dokazivao četiri od pet** puteva iz DoD-a (direktan upit,
po `id`-u, po `auth_identity_id`, embed `appointments → customers`) — ono što mu je nedostajalo
nije bio još jedan opšti test nego **puteve koje uvodi baš ovaj ekran**: pretraga po uzorku i
**obrnuti** embed `customers → appointments`. Oba su neugodna na isti način: ne traži se tuđi red
nego se šalje uzorak, pa curenje ne bi izgledalo kao napad nego kao klijent koji se pojavio
niotkuda. 13 novih asercija, 27 → **40**.

### Migracije nema, i to je nalaz a ne propust

`staff_manage` politika nad `customers` (`for all`, `private.is_admin(salon_id)`) stoji od init
migracije, i grantovi su tu. **`customers` je zadržala `insert`/`update`** — za razliku od
`appointments` (24), `employees` (33) i `working_hours` (34), gdje su ih ti taskovi oduzeli; task
24 ju je izričito ostavio da salon ispravi ime i zabilježi napomenu. Zato je ovo jedini staff
repozitorij kod kojeg „samo kroz `rpc`" **ne drži grant nego odluka**, i to je zapisano u
`security.md` i `architecture.md`, jer je baš tu sljedeća izmjena najbliža tome da dopiše `insert`.

### Pretraga je prvo mjesto gdje korisnikov tekst ulazi u PostgREST izraz

`or=(...)` razdvaja uslove **zarezom**, pa bi ime sa zarezom raspalo izraz u dva uslova; `%` i `_`
su `like` džokeri, pa bi neočišćen `_` pogađao bilo koji znak i pretraga bi izgledala kao da vraća
nasumične ljude. `,`, `(`, `)` se uklanjaju, `%`, `_`, `\` brišu, a unos koji se sav očisti daje
uzorak koji **ne pogađa ništa** — ne `*%*` koji pogađa sve. RLS ovo ionako presijeca, ali izraz
koji se da razbiti je pogrešna navika bez obzira na politiku iza njega.

### Četiri stanja koja bi pala na `!`

Anonimiziran red poslije brisanja naloga (task 17) nema upotrebljivo ime, telefonski klijent nema
`auth_identity_id`, klijent bez ijednog dolaska nema `last_visit_at`, termin bez radnika nema
`employee_name`. Nijedno nije greška nego stanje, pa svako dobija riječ („Bez imena", „Bez broja",
„Nikad") umjesto praznog mjesta ili crtice koja se čita kao greška u učitavanju.

### „Nema podatka" se ne crta kao nula

„Potrošeno" zbraja samo `completed` termine — otkazan termin nije prihod — i **izostaje** kad
nijedan ne nosi cijenu, jer bi „0 KM" tvrdilo da klijent ništa nije potrošio umjesto da se ne zna.
Isto pravilo kao u tasku 30. Cijena dolazi iz `service_price` snapshota (task 32), ne iz današnjeg
cjenovnika: poskupljenje usluge ne smije unazad promijeniti koliko je neko potrošio.

### Dokazi

- `deno run --allow-env --allow-net supabase/tests/rest_cross_salon_isolation.ts` — **40 asercija**
  kroz tri stvarna JWT-a. **Dvije sabotaže potvrđuju da nove asercije mogu pasti:** pretraga po
  imenu (`error: Pretraga po imenu vraca samo red iz salona A…`) i embed po tačnom tuđem `id`-u
  (`error: Embed po tacnom id-u tudjeg klijenta ne smije vratiti nista.`).
- Svih **devet** REST suita prolazi (234 asercije ukupno) — nema regresije od izmjene
  `providers.dart`.
- `npx supabase test db` — **385 testova, PASS**.
- `dart run melos run test` — **SUCCESS**, 779 testova u pet paketa: admin **268** (bilo 247, 18
  novih), core_domain 88, core_api 122, core_ui 67, client 234.
- `dart run melos run analyze` i `dart format --set-exit-if-changed` — bez ijedne primjedbe.
- Sabotaža Flutter testa: uklonjen `completed` guard u `potroseno()` daje **60 umjesto 45**, i test
  to imenuje.

### Ostalo za sljedećeg

- **CI nije potvrđen** u trenutku pisanja — PR #58 je otvoren, oba joba treba da budu zelena prije
  spajanja. Dokaz iz čistog checkouta je ono što lokalno pokretanje ne može dati.
- **Ekran nije viđen uživo**, ni na webu ni na uređaju. Widget testovi pokrivaju obje širine i
  hvataju preljeve, ali task 30 i 31 su pokazali da ekran nađe greške koje testovi ne mogu.
- **Četiri stvari iz canvasa `3e` namjerno nisu nacrtane**, sa razlogom i mjestom povratka u
  `prototype/admin/SPEC.md`: „+ Novi klijent" (traži obrazac nad `upsert_walkin_customer`),
  „342 ukupno" (zbir preko cijelog adresara, a lista je odrezana na `limit`), „Sljedeći termin"
  (traži upit nad budućim terminima) i „Zakaži termin"/„Pozovi" (`url_launcher`, predpopunjen
  `/appointments/new`).
- **Profil nema svoju adresu.** Izbor živi u provideru, pa `/clients/<id>` ne radi iz bookmarka —
  isti dug koji `/calendar` ima za dan.
- **Spajanje dva reda istog čovjeka** (telefonski + prijavljeni) je odluka salona koju ovaj ekran
  ne nudi; `security.md` je od taska 24 opisuje kao admin radnju.
