# Task 66 — Registracija: ime, telefon i uslovi u jednoj formi

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | — |
| **Blokira** | [58](58-kontakt-jednim-tapom.md), [67](67-pisanje-recenzija.md), [81](81-potvrda-emaila-kodom.md), [82](82-izmjena-profila-klijenta.md), [84](84-apple-google-prijava.md), [87](87-sigurnosni-pregled.md) |
| **Reference** | ADR-0029 · `docs/research/auth-krajnji-korisnik.md` §1, §7 · `docs/06` §3.1 (više ne važi) |

## Cilj
Salon zna ko mu dolazi. Danas je svaki email klijent u Meluri „Klijent / Bez broja", jer forma ima
samo email i lozinku, a `ensure_customer` pada na `'Klijent'`.

## Definicija gotovog
- [ ] Forma registracije: **ime i prezime, telefon, email, lozinka** (jednom, sa „prikaži lozinku").
      Otvara se na **registraciji**; „Već imate račun? Prijavite se" je sekundarno
- [ ] Telefon bez SMS verifikacije; kratko objašnjenje ispod polja zašto ga salon treba
- [ ] **Checkbox** „Prihvatam Uslove korištenja i Politiku privatnosti" sa linkovima na oba dokumenta;
      prazan po defaultu, bez njega dugme za registraciju nije aktivno. Isti checkbox na „Dopuni profil"
      poslije prve Apple/Google prijave
- [ ] Prihvatanje se bilježi: verzija oba dokumenta + vrijeme, na identitetu (migracija); nova verzija
      uslova traži ponovno prihvatanje pri sljedećoj prijavi
- [ ] Ime i telefon idu u auth metapodatke → `auth_identities` → `customers` **svakog** salona tog
      korisnika; postojeći „Klijent" redovi se osvježe
- [ ] Melura prikazuje ime i telefon (lista klijenata, detalj termina)
- [ ] Mapirani `user_already_exists` i `weak_password`; forma prijave ne provjerava pravila registracije;
      uklonjen demo tekst „ne šaljemo email potvrdu"
- [ ] `docs/06` §3.1 prepisan; `security.md` za novu kolonu; Data safety bilješka
- [ ] Widget testovi forme; pgTAP za osvježavanje imena po salonima (bez curenja u tuđi salon)

## Zamke
- `on conflict do nothing` u `ensure_customer` — bez izmjene postojeći klijenti zauvijek ostaju „Klijent".
- Ime i telefon su **po identitetu**, a `customers` je **po salonu**: salon A ne smije vidjeti da
  isti čovjek ide i u salon B (`docs/06` §4.3).

## Status
Nije počet.
