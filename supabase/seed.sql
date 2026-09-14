-- Deterministic, credential-free fixtures. Production provisioning creates Auth users separately.
insert into public.vertical_packs(key,display_name,terminology,default_settings,default_theme,default_services,feature_flags)
values
('barber','Barber',
'{"businessSingular":"Barbershop","customerSingular":"Klijent","customerPlural":"Klijenti","serviceSingular":"Usluga","servicePlural":"Usluge","staffSingular":"Barber","staffPlural":"Naš tim","appointmentSingular":"Termin","bookCta":"Zakaži termin","noteLabel":"Napomena","myAppointments":"Moji termini","priceLabel":"Cijena","durationLabel":"Trajanje"}',
'{"bookingMode":"manual","bookingGranularity":"exact_slot","slotStepMinutes":15,"bufferMinutes":5,"minAdvanceBookingHours":2,"maxAdvanceBookingDays":30,"minCancelHours":3,"pendingExpiryHours":12,"requireStaffChoice":false,"showPricesInApp":true,"allowGuestBooking":false}',
'modern_barber',
'[{"name":"Muško šišanje","durationMinutes":30,"price":15},{"name":"Brada","durationMinutes":20,"price":10},{"name":"Šišanje + brada","durationMinutes":45,"price":25},{"name":"Fade","durationMinutes":40,"price":20}]',
'{"gallery":true,"prices":true,"anyStaff":true,"team":true,"socialLinks":true,"noShowTracking":true,"recall":false}'),
('beauty','Beauty',
'{"businessSingular":"Salon","customerSingular":"Klijentica","customerPlural":"Klijentice","serviceSingular":"Tretman","servicePlural":"Usluge","staffSingular":"Stilistica","staffPlural":"Naš tim","appointmentSingular":"Termin","bookCta":"Rezerviši termin","noteLabel":"Napomena","myAppointments":"Moji termini","priceLabel":"Cijena","durationLabel":"Trajanje"}',
'{"bookingMode":"manual","bookingGranularity":"exact_slot","slotStepMinutes":15,"bufferMinutes":10,"minAdvanceBookingHours":4,"maxAdvanceBookingDays":45,"minCancelHours":6,"pendingExpiryHours":12,"requireStaffChoice":false,"showPricesInApp":true,"allowGuestBooking":false}',
'elegant_beauty',
'[{"name":"Žensko šišanje","durationMinutes":45,"price":25},{"name":"Feniranje","durationMinutes":40,"price":20},{"name":"Farbanje","durationMinutes":120,"price":70},{"name":"Pramenovi","durationMinutes":150,"price":100}]',
'{"gallery":true,"prices":true,"anyStaff":true,"team":true,"socialLinks":true,"noShowTracking":true,"recall":false}'),
('generic','Usluge',
'{"businessSingular":"Firma","customerSingular":"Klijent","customerPlural":"Klijenti","serviceSingular":"Usluga","servicePlural":"Usluge","staffSingular":"Radnik","staffPlural":"Naš tim","appointmentSingular":"Termin","bookCta":"Zakaži termin","noteLabel":"Napomena","myAppointments":"Moji termini","priceLabel":"Cijena","durationLabel":"Trajanje"}',
'{"bookingMode":"manual","bookingGranularity":"exact_slot","slotStepMinutes":30,"bufferMinutes":10,"minAdvanceBookingHours":4,"maxAdvanceBookingDays":60,"minCancelHours":6,"pendingExpiryHours":24,"requireStaffChoice":false,"showPricesInApp":true,"allowGuestBooking":false}',
'modern_barber','[]',
'{"gallery":false,"prices":true,"anyStaff":true,"team":true,"socialLinks":true,"noShowTracking":true,"recall":false}')
on conflict(key) do nothing;

-- **Kontakt podaci Barber Studija Vitez su izmisljeni za demo.** Adresa, telefon i mail ne
-- pripadaju nikome i ne smiju se zvati; mreze vode na profile koji ne postoje. Salon je demo
-- fixtura, ne stvarni klijent — stvarni tenant nosi svoje podatke u `tenants/<flavor>/tenant.yaml`
-- i u svom redu ove tabele.
--
-- **Fotografije su Unsplash URL-ovi, ne spakovani assets.** Unsplash licenca dozvoljava
-- komercijalnu upotrebu bez atribucije. Namjerno ostaju daljinski: Flutter nema asset po flavoru
-- (v. `apps/client/pubspec.yaml`), pa bi devetnaest fotografija **demo** salona uslo u build svakog
-- tenanta. Cijena je da demo bez interneta pokazuje prazne okvire — isto stanje koje salon bez
-- fotografija ionako ima.
insert into public.salons(id,name,slug,description,city,address,phone,email,instagram_url,facebook_url,
cover_image_url,gallery_urls,primary_color,secondary_color,theme,vertical_pack_key,plan)
values
('550e8400-e29b-41d4-a716-446655440000','Barber Studio Vitez','barberstudiovitez',
 'Precizni rezovi, svjež izgled i vrijeme samo za vas.','Vitez',
 'Stjepana Radića 12','030 711 000','kontakt@barberstudiovitez.ba',
 'https://instagram.com/barberstudiovitez','https://facebook.com/barberstudiovitez',
 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=1200&h=1600&fit=crop&q=80',
 '["https://images.unsplash.com/photo-1536520002442-39764a41e987?w=800&h=800&fit=crop&q=80","https://images.unsplash.com/photo-1621645582931-d1d3e6564943?w=800&h=800&fit=crop&q=80","https://images.unsplash.com/photo-1599351431613-18ef1fdd27e1?w=800&h=800&fit=crop&q=80","https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=800&h=800&fit=crop&q=80","https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800&h=800&fit=crop&q=80","https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=800&h=800&fit=crop&q=80","https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=800&h=800&fit=crop&q=80","https://images.unsplash.com/photo-1493256338651-d82f7acb2b38?w=800&h=800&fit=crop&q=80","https://images.unsplash.com/photo-1587909209111-5097ee578ec3?w=800&h=800&fit=crop&q=80","https://images.unsplash.com/photo-1567894340315-735d7c361db0?w=800&h=800&fit=crop&q=80","https://images.unsplash.com/photo-1621607512022-6aecc4fed814?w=800&h=800&fit=crop&q=80","https://images.unsplash.com/photo-1622287162716-f311baa1a2b8?w=800&h=800&fit=crop&q=80"]'::jsonb,
 '#C6A667','#171717','modern_barber','barber','pro'),
('550e8400-e29b-41d4-a716-446655440001','Beauty Studio Travnik','beautystudiotravnik',
 'Vaš trenutak njege, ljepote i opuštanja.','Travnik',
 '','',null,null,null,
 null,'[]'::jsonb,
 '#B76E79','#FFF5F5','elegant_beauty','beauty','pro')
on conflict(id) do nothing;

insert into public.salon_builds(salon_id,flavor,application_id,bundle_id,app_display_name)
select id,slug,'ba.nasadomena.'||slug,'ba.nasadomena.'||slug,name from public.salons
where id in ('550e8400-e29b-41d4-a716-446655440000','550e8400-e29b-41d4-a716-446655440001')
on conflict(salon_id) do nothing;

insert into public.salon_settings(salon_id,buffer_minutes,slot_step_minutes,min_advance_booking_hours,
max_advance_booking_days,pending_expiry_hours,min_cancel_hours)
values
('550e8400-e29b-41d4-a716-446655440000',5,15,2,30,12,3),
('550e8400-e29b-41d4-a716-446655440001',10,15,4,45,12,6)
on conflict(salon_id) do nothing;

-- **Barber je od sada pun**, sa stvarnom fotografijom na svakoj usluzi — sluzi da se cijela
-- Pocetna moze vidjeti onako kako je salon vidi.
--
-- **Prazan okvir se i dalje dokazuje, ali na beautyju** (Pramenovi, `image_url` NULL). To stanje
-- mora ostati vidljivo u demou, inace se otkrije tek kod prvog klijenta bez fotografija — samo
-- vise nije na salonu na kojem se gleda raspored. Ranije je tu ulogu nosila i barberova „Brada".
insert into public.services(id,salon_id,name,category,price,duration_minutes,image_url) values
('10000000-0000-4000-8000-000000000001','550e8400-e29b-41d4-a716-446655440000','Muško šišanje','Šišanje',15,30,'https://images.unsplash.com/photo-1647140655214-e4a2d914971f?w=800&h=800&fit=crop&q=80'),
('10000000-0000-4000-8000-000000000002','550e8400-e29b-41d4-a716-446655440000','Brada','Brada',10,20,'https://images.unsplash.com/photo-1596728325488-58c87691e9af?w=800&h=800&fit=crop&q=80'),
('10000000-0000-4000-8000-000000000003','550e8400-e29b-41d4-a716-446655440000','Šišanje + brada','Paketi',25,45,'https://images.unsplash.com/photo-1605497788044-5a32c7078486?w=800&h=800&fit=crop&q=80'),
('10000000-0000-4000-8000-000000000004','550e8400-e29b-41d4-a716-446655440000','Fade','Šišanje',20,40,'https://images.unsplash.com/photo-1672642150228-3fcd5826ec26?w=800&h=800&fit=crop&q=80'),
('10000000-0000-4000-8000-000000000005','550e8400-e29b-41d4-a716-446655440001','Žensko šišanje','Kosa',25,45,'https://images.demo.invalid/beauty/sisanje.jpg'),
('10000000-0000-4000-8000-000000000006','550e8400-e29b-41d4-a716-446655440001','Feniranje','Kosa',20,40,'https://images.demo.invalid/beauty/feniranje.jpg'),
('10000000-0000-4000-8000-000000000007','550e8400-e29b-41d4-a716-446655440001','Farbanje','Boja',70,120,'https://images.demo.invalid/beauty/farbanje.jpg'),
('10000000-0000-4000-8000-000000000008','550e8400-e29b-41d4-a716-446655440001','Pramenovi','Boja',100,150,null)
on conflict(id) do nothing;

-- Lejla namjerno nema `experience_years`: red bez staza mora izgledati uredno, a ne kao
-- red kojem fali podatak.
insert into public.employees(id,salon_id,name,role,bio,experience_years,image_url) values
('20000000-0000-4000-8000-000000000001','550e8400-e29b-41d4-a716-446655440000','Emir','Barber','Precizno šišanje i oblikovanje brade.',9,'https://images.unsplash.com/photo-1640301133857-c4bc5789c1bb?w=800&h=800&fit=crop&q=80'),
('20000000-0000-4000-8000-000000000002','550e8400-e29b-41d4-a716-446655440000','Amar','Barber','Klasični stilovi i moderni fade.',4,'https://images.unsplash.com/photo-1598524374912-6b0b0bab43dd?w=800&h=800&fit=crop&q=80'),
-- Beauty ostaje bez fotografija radnika: okvir sa inicijalom je predvidjeno stanje i mora se
-- negdje vidjeti u demou, sad kad ga barber vise ne pokazuje.
('20000000-0000-4000-8000-000000000003','550e8400-e29b-41d4-a716-446655440001','Amina','Stilistica','Njega kose i boje prilagođene vama.',12,null),
('20000000-0000-4000-8000-000000000004','550e8400-e29b-41d4-a716-446655440001','Lejla','Stilistica','Frizure za svaki dan i posebne prilike.',null,null)
on conflict(id) do nothing;

insert into public.employee_services(salon_id,employee_id,service_id)
select e.salon_id,e.id,s.id from public.employees e join public.services s using(salon_id)
where e.salon_id in ('550e8400-e29b-41d4-a716-446655440000','550e8400-e29b-41d4-a716-446655440001')
on conflict(salon_id,employee_id,service_id) do nothing;

-- ISO weekday 1=Monday..7=Sunday; demo schedules from section 6.3.
insert into public.working_hours(salon_id,day_of_week,start_time,end_time,is_closed)
select s.id,d,'09:00'::time,case when d=6 then '14:00'::time else '17:00'::time end,d=7
from public.salons s cross join generate_series(1,7) d
where s.id in ('550e8400-e29b-41d4-a716-446655440000','550e8400-e29b-41d4-a716-446655440001')
on conflict(salon_id,employee_id,day_of_week) do nothing;

-- ---------------------------------------------------------------------------
-- Recenzije (task 20)
-- ---------------------------------------------------------------------------
-- **Datumi su relativni na `now()`, ne fiksni.** Ekran pise "prije 3 dana"; sa fiksnim
-- datumom demo za mjesec dana pise "prije 5 sedmica", a za godinu "prije 11 mjeseci". Task 17
-- je nasao tri zatecena testa koja su bila zelena samo u dijelu dana ili sedmice — fiksan
-- datum u seedu je isti rod greske, samo sporiji.
--
-- **Raspodjela je namjerno 4,8.** 21x5 + 3x4 + 1x3 = 120 / 25 = 4.8, tacno broj sa
-- `13-recenzije.png`. Histogram time dobija oblik koji handoff crta: peterka dominira,
-- cetvorka mala, trojka jedva vidljiva, dvojka i jedinica prazne.
--
-- **Vecina ocjena nema tekst, i to nosi histogram.** Handoff pokazuje "142 ocjene" iznad tri
-- napisane recenzije: ljudi daju zvjezdice bez teksta. Da su sve ocjene i recenzije, prosjek
-- bi se racunao nad drugim skupom nego sto salon vidi na Googleu.
--
-- **Beauty namjerno nema nijednu.** Prazno stanje recenzija mora se vidjeti u demou, isto kao
-- prazna galerija i prazan okvir usluge (task 22) — inace se otkrije tek kod prvog klijenta.
insert into public.reviews(salon_id,author_name,rating,comment,created_at) values
-- Tri napisane recenzije su doslovno one sa `13-recenzije.png`.
('550e8400-e29b-41d4-a716-446655440000','Nedim H.',5,
 'Fade je uvijek isti, tačno kako tražim. Nikad čekanja kad se zakaže preko aplikacije.',
 now() - interval '3 days'),
('550e8400-e29b-41d4-a716-446655440000','Amar S.',5,
 'Emir zna posao. Brada uređena za 20 minuta, cijena poštena.',
 now() - interval '14 days'),
('550e8400-e29b-41d4-a716-446655440000','Haris M.',4,
 'Sve super, jedino subotom zna biti gužva pa termin uzmite ranije.',
 now() - interval '31 days'),
-- Cetvrta napisana, da lista ima sta skrolati ispod tri iz handoffa.
('550e8400-e29b-41d4-a716-446655440000','Dženan K.',5,
 'Dođem, sjednem, gotovo. Bez dogovaranja preko poruka.',
 now() - interval '47 days')
on conflict do nothing;

-- Ocjene bez teksta: 18x5, 2x4, 1x3. Sa cetiri napisane iznad daju 25 ocjena i prosjek 4,8.
insert into public.reviews(salon_id,author_name,rating,comment,created_at)
select '550e8400-e29b-41d4-a716-446655440000', o.ime, o.ocjena, null,
       now() - (o.dana || ' days')::interval
from (values
  ('Adnan P.',5,5),   ('Tarik B.',5,8),    ('Mirza D.',5,11),  ('Faruk J.',5,17),
  ('Vedad S.',5,19),  ('Kenan A.',5,23),   ('Damir L.',5,26),  ('Ismar T.',5,29),
  ('Edin M.',5,34),   ('Sanjin R.',5,38),  ('Benjamin Ć.',5,41),('Armin N.',5,45),
  ('Nihad Z.',5,52),  ('Elvir K.',5,58),   ('Muhamed H.',5,63), ('Anel P.',5,70),
  ('Dino V.',5,77),   ('Alen G.',5,84),
  ('Emin F.',4,36),   ('Samir O.',4,66),
  ('Nermin Š.',3,73)
) as o(ime,ocjena,dana)
on conflict do nothing;

-- **Jedna sakrivena, i namjerno jedinica.** Dokazuje `is_published` i cini curenje vidljivim
-- kao broj: ako politika propusti ovaj red, prosjek padne sa 4,8 na 4,7. Test koji mjeri
-- prosjek zato pada na propuštenoj recenziji, a ne samo na brojanju redova.
insert into public.reviews(salon_id,author_name,rating,comment,is_published,created_at) values
('550e8400-e29b-41d4-a716-446655440000','Sakriveni S.',1,
 'Sadržaj koji je salon sakrio kroz admin. Ne smije se vidjeti bez tokena osoblja.',
 false, now() - interval '9 days')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Pravila koristenja i politika privatnosti (task 21)
-- ---------------------------------------------------------------------------
-- **Tekst je pisan nanovo, ne prepisan iz handoffa.** Sekcija „Vasi podaci" na
-- `15-pravila-koristenja.png` pise „Cuvamo ime, **broj telefona** i historiju termina", a
-- klijentska app broj telefona **nikad ne trazi**: `ensure_customer` upisuje samo ime, booking
-- ekran nema polje, a `docs/01` to vodi kao donesenu odluku. Prepisan handoff bi lagao u prvoj
-- recenici pravno obavezujuce sekcije.
--
-- Generican template bi bio ista greska u drugom obliku — tvrdi kolacice, placanja i lokaciju,
-- cega ovdje nema.
--
-- Stvarni inventar, provjeren u semi i u kodu:
--   email          -> `auth_identities.email` (Apple / Google / email OTP)
--   ime            -> `customers.name` (display name providera; salon ga moze ispraviti)
--   historija      -> `appointments` (usluga, radnik, datum, status)
--   napomena       -> `appointments.customer_note` (opciono, korisnik je pise)
--   push token     -> `devices` (**tek sa taskom 25**, zato u tekstu stoji uslovno)
-- `customers.phone` i `appointments.customer_phone` postoje, ali ih puni salon iz admina.
--
-- **Sta se namjerno ne tvrdi:** da neodgovoren zahtjev istekne sam. `pending_expires_at` se
-- upisuje, ali `supabase/functions/expire-pending/` je danas samo README — funkcije nema. Tekst
-- koji obecava automatiku koje nema je tekst koji ce prvi korisnik demantovati.
--
-- **Ovo nije pravni savjet.** Pisano da bude tacno naspram koda i upotrebljivo za App Privacy i
-- Data Safety formulare; prije submissiona ga mora pogledati neko ko za to odgovara.

-- Platformske sekcije pravila. `sort_order` je rijedak (10, 40, 50) da salonske sekcije stanu
-- izmedju njih bez preracunavanja — handoff ih upravo tako i isprepliće.
insert into public.app_policies(document,sort_order,title,body) values
('terms',10,'Zakazivanje',
 'Zahtjev za termin nije potvrda. {appointmentSingular} je potvrđen tek kad ga salon prihvati i kad o tome dobijete obavijest u aplikaciji.

Dok je zahtjev na čekanju, salon ga može prihvatiti ili odbiti. Do potvrde vrijeme nije rezervisano za vas.'),
('terms',40,'Cijene',
 'Cijene u aplikaciji su informativne i važe za standardnu izvedbu usluge. Konačnu cijenu dogovarate u salonu, prije nego što usluga počne.

Aplikacija ne naplaćuje ništa i ne prima podatke o kartici. Plaćanje ide u salonu.'),
('terms',50,'Vaši podaci',
 'Kad se prijavite, čuvamo vašu email adresu i ime koje stigne od Apple, Google ili email prijave. Uz svaki zahtjev čuvamo uslugu, radnika, datum i status, te napomenu ako je upišete.

Podatke koristimo da salon zna ko dolazi i da vam možemo poslati obavijest o terminu. Ne prodajemo ih i ne dijelimo trećim stranama.

Brisanje računa i svih podataka možete pokrenuti u Postavkama, u samoj aplikaciji. Detalji su u Politici privatnosti.')
on conflict do nothing;

-- Politika privatnosti — u cijelosti platformska (ADR-0009). Sekcije prate redoslijed pitanja
-- iz App Privacy i Data Safety formulara: ko, sta, zasto, sta ne, koliko dugo, s kim, prava.
--
-- **Nijedna sekcija ne nosi `{email}`, i to je namjerno.** Taj placeholder znaci *salonov* mail,
-- a pitanja o obradi podataka idu firmi — cija adresa (`supportEmail`) jos nije data. Tekst zato
-- upucuje na kontakt sa ekrana „O aplikaciji", koji se crta iz `salons` i sam se sakrije kad
-- podatka nema. Kad `supportEmail` stigne, dodaje se kao `{supportEmail}` u ove tri sekcije —
-- dok ga nema, raw `{supportEmail}` na pravnom ekranu bi bio vidljiv kvar.
insert into public.app_policies(document,sort_order,title,body) values
('privacy',10,'Ko obrađuje podatke',
 'Aplikaciju objavljuje i održava razvojna firma, a salon je koristi da vodi svoje termine. Salon vidi podatke o svojim terminima; podatke drugih salona ne vidi.

Za sve u vezi sa podacima obratite se salonu — kontakt stoji na ekranu „O aplikaciji". Upit koji salon ne može riješiti sam prosljeđuje nama.'),
('privacy',20,'Šta prikupljamo',
 'Email adresu i ime — dolaze od prijave preko Apple, Google ili email koda. Lozinku ne čuvamo jer je ni nemamo.

Historiju termina — usluga, radnik, datum, vrijeme i status zahtjeva.

Napomenu uz termin, ako je upišete. Polje je opciono i prazno dok ga sami ne popunite.

Oznaku uređaja za slanje obavijesti, ako obavijesti uključite. Oznaka služi samo za slanje i ne kaže gdje ste.'),
('privacy',30,'Zašto ih prikupljamo',
 'Da salon zna ko dolazi i na koji termin, i da vam možemo javiti kad zahtjev bude prihvaćen, odbijen ili otkazan.

Bez emaila nema prijave, a bez prijave nema načina da vam pokažemo vaše termine i samo vaše.'),
('privacy',40,'Šta ne prikupljamo',
 'Ne tražimo broj telefona. Ako vaš broj postoji u salonovoj evidenciji, upisao ga je salon, ne aplikacija.

Ne pratimo lokaciju, ne čitamo kontakte, ne postavljamo kolačiće za oglašavanje i ne koristimo analitiku trećih strana. Ne obrađujemo podatke o plaćanju jer se plaća u salonu.'),
('privacy',50,'Koliko dugo ih čuvamo',
 'Dok imate račun. Historija termina ostaje salonu kao evidencija posla i nakon brisanja računa, ali bez vašeg imena i kontakta — ostaju samo usluga, datum i status.'),
('privacy',60,'S kim ih dijelimo',
 'Sa salonom čiju aplikaciju koristite, i ni sa kim više. Podatke ne prodajemo i ne ustupamo za oglašavanje.

Tehnički ih čuvamo kod pružaoca usluge hostinga, koji ih obrađuje isključivo po našem nalogu.'),
('privacy',70,'Vaša prava',
 'Možete tražiti uvid u svoje podatke, ispravku netačnog podatka i brisanje računa. Ime koje salon vidi možete promijeniti u salonu.

Zahtjev šaljete salonu, na kontakt sa ekrana „O aplikaciji", i odgovaramo u razumnom roku.'),
('privacy',80,'Brisanje računa',
 'Račun brišete sami, u Postavkama aplikacije. Brisanje ukloni vaše ime, email i napomene, a budući termini se otkazuju.

Brisanje vrijedi za sve salone u kojima ste koristili isti nalog, ne samo za ovaj.'),
('privacy',90,'Kontakt',
 'Pitanja o obradi podataka i pitanja o samom terminu idu na isti kontakt salona — telefon, adresa i mreže stoje na ekranu „O aplikaciji".')
on conflict do nothing;

-- Salonske sekcije. Rok otkazivanja **nije upisan kao broj** nego kao `{minCancelHours}`, koji
-- ekran puni iz `salon_settings.min_cancel_hours` — barber 3, beauty 6, a handoff pise 2.
-- `cancel_appointment` taj rok stvarno provodi, pa bi upisana cifra bila tvrdnja koju baza
-- demantuje cim salon promijeni postavku.
--
-- **Beauty namjerno ima manje sekcija od barbera** i nema „Kontakt": u seedu nema ni telefon ni
-- mail (prazan string), pa bi sekcija ispala kao recenica sa rupom. Salon bez kontakta ne pise
-- sekciju o kontaktu — i time se u demou vidi da ekran radi i sa nepotpunim setom.
insert into public.salon_policies(salon_id,sort_order,title,body) values
('550e8400-e29b-41d4-a716-446655440000',20,'Otkazivanje',
 'Termin možete otkazati u aplikaciji najkasnije {minCancelHours} h prije početka. Poslije toga otkazivanje ide telefonom, na {phone}.

Salon evidentira kasna otkazivanja i nedolaske. Ako se ponavljaju, zakazivanje preko aplikacije može biti ograničeno.'),
('550e8400-e29b-41d4-a716-446655440000',30,'Kašnjenje',
 'Ako kasnite, javite se na {phone}. Salon može skratiti uslugu ili ponuditi prvi sljedeći slobodan termin, jer iza vas najčešće dolazi neko drugi.'),
('550e8400-e29b-41d4-a716-446655440000',60,'Kontakt',
 'Za sve nejasnoće oko termina: {phone} ili {email}.'),
('550e8400-e29b-41d4-a716-446655440001',20,'Otkazivanje',
 'Termin možete otkazati u aplikaciji najkasnije {minCancelHours} h prije početka. Tretmani traju duže i planiraju se unaprijed, pa kasno otkazivanje ostavlja prazan termin koji se teško popuni.'),
('550e8400-e29b-41d4-a716-446655440001',30,'Kašnjenje',
 'Ako kasnite, salon može skratiti tretman ili ga pomjeriti na prvi sljedeći slobodan termin.')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Osoblje: po jedan `salon_admin` za svaki demo salon.
--
-- Do taska 23 seed nije imao **nijednog** admina, pa se u admin aplikaciju nije imalo
-- cime prijaviti. Testovi to nisu otkrivali jer svaki pgTAP fajl pravi svoje korisnike i
-- rollbackuje ih — fixture nije seed, i prijava kroz GoTrue ih ne vidi.
--
-- **`private.is_admin()` trazi oba uslova**, pa ih oba i upisujemo:
--   1. `raw_app_meta_data` sa `role` i `salon_id` — odatle GoTrue puni JWT claimove,
--   2. red u `public.users` sa istim `salon_id`.
-- Samo jedan od njih znaci admina koji se prijavi ali ne vidi nijedan red, sto na ekranu
-- izgleda kao prazna baza umjesto kao pogresna konfiguracija. Detalji: `.claude/docs/security.md`.
--
-- Lozinka je ista za oba i namjerno trivijalna: **ovo je lokalni demo seed**, koji nikad ne
-- ide na produkciju (`supabase db reset` je lokalna komanda). Pravi salon dobija nalog kroz
-- poziv iz super admin konzole u Sprintu 3, ne kroz seed.
--
--   admin@barberstudiovitez.test / admin@beautystudiotravnik.test — lozinka: `admin123456`
--
-- `instance_id`, `aud` i `role` moraju biti popunjeni tacno ovako: GoTrue filtrira po njima
-- pri prijavi, a red bez njih postoji u tabeli i **ne moze se prijaviti** — greska koja se
-- vidi tek na ekranu za login, ne u bazi.
--
-- **Nullable text kolone moraju biti prazan string, ne NULL.** GoTrue ih skenira u Go `string`,
-- pa NULL obara prijavu sa `500 Database error querying schema` â porukom koja ne kaze koja je
-- kolona kriva. Kolone su nullable, insert prolazi, red izgleda ispravno u `psql`, a greska se
-- vidi **tek na prijavi**. Zato ide `update` ispod, a ne nabrajanje u `insert`: kolona koju
-- Supabase doda u nekoj verziji GoTrue-a bila bi opet NULL i opet bi srusila prijavu.
insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
('00000000-0000-0000-0000-000000000000','11111111-0000-4000-8000-000000000001','authenticated','authenticated',
 'admin@barberstudiovitez.test', extensions.crypt('admin123456', extensions.gen_salt('bf')), now(),
 '{"provider":"email","providers":["email"],"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}',
 '{"name":"Vlasnik Barber Studio Vitez"}', now(), now()),
('00000000-0000-0000-0000-000000000000','11111111-0000-4000-8000-000000000002','authenticated','authenticated',
 'admin@beautystudiotravnik.test', extensions.crypt('admin123456', extensions.gen_salt('bf')), now(),
 '{"provider":"email","providers":["email"],"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}',
 '{"name":"Vlasnica Beauty Studio Travnik"}', now(), now())
on conflict (id) do nothing;

-- Prazni stringovi umjesto NULL-a u svim nullable text kolonama koje GoTrue skenira
-- (`confirmation_token`, `email_change`, `phone_change`, ...). Pisano kao `update` nad
-- informacijskom shemom, da nova kolona u buducoj verziji GoTrue-a ne obori prijavu nijemo.
do $$
declare kolona text;
begin
  foreach kolona in array array[
    'confirmation_token','recovery_token','email_change_token_new','email_change',
    'phone_change','phone_change_token','email_change_token_current','reauthentication_token']
  loop
    execute format(
      'update auth.users set %I = %L where id in (%L,%L) and %I is null',
      kolona, '', '11111111-0000-4000-8000-000000000001',
      '11111111-0000-4000-8000-000000000002', kolona);
  end loop;
end $$;

-- Identitet za email prijavu. Bez reda u `auth.identities` GoTrue vraca „Invalid login
-- credentials" iako lozinka odgovara — provjerava identitet, ne samo `auth.users` red.
insert into auth.identities(id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
values
('11111111-0000-4000-8000-000000000001','11111111-0000-4000-8000-000000000001','11111111-0000-4000-8000-000000000001','email',
 '{"sub":"11111111-0000-4000-8000-000000000001","email":"admin@barberstudiovitez.test","email_verified":true,"phone_verified":false}',
 now(), now(), now()),
('11111111-0000-4000-8000-000000000002','11111111-0000-4000-8000-000000000002','11111111-0000-4000-8000-000000000002','email',
 '{"sub":"11111111-0000-4000-8000-000000000002","email":"admin@beautystudiotravnik.test","email_verified":true,"phone_verified":false}',
 now(), now(), now())
on conflict (id) do nothing;

insert into public.users(id, salon_id, name, email, role) values
('11111111-0000-4000-8000-000000000001','550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik Barber Studio Vitez','admin@barberstudiovitez.test','salon_admin'),
('11111111-0000-4000-8000-000000000002','550e8400-e29b-41d4-a716-446655440001',
 'Vlasnica Beauty Studio Travnik','admin@beautystudiotravnik.test','salon_admin')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Klijenti i termini — demo podaci za admin listu (task 23).
--
-- Do sada je seed imao usluge i radnike, ali **nijednog klijenta i nijedan termin**:
-- `customers=0, appointments=0`. Posljedica nije samo prazan ekran — **izolacija se na
-- praznim tabelama ne moze dokazati.** Upit „admin A ne vidi termine salona B" vraca nula
-- redova i kad RLS radi i kad je iskljucen, pa test koji broji redove prolazi nad pokvarenom
-- bazom. Zato oba salona dobijaju podatke, i to **razlicit broj** (A: 3, B: 2) — kad bi broj
-- bio isti, zamijenjeni token se ne bi vidio u brojacu.
--
-- Datumi su relativni na `current_date`, da lista „danas" ima sadrzaj kad god se seed pokrene.
-- Fiksni datum bi vec sutra dao prazan dashboard i izgledao kao greska u upitu.
insert into public.customers(id, salon_id, name, phone) values
('c1111111-0000-4000-8000-000000000001','550e8400-e29b-41d4-a716-446655440000','Adnan Music','+387 61 111 111'),
('c1111111-0000-4000-8000-000000000002','550e8400-e29b-41d4-a716-446655440000','Emir Hodzic','+387 61 222 222'),
('c1111111-0000-4000-8000-000000000003','550e8400-e29b-41d4-a716-446655440000','Tarik Begic',null),
('c2222222-0000-4000-8000-000000000001','550e8400-e29b-41d4-a716-446655440001','Lejla Karic','+387 62 333 333'),
('c2222222-0000-4000-8000-000000000002','550e8400-e29b-41d4-a716-446655440001','Amina Sabic',null)
on conflict (id) do nothing;

-- Statusi su namjerno izmijesani: `pending` je ono sto dashboard broji kao „zahtjevi koji
-- cekaju", `confirmed` puni „danas", a `cancelled` mora **ostati vidljiv u listi** ali ne
-- smije uci u brojac — filter po statusu se inace ne moze provjeriti.
insert into public.appointments(
  id, salon_id, service_id, employee_id, customer_id, customer_name, customer_phone,
  customer_note, date, start_time, end_time, buffer_minutes, status, source)
select
  v.id, v.salon_id, s.id, e.id, v.customer_id, v.customer_name, v.customer_phone,
  v.customer_note, v.date, v.start_time, v.end_time, 5, v.status::public.appointment_status,
  v.source::public.appointment_source
from (values
  ('a1111111-0000-4000-8000-000000000001'::uuid,'550e8400-e29b-41d4-a716-446655440000'::uuid,
   'c1111111-0000-4000-8000-000000000001'::uuid,'Adnan Music','+387 61 111 111',
   'Kratko sa strane.', current_date, time '10:00', time '10:40','confirmed','app'),
  ('a1111111-0000-4000-8000-000000000002'::uuid,'550e8400-e29b-41d4-a716-446655440000'::uuid,
   'c1111111-0000-4000-8000-000000000002'::uuid,'Emir Hodzic','+387 61 222 222',
   null, current_date, time '11:30', time '12:10','pending','app'),
  ('a1111111-0000-4000-8000-000000000003'::uuid,'550e8400-e29b-41d4-a716-446655440000'::uuid,
   'c1111111-0000-4000-8000-000000000003'::uuid,'Tarik Begic',null,
   null, current_date + 1, time '09:00', time '09:40','cancelled','app'),
  ('a2222222-0000-4000-8000-000000000001'::uuid,'550e8400-e29b-41d4-a716-446655440001'::uuid,
   'c2222222-0000-4000-8000-000000000001'::uuid,'Lejla Karic','+387 62 333 333',
   'Alergija na jedan proizvod — provjeriti.', current_date, time '13:00', time '14:00','confirmed','app'),
  ('a2222222-0000-4000-8000-000000000002'::uuid,'550e8400-e29b-41d4-a716-446655440001'::uuid,
   'c2222222-0000-4000-8000-000000000002'::uuid,'Amina Sabic',null,
   null, current_date, time '15:00', time '16:00','pending','app')
) as v(id,salon_id,customer_id,customer_name,customer_phone,customer_note,date,start_time,end_time,status,source)
-- Usluga i radnik se **biraju iz baze**, ne kucaju kao UUID: seed usluga koristi
-- `gen_random_uuid()`, pa zakucan id ne bi postojao i insert bi pao na FK.
cross join lateral (
  select id from public.services where salon_id = v.salon_id and is_active order by name limit 1) s
cross join lateral (
  select id from public.employees where salon_id = v.salon_id and is_active order by name limit 1) e
on conflict (id) do nothing;
