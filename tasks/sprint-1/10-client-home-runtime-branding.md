# Task 10 — Client: home ekran sa runtime brandingom

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [06 — VerticalPack](../06-vertical-pack.md), [08 — core_api](08-core-api-repozitoriji.md), [09 — core_ui](09-core-ui-theme-factory.md) |
| **Blokira** | 11 (booking flow) |
| **Reference** | [01 §12](../../docs/01-mvp-spec.md#12-screens) · [02 §2](../../docs/02-user-flows-wireframes.md) · prototip `src/app/pages/LandingPage.tsx` |

## Cilj
Prvi pravi ekran, i prvi **end-to-end dokaz** da lanac baza → repozitorij → provider → tema → tekst radi: isti build sa drugim `SALON_ID` daje drugi salon, druge boje i drugu terminologiju, bez ijedne izmjene koda.

## Definicija gotovog
- [ ] `/` prikazuje: logo i cover salona, ime, vertikalno tačan naslov sekcija, listu usluga sa cijenom i trajanjem, tim, i primarni CTA
- [ ] **Svaki tekst koji se razlikuje po vertikali ide kroz `vertical.terms.*`** — CTA je `terms.bookCta`, sekcija tima je `terms.staffPlural`, usluge su `terms.servicePlural`. Nijedan takav literal u `.dart` fajlu ekrana
- [ ] Ostali tekstovi (dugmad, greške, prazna stanja) idu kroz `.arb`
- [ ] Ekran radi **bez prijave** — nigdje ne traži login ([06 §1.1](../../docs/06-auth-login-flow.md))
- [ ] Tri stanja pokrivena: učitavanje (skeleton, ne spinner preko praznog ekrana), greška (poruka + retry), prazno (salon bez usluga)
- [ ] Slike idu kroz `cached_network_image` — isti brend se učitava na svakom otvaranju
- [ ] Dokaz: isti build, dva `SALON_ID`-a, dva screenshota koja se razlikuju po imenu, bojama **i** terminologiji
- [ ] Web build iste rute radi i ima ispravan URL

## Koraci
1. Ekran čita `salonProvider`, `servicesProvider`, `employeesProvider`, `verticalProvider` — bez direktnog poziva repozitorija
2. Složi layout po prototipu (`src/app/pages/LandingPage.tsx`) koristeći komponente iz `core_ui`, ne nove ad-hoc widgete
3. Prazno/greška/učitavanje prije nego što se "završi" sretan slučaj
4. Napravi screenshotove za oba tenanta i zakači ih u status blok taska
5. Commit: `feat(client): home ekran sa runtime brandingom i vertikalnom terminologijom`

## Zamke
- Prototip u `src/` je referenca za flow i vizual, **ne izvor komponenti**. Ne prevodi Tailwind klase jedan-na-jedan; koristi tokene iz `core_ui`.
- Ovo je prvi ekran, pa postaje šablon koji će se kopirati. Šta god ovdje bude prečica — literal boja, literal string, poziv repozitorija iz widgeta — bit će ponovljeno petnaest puta.
