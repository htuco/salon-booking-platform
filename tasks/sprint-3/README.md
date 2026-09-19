# Taskovi — Sprint 3: admin aplikacija po handoffu

Nastavak [Sprinta 2](../sprint-2/). Cijeli sprint je **jedna aplikacija**: `apps/admin` prestaje
biti četiri ekrana i placeholder rute i postaje alatka kojom salon vodi dan.

Izvor istine je [`prototype/admin/SPEC.md`](../../prototype/admin/SPEC.md) — 10 desktop prikaza na
1440×900 i 11 mobilnih na 402×874, sa mapom prikaza na rute. Redoslijed ispod prati njegov
odjeljak „Redoslijed implementacije", uz jedno namjerno odstupanje (v. ispod).

| # | Task | Prikazi | Blokira | Procjena |
|---|---|---|---|---|
| [28](28-admin-tema-i-tipografija.md) 🟡 | Admin tema, tipografija i tokeni | svi | 29, 30 | 1 dan |
| [29](29-responsive-shell.md) ✅ | Responsive shell: desktop sidebar + mobilna navigacija | `3b`–`3i`, `3k`–`3t` | 30–36 | 1–2 dana |
| [30](30-postojeci-ekrani-na-handoff.md) | Postojeći ekrani na handoff: prijava, Danas, zahtjevi, termini | `3b` `3d` `3j` `3k` `3m` `3n` `3u` | — | 2–3 dana |
| [31](31-kalendar-dana.md) | Kalendar dana | `3c` `3l` | — | 2–3 dana |
| [32](32-usluge-i-cjenovnik.md) | Usluge i cjenovnik — CRUD | `3f` `3p` `3q` | — | 2–3 dana |
| [33](33-osoblje-i-smjene.md) | Osoblje i smjene — CRUD | `3g` `3r` | 34 | 2–3 dana |
| [34](34-radno-vrijeme-i-blokade.md) | Radno vrijeme, pauze i blokade | `3h` `3s` | — | 2–3 dana |
| [35](35-klijenti-i-profil.md) | Klijenti i profil | `3e` `3o` | — | 1–2 dana |
| [36](36-postavke-lokacije.md) | Postavke lokacije | `3i` `3t` | — | 1–2 dana |

**Ukupno: ~15–22 radna dana.**

## Redoslijed koji nije očigledan

- **29 ide prije 30, obrnuto od `SPEC.md`.** Handoff prvo traži prevod postojećih ekrana, pa onda
  shell. Redoslijed je zamijenjen jer `3b` i `3k` **nisu dva ekrana nego jedan ekran u dvije
  ljuske** — desktop ga crta u radnoj površini pored sidebara, telefon iznad donje navigacije. Ko
  prvo prevede ekran, prevodi ga u ljusku koja se sutra mijenja, pa ga prevodi dvaput.
- **28 je prvi i nije kozmetika.** Dok tokeni nisu na jednom mjestu, svaki naredni ekran ih
  prepisuje. `SPEC.md` to kaže izričito: „Vrijednosti prvo centralizovati u
  `apps/admin/lib/src/core/theme/`; ne ponavljati hex vrijednosti po ekranima." Taj folder je do
  28 imao samo `.gitkeep`, a `main.dart` je temu gradio iz jednog `ColorScheme.fromSeed`.
- **33 prije 34.** Smjena je smjena **radnika**; radno vrijeme koje se piše prije nego osoblje ima
  svoj ekran nema na šta da se veže.
- **32, 33 i 34 nose backend, ne samo ekran.** Danas ne postoji nijedna RPC putanja kojom admin
  piše uslugu, radnika ili radno vrijeme — `docs/01 §17` korak 25 ih broji zajedno. Svaka od te
  tri ide istim redom kao task 24: **migracija i pgTAP prije ekrana**.
- **35 i 36 su zadnji jer ništa ne blokiraju.** Ako sprint pukne, pucaju oni, a admin i dalje vodi
  dan.

## Granice koje handoff izričito postavlja

- **`3a` (pregled mreže, svi saloni) nije u ovom sprintu.** Traži multi-location RBAC i serversku
  autorizaciju kojih nema. Prikaz u prototipu **nije dozvola** za client-side izbor salona; salon i
  ovlasti i dalje dolaze iz membershipa i RLS-a (`ADR-0003`).
- **Admin nije brandiran.** Plava je identitet Salon OS-a, ne boja salona. Ne uvozi se klijentska
  `core_ui` tema niti bilo šta iz `tenant.yaml` — to je obrnuto od pravila koje vrijedi za
  `apps/client`, i najlakše se prekrši navikom.
- **Prototip ne zamjenjuje postojeće RPC tokove.** Potvrda, odbijanje, otkazivanje, `no_show` i
  ručni termin rade od taska 24 i ostaju kakvi jesu; mijenja im se izgled, ne putanja.
- **Tablet nije nacrtan.** Raspored se mijenja na breakpointu, a ne skaliranjem desktopa.

## Šta ovaj sprint **ne** zatvara

`docs/01 §17` pod Sprint 3 broji još i ovo — ostaje otvoreno i ne gubi se:

- **Super admin web konzola** (Next.js, `docs/07`) — drugi proizvod, drugi toolchain.
- **Podsjetnici D-1 / H-3** — traže scheduler nad `notification_logs` iz taska 25.
- **Web build klijentske app-e + QR**, **javna URL politike privatnosti**, **prvi Play
  submission**, **demo pravom salonu**.

Iz Sprinta 2 ostaju 🟡 stavke koje **ne zavise od koda** nego od tuđih naloga: deploy šeme na
hostovani Supabase, FCM na fizičkom uređaju, Apple i Google konzole. One ne blokiraju nijedan task
ovdje — admin se razvija protiv lokalnog stacka.

## Status

> **28 — Admin tema, tipografija i tokeni (🟡, 2026-09-19).** `apps/admin/lib/src/core/theme/` je
> prestao biti `.gitkeep`: pet fajlova nose paletu, razmake, uglove, tipografiju i statusne tonove,
> a `main.dart` više ne gradi temu iz `ColorScheme.fromSeed`. Space Grotesk i JetBrains Mono su
> **zapakovani u repo** uz OFL licence; browser potvrđuje da se učitavaju iz bundlea, ne sa Google
> Fonts.
>
> **Mjerenje canvasa je oborilo tri stvari koje `SPEC.md` tvrdi**, i sve tri su zapisane nazad u
> `SPEC.md`: velika brojka i statusna pilula **nisu** mono (to je iz skice `Smjer C`, finalni canvas
> ih crta u Space Grotesku), a sekundarni akcent `#5980A6` finalni canvas **ne koristi nijednom**.
> Uz to, dvije vrijednosti za „sekundarni tekst" nisu izbor nego dvije uloge, razdvojene po
> veličini teksta.
>
> **Dva para iz handoffa padaju WCAG AA i nisu prepisana doslovno:** `#6B757B` na radnoj pozadini
> mjeri 4,35:1, a oznaka „Završeno" (`#6B757B` na `#EEF1F3`) 4,15:1 — tekst je spušten na `#5B656B`
> (5,26:1). Razlika je jedna nijansa sive; pad ispod praga se vidi tek kome smeta. `theme_contrast_test.dart`
> drži i tvrdnju da ti parovi **padaju**, da se „vraćanje na handoff" ne desi nečujno.
>
> Dokazano lokalno: **567 Dart testova** u pet paketa, od toga `admin` **70** (bilo 16 — ostali
> paketi su rasli kroz taskove 24–27, ne kroz ovaj), čista analiza svuda, i **login ekran u Chromiumu na 1440×900 i 402×874** —
> `docs/screenshots/task-28-admin-login-*.png`. Provjereno da novi testovi **mogu pasti**: heks
> ubačen u ekran, `onSurfaceVariant` spušten na `textMuted`, uklonjen `FontVariation`, i statusni
> ton vraćen na `primaryContainer` — svaki put padne tačno onaj test koji to pokriva.
>
> **Ostalo za sljedećeg:** dashboard, lista termina i ručni unos su prošli samo kroz widget testove
> — na ekranu nisu, jer na ovoj mašini nema ni Dockera ni `supabase` CLI-ja, pa se lokalni stack ne
> može dići (`supabase start` → komanda ne postoji). Kad stack postoji, dokaz je prijava pa
> `/dashboard` i `/appointments` u browseru.
>
> **Zatvoreno:** PR [#49](https://github.com/htuco/salon-booking-platform/pull/49) je spojen u
> `main` (`61da040`), job „Analiza, format i testovi" zelen i na PR-u i nad merge commitom.
> Ostaje 🟡 samo zbog dokaza na ekranu koji čeka Docker, ne zbog koda.
>
> Sljedeći task je [29](29-responsive-shell.md); mjere ljuske (sidebar 236, top bar 66, gutter 20)
> već stoje u `AdminSize`/`AdminSpacing` da ih ne prepisuje kod sebe.

> **29 — Responsive shell (✅, 2026-09-19).** `AdminScaffold` na 1440 crta tamni sidebar od 236 px
> i top bar od 66, na 402 četiri ćelije; prelaz na **840**, jer canvas taj broj ne daje a tablet
> „nije posebno nacrtan". Obje ljuske čitaju `kAdminDestinations` — prve tri su ćelije telefona,
> ostalih pet rep iste liste iza „Još".
>
> **Mjerenje canvasa je oborilo token iz taska 28:** `AdminSpacing.gutterDesktop` je bio 24, a
> canvas crta **28** — `padding:28px` u svih sedam desktop prikaza u opsegu, `padding:24px`
> nijednom.
>
> **Handoff nema ćeliju „Termini"**, pa „Zahtjevi" vode na `/appointments?status=pending`, a ne na
> vlastitu rutu — zasebna ruta bi punu listu ostavila bez ijednog ulaza iz navigacije. Time je
> popravljena i web greška: kartica na dashboardu je mijenjala stanje providera pa navigirala, pa
> su refresh i „nazad" vraćali nefiltriranu listu. Dodane `/clients` i `/more`, i upisane u
> `docs/01 §12`.
>
> **Ranija odluka je svjesno obrnuta** i tako zapisana: „ćelija koja vodi na placeholder je gora od
> ćelije koje nema" više ne vrijedi, jer `3b` crta svih osam modula.
>
> **Greška koju je našao browser, a testovi nisu mogli:** `AdminPlaceholderScreen` je imao vlastiti
> `Scaffold`, pa je `/clients` otvoren iz „Još" bio slijepa ulica bez ikakve navigacije. Widget test
> to ne vidi jer diže jedan ekran, a ovo je svojstvo prelaza između dva. **Usput ispravljen i jedan
> bezvrijedan test** — provjera guttera je poredila token sam sa sobom i prolazila nad pogrešnom
> vrijednošću.
>
> Dokazano: **85 admin testova** (bilo 70), 582 ukupno, čista analiza; svaki novi test provjeren da
> **može pasti**; uživo u Chromiumu na obje širine, uključujući refresh na
> `/appointments?status=pending` — `docs/screenshots/task-29-admin-*.png`.
>
> **Ostalo za sljedećeg:** snimci su iz novog `apps/admin/lib/demo_main.dart`, ne iz prave prijave —
> nema Dockera ni `supabase` CLI-ja. Hostovani projekat iz `.env.live` **sada ima šemu**
> (`/rest/v1/salons` → 200), ali nije bilo naloga; kad ga bude, `tool/run_live_demo.sh admin`.
> Breadcrumb `Vitez / Danas`, akcije top bara i naslov „Danas" umjesto „Pregled" su copy i akcije
> ekrana — task [30](30-postojeci-ekrani-na-handoff.md).
>
> PR: [#51](https://github.com/htuco/salon-booking-platform/pull/51).
