# Trenutni task: FE-403 — Kalendar termina

Učitan 2026-09-22 iz [fe-redizajn/FE-403](fe-redizajn/FE-403-kalendar-termina.md). Grana
`feat/fe-403-kalendar-termina` sa svježeg `main`-a, jedan commit,
[PR #72](https://github.com/htuco/salon-booking-platform/pull/72) (draft).

## Status

Redizajnerski dio gotov i dokazan. **309 testova PASS** (bilo 306), čista analiza i format.
Viđeno uživo na 1440×900 i 402×874, i u tamnoj temi.

## Ciljevi

- [x] Zahtjevi na odobrenju vizuelno odvojeni — isprekidan rub na mreži `3c`, u listi `3l`
      i na uzorku u legendi
- [x] Tri nova testa, svaki uz **negativnu** provjeru da potvrđen termin rub nema
- [x] Dark mode — rub prati `waiting` token, nijedna statična light vrijednost
- [ ] **Prebacivanje dan / sedmica** — izostavljeno, imenovan dug
- [ ] **Odobravanje na realtime signal** — izostavljeno, imenovan dug

## Napomene uz FE-403

- **Ekran je bio već ispunjen do četiri od šest DoD stavki.** Kolone po radniku, preklapanje
  kroz trake, raspodjela po širini i mobilna lista stoje iz taska 31 i FE-406. Provjereno u
  kodu prije pisanja; stvarni posao je bio **jedna rupa**, ne cijeli ekran.
- **Dvije DoD stavke se kose sa tabelom izostavljanja u `prototype/admin/SPEC.md`.** Prekidač
  `Dan · Sedmica · Mjesec` je tamo izričito izostavljen („dvije od tri opcije ne bi radile"),
  a sam task ga priznaje kao jedinu stavku koja je nova funkcionalnost. Ulazak traži **ADR**,
  nije usputna promjena koda. Realtime isto: epik FE-4 piše da nijedan task u njemu ne mijenja
  upit ni ponašanje rezervacije.
- **Prva verzija testa bila je zelena i za potvrđen termin.** Hvatala je `foregroundPainter`,
  koji i `Material` postavlja za svoj oblik. Zato je `RubZahtjeva` javan widget — test pita
  njegov `ceka`, umjesto da pogađa tip privatnog painter-a.
- **`find.ancestor` vraća sve pretke, ne najbližeg.** U legendi je uzorak **brat** teksta, pa
  je najdalji `Row` obuhvatao cijelu stranicu i uvlačio uzorke svih redova — provjera bi bila
  zelena i za „Potvrđeno". Rješenje je `.first`.
- **`SPEC.md` nije mijenjan** — izvoz i tekst se na ovom ekranu nisu razišli.

## Šta je sljedeće

Admin blok (FE-401…FE-406) je ovim **zatvoren**. Ostatak epika je klijentska aplikacija i
čeka **tri neriješene ADR odluke** (Barlow, koralna u klijentu, Lucide). To je usko grlo, ne
broj preostalih dana.

---

# Prethodni task: FE-404 — Usluge, osoblje i klijenti

Spojen u `main` ([PR #71](https://github.com/htuco/salon-booking-platform/pull/71)).
Terminologija po vertikali umjesto „Majstor" iz canvasa, zelen CI na oba joba.
