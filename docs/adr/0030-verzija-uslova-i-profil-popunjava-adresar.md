# Verzija uslova je eksplicitna, a profil klijenta adresar salona samo popunjava

## Status

prihvaćen (2026-10-13) — razrađuje [ADR-0029](0029-opseg-do-lansiranja-zero-crisis.md) za task 66.

## Kontekst

ADR-0029 je odlučio da registracija traži ime, telefon i checkbox uslova, i da se prihvatanje
bilježi „sa verzijom". Kod taska 66 su se otvorila dva pitanja na koja ni ADR ni kod ne odgovaraju:

- **Šta je verzija?** `app_policies` i `salon_policies` nemaju kolonu verzije, samo `updated_at`
  po sekciji. Sekcije se mijenjaju zbog tipfelera, a `salon_policies` mijenja i svaki salon za
  sebe.
- **Ko pobjeđuje kad se profil i adresar raziđu?** Ime i telefon su na identitetu (osoba), a
  `customers` je red po salonu, koji salon smije ispraviti u svom adresaru. `ensure_customer` od
  taska 14 namjerno ne prepisuje ime (`on conflict do nothing`), upravo zbog salonovih ispravki.
  Do taska 66 su svi email klijenti u adresaru bili „Klijent / Bez broja".

## Odluka

**Verzija uslova je eksplicitan broj koji platforma podiže ručno.** Važeća verzija oba dokumenta
je konstanta u `public.legal_versions()`, a podiže se **novom migracijom** kad se dokument
suštinski promijeni. Identitet pamti prihvaćenu verziju svakog dokumenta i vrijeme. Profil sa
starijom verzijom pri sljedećoj prijavi prolazi kroz „Dopuni profil", gdje vidi samo checkbox.

**Identitet adresar salona samo popunjava, nikad ne prepisuje.** Ime se upisuje samo preko
„Klijent" (fallback iz `ensure_customer`) ili praznog, a telefon samo preko praznog. Salonova
ispravka uvijek pobjeđuje. Isto pravilo važi za denormalizovano ime i telefon na terminima.
Popunjavanje radi trigger nad `auth_identities`, u svakom salonu tog identiteta, i dira isključivo
redove tog identiteta.

**Broj koji salon već ima na drugom klijentu se ne kopira.** Poredi se po ciframa. Isti broj na
telefonskom klijentu znači vjerovatno istog čovjeka, ali spajanje dva reda je odluka salona iz
admin ekrana, ne baze (v. `upsert_walkin_customer`, task 24).

## Razmatrane opcije

- **Verzija kao `max(updated_at)` sekcija** — odbačeno: ispravka zareza, ili izmjena salonske
  sekcije, tražila bi ponovno prihvatanje od svih korisnika. Ponovno prihvatanje koje se dešava
  zbog tipfelera korisnik nauči da klikne bez čitanja.
- **Tabela verzija bez `salon_id`** — odbačeno: treći izuzetak od zlatnog pravila (uz
  `vertical_packs` i `app_policies`) za dva broja, sa svojim grantom, politikom i negativnim
  testom. Konstanta u funkciji se mijenja kroz isti pregled kao svaka druga promjena šeme.
- **Profil uvijek prepisuje adresar** — odbačeno: briše salonove ispravke („Ana iz Viteza" →
  „Ana"), i to tiho, pri svakoj prijavi tog klijenta.
- **Telefon iz profila spaja klijenta sa telefonskim po broju** — odbačeno: broj ne dokazuje da
  je to isti čovjek (task 24 je to već odbio za `ensure_customer`).

## Posljedice

- Promjena teksta uslova **ne traži** ponovno prihvatanje dok neko ne podigne verziju u
  migraciji. Ko mijenja dokument suštinski, mora i to.
- Klijent koji promijeni ime u profilu (task 82) ga **neće** vidjeti promijenjenog u salonu koji
  ga je već imao pod imenom. To je namjerno: adresar je salonov.
- Klijent kojem je broj preskočen zbog sudara u jednom salonu ima „Bez broja" u tom salonu, a broj
  u svim ostalim. Izgleda kao bug, a znači da salon ima dva reda za istog čovjeka.
- Prihvatanje uslova pri registraciji putuje kroz metapodatke `signUp`-a (sesije tada nema kad je
  potvrda emaila uključena), a baza ga čita **samo pri nastanku naloga**. Ponovno prihvatanje ide
  samo kroz `complete_my_profile`, sa sesijom.
