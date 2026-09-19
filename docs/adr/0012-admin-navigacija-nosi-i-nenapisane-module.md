# Admin navigacija nosi i nenapisane module, a „Zahtjevi" nisu svoja ruta

## Status

prihvaćen

## Kontekst

Task 23 je adminu dao donju navigaciju sa **dvije** ćelije, Pregled i Termini, i pravilo zapisano u
komentaru: „Ćelija koja vodi na placeholder je gora od ćelije koje nema: obeća funkciju koja ne
postoji i vlasnik je traži ponovo." Kalendar, usluge, radnici i postavke su postojali kao rute, ali
ih navigacija nije nudila.

Task 29 je tu ljusku pisao po handoffu iz `prototype/admin/`. Mjerenje canvasa
(`canvas/Salon OS Admin.dc.html`) je dalo sastav koji SPEC tabela prikaza ne pokazuje:

- **sidebar `3b` nosi osam stavki** — Danas, Kalendar, Zahtjevi, Klijenti, Usluge, Osoblje, Radno
  vrijeme, Postavke;
- **donja navigacija `3k`/`3t` nosi četiri** — Danas, Kalendar, Zahtjevi, Još.

Dvije posljedice nisu bile očigledne dok se nije brojalo. Prva: **puna lista termina nema svoju
ćeliju ni u jednoj navigaciji** — „Termini" kao stavka ne postoji, a `/appointments` je danas jedan
od tri napisana admin ekrana. Druga: **šest od osam modula u sidebaru nema ekran**, pa pravilo iz
taska 23 i handoff ne mogu oba važiti.

Uz to, „Zahtjevi" u aplikaciji nisu bili adresa nego stanje: kartica na dashboardu je zvala
`postaviStatus(AppointmentStatus.pending)` pa navigirala na `/appointments`. Admin je i web build,
pa je to značilo da refresh i „nazad" vrate nefiltriranu listu, a URL ne opisuje šta se vidi.

## Odluka

- **Navigacija nosi svih osam modula, i onih šest bez ekrana.** Pravilo iz taska 23 se obrće.
  Placeholder je ono što vlasnik vidi dok modul ne dobije ekran — **vidljivo prazno mjesto umjesto
  nevidljivog**.
- **Svaki admin ekran stoji u `AdminScaffold`, uključujući placeholder.** Ekran sa vlastitim
  `Scaffold`-om je slijepa ulica čim navigacija vodi do njega. Izuzetak su prijava i ručni unos:
  prva nema navigaciju, drugi je modalni tok.
- **„Zahtjevi" vode na `/appointments?status=pending`, ne na vlastitu rutu.** Filter je u adresi,
  pa preživi refresh i „nazad". Istu adresu nosi i kartica na dashboardu.
- **Jedna lista odredišta za obje ljuske** (`core/navigation/admin_destinations.dart`). Prve tri
  stavke su ćelije telefona, ostalih pet su **rep iste liste** iza „Još" (`3t`).
- **`3a` (pregled mreže, birač lokacije, „‹ Nazad na mrežu") ne ulazi u navigaciju.** Salon i dalje
  dolazi iz membershipa ([ADR-0003](0003-x-salon-id-bira-kontekst-ne-daje-prava.md)).

## Razmatrane opcije

- **Zadržati pravilo iz taska 23 i nuditi samo napisane module** — odbačeno: donja navigacija bi
  imala dvije ili tri ćelije umjesto četiri, a „Još" bi bio prazan ekran. Handoff bi se onda
  implementirao tek u zadnjem tasku sprinta, kad svih šest modula dobije ekran — a do tada bi svaki
  od tih taskova pisao svoj ulaz u navigaciju, pa bi se ljuska mijenjala sedam puta.
- **Zasebna ruta `/requests` za zahtjeve** — odbačeno: handoff nema ćeliju „Termini", pa bi
  `/appointments` ostao bez ijednog ulaza iz navigacije. Ovako je to ista ruta, a postojeća filter
  traka na ekranu vraća na „sve".
- **Ostaviti zahtjeve kao stanje providera i dati ćeliji da ga postavi** — odbačeno: to je upravo
  greška koja je već bila u kodu. Ćelija koja mijenja stanje pa navigira daje adresu koja ne opisuje
  ekran, i razlikuje se od iste adrese otvorene iz bookmarka.
- **Dvije liste odredišta, po jedna za svaku ljusku** — odbačeno: modul dodan u jednu, a zaboravljen
  u drugoj, dostupan je samo na jednoj širini. To se ne vidi na širini na kojoj se piše kod.
- **Ćelija „Termini" dodana mimo handoffa, da puna lista ima svoj ulaz** — odbačeno: pet ćelija na
  402 px razbija raspored koji canvas crta, a peta bi postojala samo zato što nam je zgodna.

## Posljedice

- **`AdminRoute` je dobio `clients` i `more`**, i oboje je upisano u `docs/01 §12`. `/more` postoji
  zbog oblika navigacije, ne zbog novog sadržaja: osam modula ne stane u četiri ćelije.
- **Placeholder ekran više nije neutralan.** Nosi ljusku, pa ga svaka promjena navigacije dotiče.
  To je namjerno — ekran bez navigacije je ono što je i bio kvar.
- **Vlasnik vidi module koji ne rade.** To je prihvaćen trošak do kraja sprinta: taskovi 31–36 pune
  redom `/calendar`, `/services`, `/employees`, `/working-hours`, `/settings` i `/clients`.
- **Filter statusa se čita u route builderu, ne u ekranu.** Pravilo iz taska 23 — ekran ne čita
  `GoRouterState` — ostaje netaknuto: builder pročita `?status=` i preda ga konstruktoru, pa se
  ekran i dalje diže u widget testu bez pravog `GoRouter`-a.
- **`AppointmentsFilterNotifier` je dobio `postaviStatusTacno`** uz postojeći `postaviStatus`, koji
  prebacuje. Bez te razlike bi ista adresa davala dva ekrana: filtriran kad se dođe izvana, prazan
  filter kad se ćelija tapne dvaput.

## Reference

- [`prototype/admin/SPEC.md`](../../prototype/admin/SPEC.md) — sastav navigacije i mjere, dopunjeni
  nalazima iz ovog taska
- [`.claude/docs/architecture.md`](../../.claude/docs/architecture.md) — „Admin ljuska: jedna lista
  odredišta, dvije ljuske"
- [ADR-0003](0003-x-salon-id-bira-kontekst-ne-daje-prava.md) — zašto `3a` i birač lokacije ne ulaze
- [Task 29](../../tasks/sprint-3/29-responsive-shell.md) — dokaz i „ostalo za sljedećeg"
