# Task 31 — Kalendar dana

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [29](29-responsive-shell.md) |
| **Blokira** | — |
| **Reference** | `SPEC.md` prikazi `3c` `3l` · [16](../sprint-2/16-moji-termini-i-otkazivanje.md) |

## Cilj
`/calendar` prestaje biti placeholder: dan po radnicima, sa terminima na svojim mjestima.

## Definicija gotovog
- [x] Desktop `3c`: kolona po radniku, vremenska osa, termin kao blok
- [x] Telefon `3l`: isti podaci kao lista po vremenu — ne stisnuta mreža
- [x] Termin vodi na detalj iz [30](30-postojeci-ekrani-na-handoff.md)
- [x] Pauze, neradni dani i blokade se **vide**, ne samo kao praznina
- [x] Čita se kroz postojeći `StaffAppointmentRepository`, bez novog direktnog upita
      (nad `appointments`; blokade su tražile **nov** put čitanja — v. status)
- [x] Testovi rade u bilo koje doba dana i bilo koji dan u sedmici

## Koraci
1. Model dana i mapiranje termina na osu, sa testovima nad rubnim slučajevima
2. Desktop mreža, pa mobilna lista
3. Commit: `feat(admin): kalendar dana po radnicima`

## Zamke
- **`get_available_slots` vraća red po radniku.** Ista osobina je u tasku 24 dala duplirana vremena
  u ručnom unosu, zbog čega `distinctTimes` i postoji. Kalendaru red po radniku **i treba** — ali
  svako miješanje ta dva pogleda daje ili duplikate ili izgubljene termine.
- **Test koji radi samo u dijelu dana nije test.** Tri zatečena testa nađena u tasku 17 bila su
  zelena samo poslije 09:30 ili ponedjeljkom. Kalendar je najgore mjesto za tu grešku — fiksiraj
  vrijeme umjesto da se oslanjaš na `DateTime.now()`.
- Termin duži od jednog slota i prekoračenje preko ponoći moraju imati svoj slučaj.

## Status (2026-09-20) — ✅ zatvoren

`/calendar` više nije placeholder. Desktop `3c` je mreža sa kolonom po radniku nad satnom osom,
telefon `3l` ista stvar kao lista po vremenu. Grana `feat/admin-kalendar-dana`,
[PR #53](https://github.com/htuco/salon-booking-platform/pull/53).

**Model je odvojen od ekrana.** `apps/admin/lib/src/features/calendar/calendar_day.dart` je čista
funkcija nad terminima, radnim vremenom i blokadama; `izgradiDan()` daje kolone, `redoviKolone()`
jednu kolonu izravna u listu jednog radnika, `redoviDana()` cijeli dan u listu svih. Razlog je
zamka iz ovog taska: `get_available_slots` vraća red po radniku, pa svako miješanje pogleda „po
radniku" i „po vremenu" daje ili duplikate ili izgubljene termine. Vrijeme je svugdje `int` minuta
od ponoći — osa je linija od 0 do 1440 i sve na njoj je oduzimanje.

**Blokade su tražile nov put čitanja, i to je jedino odstupanje od DoD-a.** Termini idu kroz
postojeći `StaffAppointmentRepository.forDay`, bez ijednog novog upita nad `appointments` — ali
`public.blocked_slots` do sada **nije imala Dart repozitorij**: postoji od init migracije i čitana
je isključivo iz SQL-a (`get_available_slots`, admin akcije). Bez nje se stavka „blokade se vide"
ne može ispuniti, pa su dodani `BlockedSlot` (`core_domain`) i `BlockedSlotRepository`
(`core_api`), **samo za čitanje**.

**Četiri odluke koje se ne vide iz koda:**

- **Osa se razvlači preko svega što dan sadrži**, ne staje na radnom vremenu. Ručni unos smije
  upisati termin izvan smjene; osa koja bi ga odsjekla ostavila bi kao jedini trag to da brojka
  „6 termina" ne odgovara onome što se broji na ekranu.
- **Zatvoren dan se ne čita iz `start_time`/`end_time`.** Ti stupci nose default `09:00–17:00` i u
  redu koji kaže `is_closed`, pa bi ih čitanje kao rasporeda pretvorilo zatvorenu nedjelju u radni
  dan. Dan bez ičega dobija prozor 08–20 **za gledanje**, koji nije tvrdnja o radnom vremenu.
- **Termin bez radnika dobija kolonu „Bez radnika"** (canvas je nema). `employee_id` je nullable;
  tu ide i termin čiji radnik više ne postoji. Raspored koji tiho izostavi termin je gori od
  rasporeda sa kolonom viška.
- **Preklapanje ide u trake.** Dva termina istog radnika u isto vrijeme nisu greška availability
  enginea: otkazan termin ostaje u listi, pa novi legitimno stoji preko njega.

**Prekoračenje preko ponoći** ima svoj slučaj: `end_time` je `time`, a Postgresov `time` poznaje
`24:00:00` dok `LocalTime` zna sate 0–23. Takav red stiže kao kraj koji nije veći od početka i bez
zaštite daje blok negativne visine — Flutter ga ne iscrta, pa termin nestane sa rasporeda.

**Tri greške koje je našao ekran, a testovi nisu mogli:**

1. **Kvadratići u legendi** su uzimali `foreground` umjesto `background`, pa su pokazivali boju koje
   na rasporedu nema — a „Otkazano" (`onDestructive`, skoro bijela) se nije ni vidio. Widget test
   vidi da red postoji, ne i da mu je uzorak nevidljiv.
2. **Tekst u 40-minutnom bloku se rezao po dnu.** Padding se sada bira po visini u pikselima, ne po
   trajanju u minutama — ista pauza je na gušćoj osi niža, a veći `textScaleFactor` je čini
   pretijesnom bez ijedne promjene u podacima.
3. **„Slobodno" se protezalo preko zatvaranja salona.** Subota se zatvara u 14:00, a termin u 14:20
   je prijavio „Slobodno 2h 20m" — red koji nudi da se zakaže kad se ne radi. Rupa se sada odsijeca
   na kraj smjene, i to je pokriveno testom.

Uz njih, `Positioned` umotan u `LayoutBuilder` unutar `Stack`-a obara layout (`Incorrect use of
ParentDataWidget`); širina kolone sada dolazi odozgo, iz `_Mreza`.

**Ispravljena netačna tvrdnja u dokumentaciji.** Prvi doc `BlockedSlotRepository`-ja je tvrdio da bi
direktan upis bio „obrnuto od pravila upisanog u grantove". Nije: init migracija daje
`insert/update/delete` nad `blocked_slots` roli `authenticated` i nikad ih nije oduzela, za razliku
od `appointments`, gdje ih je task 24 povukao. Provjereno pozivom, ne čitanjem migracije. Upisano u
`.claude/docs/security.md`.

### Dokaz

```
$ flutter test            # po paketu
apps/client        00:23 +232 ~1: All tests passed!
apps/admin         00:09 +219:   All tests passed!
packages/core_domain 00:02 +80:  All tests passed!
packages/core_api  00:02 +118:   All tests passed!
packages/core_ui   00:03 +67:    All tests passed!

$ dart analyze            # svi paketi — No issues found!
$ git ls-files '*.dart' | xargs -n 60 dart format --set-exit-if-changed   # bez izmjena
```

**716 testova ukupno, `admin` 219**, od čega **62 nova** u `test/calendar_day_test.dart` (39) i
`test/calendar_screen_test.dart` (23). Nijedan ne zove `DateTime.now()`: dan je fiksiran na
ponedjeljak 18. maj 2026, a „sada" ulazi kroz `sadaProvider`, koji je zato i `StreamProvider`.

**Provjereno da testovi mogu pasti** — četiri sabotaže, svaki put padne tačno ono što pokriva:
blok bez `onTap` (2 testa), pozadinski pojasevi se ne crtaju (1), salonska blokada se ne
deduplicira (1), osa ignoriše termine (3).

**Uživo, uz pravu prijavu** protiv hostovanog projekta iz `.env.live`
(`admin@barberstudiovitez.test`): `docs/screenshots/task-31-admin-kalendar-uzivo.png`, a klik na
blok otvara pravi detalj — `task-31-admin-kalendar-uzivo-detalj.png`. Da kalendar ima šta da crta,
u hostovanu bazu su **privremeno** upisane jedna blokada i jedna smjena sa pauzom, pa obrisane;
`blocked_slots` i `working_hours` sa `employee_id` su ponovo prazni (`204`, pa prazne liste).

**Novi upit nad `blocked_slots` je odigran protiv prave RLS politike**, ne samo napisan: prijavljen
seed admin ga čita kroz REST sa istim kolonama koje traži repozitorij.

Web snimci demo ulaza, na obje širine: `task-31-admin-kalendar-desktop.png`,
`-neradni-desktop.png` (zatvorena nedjelja), `-telefon.png`, `-telefon-radnik.png`.

### Ostalo za sljedećeg

- **`/calendar` ne nosi dan u adresi.** Bookmark i refresh uvijek otvaraju današnji dan. Nije
  regresija — nijedan ulaz u app ne traži određeni dan — ali je odstupanje od onoga što je task 29
  uradio za `?status=pending`. Ako zatreba: isti obrazac, filter se čita u `GoRoute.builder`-u i
  prosljeđuje ekranu kao argument.
- **Deep link na bilo koju admin rutu poslije osvježavanja pada na `/dashboard`.** Nađeno uživo, i
  **nije od ovog taska**: `/calendar`, `/appointments` i `/more` se svi tako ponašaju. Redirect
  prvo pošalje na `/login` dok sesija nije učitana, pa odatle na `/dashboard` — tražena putanja se
  izgubi. Provjera: `tool/serve_web_demo.sh`, pa otvori `/appointments` u novoj kartici.
- **Blokade nemaju seed red.** Dok ih task 34 ne bude pisao iz app-e, jedini način da se vide je
  ručan upis u bazu.
- **Nije pokrenuto na fizičkom uređaju**, a iOS je nedostupan — mašina je Windows.
