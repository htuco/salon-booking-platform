# Sedmica — skica za task 69

Sedmični prikaz kalendara u Meluri (`7a` desktop, `7c` tablet, `7b` telefon). Ovo nije dizajnerski
handoff nego **skica iz taska**, jer u `adminv2/export/` sedmice nema (`3c` crta samo prekidač).
Oblik se naslanja na `3c` (mreža dana) i `3l` (lista na telefonu), pa za sve što ovdje nije rečeno
važe oni.

- `index.html` — skica, otvara se preko lokalnog servera (`python3 -m http.server` u ovom
  folderu), jer browser blokira `file:`. Klik na čip radnika filtrira, a promjena širine prozora
  prelazi 1440 → 1024 → 402. Podaci su izmišljeni.
- `screenshots/7a-sedmica-1440.png`, `7c-sedmica-1024.png`, `7b-sedmica-402.png`,
  `7b-sedmica-402-odsutni.png` (utorak i srijeda: red odsutnih i blokada u listi)

**Iz skice se uzimaju raspored i pravila, ne boja.** Boje termina dolaze iz admin teme, kao u
dnevnom prikazu; boje radnika iz `AdminPalette.radnici`.

## Odluke (Hamza, 2026-10-16)

1. **Radnik = profilna slika, a bez nje krug sa inicijalima na boji radnika.** Boja se ne bira:
   `bojeRadnika` je dodjeljuje iz id-a radnika, stabilno na svim uređajima, i dok ima boja dva
   radnika je ne dijele. Inicijali su dva slova (`inicijaliOd`: Emir Bešić → EB, Edin Mujić → EM),
   pa se radnici na isto slovo razlikuju i bez boje.
2. **Tekst neradnog je isti kao u danu**: „Ne radi", „Ne radi do 09:00", „Ne radi od 15:00".
3. **Tablet je nacrtan** (`7c`, 1024 u landscapeu). iPad u portretu je ispod 840 i dobija
   telefonski raspored (`AdminBreakpoint.desktop`).
4. **Uz „Svi" se odsutnost radnika kaže u zaglavlju dana**, a ne crta u koloni (v. Pravila).

## Pravila

| | |
|---|---|
| Ulaz | „Sedmica" u postojećem prekidaču `Dan · Sedmica · Mjesec`. „Mjesec" ostaje ugašen i uz sebe piše „Uskoro" (ne samo tooltip — tablet nema hover). Kad top bar nema mjesta (tablet, uvećan font), onemogućeni „Mjesec" se sklanja prvi. Okvir prekidača je 36 px, dodirna meta 44 |
| Kolone | 7 dana, ponedjeljak–nedjelja, sedmica u kojoj je izabrani datum. Strelice idu za sedmicu, „Ova sedmica" vraća na tekuću i **nestaje kad se tekuća već gleda** (kao „Danas" u danu) |
| Radnici | **Svi u istoj koloni dana** (odluka 2026-10-14). Svaki termin nosi avatar radnika (slika ili inicijali na boji); čipovi `Svi · Emir · …` filtriraju i nose isti avatar. Radnik vidi samo svoje, bez čipova |
| Zaglavlje dana | Dan, datum, radno vrijeme salona i broj termina. Danas je istaknut (i čitaču ekrana se kaže „danas"). **Tap na zaglavlje otvara taj dan** u prikazu „Dan". Podnaslov je u jednom redu samo kad stane cijeli u svakoj koloni — mjeri se tekst, ne prag; na 1440 (kolona ~161 px) je to obično dva reda, jer `09:00–20:00 · 0 termina` traži ~150 px |
| Odsutni (uz „Svi") | Ispod podnaslova, red po radniku: „Edin ne radi" (nema smjene ili je dan zatvoren), pa „Vedad 12:00–13:00 · Doktor" (radnikova blokada), po vremenu. Avatar je prigušen. Tekst se reže sa „…", pun je u tooltipu. Nema ga kad salon taj dan ne radi ni kad je filtriran radnik — tada je sve već u koloni. Model: `DanSedmice.odsutni` |
| Vremenska osa | Od najranijeg početka do najkasnijeg kraja radnog vremena u toj sedmici, ne fiksno |
| Termin | Avatar + početak + ime klijenta. Status kao u danu: potvrđen, čeka potvrdu (isprekidan rub, FE-403), završen, u toku |
| Preklapanje | Jedan pored drugog, kao u danu. **Sadržaj bira izmjereni prostor**, ne broj traka: vrijeme se izmjeri u stilu i fontu u kojem se crta, pa ide avatar + vrijeme (+ ime ako ima mjesta), avatar iznad vremena, ili samo avatar. **Vrijeme se nikad ne reže** — „10" umjesto „10:30" je pogrešno vrijeme. U Barlowu je granica za avatar + vrijeme oko 64 px širine bloka. Ime je uvijek u tooltipu i detalju. Termin kraći od ~40 px staje u jedan red |
| Tablet (840–1279) | Ista mreža od 7 kolona, **bez vodoravnog skrola**: na 1024 je kolona ~102 px (sidebar je 236), pa blok skraćuje sadržaj po pravilu iznad. Podnaslov zaglavlja ide u dva reda (radno vrijeme / broj termina), legenda u svoj red ispod čipova |
| Neradno | Neradni dan je šrafirana cijela kolona („Ne radi"). Prije otvaranja i poslije zatvaranja je šrafirano („Ne radi do …", „Ne radi od …"). Salonska blokada je šrafirana sa svojim tekstom; radnikova blokada se u koloni crta samo kad je filtriran taj radnik, a uz „Svi" je red odsutnih. **Natpis se u koloni lomi u onoliko redova koliko pojas primi, a ne reže**; vrijeme blokade se u sedmici ne piše (čita se sa ose), razlog je važniji. Termin koji pada u salonsku blokadu crta se preko nje i može joj prekriti natpis — tada je razlog u tooltipu i za čitač ekrana |
| Radnik duže od salona | Uz „Svi" kolona crta salonsko radno vrijeme, pa termin radnika poslije zatvaranja salona stoji preko šrafure „Ne radi od …". To je namjerno: termin se ne smije sakriti, a filtriran radnik dobija svoju smjenu |
| Sada | Crvena linija samo u koloni današnjeg dana |
| Tap | Termin otvara **isti detalj** kao dnevni prikaz. Prazno mjesto nudi ručno zakazivanje za taj dan i vrijeme (zaokruženo na 30 min) — **samo za danas i dalje**; dan prije danas i šrafura ne nude ništa. Forma vrijeme izabere tek ako ga baza vrati među slobodnima |
| Telefon (< 840) | Podrazumijevano je „Dan" (`3l`). „Sedmica" je **lista po danima**: zaglavlje dana, red odsutnih, pa termini i blokade po vremenu sa avatarom radnika. Neradni dan je jedan red. Mreža od 7 kolona se ne stiska na 402 px (`SPEC.md`) |
| Prazno | Sedmica bez termina i dalje crta kolone i radno vrijeme; na telefonu sedmica bez ijednog termina kaže „Nema termina ove sedmice" — i kad salon ima dnevnu pauzu (pauza nije termin) |
