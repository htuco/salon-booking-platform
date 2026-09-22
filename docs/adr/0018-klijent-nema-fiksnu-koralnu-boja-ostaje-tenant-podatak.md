# Klijentska aplikacija nema fiksnu koralnu — boja ostaje tenant podatak

## Status

prihvaćen

## Kontekst

Dizajnerski handoff FE epika traži koralnu `#EE6C4D` kao akcent u **obje** aplikacije.
`tasks/fe-redizajn/README.md` to vodi kao odluku 2, koja blokira FE-1xx i FE-3xx.

Koralna je u adminu ispravna i tamo ostaje — to je riješeno
[ADR-0016](0016-adminv2-je-vizuelni-izvor-istine-za-admin.md): admin je **jedan platformski build
za sve salone**, pa njegov akcent jeste identitet proizvoda.

Klijentska aplikacija je suprotan slučaj i to je nosiva razlika cijelog proizvoda:

- `apps/client` je **N brandiranih buildova**, jedan po salonu. Boja dolazi iz
  `tenants/<flavor>/tenant.yaml` kroz `buildAppTheme()`
  (`packages/core_ui/lib/src/theme/theme_factory.dart:26`).
- Mehanizam **nije teorijski** — dva postojeća tenanta nose dvije različite boje:
  `barberstudiovitez` `#C6A667` (zlatna) i `beautystudiotravnik` `#B76E79` (roze).
  `_template` nosi `#1A1A1A`.
- `CLAUDE.md` to vodi kao **tvrdo pravilo**: „Iz `prototype/ui/` se uzima oblik, ne boja. […]
  Hardkodiran hex u ekranu je greška koja se vidi tek na drugom tenantu."
- Provjereno grepom: **`#EE6C4D` se danas ne pojavljuje nigdje u `apps/client` ni u
  `packages/core_ui`.** Pravilo se dosad poštovalo.

Fiksna koralna u klijentu bi prošla svaki test u repou — testovi crtaju jedan tenant — i pukla bi
tek kad vlasnik drugog salona otvori svoju aplikaciju i vidi tuđu boju.

## Odluka

**Koralna `#EE6C4D` ostaje isključivo u `apps/admin`. `apps/client` je ne dobija ni u jednom
obliku.**

Mehanika:

- Akcent klijenta je i dalje `primaryColor` iz `tenant.yaml`, kroz `buildAppTheme()`.
- Iz klijentskog dijela handoffa se uzima **oblik**: raspored, razmaci, tipografska skala,
  radius 0, hairline granice, oblik komponenti. To je platformsko i ide u `core_ui`.
- **Hex u fajlu ekrana klijenta je greška pregleda**, bez izuzetka za koralnu.
- Gdje handoff koralnom nosi **značenje** (primarna radnja, oznaka koja traži pažnju), značenje se
  preslikava na **semantičku ulogu** u temi, a ulogu boji tenant. Ne preslikava se hex.

## Razmatrane opcije

- **Koralna kao fiksni akcent i u klijentu** — odbačeno: ruši multi-tenant branding, koji je
  razlog postojanja `tenant.yaml`-a i [ADR-0001](0001-tenant-yaml-je-jedini-fajl-po-klijentu.md).
  Dva postojeća salona već nose svoje boje.
- **Koralna kao zadana vrijednost, tenant je prepisuje** — odbačeno: zadana vrijednost koja se
  nikad ne koristi je mrtav kod, a kad se jednom upotrijebi (novi tenant bez `primaryColor`-a)
  daje salonu tuđi identitet tiho. `_template` već nosi neutralnu `#1A1A1A`.
- **Koralna samo za destruktivne/upozoravajuće radnje u klijentu** — odbačeno: za to već postoji
  semantička uloga, i ona ne treba biti ista boja kao akcent admina.
- **Pitati dizajnera da li je koralna u klijentu namjera** — odgođeno, ne odbačeno: vraća se na
  sto ako stigne handoff koji izričito kaže da klijent prestaje biti brandiran po salonu. To bi
  bila promjena proizvoda, ne promjena boje.

## Posljedice

- **FE-101 i FE-3xx su odblokirani** u dijelu koji se ticao ove odluke: crtaju se po obliku iz
  `prototype/ui/`, a boja ostaje kroz `buildAppTheme()`.
- Klijentski ekrani **neće izgledati kao handoff PNG-ovi u boji**, i to je očekivano, ne bug.
  Poklapa se raspored, razmak i težina, ne hex.
- Pregled klijentskog ekrana mora provjeriti hex grepom, jer test sa jednim tenantom to ne hvata.
- **Izgleda kao propušten zahtjev handoffa, a nije**: koralna u klijentu je svjesno odbijena.
