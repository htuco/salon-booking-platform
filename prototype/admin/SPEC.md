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

### Raspored i komponente

- Desktop koristi sidebar od približno 236 px, top bar od 60–66 px i kartice na svijetloj radnoj
  površini.
- Mobilni prikazi koriste 20 px horizontalni gutter, velike touch mete i donju navigaciju:
  **Danas · Kalendar · Zahtjevi · Još**.
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
