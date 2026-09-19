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

| Uloga | Vrijednost iz handoffa |
|---|---|
| Glavni tekst / tamni sidebar | `#14181B` |
| Radna pozadina | `#F4F6F7` |
| Površina kartice | `#FFFFFF` |
| Primarni akcent | `#3D6D9E` |
| Sekundarni akcent | `#5980A6` |
| Primarni obrub | `#D5DBDF` |
| Suptilni separator | `#E6EAEC` |
| Sekundarni tekst | `#5B656B` / `#6B757B` |
| Destruktivni tekst | `#9C432F` |
| Osnovni radius | `6px` |

Vrijednosti prvo centralizovati u `apps/admin/lib/src/core/theme/`; ne ponavljati hex vrijednosti
po ekranima. Admin akcent je platformski, nije tenant boja.

**Tri nalaza iz mjerenja canvasa i kontrasta (task 28)**, da se tabela ne čita doslovnije nego što
crtež dopušta:

- **Sekundarni akcent `#5980A6` finalni canvas ne koristi nijednom** — ostao je iz skice `Smjer C`.
  Bijeli tekst na njemu mjeri 4,15:1, crni 4,30:1; nije podloga za tekst, samo obrub ili ispuna
  trake. Emfazu akcenta u canvasu nosi `#27496B` na tinti `#EAF1F8`.
- **„Sekundarni tekst" su dvije uloge, ne jedan izbor.** Canvas crta `#5B656B` na tekstu tijela
  (13,5–15 px) i `#6B757B` na sitnoj labeli i mono eyebrow-u (10,5–13 px).
- **`#6B757B` se smije koristiti samo na bijeloj kartici.** Na radnoj pozadini `#F4F6F7` mjeri
  4,35:1 i pada WCAG AA. Isto vrijedi za par oznake „Završeno" iz canvasa (`#6B757B` na `#EEF1F3`,
  4,15:1) — u implementaciji je tekst spušten na `#5B656B` (5,26:1).

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

## Redoslijed implementacije

1. Centralizovati admin temu i fontove.
2. Prevesti postojeće `/login`, `/dashboard` i `/appointments` ekrane na handoff bez promjene
   provjerenih auth/RLS tokova.
3. Uvesti responsive shell: desktop sidebar i mobilnu donju navigaciju iz istog route modela.
4. Implementirati kalendar, zatim klijente, usluge, osoblje, radno vrijeme i postavke uz zasebne
   ugovore i testove.
5. `3a` raditi tek kada platforma dobije definisan multi-location RBAC i serversku autorizaciju.
