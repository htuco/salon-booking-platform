# Mobilni admin — prijedlog shella

Otvori `index.html` direktno u browseru. Nije potreban build ni server; Barlow se
učitava iz postojećih lokalnih fontova u `apps/admin/assets/fonts/`.

Ovo je samostalni interaktivni prijedlog, nije usvojeni handoff niti Flutter
implementacija. Na desktopu prikazuje telefon, na mobilnom koristi cijeli ekran.

- Danas počinje kompaktnim redom datuma i statusa, bez velikog naslova. Sljedeći
  termin je prvi, pa zahtjevi, raspored i dnevne brojke na dnu.
- Kalendar odmah prikazuje mjesec i izbor dana, bez naslovnog bloka.
- Danas i Kalendar dijele tamno zaglavlje bez pretrage i navigaciju sa pet mjesta.
- Centralni privremeni znak lokala „B“ otvara panel brzih akcija.
- Kalendar podržava izbor dana, filter zaposlenika i otvaranje forme iz slobodnog vremena.
- Zahtjevi su ekran za obradu rezervacija: svaka kartica prikazuje klijenta,
  uslugu, cijenu, datum, vrijeme, zaposlenika i trajanje čekanja. Prihvati i Odbij
  dostupni su direktno na kartici. Odbijanje traži potvrdu; obje odluke uklanjaju
  zahtjev i ažuriraju brojač. Zadani redoslijed je najduže čekanje, uz filter
  zaposlenika i alternativno sortiranje po datumu i vremenu termina.
- Demo uključuje zahtjeve za danas i sutra. Zahtjevi nemaju fiksnu grupu Danas.
  Promjene se gube osvježavanjem; prihvatanje ne mijenja statični demo kalendar.
- Forme su ilustrativne: nema slanja ili trajnog čuvanja podataka.
- Još je ravna lista sa grupama Poslovanje, Salon i Nalog, bez pastelnih kartica
  i promotivnog podnožja. Ostali moduli nisu razrađeni.

Svi podaci su demo podaci za 18. maj 2026. Logo treba zamijeniti stvarnim logom
lokala. Produkcijska implementacija treba filtrirati brze akcije po ovlastima.

Provjereni su JavaScript sintaksa, lokalni fontovi, širina sadržaja i navigacije na
390 px, zatim svih četiriju tabova na 360 px, te klikovi za panel, formu, dan, zaposlenika, potvrdu i odbijanje u Chromeu.

Referenca za organizaciju salonskih funkcija: [Fresha](https://www.fresha.com/for-business/features).
Izgled je prijedlog za Meluru, bez preuzimanja njihovih asseta. Dodatno provjereni
su filter i sortiranje zahtjeva, prazno stanje i otvaranje stavki menija.

## Šta je u aplikaciji drugačije

Prenesen je u `apps/admin` (`core/widgets/admin_mobile_shell.dart` i telefonske grane
ekrana). Namjerna odstupanja:

- **Donja traka** ide po kasnijoj specifikaciji vlasnika, ne po ovom mocku: znak salona je
  kvadrat 56 px bez labele, labele su u verzalu.
- **Panel brzih akcija** je lista iz ovog mocka, ali bez imena salona u podnaslovu.
- **„+ Slobodan termin" u Kalendaru se ne prenosi.** Slobodno vrijeme računa samo
  `get_available_slots`; v. `calendar_day.dart` i test „slobodne rupe se ne crtaju".
- Strelice u Kalendaru pomjeraju sedmicu; bez njih se iz sedmice ne izlazi.
