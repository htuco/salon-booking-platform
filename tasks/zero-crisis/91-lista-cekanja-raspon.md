# Task 91 — Lista čekanja: „Obavijesti me ako se oslobodi ranije"

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [68](68-lista-cekanja.md) |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | [ADR-0031](../../docs/adr/0031-lista-cekanja-push-svima-prvi-zakaze.md) · `supabase/migrations/20261020140000_lista_cekanja.sql` · `get_available_dates` |

## Cilj
Upis na listu čekanja više nije jedan pun dan nego **raspon do prvog slobodnog termina**. Klijent
izabere uslugu (i radnika ili „bilo ko"), vidi prvi slobodan termin i može tražiti da ga se obavijesti
ako se mjesto oslobodi ranije. Kad neko otkaže bilo koji dan u tom rasponu, push dobiju svi upisani
istovremeno, a termin dobija ko prvi zakaže.

## Odluke (Hamza, 2026-10-21)
- **Raspon se ne bira, nego izračuna:** od danas (ili od izabranog dana) do **dana prije prvog
  slobodnog termina** za tu uslugu i radnika. Ako slobodnog termina nema u prozoru
  `max_advance_booking_days`, raspon ide do kraja prozora.
- Upis ima smisla samo kad u rasponu nema slobodnog vremena, a po definiciji ga nema.
- **Limit ostaje tri upisa po klijentu u salonu**, a raspon je **jedan upis** (jedna usluga sa svojim
  rasponom).
- **Upis nestaje** kad se desi prvo od: klijent dobije potvrđen termin te usluge bilo koji dan u
  rasponu; prođe zadnji dan raspona; klijent ga ukloni. Dani koji prođu otpadaju sa početka raspona.
- **Ostaje iz ADR-0031:** push svima kojima je baš to otkazivanje otvorilo vrijeme, jedan po
  klijentu, bez držanja termina; salon vidi samo broj, ne ko čeka.
- Cutlio i drugi sistemi pravila javno ne objavljuju; odluka je po uzoru na Zenoti i Acuity
  („obavijesti me ako se oslobodi ranije").

## Definicija gotovog
- [x] Dopuna ADR-0031 (ili nov ADR koji ga mijenja) sa odlukama iznad; red u `docs/README.md`
- [x] Šema: upis nosi raspon (`date_from`, `date_to`) umjesto jednog `date`; postojeći upisi se
      migriraju u raspon od jednog dana; jedinstvenost po (identitet, usluga, radnik) a ne po danu
- [x] `join_waitlist` računa raspon u bazi (prvi slobodan dan iz istog pravila slotova,
      `private.candidate_slots`), ne prima ga od klijenta; odbija upis kad je slobodan termin već danas
- [x] Okidač ponuda: otkazivanje bilo kojeg dana u rasponu budi upis, uz postojeće pravilo da je baš
      to otkazivanje otvorilo vrijeme za njegovu uslugu i radnika
- [x] Gašenje upisa: potvrđen termin te usluge bilo koji dan u rasponu; istek posljednjeg dana; dani
      koji prođu se ne nude (cron ili filter, po obrascu taska 64)
- [x] `my_waitlist`, `waitlist_full_dates` i `waitlist_demand` usklađeni sa rasponom; Melura i dalje
      vidi samo broj upisanih po danu (upis se broji na svaki dan koji pokriva)
- [x] Klijent: u koraku izbora termina „Prvi slobodan termin: <dan>" i „Obavijesti me ako se
      oslobodi ranije"; u „Moji termini" upis pokazuje raspon („do 30.10.")
- [x] pgTAP: raspon izračunat tačno (i kad nema slobodnog u prozoru); upis odbijen kad je slobodno
      danas; otkazivanje u rasponu budi, van raspona ne budi; potvrđen termin u rasponu gasi upis;
      prošli dani se ne nude; limit tri; tenant izolacija; svaka provjera pada kad se uslov ukloni
- [x] Dokumenti: `security.md` (Lista čekanja), `supabase/IMPLEMENTATION.md`, `CONTEXT.md`
      („upis na listu čekanja"), `prototype/ui/README.md`, status ovog taska i blok u README-u
- [x] Uživo na lokalnom stacku: salon pun 5 dana, upis „ranije", otkazivanje treći dan → ponuda;
      zakazivanje → upis nestaje

## Zamke
- **Migracija mijenja deployanu šemu** (68 je spojen u `develop`; provjeri je li deployan). Nova
  migracija, nikad izmjena `20261020140000`. Postojeći upisi i ponude u `notification_logs` moraju
  preživjeti.
- **Upis ne smije sam sebe ugasiti prvim slobodnim terminom.** Prvi slobodan termin je granica
  raspona, ne termin u njemu; gasi ga samo potvrđen termin klijenta.
- **Granica raspona se ne pomjera sama.** Ako se kasnije oslobodi nešto prije granice, to je ponuda,
  a ne nova granica. Ako se granični termin zauzme, upis ostaje do svoje granice (ne produžava se).
- `date_only` vertikala (health) i dalje nema listu čekanja, kao u 68.
- Upis kod radnika kojem se skine usluga i dalje ostaje (ostatak iz 68) — ako se rješava ovdje,
  dopiši u DoD.

## Status (2026-10-21) — 🟡 PR otvoren, čeka review i CI

Grana `feat/lista-cekanja-raspon`, [PR #146](https://github.com/htuco/salon-booking-platform/pull/146).
Dopuna ADR-0031 („Dopuna 2026-10-21"), migracija `20261021191123_lista_cekanja_raspon`.

**Dokazano (pr91 stack, odvojen od Hamzinog):**

- `./tool/test_supabase.sh`: `Files=35, Tests=1168, Result: PASS`; REST izolacija 24, javni
  katalog 62, ostali REST zeleni. `033` usklađen (65), novi `036` (65).
- 33 mutacije nad `033` + `036` (tabela u `security.md`, „Lista čekanja"): svaka obara bar jednu
  aserciju, osim `candidate_slots` bez zaštite prošlog dana — tu drži druga zaštita (slot ≥ sada);
  bez obje pada 1.
- Migracija nad starim podacima (`db reset --version 20261020180000`, pa `migration up`): četiri
  upisa (tri dana „Bilo ko" i jedan kod Emira) → dva raspona (`27.–30.10.` i `28.10.`), sve četiri
  ponude preživjele sa svojim danom; od dvije ponude koje su čekale slanje istom uređaju jedna je
  `logged`/`waitlist_merged`.
- `melos run test`: client 691, admin 726, core_domain 107, core_api 159; analyze bez novih nalaza.
- Uživo (web 402, Barber Studio Vitez): šišanje puno 22, 23, 24, 26. i 27.10.; izbor 22. → „Prvi
  slobodan termin: srijeda, 28.10.2026."; upis → `[2026-10-22, 2026-10-27]`; salon otkaže 24.10. u
  09:00 → `waitlist_offer` sa danom `2026-10-24`, Obavijesti „Muško šišanje · subota 24.10.";
  zahtjev za 24.10. (`pending`) upis ostavlja, potvrda ga briše. Otkazivanje u 10:10 (van koraka
  od 15 min) ne otvara slot i ne šalje ponudu — kako i treba. Snimci `docs/screenshots/task-91-*.png`.
- `rls-auditor` i `flutter-ui-reviewer` nad diffom; nalazi popravljeni (grantovi u testu, panel
  van raspona, dugme koje se reže na 402, prozor kalendara za dan kraći od baze).

**Odluke donesene u radu** (u ADR-u): istek je filter **i** cron `expire-waitlist`; raspon mora
imati bar jedan pun dan; `date_only` se odbija i u bazi; duplikati istog ključa se pri migraciji
spajaju u jedan raspon; dugme je „Javi mi ako se oslobodi ranije" (puna rečenica se reže na 402).

**Nije provjereno:** push na stvarnom uređaju (web nema push; uređaj sa tokenom je ubačen SQL-om);
da li je `20261020140000` (68) već na hostovanom — ako jeste, postojeći upisi idu kroz spajanje
iznad.

**Ostaje:** review, CI, merge; deploy (Hamza) `supabase db push` — migracija 68 i 72 prije, i
redoslijed sa #144 (v. PR). Upis kod radnika kojem se skine usluga i dalje ostaje (ostatak iz 68,
nije rješavan ovdje).
