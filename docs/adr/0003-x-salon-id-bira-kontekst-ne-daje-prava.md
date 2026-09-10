# `x-salon-id` bira kontekst, nikad ne daje prava

## Status

prihvaćen

## Kontekst

Ista osoba može biti klijent u više salona: jedan globalni identitet (`auth_identities`), više
per-salon zapisa (`customers`). Aplikacija je uvijek u **jednom** salonu — to je brandirani build
sa svojim `SALON_ID`. Baza mora znati u kojem salonu klijent trenutno gleda svoje termine.

Očigledno rješenje — da klijent pošalje `salon_id` uz upit — nosi očiglednu zamku: pošiljalac bira
tu vrijednost. Ako ona ulazi u odluku o pristupu, klijent bira svoja prava.

## Odluka

Klijentska app šalje header `x-salon-id`. `private.client_salon_id()` ga pročita i vrati **samo ako
je to aktivan salon**; u svakom drugom slučaju vraća `NULL`, uključujući neispravan UUID (hvata se
`invalid_text_representation`).

Header **sužava** pogled i nikad ga ne proširuje. Svaka klijentska politika traži **oba** uslova:
`salon_id = private.client_salon_id()` **i** `private.owns_identity(auth_identity_id)`. Header kaže
gdje gledam; identitet kaže šta je moje.

`NULL` znači "nema konteksta". Pošto `salon_id = NULL` nikad nije istinito, nedostajući ili
pokvaren header daje prazan rezultat — ne globalni pogled.

Isto načelo važi i za ulogu: `app_metadata.role` sam po sebi ne znači ništa. `private.is_admin()` i
`private.is_super_admin()` traže i claim **i** odgovarajući red u `public.users`.

## Razmatrane opcije

- **`salon_id` kao parametar upita, bez politike** — odbačeno: filtriranje koje bira pozivalac nije
  izolacija.
- **Salon iz JWT claima za klijente** — odbačeno: klijent nije član salona, i ista osoba je klijent
  u više salona; to bi tražilo novi token po salonu.
- **Bez konteksta, klijent vidi svoje redove u svim salonima** — odbačeno: salon ne smije saznati
  da klijent ide i kod konkurencije, a app ionako radi u jednom salonu.
- **Podrazumijevati salon kad header fali** — odbačeno: podrazumijevana vrijednost u sigurnosnoj
  odluci je rupa koja čeka pogrešnu pretpostavku.

## Posljedice

- Svaki klijentski zahtjev za privatne podatke **mora** nositi header; bez njega odgovor je prazan,
  ne greška. To izgleda kao bug ("nema mojih termina") i prvo se provjerava header.
- Nova klijentska politika bez oba uslova je rupa; `rls-auditor` to traži eksplicitno.
- Deaktivacija salona odmah gasi klijentski pristup, jer `private.salon_active()` ulazi u lanac.
