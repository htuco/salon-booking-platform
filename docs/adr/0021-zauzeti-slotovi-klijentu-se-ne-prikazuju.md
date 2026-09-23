# Klijent vidi samo slobodna vremena — zauzeti slotovi se ne prikazuju

## Status

predložen — čeka vlasnika proizvoda. Do odluke vrijedi zatečeno stanje (samo slobodna vremena).

## Kontekst

DoD taska FE-302 (`tasks/fe-redizajn/FE-302-booking-flow.md`) traži da u koraku 3 nedostupni
slotovi budu „vidljivi i isključeni (45 % opacity), ne skriveni". `prototype/ui/SPEC.md:82` to ne
traži: kaže samo da izbor dana filtrira mrežu vremena. Stanje `disabled` iz `SPEC.md:92` opisuje
izgled komponente, ne to koji se slotovi uopšte prikazuju.

Prikaz je ovdje najmanji dio posla. `get_available_slots` vraća **samo slobodna** vremena, a
`.claude/docs/security.md` to navodi kao razlog zašto je funkcija `security definer` otvorena i
za `anon`: „izlaz su samo izvedena slobodna vremena". Zauzete slotove klijent ne može izvesti bez
nove funkcije ili nove kolone u izlazu. Oba puta mijenjaju taj ugovor:

- Mreža zauzetih vremena je raspored salona, i vidi je **neprijavljen** posjetilac. Iz nje se čita
  kad je koji radnik zauzet i koliko dugo, i to za svaki dan do `max_advance_booking_days`.
- Po `security.md` je blokada za klijentsku aplikaciju „odsustvo slota, a ne podatak". Precrtan
  slot bi pokazao da postoji blokada (pauza, odsustvo) tamo gdje je danas samo praznina.

`TimeSlotChip` već ima stanje „zauzet" (`onTap == null`): prigušena ispuna, precrtan tekst i
`Semantics(enabled: false)`. Opacity od 45 % tu namjerno nije korišten, jer na bojama tenanta pada
ispod AA praga (komentar u `packages/core_ui/lib/src/components/time_slot_chip.dart`). Dakle, nije
pitanje da li komponenta to može prikazati, nego da li baza smije klijentu vratiti te podatke.

## Odluka

Klijent i dalje vidi samo slobodna vremena. Izlaz `get_available_slots` se ne mijenja i ne dodaje
se funkcija koja vraća zauzeta vremena. Dan bez slobodnog vremena u kalendaru ostaje vidljiv i
isključen, kako je i danas. Tu je podatak već javan, jer `get_available_dates` ne vraća takav dan.

## Razmatrane opcije

- **Nova kolona `available boolean` u izlazu `get_available_slots`** — odbačeno dok vlasnik ne
  kaže drugačije: pokazuje raspored salona anonimnom posjetiocu, a svi postojeći pozivaoci (i
  admin, i `book_appointment` pri re-validaciji) bi morali filtrirati po koloni koju danas nemaju.
- **Mreža iz radnog vremena na klijentu, minus slobodna vremena** — odbačeno: dupla logika
  (`step`, `buffer`, pauze, `min_advance`) u Dartu. `slot_step_screen.dart` izričito kaže da se
  ovdje ništa ne računa, jer bi se pravilo razišlo sa migracijom čim se promijeni.
- **Zauzeti slotovi samo za prijavljenog klijenta** — odgođeno, ne odbačeno: smanjuje curenje na
  korisnike koji imaju nalog, ali ga ne ukida. Vraća se na sto ako vlasnik proizvoda kaže da je
  „salon je pun" poruka nedovoljna i da se raspored salona ne smatra osjetljivim.

## Posljedice

- DoD stavka FE-302 o vidljivim zauzetim slotovima ostaje otvorena **dok ovaj ADR ne bude
  prihvaćen ili odbijen**. Ako bude odbijen, posao je migracija + pgTAP + `security.md`, ne ekran.
- Dan pun do posljednjeg termina i dalje izgleda kao prazna mreža sa porukom
  (`bookingDayFull`), ne kao mreža precrtanih vremena. To je očekivano, nije bug.
