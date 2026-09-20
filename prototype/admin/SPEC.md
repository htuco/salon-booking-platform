# Salon OS admin — handoff specifikacija

## Status i opseg

Ovo je vizuelna specifikacija za generičku admin aplikaciju iz `apps/admin`. Statični canvas
prikazuje ciljano stanje proizvoda; produkcijski podaci, autorizacija, validacija termina i tenant
izolacija ostaju definisani u aplikaciji, `core_api` ugovorima, migracijama i RLS pravilima.

Canvas ima dvije ciljne širine:

- **desktop:** 1440×900, stalni tamni sidebar i sadržaj u radnoj površini;
- **telefon:** 402×874, četiri glavne navigacijske ćelije i ekrani prilagođeni dodiru.

Tablet nije posebno nacrtan. Implementacija mora mijenjati raspored na breakpointu, ne samo
smanjivati desktop prikaz.

## Mapa prikaza

### Desktop

| ID | Prikaz | Veza sa `apps/admin` |
|---|---|---|
| `3a` | Pregled mreže — svi saloni | Budući multi-location/platform scope; ne otkrivati bez posebne uloge i RLS-a. |
| `3b` | Lokacija — Danas | Ciljni izgled postojećeg `/dashboard` ekrana. |
| `3c` | Kalendar dana | Cilj za `/calendar`; ruta je trenutno placeholder. |
| `3d` | Zahtjevi za potvrdu | Ciljni pending prikaz unutar postojećih termina. |
| `3e` | Klijenti i profil | Novi modul; repozitorij i ruta još nisu izdvojeni u admin app. |
| `3f` | Usluge i cjenovnik | Cilj za `/services`; ruta je trenutno placeholder. |
| `3g` | Osoblje i smjene | Cilj za `/employees`; ruta je trenutno placeholder. |
| `3h` | Radno vrijeme i pauze | Cilj za `/working-hours`; ruta je trenutno placeholder. |
| `3i` | Postavke lokacije | Cilj za `/settings`; ruta je trenutno placeholder. |
| `3j` | Prijava | Vizuelni cilj za postojeći `/login`; auth ostaje Supabase email+password. |

### Telefon

| ID | Prikaz | Veza sa `apps/admin` |
|---|---|---|
| `3k` | Danas | Mobilni oblik dashboarda. |
| `3l` | Kalendar | Mobilni oblik kalendara. |
| `3m` | Zahtjevi | Pending lista i potvrda/odbijanje. |
| `3n` | Detalj termina | Detalj i postojeće akcije nad terminom. |
| `3o` | Klijenti | Mobilna lista klijenata. |
| `3p` | Usluge | Mobilna lista usluga. |
| `3q` | Uredi uslugu | Bottom sheet za unos/izmjenu usluge. |
| `3r` | Osoblje i smjene | Mobilno upravljanje osobljem. |
| `3s` | Radno vrijeme | Mobilno radno vrijeme, pauze i neradni dani. |
| `3t` | Još / postavke | Ulazi u module izvan četiri glavne navigacijske ćelije. |
| `3u` | Prijava | Mobilni oblik istog admin auth toka. |

## Vizuelni sistem

### Tipografija

- **Space Grotesk** 400/500/600/700: naslov, tijelo, dugmad i navigacija.
- **JetBrains Mono** 400/500/600: datumi, vrijeme, brojčane metrike, statusne oznake i eyebrow
  labele.
- Design canvas ih učitava sa Google Fonts. Flutter implementacija treba lokalno zapakovane fontove
  kako izgled aplikacije ne bi zavisio od mreže.

**Dvije ispravke izmjerene iz `canvas/Salon OS Admin.dc.html` pri implementaciji (task 28).** Gornja
rečenica o moni je prepisana iz ranije skice `canvas/Smjer C - Space Grotesk.dc.html`; finalni
canvas je crta uže:

- **Velika brojka nije mono.** Mono se nigdje ne crta iznad 15 px. Brojevi u karticama metrika
  (`14`, `71%`, `265 KM`) su Space Grotesk 700, 24–38 px. Mono je pismo *inline podatka* — `13:00`,
  `82%`, `26 MIN`, `15 KM`, broj telefona.
- **Statusna oznaka nije mono.** Pilula je `font:500 12.5px 'Space Grotesk'` malim slovima
  („Potvrđeno"), `border-radius:20px`, `padding:4px 11px`. Verzalna mono oznaka postoji samo u
  skici.

### Osnovni tokeni

Od septembra 2026. aplikacija koristi dostavljenu OKLCH paletu. Ispod su njeni sRGB ekvivalenti;
izvorne OKLCH vrijednosti ostaju dizajnerski izvor istine.

| Uloga | Svijetla | Tamna |
|---|---|---|
| Glavni tekst | `#2C2C2C` | `#DCDCDC` |
| Radna pozadina | `#FCFCF9` | `#1A1B1E` |
| Površina kartice | `#FFFFFF` | `#25262B` |
| Primarni akcent | `#3D5A80` | `#91A7FF` |
| Radnja (coral) | `#EE6C4D` | `#FF9776` |
| Tekst na radnji | `#2C2C2C` | `#1A1B1E` |
| Primarni obrub | `#E2E2E2` | `#373A40` |
| Sekundarni tekst | `#666666` | `#909296` |
| Sidebar | `#F8F9FA` | `#141517` |
| Destruktivni tekst | `#C94C4C` | `#F03E3E` |
| Osnovni radius | `6px` | `6px` |

Vrijednosti prvo centralizovati u `apps/admin/lib/src/core/theme/`; ne ponavljati hex vrijednosti
po ekranima. Admin akcent je platformski, nije tenant boja.

Paleta se u Flutteru čuva kao semantički `ThemeExtension`; prilagođeni widgeti ne smiju čitati
statične light vrijednosti jer tada ne bi pratili sistemski dark mode.

**Coral (`--secondary`) nosi glavnu radnju** — ispunjeno dugme (`+ Novi termin`, `Potvrdi`,
`Prijava`) i oznaku „Na čekanju". Primarni akcent ostaje na selekciji, aktivnoj stavci sidebara i
podacima. Boju dugmeta odlučuje `filledButtonTheme`; ekran je ne prepisuje kod sebe.

Tri korekcije izvornog para, sve zbog WCAG AA:

| Gdje | CSS daje | Implementacija | Zašto |
|---|---|---|---|
| Tekst na coralu | `#FFFFFF` | `#2C2C2C` | bijela na `#EE6C4D` = 3,05:1 |
| Tekst na tamnom destruktivnom | `#FFFFFF` | `#141517` | bijela na `#F03E3E` = 3,84:1 |
| Tamni coral | `#FFA8A8` (roza, `h=19.5`) | `#FF9776` | drugi ton, ne svjetliji coral; zadržana CSS svjetlina `L=0.8169`, uzeti ton i zasićenje corala |

### Raspored i komponente

- Desktop koristi sidebar od približno 236 px, top bar od 60–66 px i kartice na svijetloj radnoj
  površini. **Horizontalni gutter radne površine je 28 px** (izmjereno u tasku 29: `padding:28px`
  u svih sedam desktop prikaza u opsegu i `padding:0 28px` u top barovima; `padding:24px` se ne
  javlja nijednom). 24 u handoffu postoji, ali kao razmak između sekcija.
- Mobilni prikazi koriste 20 px horizontalni gutter, velike touch mete i donju navigaciju:
  **Danas · Kalendar · Zahtjevi · Još**.

**Sastav navigacije, izmjeren u tasku 29.** Sidebar (`3b`) nosi **osam** stavki — Danas, Kalendar,
Zahtjevi, Klijenti, Usluge, Osoblje, Radno vrijeme, Postavke — a donja navigacija (`3k`, `3t`)
**četiri**. Posljedica koju tabela prikaza ne pokazuje: **puna lista termina nema svoju ćeliju ni u
jednoj navigaciji**. „Zahtjevi" su zato filtrirana ista lista (`/appointments?status=pending`), a ne
zaseban ekran; zasebna ruta bi punu listu ostavila bez ijednog ulaza iz navigacije. Uz „Zahtjeve"
obje ljuske crtaju brojač, pa je i on dio ljuske, ne ekrana.
- Statusi moraju imati tekstualnu oznaku; boja nije jedini nosač značenja.
- Tabele na uskim širinama prelaze u kartice/liste. Horizontalno skalirani desktop nije prihvatljiv
  mobilni layout.
- Fotografije u `canvas/assets/` su placeholderi. Ne ulaze automatski u produkcijski bundle.

## Funkcionalne granice

- `3a` prikazuje više lokacija, ali trenutni Vitez demo admin dobija tačno jedan salon iz
  membershipa. Taj ekran je buduća funkcija, ne dozvola za client-side izbor proizvoljnog salona.
- Prototip prikazuje stanja i namjeravane akcije, ali ne zamjenjuje postojeće RPC tokove za potvrdu,
  odbijanje, otkazivanje, no-show i ručno kreiranje termina.
- Social login se ne dodaje adminu. Prijava ostaje email+password i običan klijentski nalog ne
  smije proći admin guard.
- Tekstovi i primjeri u canvasu su demo sadržaj. Tajne, stvarne lozinke i administratorski tokeni
  ne pripadaju ni prototipu ni screenshotovima.

### Šta canvas crta, a aplikacija namjerno nema (izmjereno u tasku 30)

Handoff crta i kontrole i brojke iza kojih danas ne stoji ni podatak ni RPC putanja. Svaka od njih
je **izostavljena, ne odgođena na ekranu**: dugme koje ne radi i brojka koja se računa po pogrešnom
modelu su gori od praznog mjesta, jer vlasnik po njima odlučuje.

| Iz canvasa | Zašto ne | Gdje se vraća |
|---|---|---|
| „Prijava kodom na telefon" (`3j`), „Face ID" (`3u`) | Prijava ostaje email + lozinka, v. gore | — |
| „Zaboravljena?" (`3j`, `3u`) | Reset lozinke je tok sa svojom rutom (mail → link → nova lozinka) | otvoreno |
| „Ostani prijavljen" (`3j`, `3u`) | `supabase_flutter` sesiju čuva uvijek; kvačica ne bi mijenjala ništa | — |
| „Trenutno na platformi: 6 lokacija · 19 majstora" (`3j`) | Zbir preko **svih** salona; `salon_admin` ga po RLS-u ne smije vidjeti, a ekran prijave ga traži neprijavljen | `3a` |
| Kartica „Slobodno vrijeme" (`3b`), „82%" zauzetosti (`3b`) | Traže kapacitet, tj. smjenu radnika | task 33 |
| „Otvoreno do 20:00" (`3b`) | Traži radno vrijeme salona | task 34 |
| „Pretraži klijenta" (`3b`), „Profil", „Zadnji dolasci", „12 dolazaka" (`3d`, `3n`) | Traže modul klijenata | task 35 |
| „najstariji prije 26 min" (`3b`), „prosjek odgovora 8 min" (`3m`), „Zakazano 16.05." (`3n`) | `appointments` nema `created_at` | otvoreno |
| „Preklapa se s pauzom Amara" (`3d`, `3m`) | Pauze i blokade ne postoje kao podatak | task 34 |
| „Ponudi drugo vrijeme" (`3d`), „Pomjeri" (`3n`) | Nema RPC putanje za pomjeranje termina; `set_appointment_status` mijenja status, ne vrijeme | otvoreno |
| „Pozovi" / „Poruka" (`3n`) | `tel:`/`sms:` traže `url_launcher`, koji nije zavisnost admina | otvoreno |
| Fotografije klijenata i lokacije | Placeholderi iz `canvas/assets/`; `customers` i `public.users` nemaju sliku | — |

Uz to su dvije rečenice copy-ja promijenjene jer tvrde ono što proizvod nema: podnaslov prijave
„Jedan račun za sve vaše lokacije." (admin dobija tačno jedan salon iz membershipa) i naslov
dashboarda „Pregled", koji navigacija zove „Danas".

**Detalj termina je puni ekran, ne bottom sheet.** `docs/01 §12` ga je tako zvala prije handoffa;
`3n` crta ekran sa vlastitim zaglavljem i trakom radnji u dnu, a i adresa mora raditi iz bookmarka.

## Redoslijed implementacije

1. Centralizovati admin temu i fontove.
2. Prevesti postojeće `/login`, `/dashboard` i `/appointments` ekrane na handoff bez promjene
   provjerenih auth/RLS tokova.
3. Uvesti responsive shell: desktop sidebar i mobilnu donju navigaciju iz istog route modela.
4. Implementirati kalendar, zatim klijente, usluge, osoblje, radno vrijeme i postavke uz zasebne
   ugovore i testove.
5. `3a` raditi tek kada platforma dobije definisan multi-location RBAC i serversku autorizaciju.
