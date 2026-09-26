# Task 49 — Vlasnik postavlja sliku usluge i radnika

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [48](48-storage-bucket-po-salonu.md) |
| **Blokira** | 52, 53 |
| **Reference** | ADR-0015 · `docs/01` §6.3 (Employees: slika) |

## Cilj
Vlasnik iz admina doda ili zamijeni sliku usluge i radnika, a klijent je vidi u aplikaciji.

## Definicija gotovog
- [ ] Izbor slike u obrascu usluge i obrascu radnika (web i mobilni admin)
- [ ] Upload u bucket iz taska 48, pa `image_url` dobija javni URL — kolona ostaje gdje jest
- [ ] Prikaz napretka i greške; neuspio upload ne mijenja postojeću sliku
- [ ] Uklanjanje slike vraća placeholder (inicijal / prazna površina), ne slomljenu sliku
- [ ] Klijentska aplikacija prikazuje novu sliku na početnoj, u cjenovniku i u „Naš tim"
- [ ] Widget testovi za obrazac; uživo: upload u adminu → slika u klijentu, oba tenanta

## Zamke
- Zamijenjena slika ostaje u bucketu dok task 51 ne uvede čišćenje — ovdje se to svjesno ne rješava,
  ali putanja mora biti takva da 51 zna šta je siroče.
- Veličina: telefon šalje 4–12 MB. Smanjenje prije uploada ili limit na bucketu — ne oboje napola.

## Status (2026-09-26)

🟡 **Gotov za Vitez; ostaje drugi tenant uživo i mobilni izbor.** Grana `feat/slike-usluga-i-radnika`,
PR #112 (#111 je zatvoren kad je obrisana baza #110).

- `MediaRepository` (`core_api`) — tip po sadržaju (JPEG/PNG/WebP magic bytes), 5 MB, novo ime po
  uploadu. `StorageException` → `ApiError` sa porukom na bosanskom (tip, veličina, 401, 403).
- `SlikaPolje` (admin) u obrascu usluge (panel i telefon, „Detalji i slika") i radnika (umjesto
  ručnog URL-a). Snimanje je blokirano dok upload traje; greška je `liveRegion`.
- `image_picker` je nova zavisnost, uz odobrenje vlasnika repoa; admin iOS dobija `NSPhotoLibraryUsageDescription`.
- `melos run analyze` čist; `melos run test` PASS (admin +457, client +393, core_api +135 prije
  `media_repository_test` 6 novih, core_ui +104, core_domain +87).
- **Uživo, lokalni stack:**
  - usluga „Brada" → JPG → Sačuvaj; `services.image_url` = `…/salon-media/550e8400…/usluge/muiehm0k-gcuiklj4.jpg`, objekat `image/jpeg` 5609 B, javni URL `200`, anon katalog vraća isti URL;
  - klijent web (402×874) prikazuje sliku u cjenovniku;
  - radnik „Amar" → JPG → Sačuvaj; lista osoblja i klijentski „tim" na početnoj prikazuju novu sliku;
  - „Ukloni" daje praznu površinu sa ikonom, bez slomljene slike.
- `flutter-ui-reviewer`: nije našao curenje, hardkodiranu boju ni slučaj gdje neuspio upload mijenja sliku. Dalo je 7 nalaza:
  - popravljeno: snimanje za vrijeme uploada, tip po imenu, poruka za 401/403, liveRegion, labela;
  - provjereno: da „Ukloni" radniku ne radi nije tačno, RPC radi `nullif(btrim(...))`;
  - nije urađeno: test sa fontom 130 %.

**Ostalo za sljedećeg:**
- Drugi tenant (beauty) uživo — isti kod, nije viđen.
- Android/iOS izbor iz galerije — traži uređaj.
- Test sa fontom od 130 % za `SlikaPolje`.
- Tokom Playwright testa konzola je pokazala jednu grešku iz `change` događaja na file inputu. Pretpostavka je dvostruko `setFiles` (skript i MCP modal); u ručnom toku to nije provjereno.
- Zamka: poslije `pub add` web build može zadržati stari plugin registrant (v. `workflows.md`).
