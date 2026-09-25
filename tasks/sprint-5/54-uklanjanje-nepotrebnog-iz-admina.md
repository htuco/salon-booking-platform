# Task 54 — Uklanjanje nepotrebnog iz admina

| | |
|---|---|
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | — |
| **Blokira** | 55 |
| **Reference** | [ADR-0020](../../docs/adr/0020-admin-je-1na1-sa-adminv2-barlow-i-svijetla-tema.md) tačka 3 · `prototype/admin/SPEC.md` |

## Cilj
Admin nosi samo ono što salon koristi. Dugme koje vodi u „uskoro" ili u funkciju koju vlasnik ne
želi nestaje, umjesto da čeka.

## Definicija gotovog
- [ ] Vlasnik proizvoda potvrdi listu šta se uklanja (kandidati ispod) — lista se zapisuje u status
- [ ] Dopuna ADR-0020: tačka 3 („crta se kao placeholder, ne izostavlja se") više ne važi za
      elemente koje vlasnik proizvoda odbije; novi podatak je njegova odluka
- [ ] Uklonjeni elementi nestaju iz ekrana, navigacije i testova — bez mrtvih providera i ruta
- [ ] Ono što se vraća kasnije (npr. „Promjena fotografije" sa taskom 50) ostaje, a ne briše se pa vraća
- [ ] `prototype/admin/SPEC.md` tabela usklađena; `melos run analyze` i `melos run test` zeleni
- [ ] Viđeno uživo, obje uloge, 1440 i 402

**Kandidati** (danas „uskoro" u kodu): „Pomjeri" u detalju termina · „Pregled odbijenih" i „Pregled
otkazivanja" u terminima · `Sedmica · Mjesec` u kalendaru · napomena o pauzi radnika · „+ Novi
klijent" na ekranu klijenata · „Zakaži" i „Pozovi" iz profila klijenta · „Lista čekanja",
„Podsjetnici" i „Pregled u aplikaciji" u postavkama. Uz to i sve ostalo što vlasnik proizvoda
označi kao nepotrebno.

## Zamke
- „Pozovi" je MVP (`docs/01` §6.3) i task 58 ga oživljava — ne briši ga ako 58 ide u ovaj sprint.
- „Podsjetnici" u postavkama pišu `reminders_enabled`, koji task 56 čita. Ukloniti red znači da salon
  ne može ugasiti podsjetnike — to je odluka, ne sitnica.
- Telefonski klijent se i dalje dodaje kroz „Novi termin"; uklanjanje dugmeta sa ekrana klijenata
  ne uklanja tu mogućnost.

## Status
Nije počet.
