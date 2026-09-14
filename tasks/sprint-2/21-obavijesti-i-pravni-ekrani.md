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
- [~] `/notifications` po 5j — **samo prazno stanje.** Lista, potvrde, podsjetnici i nepročitano
      stižu sa [taskom 25](25-push-notifikacije.md); prije njega nema izvora podataka (v. Status)
- [x] `/about-app` po 5n: verzija, "Kako radi" u tri koraka, pravni redovi
- [x] `/terms` po 5o: šest numerisanih sekcija (zakazivanje, otkazivanje, kašnjenje, cijene,
      podaci, kontakt)
- [x] Tekst pravila dolazi **po tenantu** (`salons` kolona ili `settings`), ne kao literal u app-i
- [x] Verzija se čita iz `package_info_plus`, ne iz konstante koja zastari

## Koraci
1. Pravila i "O aplikaciji" prvo — statični su i otključavaju submission
2. Obavijesti nakon taska 25, da imaju šta prikazati
3. Commit: `feat(client): obavijesti i pravni ekrani`

## Zamke
- **Politika privatnosti je po tenantu i mora imati javni URL** ([01 §17](../../docs/01-mvp-spec.md#17-build-order)
  korak 29). Ekran u app-i je ne zamjenjuje.
- Lista obavijesti bez servera je lokalna historija pusheva — reci to u praznom stanju, ne glumi
  server koji ne postoji.

## Status (2026-09-14) — ✅ zatvoren

Sva četiri ekrana su napisana i mergovana ([PR #38](https://github.com/htuco/salon-booking-platform/pull/38),
`21c62f9`). Task je narastao preko naslova: DoD je tražio tri ekrana, a isporučena su **četiri** —
`/privacy` je nova ruta koju task fajl ne spominje, a store submission je traži.

**Pravila su dvije tabele, ne jedna.** `app_policies` (bez `salon_id`, legal tekst koji obavezuje
firmu) i `salon_policies` (`salon_id`, pravila koja mijenja salon). Jedna tabela sa nullable
`salon_id` je odbijena jer bi politika dobila NULL granu — isti oblik koji je u tasku 14 pustio
zahtjev bez `x-salon-id` headera. Obrazloženje:
[ADR 0009](../../docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md).

**Tekst pravila je pisan nanovo, ne prepisan.** Handoff `15-pravila-koristenja.png` tvrdi da se
čuva „ime, **broj telefona** i historija termina" — klijentska app telefon **nikad ne traži**:
`ensure_customer` upisuje samo ime, booking ekran nema polje, i `docs/01` to vodi kao donesenu
odluku. Prepisan handoff bi lagao u prvoj rečenici pravno obavezujuće sekcije. Generički template
ima istu bolest u drugom obliku — tvrdi kolačiće, plaćanja i lokaciju, čega ovdje nema.

**Brojevi u tekstu se ne kucaju, nego se popunjavaju.** Tijelo sekcije nosi placeholdere
(`{minCancelHours}`, `{phone}`, `{email}`, `{appointmentSingular}`) koje ekran puni iz živih
podataka. Bez toga salon promijeni `min_cancel_hours` u postavkama, a pravila i dalje pišu staru
cifru — app bi lagala korisniku na ekranu koji ga pravno obavezuje, dok `cancel_appointment`
provodi drugi broj.

### Dokazano

- **`Supabase tests` i `Flutter` zeleni na `main`** nakon merga
  ([run 34848488626](https://github.com/htuco/salon-booking-platform/actions/runs/34848488626),
  [34848488591](https://github.com/htuco/salon-booking-platform/actions/runs/34848488591)).
- **Cijela Dart suite lokalno PASS** — `core_domain`, `core_api` i `client`, zadnji sa **231 testom**
  (`dart run melos exec --dir-exists=test -- flutter test`).
- **`007_policies.test.sql`** nosi negativan test koji drži oblik: `salon_admin` **ne može** pisati
  po `app_policies`, i sekcije neaktivnog salona su nevidljive.
- Novi Deno asertovi u `rest_public_catalog.ts` — `anon` čita pravila bez prijave.

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

### Ostalo za sljedećeg — ništa ne blokira

Tri stringa na jednom mjestu, svi namjerno prazni jer podatak nije dat:

- **`supportEmail`** u [about_app_screen.dart:20](../../apps/client/lib/src/features/legal/about_app_screen.dart#L20)
  je prazan, pa se red „Prijavite problem" **ne crta**. Mail ide **developeru**, ne salonu — zato
  se ne uzima `store.supportEmail` iz `tenant.yaml`, koji je adresa za store listing.
- **„Ocijenite aplikaciju"** stoji vidljiv ali `disabled` (45% po `SPEC.md`) i ne prima tap, jer
  aplikacije nisu u prodavnicama. Kad odu, mijenja se `storeListingUrl` u `tenant.yaml`, ne ekran.
- **Naziv pravnog lica** u footeru — zasad `© <godina> <ime salona>`.

**Pravni pregled teksta prije submissiona ostaje obavezan.** Tekst je tačan naspram koda i pisan za
App Privacy / Data Safety formulare, ali **nije pravni savjet** — posebno oko GDPR-a.

**Javna URL politika privatnosti po tenantu ([01 §17](../../docs/01-mvp-spec.md#17-build-order)
korak 29) i dalje stoji otvorena** — ekran u app-i je ne zamjenjuje. Ide sa Sprintom 3; isti
`app_policies` red servira i nju, pa se tekst ne piše dvaput.

Lista obavijesti i nepročitano stanje dolaze sa [taskom 25](25-push-notifikacije.md) — tada se
mijenja **samo tijelo** `/notifications`, ne ruta ni ulaz.
