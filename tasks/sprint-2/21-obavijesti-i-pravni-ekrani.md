# Task 21 — Client: Obavijesti, "O aplikaciji" i "Pravila korištenja"

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [18](18-pocetna-i-tab-bar.md) |
| **Blokira** | store submission (pravila su obavezna) |
| **Reference** | `prototype/ui/screenshots/10-obavijesti.png`, `14-o-aplikaciji.png`, `15-pravila-koristenja.png` |

## Cilj
Zadnja tri ekrana iz handoffa. Dva su formalnost bez koje submission pada, jedan je mjesto gdje
push notifikacije slijeću.

## Definicija gotovog

> DoD je **prekrojen 2026-09-14** po odlukama iz [ADR-0009](../../docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md).
> Prva verzija je tražila šest zakucanih sekcija i tekst iz `salons`/`settings`; oba su odbijena.

- [~] `/notifications` po 5j — **samo prazno stanje**, sa iskrenim tekstom da obavijesti stižu kad
      salon potvrdi termin. Lista dolazi sa [25](25-push-notifikacije.md), ne odavde
- [x] `/about-app` po 5n: verzija iz `package_info_plus`, monogram iz inicijala, "Kako radi" u tri
      koraka, kontakt redovi iz `salons`
- [x] `/about-app` pravni redovi: "Pravila korištenja" → `/terms`, "Politika privatnosti" →
      `/privacy`, **"Ocijenite aplikaciju" vidljiv ali neaktivan** dok app nije u prodavnici,
      "Prijavite problem" → mail developeru
- [x] `/terms` po 5o: **dinamična** lista, numerisana `01..NN` redom kojim sekcije stignu — bez
      šest sekcija zakucanih u kodu
- [x] `/privacy` — politika privatnosti, pisana za **App Privacy i Data Safety** formulare.
      Nova ruta koju prva verzija DoD-a nije nabrajala, a `14-o-aplikaciji.png` je traži
- [x] Tekst dolazi iz **dvije tabele**, ne iz literala i ne iz `salons`: `app_policies` (bez
      `salon_id`, legal tekst piše samo platforma) i `salon_policies` (`salon_id`, salon uređuje
      svoje). Obrazloženje i odbijena alternativa: [ADR-0009](../../docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md)
- [x] Verzija se čita iz `package_info_plus`, ne iz konstante koja zastari

## Koraci
1. Pravila i "O aplikaciji" prvo — statični su i otključavaju submission
2. Obavijesti idu **sad, kao prazno stanje** — ekran bez liste je iskren, a ruta iz taska 18 već
   vodi na njega. Lista dolazi sa [25](25-push-notifikacije.md)
3. Commit: `feat(client): obavijesti i pravni ekrani`

## Zamke
- **Politika privatnosti je po tenantu i mora imati javni URL** ([01 §17](../../docs/01-mvp-spec.md#17-build-order)
  korak 29). Ekran u app-i je ne zamjenjuje.
- Lista obavijesti bez servera je lokalna historija pusheva — reci to u praznom stanju, ne glumi
  server koji ne postoji.

## Status (2026-09-14) — ✅ zatvoren

PR [#38](https://github.com/htuco/salon-booking-platform/pull/38) mergovan 14.09.2026.

**Tekst pravila dolazi iz dvije tabele, ne iz `salons`.** Handoff 5o ima šest sekcija, ali nisu
iste vrste: Zakazivanje, Cijene i "Vaši podaci" obavezuju **firmu** i iste su u svakoj brandiranoj
app-i; Otkazivanje, Kašnjenje i Kontakt obavezuju **salon**. Otud `app_policies` (bez `salon_id`,
kao `vertical_packs`) i `salon_policies` (`salon_id`). Jedna tabela sa nullable `salon_id` je
odbijena: politika bi dobila NULL granu, a upravo je NULL u guardu pustio zahtjev bez
`x-salon-id` headera u tasku 14. Negativan test koji ovo drži je `salon_admin` nad `app_policies` —
`insert` mora pasti. Obrazloženje: [ADR-0009](../../docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md).

**Handoff copy nije prepisan jer tvrdi neistinu.** Sekcija "Vaši podaci" na
`15-pravila-koristenja.png` piše da čuvamo i **broj telefona**; klijentska app ga nikad ne traži
(`ensure_customer` upisuje samo ime, booking ekran nema polje, `docs/01` to vodi kao donesenu
odluku). Prepisan handoff bi lagao u prvoj rečenici pravno obavezujuće sekcije, pa su oba
dokumenta **napisana nanovo**, po stvarnom inventaru podataka i za App Privacy / Data Safety
formulare.

**Dvije greške koje je našao ekran, a testovi nisu mogli** (commit `2884a7e`):

- **Politika privatnosti je išla naopako** — "Kontakt" je bio `01`, a "Ko obrađuje podatke" `09`.
  `PostgrestTransformBuilder.order` ima `ascending = false` kao default, pa je `.order('sort_order')`
  vraćao dokument obrnuto. Ista zamka je već zapisana u `service_repository.dart`. `privacy()` sad
  ide kroz `mergePolicySections`, pa poredak ima **jedan izvor** za oba dokumenta. Asercija je u
  `rest_public_catalog.ts`, protiv pravog PostgREST-a: unit test koji mapira red ne vidi redoslijed
  kojim redovi stižu, a widget test ne vidi ni to, jer ekran ne sortira.
- **"Zadnja izmjena: 14.09.2026.."** — `formatDate` već nosi tačku, a `.arb` je dodavao još jednu.
  Dupla se vidi samo na ekranu; test koji traži podniz bi je propustio, pa novi traži cijeli string.

Uz to `run_tenant.sh` sad prosljeđuje `--build-name`/`--build-number` iz `tenant.yaml`: bez toga
`flutter run` uzima `1.0.0+1` iz `apps/client/pubspec.yaml`, pa jedini ekran koji verziju prikazuje
u razvoju pokazuje drugi broj nego store build.

**Dokazano pokretanjem** (ponovo provjereno 14.09. nakon mergea): **460 Dart testova** PASS
(admin 4, client 231, core_api 90, core_domain 68, core_ui 67 — bilo 419 na tasku 20),
**176 pgTAP** u 7 fajlova (bilo 147) i **123 REST asercije** (24 izolacija + 57 javni katalog +
20 upsert/rezervacija + 22 dva salona). `melos run analyze` čist u svih pet paketa,
`dart format` 0 izmijenjenih. Uživo na **iOS simulatoru** (iPhone 17 Pro, `barberstudiovitez`)
protiv lokalnog stacka: `/terms` numerisan `01..06` sa `3 h` iz `salon_settings` i `030 711 000`
iz `salons` — dakle iz baze, ne `2 sata` i `030 711 220` iz handoffa; `/about-app` sa monogramom
"BV" i verzijom iz `package_info_plus` (`docs/screenshots/task-21-o-aplikaciji.png`).

**Ostaje otvoreno, ali ne blokira:** `/notifications` je namjerno **samo prazno stanje** — lista
dolazi sa [25](25-push-notifikacije.md), i to je odluka, ne dug. "Ocijenite aplikaciju" stoji
vidljiv ali neaktivan dok app nije u prodavnici. Javni URL politike privatnosti
([01 §17](../../docs/01-mvp-spec.md#17-build-order) korak 29) i dalje traži hosting — ekran u
app-i ga ne zamjenjuje.

### Zamka za sljedećeg

**Lokalna suite pada iz čistog checkouta dok se ne generiše kod.** Greške izgledaju kao pravi
bugovi („getter `accountDeleteCancel` nije definisan"), a zapravo su samo negenerisan `freezed` i
`l10n`. CI to radi u zasebnim koracima, lokalno moraš sam:

```
dart run melos exec --depends-on=build_runner -- dart run build_runner build
cd apps/client && flutter gen-l10n
```

`apps/client/lib/src/l10n/generated/` **nije u repou** — otud `git status` ostaje čist nakon
`gen-l10n`.

