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
