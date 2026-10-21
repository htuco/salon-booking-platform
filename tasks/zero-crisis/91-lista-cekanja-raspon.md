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
- [ ] Dopuna ADR-0031 (ili nov ADR koji ga mijenja) sa odlukama iznad; red u `docs/README.md`
- [ ] Šema: upis nosi raspon (`date_from`, `date_to`) umjesto jednog `date`; postojeći upisi se
      migriraju u raspon od jednog dana; jedinstvenost po (identitet, usluga, radnik) a ne po danu
- [ ] `join_waitlist` računa raspon u bazi (prvi slobodan dan iz istog pravila slotova,
      `private.candidate_slots`), ne prima ga od klijenta; odbija upis kad je slobodan termin već danas
- [ ] Okidač ponuda: otkazivanje bilo kojeg dana u rasponu budi upis, uz postojeće pravilo da je baš
      to otkazivanje otvorilo vrijeme za njegovu uslugu i radnika
- [ ] Gašenje upisa: potvrđen termin te usluge bilo koji dan u rasponu; istek posljednjeg dana; dani
      koji prođu se ne nude (cron ili filter, po obrascu taska 64)
- [ ] `my_waitlist`, `waitlist_full_dates` i `waitlist_demand` usklađeni sa rasponom; Melura i dalje
      vidi samo broj upisanih po danu (upis se broji na svaki dan koji pokriva)
- [ ] Klijent: u koraku izbora termina „Prvi slobodan termin: <dan>" i „Obavijesti me ako se
      oslobodi ranije"; u „Moji termini" upis pokazuje raspon („do 30.10.")
- [ ] pgTAP: raspon izračunat tačno (i kad nema slobodnog u prozoru); upis odbijen kad je slobodno
      danas; otkazivanje u rasponu budi, van raspona ne budi; potvrđen termin u rasponu gasi upis;
      prošli dani se ne nude; limit tri; tenant izolacija; svaka provjera pada kad se uslov ukloni
- [ ] Dokumenti: `security.md` (Lista čekanja), `supabase/IMPLEMENTATION.md`, `CONTEXT.md`
      („upis na listu čekanja"), `prototype/ui/README.md`, status ovog taska i blok u README-u
- [ ] Uživo na lokalnom stacku: salon pun 5 dana, upis „ranije", otkazivanje treći dan → ponuda;
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

## Status
U toku (grana `feat/lista-cekanja-raspon`, 2026-10-21).
