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
| [30](30-postojeci-ekrani-na-handoff.md) 🟡 | Postojeći ekrani na handoff: prijava, Danas, zahtjevi, termini | `3b` `3d` `3j` `3k` `3m` `3n` `3u` | — | 2–3 dana |
| [31](31-kalendar-dana.md) ✅ | Kalendar dana | `3c` `3l` | — | 2–3 dana |
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
> PR: [#51](https://github.com/htuco/salon-booking-platform/pull/51) — CI zelen, **spojen u `main`**
> (`88c1605`).
>
> Sljedeći task je [30](30-postojeci-ekrani-na-handoff.md). Tri stvari koje mu je 29 ostavio
> vidljive na snimcima: breadcrumb `Vitez / Danas` (traži ime salona, kojeg `StaffMember` nema),
> akcije desktop top bara („Pretraži klijenta", „Blokiraj termin", „+ Novi termin"), i naslov
> dashboarda „Pregled" dok ga navigacija zove „Danas". Za vizuelni dokaz koristi
> `apps/admin/lib/demo_main.dart` — `flutter run -d chrome -t lib/demo_main.dart` iz `apps/admin`.

> **30 — Postojeći ekrani na handoff (🟡, 2026-09-19).** Prijava, „Danas", zahtjevi, lista termina
> i **detalj termina** imaju izgled iz `prototype/admin/`. `/appointments/:id` je do sada bio
> placeholder iako ruta stoji u enumu i u `docs/01 §12`; sada čita jedan termin iz baze
> (`StaffAppointmentRepository.byId`, nov) umjesto da ga dobije iz liste — ista adresa mora raditi
> iz bookmarka i, sutra, iz push obavijesti.
>
> **Ljuska je zatvorila tri stvari koje joj je 29 ostavio:** breadcrumb `Vitez / Danas` (ime salona
> dolazi iz novog `adminSalonProvider`-a, jer `StaffMember` nosi samo `salonId`), akcije desktop top
> bara, i naslov „Danas" umjesto „Pregled". Uz to `AdminScaffold` sada zna da telefonski ekran može
> nositi **svoje** zaglavlje — `3k` iznad sadržaja crta veliki naslov, a `AppBar` sa sitnim „Danas"
> bi istu riječ napisao dvaput.
>
> **Dvanaest stvari iz canvasa namjerno nije nacrtano**, sa razlogom i taskom u kojem se vraćaju —
> tabela je upisana u `prototype/admin/SPEC.md`. Tri su vrijedne pomena: brojke „6 lokacija · 19
> majstora · 84 termina" na prijavi **nisu demo sadržaj nego tuđi podaci** (zbir preko svih salona,
> koji `salon_admin` po RLS-u ne smije vidjeti, a ekran prijave bi ih tražio neprijavljen);
> „Slobodno vrijeme" i „82% zauzetosti" traže smjene radnika (task 33), pa je zauzetost ovdje u
> **minutama i relativnoj traci** umjesto izmišljenog procenta kapaciteta; a „najstariji zahtjev
> prije 26 min" nema šta da računa jer `appointments` nema `created_at`.
>
> **Četiri greške koje je našao ekran, a testovi nisu mogli:** brojanje termina po
> `status.blocksSlot` (koje je `false` za završen termin, pa je „6 termina" pokazivalo 5),
> zauzetost koja piše „3 3 termina", telefonska prijava sa dugmetom širine svog teksta nasred
> ekrana, i desktop prijava sa dva logotipa. Sve četiri su sada pokrivene testom koji mjeri cijeli
> red ili širinu, a ne postojanje widgeta.
>
> **Usput ispravljeno u dokumentaciji:** `docs/01 §12` je detalj termina zvala „bottom sheet", a
> `3n` crta puni ekran; i statusna oznaka uz termin je prešla u jedninu („Potvrđeno"), dok množina
> ostaje filteru koji imenuje grupu redova — dug koji je task 24 ostavio zapisan u kodu.
>
> Dokazano: **642 testa** u pet paketa (admin **145**, bilo 85), čista analiza i format, i svih pet
> prikaza uživo u Chromiumu na 1440 i na 402 — `docs/screenshots/task-30-admin-*.png`.
>
> **Prava prijava je odigrana, i time pada dug iz 28 i 29.** Ti taskovi su pretpostavljali da
> hostovani projekat nema naloge; seed admin `admin@barberstudiovitez.test` / `admin123456`
> **postoji**. Tok je odigran na **Android emulatoru (API 35)** protiv hostovanog Supabasea —
> prijava, „Danas" sa pravim terminima, detalj termina (`docs/screenshots/task-30-admin-uredjaj-*.png`).
>
> **Uređaj je našao grešku koju nijedan test ni web snimak nisu:** ćelija „Zahtjevi" je nosila
> crvenu tačku iako nema nijednog zahtjeva — `Badge` je bio uvijek vidljiv, a Material prazan
> `label` iscrta kao tačku. Demo je uvijek imao zahtjeve, pa se na webu nije vidjelo. Test sada
> gleda postojanje `Badge`-a, ne tekst u njemu.
>
> **Ostalo za sljedećeg:** drugi tenant — `admin@beautystudiotravnik.test` na hostovanom projektu
> **ne postoji** (`400` na `POST /auth/v1/token`), pa „ista aplikacija, druga prijava, nijedan tuđi
> termin" ostaje nedokazano uživo; izolacija i dalje stoji na pgTAP-u i Deno testovima. App nije
> pokrenuta na **fizičkom** uređaju, a iOS je nedostupan jer je mašina Windows.
>
> Sljedeći task je [31](31-kalendar-dana.md). Tri stvari koje mu 30 ostavlja spremne:
> `AppointmentCard` i `AppointmentStatusPill` (oblik termina), `core/format/datum.dart` (imena dana
> i mjeseci na jednom mjestu) i `terminProvider` sa rutom detalja, na koju kalendar može voditi.

> **31 — Kalendar dana (✅, 2026-09-20).** `/calendar` je prestao biti placeholder. Desktop `3c` je
> mreža sa kolonom po radniku nad satnom osom (80 px/sat iz canvasa), telefon `3l` ista stvar kao
> lista po vremenu — **jedan model, dva čitanja**. `calendar_day.dart` je čista funkcija nad
> terminima, radnim vremenom i blokadama, bez ijednog widgeta: blok na pogrešnom mjestu na osi
> izgleda tačno kao blok na pravom, pa se razlika vidi samo u testu.
>
> **`blocked_slots` je prvi put dobila Dart repozitorij.** Tabela postoji od init migracije, ali je
> do sada čitana **isključivo iz SQL-a** (`get_available_slots`, admin akcije) — klijentu blokada
> nije podatak nego odsustvo slota. Adminu jeste: kalendar koji je ne crta pokazuje prazninu tamo
> gdje je vlasnik svjesno zatvorio vrijeme. Repozitorij **samo čita**; pisanje („Blokiraj vrijeme",
> „Dodaj pauzu", „Zatvori dan") je task 34. To je i jedino odstupanje od DoD-a, koji je tražio da
> se čita bez novog upita — termini i jesu, kroz postojeći `forDay`.
>
> **Ispravljena netačna tvrdnja koju je prvi prolaz umalo ostavio u repou:** doc je pisao da bi
> direktan upis blokade bio „obrnuto od pravila upisanog u grantove". Nije — init migracija daje
> `insert/update/delete` nad `blocked_slots` roli `authenticated` i nikad ih nije oduzela, za
> razliku od `appointments`, gdje ih je task 24 povukao. **Provjereno pozivom**, ne čitanjem
> migracije: prijavljen seed admin je kroz REST upisao i obrisao blokadu. Zapisano u
> `.claude/docs/security.md`.
>
> **Tri stvari iz canvasa namjerno nisu nacrtane**, sa razlogom i taskom povratka, i upisane su u
> tabelu u `prototype/admin/SPEC.md`: prekidač `Dan · Sedmica · Mjesec` (dvije od tri opcije ne bi
> radile), „Dodaj pauzu" i „Zatvori dan" (pišu u `working_hours` — task 34) i fotografija radnika
> (`image_url` je prazan u seedu, pa bi svaka kolona nosila slomljenu sliku — task 33). **Dvije
> stvari aplikacija ima, a canvas nema:** peti red legende („Otkazano", jer kalendar otkazane
> termine prikazuje) i kolona „Bez radnika" (`employee_id` je nullable).
>
> **Tri greške koje je našao ekran, a testovi nisu mogli:** kvadratići u legendi su uzimali
> `foreground` umjesto `background`, pa je „Otkazano" bio nevidljiv; tekst u 40-minutnom bloku se
> rezao po dnu, jer je padding biran po trajanju u minutama a ne po visini u pikselima; i
> „Slobodno" se protezalo preko zatvaranja salona — subota se zatvara u 14:00, a termin u 14:20 je
> prijavio „Slobodno 2h 20m", red koji nudi da se zakaže kad se ne radi.
>
> Dokazano: **716 testova** u pet paketa (`admin` **219**, od toga 62 nova), čista analiza i format
> nad svim verzionisanim Dart fajlovima, četiri sabotaže koje potvrđuju da novi testovi **mogu
> pasti**, i **prava prijava** protiv hostovanog projekta — klik na blok u mreži otvara pravi detalj
> termina (`docs/screenshots/task-31-admin-kalendar-uzivo*.png`). Nijedan test ne zove
> `DateTime.now()`: dan je fiksiran, a „sada" ulazi kroz `sadaProvider`.
>
> **Ostalo za sljedećeg:** `/calendar` ne nosi dan u adresi, pa bookmark uvijek otvara danas — isti
> obrazac kao `?status=pending` iz taska 29 ako zatreba. Uz to, nađeno uživo i **nije od ovog
> taska**: deep link na **bilo koju** admin rutu poslije osvježavanja pada na `/dashboard`, jer
> redirect izgubi traženu putanju dok sesija nije učitana. Blokade nemaju seed red, pa se do taska
> 34 vide samo uz ručan upis.
>
> Sljedeći task je [32](32-usluge-i-cjenovnik.md) — prvi u sprintu koji **nosi backend**: danas ne
> postoji nijedna RPC putanja kojom admin piše uslugu, pa ide migracija i pgTAP prije ekrana.
