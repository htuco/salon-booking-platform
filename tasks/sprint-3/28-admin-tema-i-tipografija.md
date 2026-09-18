# Task 28 — Admin tema, tipografija i tokeni

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | [23](../sprint-2/23-admin-login-i-lista.md) |
| **Blokira** | 29, 30 — i svaki naredni ekran |
| **Reference** | [`prototype/admin/SPEC.md`](../../prototype/admin/SPEC.md) · [`prototype/admin/README.md`](../../prototype/admin/README.md) |

## Cilj
Jedno mjesto sa bojama, tipografijom, razmacima i radiusom admina. Dok ga nema, svaki sljedeći
ekran prepisuje hex iz handoffa i nema ga gdje promijeniti.

## Definicija gotovog
- [x] `apps/admin/lib/src/core/theme/` nosi tokene iz `SPEC.md` — danas ima samo `.gitkeep`
- [x] **Space Grotesk** (400/500/600/700) i **JetBrains Mono** (400/500/600) su **lokalno
      zapakovani**, ne sa Google Fonts: izgled admina ne smije zavisiti od mreže
- [x] JetBrains Mono nosi datume, vrijeme, brojčane metrike i statusne oznake; Space Grotesk sve
      ostalo — **uz dvije ispravke izmjerene iz canvasa**: velika brojka i statusna pilula nisu
      mono (v. status blok)
- [x] `main.dart` više ne gradi temu iz `ColorScheme.fromSeed(Color(0xFF171717))`
- [x] Nijedan admin ekran nema hardkodiran hex — provjereno `grep`-om, ne pogledom
- [x] Test koji pada ako boja procuri nazad u ekran

## Koraci
1. Tokeni i `ThemeData` u `core/theme/`, po tabeli iz `SPEC.md`
2. Fontovi u `assets/fonts/` + `pubspec.yaml`
3. Postojeća četiri ekrana prelaze na temu, bez promjene ponašanja
4. Commit: `feat(admin): centralizuj temu, tipografiju i tokene`

## Zamke
- **Admin nema `core_ui`.** `core_ui` je klijentska tema koja boju uzima iz `tenant.yaml`. Admin je
  jedan build za sve salone i njegova plava je identitet Salon OS-a. Uvoz `core_ui` u admin prolazi
  analizu, prolazi test, i vidi se tek kad dva salona otvore istu aplikaciju.
- **Radius je `6px`, ne `0`.** Klijentska app ima radius 0 iz `prototype/ui/`; to je drugi proizvod
  i drugi handoff. Prepisivanje navike iz `core_ui` je ovdje greška.
- Statusna oznaka mora nositi **tekst**, ne samo boju (`SPEC.md`, „Raspored i komponente").

## Status (2026-09-19) — 🟡 kod gotov, ekranski dokaz djelimičan

Admin je prvi put dobio vlastiti dizajn sistem. `apps/admin/lib/src/core/theme/` nosi pet fajlova:
paleta (`admin_colors.dart` — **jedino mjesto sa heksom u `apps/admin`**), razmaci i uglovi
(`admin_tokens.dart`), tipografija (`admin_typography.dart`), statusni tonovi kao `ThemeExtension`
(`admin_status_colors.dart`) i `buildAdminTheme()` (`admin_theme.dart`).

### Odluke koje se ne vide iz koda

- **Admin ne dobija `core_ui`, i to više nije dogovor nego test.** `core_ui` gradi temu iz *tenant*
  boja; da ga admin uveze, sidebar bi promijenio boju kad se prijavi drugi vlasnik — prolazi
  analizu, prolazi test, vidi se tek kad dva salona otvore istu aplikaciju.
  `no_hardcoded_colors_test.dart` pada na uvoz i na zavisnost u `pubspec.yaml`-u.
- **Kontrast se mjeri u testu, ne računa u runtime-u.** To je cijela razlika od `core_ui`: tamo je
  brand boja **ulaz** koji vlasnik bira i koji niko ne vidi prije builda, pa postoji
  `contrast.dart`. Ovdje su boje konstante, pa admin namjerno **nema** svoj `contrast.dart` u
  `lib/` — funkcija koja se poziva samo iz testa nije produkcijski kod.
- **Radius je 6, ne 0.** `AppRadius.none` je klijentsko pravilo iz `prototype/ui/`. Test to tvrdi
  brojem, jer je to najlakša greška iz navike.

### Šta je mjerenje canvasa oborilo

Sve tri stvari su vraćene u `prototype/admin/SPEC.md`, da ih naredni task ne otvara ponovo:

- **Velika brojka nije mono.** JetBrains Mono se u finalnom canvasu ne crta nigdje iznad 15 px;
  metrike (`14`, `71%`, `265 KM`) su Space Grotesk 700, 24–38 px.
- **Statusna pilula nije mono.** Canvas: `font:500 12.5px 'Space Grotesk'`, malim slovima
  („Potvrđeno"). Verzalna mono oznaka postoji samo u ranijoj skici `Smjer C - Space Grotesk.dc.html`,
  iz koje je i rečenica u `SPEC.md` prepisana.
- **Sekundarni akcent `#5980A6` finalni canvas ne koristi nijednom** (`grep -oi '#5980a6'` → 0).
  Bijeli tekst na njemu je 4,15:1, crni 4,30:1 — nije podloga za tekst. Token stoji jer ga `SPEC.md`
  nabraja, ali **nije u `ColorScheme`-u**, i test pada ako ga neko ubaci.

Uz to: „sekundarni tekst" u SPEC tabeli ima dvije vrijednosti i tabela ne kaže koja je koja. Podjela
je izmjerena, ne izabrana — `#5B656B` na tekstu tijela (59 pojava na 14 px), `#6B757B` na sitnoj
labeli.

### Dva para iz handoffa koja padaju AA

`#6B757B` na radnoj pozadini `#F4F6F7` mjeri **4,35:1**, a oznaka „Završeno" (`#6B757B` na
`#EEF1F3`) **4,15:1**. Oba su ispravljena spuštanjem teksta na `#5B656B` (5,50:1 odnosno 5,26:1).
`theme_contrast_test.dart` drži i **tvrdnju da ti parovi padaju** — da se vrijednost ne vrati „nazad
na handoff" bez razloga i bez traga.

### Dokazano

- **567 Dart testova PASS** u pet paketa, od toga `admin` **70** (bilo 16; ostali paketi su rasli
  kroz taskove 24–27, ne kroz ovaj); čista `melos run analyze` svuda.
- **Login ekran u Chromiumu**, 1440×900 i 402×874, iz stvarnog `flutter build web` bundlea:
  `docs/screenshots/task-28-admin-login-desktop.png` i `-mobile.png`.
- **Fontovi stvarno dolaze iz bundlea**, ne sa mreže — mrežni log pokazuje
  `assets/assets/fonts/SpaceGrotesk[wght].ttf` i `JetBrainsMono[wght].ttf` sa lokalnog servera, i
  nijedan zahtjev ka `fonts.googleapis.com`. (CanvasKit i dalje povlači vlastiti Roboto fallback sa
  `gstatic.com`; to je ponašanje web engine-a, ne naša tipografija, i na Androidu/iOS-u ga nema.)
- **`wght` ose provjerene iz samih fajlova** (`fvar`): Space Grotesk 300–700 sa **defaultom 300**,
  JetBrains Mono 100–800. Zato svaki stil postavlja `FontVariation`, a ne samo `fontWeight` — bez
  toga bi cijeli admin bio tanji od handoffa, ujednačeno, pa bi izgledao kao izbor a ne kao greška.
- **Provjereno da novi testovi mogu pasti:** heks ubačen u ekran obori `no_hardcoded_colors_test`,
  `onSurfaceVariant` spušten na `textMuted` obori `theme_contrast_test`, uklonjen `FontVariation`
  obori `theme_tokens_test`, a statusni ton vraćen na `primaryContainer` obori tri od četiri
  tvrdnje u `appointment_tile_theme_test`. Sve vraćeno.

### Ostalo za sljedećeg

- **Dashboard, lista termina i ručni unos nisu viđeni na ekranu** — samo kroz widget testove. Na
  ovoj mašini nema ni Dockera ni `supabase` CLI-ja, pa se lokalni stack ne može dići. Kad postoji:
  `supabase start`, pa `flutter run -d chrome` i prijava, pa `/dashboard` i `/appointments`.
- **Copy statusa je i dalje u množini** („Potvrđeni"), jer isti string služi i kao labela filtera;
  canvas piše „Potvrđeno". To je promjena teksta i pripada tasku
  [30](30-postojeci-ekrani-na-handoff.md).
- **CI još nije zelen** — PR [#49](https://github.com/htuco/salon-booking-platform/pull/49) je
  otvoren kao draft, job „Analiza, format i testovi" je u redu čekanja.
- **`gh` postoji ali nije na PATH-u** (`C:\Program Files\GitHub CLI\gh.exe`); bez ručnog dodavanja
  u PATH izgleda kao da nije instaliran.
