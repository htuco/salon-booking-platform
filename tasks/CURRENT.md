# Trenutni task: 40 — Naziv lokala se ne mijenja iz admina

Učitan 2026-09-23 iz [sprint-4/40](sprint-4/40-naziv-lokala-se-ne-mijenja.md). Popravka,
procjena 0,5 dana, bez zavisnosti i bez taskova koje blokira.

## Status

U toku na grani `fix/naziv-lokala-zakljucan`.

## Ciljevi

- [x] U admin postavkama prikazati naziv salona samo za čitanje i objasniti da se naziv aplikacije
      mijenja kroz novi store build
- [ ] Novom migracijom učvrstiti `update_salon_contact`: pokušaj slanja drugačijeg naziva mora
      vratiti grešku, dok ostali kontakt podaci ostaju promjenjivi
- [x] Prilagoditi Dart ugovor i testove zaključanom nazivu bez otvaranja drugog puta pisanja
- [ ] Dodati negativan pgTAP slučaj koji pokušava promijeniti naziv i dokazuje da je red netaknut
- [x] Zapisati puni put promjene naziva: `tenants/<flavor>/tenant.yaml` →
      `dart run tool/gen_flavors.dart` → novi store build/submission

## Napomene

- Danas je naziv stvarno promjenjiv na oba sloja: `settings_screen.dart` crta obični
  `TextFormField`, a `update_salon_contact` prima `p_name` i radi `set name = btrim(p_name)`.
  Postojeći testovi čak tvrde „Naziv je upisan", pa moraju biti promijenjeni zajedno s ugovorom.
- Direktan `UPDATE public.salons` je već oduzet roli `authenticated`; RPC iz taska 36 je jedini
  aplikacijski put pisanja. Zaštita zato pripada novoj migraciji, ne izmjeni već deployane
  `20260921180000_postavke_lokacije.sql`.
- Postojeći potpis RPC-a može ostati kompatibilan tako da `p_name` služi kao tvrdnja o zatečenom
  nazivu, ali mora odbiti različitu vrijednost i nikad je ne upisati. Time PostgREST i postojeći
  klijenti ne dobijaju paralelno preopterećenje funkcije.
- Build-time izvor već postoji: oba `tenant.yaml` fajla nose `app.displayName`, a
  `tool/gen_flavors.dart` iz njega generiše Android `app_name`, iOS `PRODUCT_NAME` i Dart tenant
  registar. Nedostaje eksplicitna uputa da promjena traži novi build i store submission.
- `x-salon-id` ne daje pravo izmjene; RPC i dalje mora tražiti `private.is_admin(p_salon_id)`.
  Nova `security definer` verzija zadržava `set search_path = ''` i potpuno kvalifikovane reference.
- Otvoreno pitanje o zasebnom runtime prikaznom nazivu ostaje van ovog taska; nova kolona bez ADR-a
  se ne uvodi.
- Procjena ostaje 0,5 dana: šema i jedini write put već postoje, ali promjena prelazi migraciju,
  pgTAP, `core_api`, admin ekran i njihove testove.
- Dokaz u ovom prolazu: `settings_screen_test.dart` **16/16**, `catalog_repository_test.dart`
  **18/18**, `flutter analyze apps/admin packages/core_api` čist i `gen_flavors --check` potvrđuje
  dva ažurna tenanta. pgTAP još nije pokrenut jer na mašini nema ni `supabase` CLI-ja ni Dockera.

## Istorija

### FE-403 — Kalendar termina (gotov)

Spojen u `main` ([PR #72](https://github.com/htuco/salon-booking-platform/pull/72)). Zahtjev na
odobrenju nosi isprekidan rub na mreži, u listi i u legendi — razlika **oblikom**, ne samo bojom.
309 testova PASS, viđeno na 1440×900, 402×874 i u tamnoj temi. Prekidač dan/sedmica i realtime
osvježavanje ostali **imenovan dug** — oba traže ADR jer ih `prototype/admin/SPEC.md` izričito
izostavlja. Time je admin blok FE-401…FE-406 zatvoren.

### FE-404 — Usluge, osoblje i klijenti (gotov)

Spojen u `main` ([PR #71](https://github.com/htuco/salon-booking-platform/pull/71)).
Terminologija po vertikali umjesto „Majstor" iz canvasa, zelen CI na oba joba.

### 39 — Push obavijesti na Androidu (gotov)

Zatvoren uživo 2026-09-22 i spojen u `main`: migracija za `auto` mod je na hostovanom projektu,
admin Firebase aplikacija i staff uređaj su registrovani, a push je dokazan u oba smjera. Zvuk i
vlastiti Android kanal spojeni su zasebno kroz PR #80. iOS push ostaje imenovan dug do Apple
developer naloga.
