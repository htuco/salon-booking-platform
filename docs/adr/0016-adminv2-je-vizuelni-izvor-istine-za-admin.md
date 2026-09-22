# `prototype/adminv2/` je vizuelni izvor istine za admin, `admin/` je zastario

## Status

prihvaćen

## Kontekst

`prototype/adminv2/` je stigao commitom `1edd73a` („feat: new admin screens for improved UI/UX") sa
21 PNG izvozom i **bez ijednog opisa**: nema `SPEC.md`, nema `README.md`, folder sadrži samo
`export/`. `prototype/CLAUDE.md` ga ne spominje — njegova tabela i dalje nabraja tri foldera i
`admin/` vodi kao „vizuelni izvor istine za `apps/admin`".

Zbog toga je svih šest admin taskova FE epika (`tasks/fe-redizajn/`, FE-401…FE-406) imalo dva
izvora koji se ne slažu: task fajlovi referenciraju `adminv2/export/*.png`, a pravilo repoa
upućuje na `admin/SPEC.md`. [FE-406](../../tasks/fe-redizajn/FE-406-desktop-fluidni-layout.md) je
mogao naprijed jedino zato što je **jedini od šest koji ne referencira nijedan PNG**.

Novi podatak koji je odluku učinio uskom: **oba foldera pokrivaju isti skup ekrana.** Izvučeni
identifikatori iz imena fajlova u `adminv2/export/` daju `3a`–`3u`, a `admin/SPEC.md` u „Mapi
prikaza" nabraja tačno isti skup `3a`–`3u`. Razlika je nula u oba smjera. Dakle `adminv2` nije
drugi handoff niti novi opseg — to je **redizajn istih 21 prikaza**.

Pregled izvoza (`3b` dashboard, `3j` prijava) pokazuje da je i raspored zadržan: iste kartice
metrika, ista tabela rasporeda dana, isti panel zahtjeva, iste trake zauzetosti. Mijenja se
površina:

- **Melura** wordmark i logo placeholder umjesto „Salon OS"
- **koralna `#EE6C4D` prelazi iz sporedne u glavnu ulogu.** Ona nije nova boja — `SPEC.md:82` je
  već vodi kao „Radnja (coral)", uz plavu `#3D5A80` kao „Primarni akcent" (`SPEC.md:81`). U
  `adminv2` izvozima koralna nosi primarne akcije i oznake, a plava ostaje na linkovima i
  sporednom tekstu. Mijenja se **raspodjela uloga**, ne paleta.
- navigacija velikim slovima, aktivna stavka tamna
- sidebar nosi birač lokacije i „6 lokacija"

## Odluka

**`prototype/adminv2/` je vizuelni izvor istine za `apps/admin`. `prototype/admin/` je zastario.**

Mehanika, jer se ovo najlakše pogrešno pročita:

- Gdje se izvozi razilaze, **`adminv2/` je jači**. Ekran se crta po njemu.
- **`admin/SPEC.md` ostaje na snazi kao tekst** i ne briše se. On nosi ono što PNG ne može:
  mapu `3a`–`3u` na Flutter module, funkcionalne granice („šta canvas crta, a aplikacija
  namjerno nema"), tokene i redoslijed implementacije. Isti skup ekrana znači da ta mapa i
  dalje važi.
- Gdje `SPEC.md` opisuje **vizual** (boja akcenta, ime proizvoda, tipografija), `adminv2/` ga
  nadjačava i `SPEC.md` se ispravlja u istoj promjeni koja taj ekran dira.
- `admin/canvas/` i `admin/index.html` se **ne portuju**, kao ni ranije.
- Koralna je ovdje ispravna i ostaje **u adminu**: admin je jedan platformski build za sve
  salone, pa njegov akcent jeste identitet proizvoda. U klijentskoj aplikaciji ista boja je
  greška — tamo boja dolazi iz `tenant.yaml` kroz `buildAppTheme()`.
- Birač lokacije i „6 lokacija" iz sidebara su `3a` multi-location scope. Ostaju **budući**, kao
  što `admin/SPEC.md` već vodi: traže RBAC koji ne postoji.

## Razmatrane opcije

- **`admin/` ostaje jači, `adminv2/` je skica** — odbačeno: commit ga uvodi kao „improved UI/UX",
  a svih pet preostalih admin taskova u `tasks/fe-redizajn/` već referencira `adminv2/export/`
  kao referencu. Držati staro jačim značilo bi da su ti taskovi napisani protiv pogrešnog izvora.
- **Obrisati `prototype/admin/`** — odbačeno: `SPEC.md` je jedini tekst koji mapira prikaze na
  module i nabraja funkcionalne granice; PNG izvoz to ne nosi. Brisanjem bi se izgubio opis, a
  dobila samo uredna lista foldera.
- **Tražiti `SPEC.md` za `adminv2/` prije nego se krene** — odgođeno, ne odbačeno: bio bi bolji
  ulaz, ali ga nema i niko ga ne piše. Vraća se na sto ako se pojave ekrani koje `3a`–`3u` ne
  pokriva, jer tada mapa iz starog `SPEC.md` prestaje važiti.

## Posljedice

- FE-401…FE-405 su odblokirani. Crta se po `adminv2/export/`, mapa i granice se čitaju iz
  `admin/SPEC.md`.
- **`admin/SPEC.md` sada opisuje vizual koji više ne važi na dva mjesta**: raspodjela akcenta
  (`SPEC.md:81` vodi plavu `#3D5A80` kao primarni akcent, a `SPEC.md:91` tvrdi da je „Admin
  akcent platformski") i ime „Salon OS" (`SPEC.md:1`). To je poznata neusklađenost, ne propust —
  ispravlja je [FE-401](../../tasks/fe-redizajn/FE-401-admin-shell.md), koji preimenovanje i
  koralnu nosi u svom DoD-u.
- Postalo je teže: dva foldera opisuju isti admin, pa svako ko crta admin ekran mora znati da
  tekst uzima iz jednog, a sliku iz drugog. `prototype/CLAUDE.md` to zato izričito piše.
- **Izgleda kao bug, a nije**: sidebar u `adminv2` izvozima ima birač lokacije i „6 lokacija",
  a aplikacija ih nema. To je `3a` scope koji čeka RBAC.
- Odluka o **Barlow tipografiji nije ovdje.** `adminv2` izvozi je koriste, ali zamjena pisma
  dira i klijentsku aplikaciju i dva postojeća para pisama zapakovana uz OFL licence; to je
  zaseban ADR i zaseban task (FE-102).
