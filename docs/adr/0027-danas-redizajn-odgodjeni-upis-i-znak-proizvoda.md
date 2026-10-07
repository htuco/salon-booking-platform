# Danas je radna površina iz `adminv2/danas`; „Poništi" odgađa upis; Melura dobija znak

## Status

prihvaćen. Dopunjuje [ADR-0020](0020-admin-je-1na1-sa-adminv2-barlow-i-svijetla-tema.md):
za ekran Danas izvor istine je `prototype/adminv2/danas/` (prikazi `6a`–`6m`), ne `3b`/`3k`.
Zatvara „Dizajn prije koda" iz taska 55.

## Kontekst

Handoff `design_handoff_danas` (2026-10-01) zamjenjuje `3b`/`3k`: redoslijed „šta čeka odgovor →
šta slijedi → brojke", blok „je li došao?", vremenska linija sa „Sad", kontekstni panel na
2560 i undo toast za potvrdu (`6m`). Pregled handoffa je našao mjesta koja se sudaraju sa
podacima ili sa pravilima repoa; vlasnik proizvoda je usvojio verziju sa ispravkama
(`prototype/adminv2/danas/`, sekcija „P").

Četiri činjenice iz koda su odlučile:

1. `set_appointment_status` prima samo `confirmed`, `completed`, `no_show` — potvrda se ne
   može vratiti na `pending`.
2. Isti RPC uvećava `visit_count` i `no_show_count`, a vraćanje statusa ih ne umanjuje.
3. Push klijentu polazi sa servera pri promjeni statusa; odgođene obavijesti nema.
4. Rječnik vertikale (`VerticalTerms`) ima samo `staffSingular`; nema genitiva množine, a
   `employees` nema rod.

## Odluka

- **„Poništi" odgađa upis, ne vraća ga.** Potvrda, „Završeno" i „Nije došao" se na ekranu
  vide odmah, a RPC ide kad istekne rok od 5 s (`odgodjene_akcije.dart`). Sve što čeka se upiše
  odmah kad aplikacija ode u pozadinu. Odbijanje ide odmah, uz dijalog sa razlogom (`6l`).
- **Zahtjevi su poredani po vremenu termina**, danas prije sutra, ne po čekanju — zahtjev za
  danas u 18:00 ističe prije onog za sutra.
- **Tekst bez padeža imena i roda:** „· Emir" umjesto „kod Emira", „U smjeni 3" umjesto
  „3 majstora u smjeni", „Odabrana osoba ne radi u to vrijeme".
- **Razlog odbijanja „čuva se uz termin"**, ne „klijent ga vidi" — ni push ni klijentska
  aplikacija `cancel_reason` ne čitaju.
- **Telefon pokazuje jedan zahtjev**, ostali iza „Još N", da „Sljedeći" stane na prvi ekran.
- **„Ostatak dana" na desktopu ima prikaz Kalendar** (ista mreža kao `3c`, kolona po radniku)
  pored liste iz `6a`. Kalendar je podrazumijevan; telefon ostaje lista.
- **Radnik nema „Novi termin" ni „Blokiraj vrijeme"** iako ih `6d` crta: oba traže `is_admin`
  (task 47), a `employee_blocks` je samo `select`.
- **Melura dobija znak** (`apps/admin/assets/brand/`): „M" od dva bloka termina iste širine i
  zrcalnog oblika, koralni `#EE6C4D` i plavi `#3D5A80` (na tamnoj podlozi `#6F8FBF`).
  Zamjenjuje placeholder `LOGO` iz `3b`/`3j` u sidebaru, na prijavi, u faviconu i u ikonama.

## Razmatrane opcije

- **Upis odmah, „Poništi" vraća status** — odbačeno: traži migraciju (`pending` u RPC-u) i
  korekciju brojača, a klijent bi dobio obavijest pa ispravku.
- **Redoslijed po čekanju, kako `6a` piše** — odbačeno: hitniji je zahtjev koji ranije ističe.
- **Genitiv i rod u rječniku vertikale** — odgođeno, ne odbačeno: vraća se kad
  `VerticalTerms` dobije `staffGenitivePlural` i radnik rod; do tada rečenica bez padeža.
- **Znak sa kosinom i šiljkom (prvi ChatGPT prijedlozi)**, **„Termin i sada" kao znak** —
  odbačeno kao znak; „Termin i sada" ostaje animacija učitavanja (task 63).

## Posljedice

- Akcija postoji samo u memoriji do 5 s. Zatvoren tab poslije `hidden` je upiše; pad
  preglednika bez tog događaja je gubi — vlasnik tada vidi zahtjev ponovo na čekanju.
- RPC koji padne poslije roka javlja grešku toastom; red je do tada već nestao sa ekrana.
- Toast koji hover zadrži duže od roka nudi „Poništi" za akciju koja je već upisana — tada
  kaže „Prekasno za poništavanje".
- Novi zahtjev uživo ne klizi u listu (handoff traži 320 ms): realtime osvježi listu i red se
  pojavi na mjestu.
