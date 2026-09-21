# Korak rezervacije je po usluzi, ne samo po salonu

## Status

prihvaćen

## Kontekst

`salon_settings.slot_step_minutes` bira dozvoljene početke termina i vrijedi za cijeli salon. Kod
Viteza je 15 minuta. Usluga „Brada" traje 20, „Muško šišanje" 30, „Šišanje + brada" 45.

Problem se vidi tek na kratkoj usluzi: termin u 11:00 za uslugu od 15 minuta završi u 11:15, a
sljedeći početak koji sistem nudi je 11:30 ako je iza njega duža usluga. Petnaest minuta koje
nijedan klijent ne može uzeti, a barber ih ne može ni naplatiti ni iskoristiti. Na dan sa nekoliko
kratkih usluga to je sat vremena.

## Odluka

Korak se pomjera sa salona na uslugu. `services` dobija vlastiti `slot_step_minutes`;
`salon_settings.slot_step_minutes` ostaje **podrazumijevana** vrijednost kad usluga svoju nema.

Migracija ne mijenja nijedno postojeće ponašanje: dok se korak ne upiše na uslugu, sve radi kao i
do sada.

## Zašto ne jednostavnije

**Zaokružiti trajanje na korak** (brada od 15 zauzme 30) rješava rupu tako što je pretvara u
plaćeno vrijeme koje salon gubi na svakoj kratkoj usluzi. To je cjenovnička odluka prerušena u
tehničku.

**Pakovati dan automatski** — nuditi samo početke koji se nadovezuju na postojeći termin — daje
najbolju popunjenost bez ijedne postavke, ali klijentu skriva slobodne termine koje vidi kao
slobodne. Ostaje kao moguća nadogradnja kad bude stvarnih salona i podataka; tada je to nova
odluka, ne izmjena ove.

**Ostaviti kako jeste** je branjivo dok salon ima jednu dužinu usluge. Vitez je nema.

## Posljedice

- Ovo dira `get_available_slots`, dakle i **klijentsku** aplikaciju. Regresija se vidi u booking
  flowu, ne u adminu.
- Trajanje i korak prestaju biti ista stvar i u razgovoru: trajanje puni termin, korak bira
  dozvoljene početke. Usluga od 15 minuta sa korakom 30 je legitimna i namjerna.
- Snapshot termina (task 32) ne nosi korak i ne treba ga — korak utiče na izbor početka, ne na ono
  što je dogovoreno.
