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

insert into public.salons(id,name,slug,description,city,primary_color,secondary_color,theme,vertical_pack_key,plan)
values
('550e8400-e29b-41d4-a716-446655440000','Barber Studio Vitez','barberstudiovitez','Precizni rezovi, svjež izgled i vrijeme samo za vas.','Vitez','#C6A667','#171717','modern_barber','barber','pro'),
('550e8400-e29b-41d4-a716-446655440001','Beauty Studio Travnik','beautystudiotravnik','Vaš trenutak njege, ljepote i opuštanja.','Travnik','#B76E79','#FFF5F5','elegant_beauty','beauty','pro')
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

insert into public.services(id,salon_id,name,category,price,duration_minutes) values
('10000000-0000-4000-8000-000000000001','550e8400-e29b-41d4-a716-446655440000','Muško šišanje','Šišanje',15,30),
('10000000-0000-4000-8000-000000000002','550e8400-e29b-41d4-a716-446655440000','Brada','Brada',10,20),
('10000000-0000-4000-8000-000000000003','550e8400-e29b-41d4-a716-446655440000','Šišanje + brada','Paketi',25,45),
('10000000-0000-4000-8000-000000000004','550e8400-e29b-41d4-a716-446655440000','Fade','Šišanje',20,40),
('10000000-0000-4000-8000-000000000005','550e8400-e29b-41d4-a716-446655440001','Žensko šišanje','Kosa',25,45),
('10000000-0000-4000-8000-000000000006','550e8400-e29b-41d4-a716-446655440001','Feniranje','Kosa',20,40),
('10000000-0000-4000-8000-000000000007','550e8400-e29b-41d4-a716-446655440001','Farbanje','Boja',70,120),
('10000000-0000-4000-8000-000000000008','550e8400-e29b-41d4-a716-446655440001','Pramenovi','Boja',100,150)
on conflict(id) do nothing;

insert into public.employees(id,salon_id,name,role,bio) values
('20000000-0000-4000-8000-000000000001','550e8400-e29b-41d4-a716-446655440000','Emir','Barber','Precizno šišanje i oblikovanje brade.'),
('20000000-0000-4000-8000-000000000002','550e8400-e29b-41d4-a716-446655440000','Amar','Barber','Klasični stilovi i moderni fade.'),
('20000000-0000-4000-8000-000000000003','550e8400-e29b-41d4-a716-446655440001','Amina','Stilistica','Njega kose i boje prilagođene vama.'),
('20000000-0000-4000-8000-000000000004','550e8400-e29b-41d4-a716-446655440001','Lejla','Stilistica','Frizure za svaki dan i posebne prilike.')
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
