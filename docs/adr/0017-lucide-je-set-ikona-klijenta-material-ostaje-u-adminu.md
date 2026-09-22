# Lucide je set ikona klijenta, Material ostaje u adminu

## Status

prihvaćen

## Kontekst

`tasks/fe-redizajn/README.md` vodi izbor seta ikona kao jednu od četiri odluke koje blokiraju
FE epik, uz obrazloženje da „u Flutteru ga danas nema nijedan paket, a u kodu stoji 116 upotreba
`Icons.*`". **Taj opis više ne odgovara kodu.**

Stvarno stanje, izmjereno u repou:

- `lucide_icons_flutter: ^3.1.19` stoji u `apps/client/pubspec.yaml:68` **i** u
  `packages/core_ui/pubspec.yaml:20`.
- Uvezen je u **12 fajlova** klijentske aplikacije i **četiri** komponente `core_ui`-ja
  (`back_header`, `calendar_month`, `link_row`, `selectable_row`).
- Preostale `Icons.*` upotrebe su **109, ne 116**, i raspodjela nije ravnomjerna:
  **71 u `apps/admin` i `packages`**, a samo **34 u `apps/client`**.

Dakle odluka je već djelimično pala — u kodu, bez ADR-a — i pala je **po aplikaciji**: klijent je
na Lucideu, admin nije. `prototype/ui/SPEC.md:118` traži Lucide stroke 1.5 za klijenta;
`prototype/admin/SPEC.md` ne traži Lucide nigdje.

Uz to, jedan nalaz iz rada na klijentu je već zapisan u kodu
(`packages/core_ui/lib/src/components/star_rating.dart:11`): **Lucide nema punu zvjezdicu** —
set je cijeli linijski. Prva verzija ocjene je punu od prazne razlikovala bojom iste linijske
ikone, što je na živom ekranu palo i uz to je WCAG 1.4.1 problem. Zvjezdica je zato crtana
površina, ne ikona.

## Odluka

**`lucide_icons_flutter` je set ikona `apps/client`-a i `packages/core_ui`-ja. `apps/admin` ostaje
na Material `Icons.*`.**

Mehanika:

- Novi kod u klijentu i u `core_ui` uzima ikonu iz Lucidea. `Icons.*` u ta dva mjesta je nalaz
  pregleda, ne stil.
- Preostalih 34 `Icons.*` u klijentu su **imenovan dug**, ne greška koja blokira. Mijenjaju se
  kad se dirne ekran na kojem stoje, ne kampanjski.
- **Admin se ne prevodi na Lucide.** Admin je interni alat jedne platforme, njegov handoff
  (`prototype/admin/SPEC.md`, `prototype/adminv2/export/`) ne traži Lucide, i 71 upotreba
  `Icons.*` tamo nema šta da dobije zamjenom.
- Gdje Lucide nema oblik koji nosi **informaciju** (puna naspram prazne zvjezdice), crta se
  površina. Razlika nošena samo bojom ili samo debljinom linije je WCAG 1.4.1 problem i ne prolazi.

## Razmatrane opcije

- **Lucide u obje aplikacije** — odbačeno: 71 upotreba `Icons.*` u adminu i `packages`, a nijedan
  admin handoff ne traži Lucide. To je rad bez tražioca, i uz to rizik prelivanja jer se metrike
  ikona razlikuju.
- **Zapakovan icon font ili SVG set umjesto pub paketa** — odbačeno: paket je već u `pubspec.lock`
  i radi; njegov font se tree-shakuje po težini (`LucideVariable-w100…w600` u
  `build/unit_test_assets`). Zamjena bi bila trošak bez dobitka.
- **Kampanjska zamjena svih 34 `Icons.*` u klijentu odmah** — odgođeno, ne odbačeno: vraća se na
  sto uz FE-104, koji je zaseban task i nosi provjeru debljine linije.

## Posljedice

- **FE-104 je odblokiran** i sužen: nije „uvedi set ikona" nego „ujednači debljinu i dovrši
  preostalih 34 u klijentu".
- `tasks/fe-redizajn/README.md` je nosio netačan broj (116) i netačnu tvrdnju („nema nijedan
  paket"). Ispravlja se u istoj promjeni.
- Postalo je teže: **dva seta ikona u jednom repou.** Ko piše `core_ui` komponentu mora znati da
  ona ide u klijenta i da se tamo crta Lucide, dok isti `Icons.*` u adminu ostaje ispravan.
- **Izgleda kao nedosljednost, a nije**: `Icons.*` u `apps/admin` nije zaostatak nego odluka.
