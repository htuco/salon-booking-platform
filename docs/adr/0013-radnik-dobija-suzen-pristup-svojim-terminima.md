# Radnik dobija sužen pristup svojim terminima

## Status

prihvaćen

## Kontekst

`docs/01 §5.3` od početka razdvaja dvije faze: u Fazi 1 radnik postoji kao **resurs** (ima usluge,
raspored, termine), ne kao korisnik, a u Fazi 2 dobija login u istu admin aplikaciju i vidi **samo
svoje** termine. Task 33 je tu granicu zapisao i kao zamku: „`employees` je osoblje salona;
`public.users` + `auth_identities` su prijava. Spajanje to dvoje daje radniku pravo prijave koje mu
niko nije dao."

Novi podatak je proizvodni: salon traži da radnik upravlja svojim terminima. To otvara Fazu 2 i
traži odluku prije koda, jer dira model autorizacije.

Zatečeno stanje je polovično na način koji vara. `staff_role` enum **već ima** vrijednost
`employee`, ali je nijedna politika ne prihvata: `private.is_admin()` traži `salon_admin` i u JWT-u
i u redu `public.users`, a `private.is_client()` izričito isključuje `employee`. Nalog sa tom
ulogom danas nema **nijedno** pravo — niti je osoblje niti klijent. Uz to `public.users` nema
kolonu koja bi nalog vezala za red u `employees`, pa baza ne bi znala ni koji je radnik u pitanju.

## Odluka

Radnik dobija vlastitu ulogu i **sužen** pristup, ne umanjenu admin ulogu.

- `public.users.employee_id` vezuje nalog za red u `employees`, i obavezan je kad je uloga `employee`.
- Autorizacija ide kroz nove `private.is_employee(p_salon)` i `private.current_employee_id()`, ne
  kroz proširenje `private.is_admin()`. `is_admin` ostaje ono što je i bio — pun pristup salonu.
- Politike se pišu nanovo za radnika, a **ne** dopunjuju postojeće. Svaka politika koja danas glasi
  „osoblje = admin" mora biti pregledana, jer je pisana pod pretpostavkom koja prestaje važiti.
- Radnik vidi i mijenja svoje termine. Cjenovnik, osoblje i postavke salona nisu njegovi.

## Zašto ne jednostavnije

**Dati radniku `salon_admin`** je najmanje posla i najgori ishod: radnik bi vidio promet salona,
tuđe klijente i cjenovnik. Zahtjev je bio suprotan — „da manageuje svoje termine".

**Proširiti `is_admin()` da prima i `employee`** bi jednim potezom otvorilo sve što danas stoji na
toj funkciji, uključujući cjenovnik i postavke. Funkcija koja znači dvije različite stvari zavisno
od pozivaoca je mjesto gdje curenje nastaje tiho.

**Filtrirati samo na ekranu** nije izolacija. Sakriven modul je i dalje dostupan kroz URL i kroz
PostgREST; ekran prati politiku, ne zamjenjuje je.

## Posljedice

- Termin **bez** dodijeljenog radnika (`employee_id is null`) nije ničiji. Vidi li ga radnik je
  odluka koja se donosi u tasku 46 i zapisuje — tiho izostavljanje znači da termin nestane iz svih
  pogleda osim admin.
  **Odlučeno u tasku 46:** takav termin vidi samo admin. Radnik bi inače vidio klijente koji nisu
  njegovi; dodjela radniku je posao admina, a termin i dalje stoji u admin pogledu.
- Deno REST test sa stvarnim JWT-om radnika je obavezan uz pgTAP: pgTAP ne dokazuje PostgREST sloj.
- Prije ovoga mora postojati način da se nalog uopšte napravi (task 45) — danas ga nema ni za
  `salon_admin`.
