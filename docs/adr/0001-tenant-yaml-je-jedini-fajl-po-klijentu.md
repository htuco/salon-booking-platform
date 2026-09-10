# `tenant.yaml` je jedini fajl koji se piše po klijentu

## Status

prihvaćen

## Kontekst

Model prodaje je N brandiranih aplikacija iz jednog codebasea, sa ambicijom od desetina klijenata.
Svaki klijent nosi logo, boje, ime, ikonu, usluge, radnike, radno vrijeme i tekstove. Ako svaka od
tih stavki živi u repou, dodavanje klijenta postaje programerski zadatak, a promjena boje —
store review od nekoliko dana.

Istovremeno, dio identiteta **fizički mora** biti u binarnom fajlu: `applicationId`/`bundleId`,
ime u launcheru, ikona, splash. Store to ne čita iz mreže.

## Odluka

Repo drži **samo ono što se ne može promijeniti bez novog builda**, u jednom fajlu po klijentu:
`tenants/<flavor>/tenant.yaml`. Sve ostalo živi u backendu i uređuje se kroz super admin konzolu.

Test za svako novo polje: *može li se ovo promijeniti bez novog store reviewa?* Ako može — backend.

Boje su namjerno na oba mjesta: u bazi kao izvor istine, u `tenant.yaml` kao **fallback dok backend
ne odgovori**, da nema bijelog flasha pri pokretanju. Kad se razilaze, baza je u pravu.

## Razmatrane opcije

- **Sve u repou (folder po klijentu sa assetima i configom)** — odbačeno: svaka promjena boje traži
  build, PR i store review; vlasnik salona ne može ništa sam.
- **Sve u backendu, bez ijednog fajla u repou** — nije izvedivo: ime, ikona i bundle ID moraju
  postojati u vrijeme builda.
- **Config u bazi, generisan u repo pri buildu** — odgođeno: traži da CI ima pristup produkcijskoj
  bazi da bi uopšte buildao, što je gora zavisnost od jednog YAML fajla. Vrijedi otvoriti kad broj
  tenanata pređe granicu na kojoj je ručno održavanje YAML-a stvaran trošak.

## Posljedice

- Novi klijent je `cp -r tenants/_template` + popunjavanje jednog fajla + generatori.
- Promjena brendiranja u radu ne dira repo uopšte.
- Postoji obaveza sinhronizacije koju niko ne provjerava automatski: fallback boje u `tenant.yaml`
  naspram `salons.primary_color`/`secondary_color`. `/cleanup` ima korak za to.
- `tenant.yaml` je jedini fajl gdje greška u kucanju daje aplikaciju koja se uredno builda i ne
  radi — `salonId` koji ne postoji u bazi. Zato generator validira UUID, a `/new-tenant` traži
  poklapanje sa `seed.sql`.
