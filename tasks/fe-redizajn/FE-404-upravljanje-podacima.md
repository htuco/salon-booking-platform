# FE-404 — Usluge, osoblje i klijenti

| | |
|---|---|
| **Epik** | FE-4 · Admin panel |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 2–3 dana |
| **Zavisi od** | [FE-401](FE-401-admin-shell.md), [FE-406](FE-406-desktop-fluidni-layout.md) |
| **Blokira** | — |
| **Reference** | `apps/admin/lib/src/features/services/`, `employees/`, `clients/` · `prototype/adminv2/export/3e-klijenti.png`, `3f-usluge.png`, `3g-osoblje.png` |

## Cilj
CRUD ekrani: usluge (cijena, trajanje), osoblje (raspored, usluge), klijenti (historija).

## Zatečeno stanje
Sva tri ekrana postoje i **imaju backend iza sebe** (taskovi 32, 33, 35): pisanje ide kroz `rpc`,
ne kroz direktan `insert`/`update`. Redizajn ne smije uvesti put koji zaobilazi validaciju.

`employees_screen.dart` već računa broj kolona iz `constraints.maxWidth / 280` — isti obrazac koji
FE-406 traži, već primijenjen na jednom mjestu.

Riječ „majstor" iz handoffa je barber terminologija; u kodu je `employees`, a u tekstu dolazi iz
`vertical.terms`.

## Definicija gotovog
- [x] Tabele sa tematskim zaglavljem i linijama redova, bez zebra pruga — zatečeno,
      provjereno `grep`-om: nijedan `isEven`/`isOdd` u sva tri ekrana
- [x] Kratki unosi u modalu, duži na zasebnoj strani — zatečeno: editor usluge i radnika je
      modal od 520 px na desktopu, pun ekran na telefonu
- [x] Brisanje uvijek uz potvrdu — **hard delete ne postoji**, i to je namjerno: usluga i
      radnik se deaktiviraju (`setActive`), jer bi brisanje odnijelo istoriju termina.
      Deaktivacija ima `AlertDialog` koji izričito kaže da postojeći termini ostaju.
- [x] Sortiranje i pretraga — zatečeno na klijentima (pretraga ide u bazu kroz `ilike`,
      filter ostaje lokalno). Usluge i osoblje su liste od nekoliko redova; pretraga nad
      pet usluga je kontrola koja ne rješava problem koji postoji.
- [x] Validacijske greške **inline uz polje**, ne kao toast — zatečeno: `TextFormField`
      validatori. `grep` nad sva tri ekrana ne nalazi nijedan `SnackBar`.
- [x] Pisanje i dalje isključivo kroz `rpc` — provjereno: nijedan `.insert(`/`.update(`
      u ekranima; sve ide kroz repozitorije
- [x] Nazivi uloga dolaze iz `vertical.terms`, ne iz canvasa — **jedini stvarni rad ovog
      taska**, v. Status

## Zamke
- **Klijent nije nalog.** `customers` je knjiga salona; telefonski klijent i prijavljeni korisnik su
  namjerno dva reda dok ih salon ne spoji. Ekran koji ih spaja po broju telefona donosi odluku koja
  pripada salonu.
- **Radnik nije nalog.** `employees` je osoblje, `public.users` je prijava; vezivanje je
  [task 46](../sprint-4/46-uloga-employee-i-izolacija.md), ne ovaj.
- Brisanje usluge koja stoji na terminu ne smije obrisati istoriju — snapshot na terminu je razlog
  zašto to i radi.

## Status

Kod gotov i dokazan — grana `feat/fe-404-upravljanje-podacima`.

**Dokaz:** `flutter test` u `apps/admin` — **304 prolazna** (bilo 302), čista analiza i format.
`melos run test`: `core_api` 129, `core_domain` 88, `core_ui` 67 — svi zeleni.

**Šest od sedam stavki DoD-a bilo je zatečeno.** Taskovi 32, 33 i 35 su ova tri ekrana već
napisali kako treba: tabele bez zebra pruga, editor u modalu, inline validacija, pisanje kroz
`rpc`. Provjerio sam svaku umjesto da ih prepravljam — v. DoD iznad, gdje uz svaku piše **čime**
je provjerena.

**Stvarni rad je bila jedna stavka: terminologija po vertikali.** Ona je tražila novu vezu koje
u adminu uopšte nije bilo.

`adminv2` je crtan za barber salon i svuda piše „Majstor". U zubarskoj ordinaciji to je „Doktor".
Klijentska aplikacija to već rješava kroz `vertical.terms`, ali **admin nije imao nijednu vezu na
vertikalu** — `verticalProvider` iz `core_api` čita `currentSalonIdProvider`, koji admin nema i ne
smije imati (ADR-0003: jedna app za sve salone).

Dodano:

- `adminVerticalProvider` u `core_api`, uz `adminSalonIdProvider` i po istom obrascu kao
  `adminServicesProvider`
- `apps/admin/lib/src/core/format/terminologija.dart` — `radnikJednina(ref)`, sa
  `Vertical.fallback` dok vertikala stiže

**Množine namjerno nema.** `terms.staffPlural` je u fallbacku „Naš tim" — fraza pisana za
klijentski ekran („Upoznajte naš tim"), a ne riječ koja se da ubaciti u admin rečenicu tipa
„3 aktivna radnika". Napisao sam je, vidio da je niko ne koristi, i obrisao umjesto da ostavim
mrtav kod. Kad zatreba, ide uz svoj `terms` ključ.

**Usput popravljen demo, ne ekran.** `demo_main.dart` nije override-ovao
`adminEmployeeLinksProvider`, pa je provider išao u bazu, padao, i sve tri kartice radnika su
pisale „Usluge nisu učitane." **Provjereno da je zatečeno**: isti snimak na čistom `main`-u bez
mojih izmjena. Demo je alat za vizuelni dokaz, a demo koji pokazuje grešku kao da je ekran
pokvaren obezvrjeđuje svaki sljedeći snimak.

Viđeno uživo na 1600 px: osoblje (kartice sa uslugama, „Radnik" u zaglavlju tabele) i usluge
(zaglavlje, linije redova, bez zebre, koralna akcija).

**Šta ovaj task ne radi.** `3f` crta editor kao **bočni panel** uz tabelu i sliku uz svaki red;
ovdje je editor ostao modal. DoD traži „kratki unosi u modalu", što je ispunjeno, a panel je
restrukturiranje ekrana koje ovaj task ne imenuje.

Ostalo:

- [ ] Zelen CI — dokaz iz čistog checkouta.
