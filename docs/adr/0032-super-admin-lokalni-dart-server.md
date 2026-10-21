# Super admin konzola: lokalni Dart server, baza prva, vlasnik kroz poziv

## Status

prihvaćen (2026-10-21) — razrađuje [ADR-0029](0029-opseg-do-lansiranja-zero-crisis.md) za task 72.
Predložen 2026-10-20; Hamza ga je prihvatio u reviewu PR-a #143, uz popravke koje su ušle u ovaj
tekst (UUID po okruženju, povlačenje poziva, rezervisana imena flavora).

## Kontekst

ADR-0029 kaže da je super admin konzola lokalni alat na mašini developera, nikad deployan, mali i
jasan. Task 72 ostavlja tri pitanja: tehnologija, šta alat piše (fajl ili bazu) i gdje stoji
service role ključ. Danas novi salon nastaje ručno, u četiri koraka koja se lako raziđu:

- blok u `supabase/seed.sql` (salon, `salon_builds`, `salon_settings`, usluge, radno vrijeme), koji
  se ručno pušta i na hostovani projekat (Amko, Authentic);
- `tenants/<flavor>/tenant.yaml` sa **istim** UUID-om i **istim** bojama;
- `gen_flavors.dart`, placeholder ikona, `flutter_launcher_icons`;
- admin nalog vlasnika rukom u `auth.users` i `public.users`. `security.md` opisuje dvije zamke tog
  posla koje se vide tek na ekranu za prijavu.

U šemi već postoji sve što konzola treba čitati: `salons.status` (`active`/`inactive`) i
`salon_builds` sa `play_store_status` i `app_store_status` (`draft` → `in_review` → `live`). Nijedan
red koda ih ne piše. Poziv sa kodom (task 45, ADR-0023) već pravi ispravan nalog osoblja, a Melura
ima ekran „Imam poziv od salona". Jedino ga ne može napraviti niko izvan salona: `create_staff_invite`
traži admina tog salona, a `staff_invites.created_by` je `not null`.

Mašine tima su Windows i macOS. Flutter desktop na Windowsu traži Visual Studio toolchain, kojeg na
razvojnim mašinama nema.

## Odluka

**1. Tehnologija: mali Dart server na `127.0.0.1` i jedna HTML stranica** (`apps/superadmin`, čisti
Dart paket u workspaceu). `dart run superadmin` pokrene server i ispiše adresu, a stranica je
vanilla HTML i JS bez build koraka. Server je jedino mjesto koje drži ključ. Samo on čita i piše
fajlove i pokreće generatore. Stranica dobija samo ono što smije vidjeti: liste, statuse i
jednokratni kod poziva.

- Server sluša **samo na loopbacku** i API odbija zahtjev bez tokena sesije. Token je nasumičan
  pri svakom pokretanju i stoji samo u ispisanoj adresi. Stranica ga spremi u `sessionStorage`
  taba i skloni iz adresne trake. Samu stranicu server daje i bez tokena, jer je to statičan HTML
  bez ijednog podatka i bez ključa; zato F5 radi. Server odbija i zahtjev čiji `Host` ili `Origin`
  nije njegov (zaštita od DNS rebindinga i od tuđe stranice u istom pregledniku).
- Oblik stranice prati platformu (radius 0, hairline granice, ista tipografska skala). Konzola nije
  brendirana, pa nema boje tenanta.

**2. Baza prva, pa fajl, pa generatori.** „Novi salon" jednim pozivom
`platform_create_salon` upiše `salons`, `salon_builds` i `salon_settings` (početne vrijednosti iz
`vertical_packs.default_settings`) u istoj transakciji. Tek poslije uspjeha server napiše
`tenants/<flavor>/tenant.yaml` sa **istim** UUID-om, bojama i temom, pa pokrene
`tool/gen_flavors.dart` i `tool/gen_placeholder_icons.dart`. Ako fajl ili generator padnu, salon u
bazi ostaje. Bez fajla konzola nudi „Napiši tenant.yaml" iz reda u bazi, a sa fajlom „Ponovi
generatore" (i kad padne upis ikone, koji je svoj korak). Obrnut redoslijed bi ostavio fajl sa
UUID-om koji ne postoji, što je po `tenant-factory.md` najskuplja tiha greška.

- **UUID salona je isti u svakom okruženju.** Prvo okruženje u kojem salon nastane (obično
  produkcija) UUID izmisli. Svako sljedeće ga upiše **iz `tenant.yaml`-a**: lista „Tenanti bez
  reda u ovoj bazi" nudi „Upiši u ovu bazu iz tenant.yaml", a to je isti
  `platform_create_salon` sa `p_id` = `salonId` iz fajla. Fajl se tada ne piše i generatori se ne
  pokreću. Lokalni stack poslije `db reset` tako dobija salon jednim klikom. Zauzet UUID je
  `PT409`. Naziv salona i grad nisu polja fajla; konzola ih predloži iz prvog komentara koji sama
  piše (`# Naziv (Grad) — …`), a developer potvrdi.
- Flavor ne smije počinjati sa `test`, niti biti `lint`, `main` ili ime build tipa (`debug`,
  `profile`, `release`). `[a-z][a-z0-9]*` to pušta, a Android Gradle Plugin takav flavor odbija i
  pada sync **svih** tenanata. Konzola flavor izvodi iz naziva („Test Salon" → `testsalon`), pa
  pravilo drže i baza (`private.is_reserved_flavor`) i `gen_flavors.dart`.

- Promjena boja i teme ide u bazu (`platform_set_branding`) **i** u `branding` blok
  `tenant.yaml`-a (fallback mora biti isti, inače treptaj boje). U fajlu se mijenjaju samo te tri
  linije, pa komentari i ostala polja ostaju kako ih je čovjek napisao.
- Usluge, radnike i radno vrijeme konzola ne piše. To je posao vlasnika u Meluri (task 71 ga vodi
  kroz prvi ulazak). Logo salona isto: mijenja se bez store reviewa, pa ga vlasnik postavlja iz
  Melure (task 50). Konzola prima samo **ikonu aplikacije**, jer je ona build artefakt
  (`tenants/<flavor>/assets/icon.png`).
- `supabase/seed.sql` konzola ne dira. Seed ostaje za demo fixture. Pravi salon nastaje u jednom
  okruženju, a ostala (i lokalni stack poslije `db reset`) ga upišu iz `tenant.yaml`-a sa istim
  UUID-om, kao gore.
- Koraci koje ni jedan alat ne smije uraditi za developera ostaju kao **lista u konzoli**, sa
  stanjem koje se može provjeriti: flavor u tri CI matrice (`flutter-build.yml` se čita, ne piše),
  `gen_ios_flavors.sh` na macOS-u, OAuth klijenti i redirect URL.

**3. Ključ: iz okruženja procesa, nikad iz repoa ni iz stranice.**

- `dart run superadmin` bez argumenata uzima URL i service ključ iz `supabase status -o json`
  lokalnog stacka. To je podrazumijevani način rada; posebnog flaga za njega nema.
- `dart run superadmin --env <fajl>` čita `SUPABASE_URL` i `SUPABASE_SERVICE_ROLE_KEY` iz fajla
  koji je ignorisan u gitu (`.env.*`). Relativna putanja je od foldera iz kojeg je komanda
  pokrenuta. `.env.live` ostaje bez service ključa, kako `.env.example` traži. Produkcijski fajl
  nastaje u tasku 80, na Hamzinoj mašini.
- Ključ se ne ispisuje, ne loguje i ne šalje stranici. Konzola u zaglavlju pokazuje **na koji
  host** piše, a za ne-lokalni host traži da se ime projekta otkuca prije svakog upisa: ref
  projekta za `<ref>.supabase.co`, a cijeli host za svaki drugi (custom domen `api.x.ba` bi inače
  tražio samo „api").

**4. Platformska prava su u RPC-ovima koje smije zvati samo `service_role`.** `platform_*`
funkcije (`list_salons`, `list_themes`, `create_salon`, `set_salon_status`, `set_branding`,
`set_store_status`, `create_owner_invite`, `revoke_owner_invite`) imaju `revoke ... from public,
anon, authenticated` i `grant execute ... to service_role`, isti obrazac kao `peek_staff_invite`.
Validacija je u bazi (flavor i rezervisana imena, slug, boje, tema, ID aplikacije, UUID, kontrolni
znakovi u nazivu, gradu i imenu aplikacije), ne u konzoli, pa ručni poziv ne zaobilazi pravila.
Lista tema je samo u bazi (`private.known_themes`); konzola je čita, a da se slaže sa `core_ui`
drži test.

**5. Vlasnik dobija nalog kroz poziv, ne kroz ručni SQL.** `platform_create_owner_invite` pravi
`salon_admin` poziv sa `created_by = null`, što znači „platforma". Kod se vidi jednom, vlasnik ga
unese u Meluri na „Imam poziv od salona", a `accept-staff-invite` pravi nalog kao i za svako osoblje.
Obje zamke iz `security.md` (claim bez reda, `NULL` u `auth.users`) time nestaju za nove salone.

- Novi poziv platforme **povlači prethodne otvorene pozive platforme** za isti salon, pa svaki
  klik ne ostavlja još jedan važeći vlasnički kod. Otvoren poziv se može i povući
  (`platform_revoke_owner_invite`, dugme „Povuci poziv"). Pozive koje je napravio salon platforma
  ne dira.
- Ovo ne zatvara stari put: **`super_admin` JWT i dalje pravi poziv vlasnika za bilo koji salon
  kroz `create_staff_invite`** (`private.is_admin` počinje sa `is_super_admin()`), i piše
  `salon_builds` kroz politiku `super_builds`. To je postojeća rupa iz `security.md` §„Šta još
  nije zatvoreno" i zatvara se zasebnim taskom, ne ovim.

## Razmatrane opcije

- **Flutter desktop sa `core_ui`** — odbačeno: na Windowsu traži Visual Studio, a dijeljenje
  `core_ui` donosi tenant temu u alat koji nije tenant. Flutter app bi i dalje morala sama čitati
  ključ i pokretati procese, a to je upravo ono što server radi bez ijedne zavisnosti.
- **Flutter web** — odbačeno: ključ bi završio u JS bundleu u pregledniku, a web ne može pisati
  `tenant.yaml` ni pokrenuti generator.
- **Uloga `platform_admin` u Meluri** — odbačeno već u ADR-0029: platformska prava u aplikaciji
  salona su nova površina za curenje između tenanata.
- **Konzola piše samo `tenant.yaml`, a baza se puni iz fajla** — odbačeno: fajl bi morao nositi
  podatke koji se mijenjaju bez store reviewa (status, boje u bazi), što krši pravilo iz
  `tenant-factory.md`. UUID bi pritom nastajao na dva mjesta.
- **Konzola dopisuje blok u `seed.sql`** — odbačeno: seed je fixture, a ne registar pravih salona.
  Pravi podaci (telefon vlasnika) bi završili u javnom repou.
- **Konzola mijenja CI matrice u `flutter-build.yml`** — odgođeno, ne odbačeno: matrica je YAML sa
  tri različita oblika reda. Alat koji ga prepisuje bez parsera bi jednom pogriješio za sve
  tenante. Konzola zato samo provjerava i pokazuje šta fali. Vraća se kad matrica bude izvedena iz
  `tenants/` (`docs/04` §8.1).

## Posljedice

- `staff_invites.created_by` postaje nullable; `null` znači poziv platforme. Lista „na čekanju" u
  Meluri prikazuje i taj poziv, jer ga čita po salonu.
- Novi `apps/superadmin` je u `workspace:` listi i u `melos` skriptama (analyze, test). Nema
  Fluttera, pa se testovi pokreću i na mašini bez Flutter SDK-a.
- Pravilo „`salonId` mora odgovarati redu u `seed.sql`" postaje „redu u bazi okruženja". Za demo
  tenante je to i dalje seed.
- Konzola koja padne između baze i fajla ostavlja salon bez `tenant.yaml`-a. Lista to pokazuje
  („nema tenant.yaml") i nudi da se fajl napiše ponovo.
- `platform_create_salon` prima `p_id`, pa `tenant.yaml` postaje izvor UUID-a za svako okruženje
  osim prvog. Fajl koji postoji bez reda u bazi nije greška nego „upiši me": lista ga nudi sa
  akcijom „Upiši u ovu bazu iz tenant.yaml".
- Rezervisano ime flavora odbija i `gen_flavors.dart`, pa ni ručno pisan `tenant.yaml` ne može
  oboriti Gradle za sve tenante.
- Deaktiviran salon nestaje iz klijentske aplikacije odmah (`private.salon_active`), a poziv za
  njega se više ne može prihvatiti (`peek_staff_invite`). To je očekivano ponašanje, ne bug.
