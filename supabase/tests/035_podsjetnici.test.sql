-- Push podsjetnici. Task 56, ADR-0033.
--
-- `private.queue_reminders(p_now)` se ovdje zove sa postavljenim satom, pa test ne zavisi od
-- doba dana kad se pokrene: referentni trenutak R je podne za tri dana, u zoni salona, a svi
-- termini su postavljeni oko njega. `claim_push_notifications` gleda pravi `now()`, pa su
-- njegovi termini dan ili dva od danas (ili jucer, za „poceo je").
--
-- Granice:
--   1. dnevni: tacno 24 h prije, do ponoci pred dan termina;
--   2. satni: N h prije, do pocetka; promjena N mijenja trenutak;
--   3. samo `confirmed`; zakazan ili potvrdjen poslije trenutka podsjetnika ne dobija ga;
--   4. samo klijentski uredjaji vlasnika, sa tokenom, u salonu termina; osoblje nikad;
--   5. jednom po (termin, uredjaj, tip): drugi prolaz ne pravi nista;
--   6. zona salona, a ne UTC ni Sarajevo;
--   7. ugasen dnevni / satni ne pravi red, a red koji ceka ide u `logged` pri slanju;
--   8. claim: otkazan, poceo, ugasen, zakasnio dnevni → `logged`; rijec za termin po vertikali;
--   9. grantovi, cron i `update_salon_settings`.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as salon_b,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  (select id from public.services where salon_id = '550e8400-e29b-41d4-a716-446655440001'
   order by id limit 1) as usluga_b,
  ((now() at time zone 'Europe/Sarajevo')::date + 3) as d,
  (((now() at time zone 'Europe/Sarajevo')::date + 3) + time '12:00')
    at time zone 'Europe/Sarajevo' as r;
grant select on fix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fd000000-0000-4000-8000-000000000001', 'ana@podsj56.invalid', '{"providers":["email"]}', '{}'),
('fd000000-0000-4000-8000-000000000003', 'bob@podsj56.invalid', '{"providers":["email"]}', '{}'),
('fd000000-0000-4000-8000-000000000002', 'vlasnik@podsj56.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('fd000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'vlasnik@podsj56.invalid', 'salon_admin');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- Vlasnikov uredjaj: osoblje ne dobija podsjetnike.
set local request.jwt.claims = '{"sub":"fd000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table vlasnik_uredjaj as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000a2', repeat('c', 64), 'android', 'owner-token', true) as id;
reset role;

-- Ana: telefon i tablet sa tokenom, treci uredjaj bez tokena, i uredjaj u salonu B.
set local request.jwt.claims = '{"sub":"fd000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table ana_tel as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000a1', repeat('a', 64), 'android', 'ana-tel') as id;
create temporary table ana_tablet as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000a3', repeat('b', 64), 'ios', 'ana-tablet') as id;
create temporary table ana_bez_tokena as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000a4', repeat('e', 64), 'android', null) as id;
create temporary table ana as select (public.ensure_customer((select salon from fix))).id as customer_id;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
create temporary table ana_b_tel as select public.register_device((select salon_b from fix),
  'fd000000-0000-4000-8000-0000000000a5', repeat('f', 64), 'android', 'ana-b') as id;
create temporary table ana_b as select (public.ensure_customer((select salon_b from fix))).id as customer_id;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
reset role;

-- Bob: drugi klijent istog salona.
set local request.jwt.claims = '{"sub":"fd000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table bob_tel as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000b1', repeat('d', 64), 'android', 'bob-tel') as id;
create temporary table bob as select (public.ensure_customer((select salon from fix))).id as customer_id;
reset role;

create temporary table ident as select
  (select id from public.auth_identities where supabase_user_id = 'fd000000-0000-4000-8000-000000000001') as ana,
  (select id from public.auth_identities where supabase_user_id = 'fd000000-0000-4000-8000-000000000003') as bob;

-- Uredjaj osoblja koji (pogresno) nosi i klijentski identitet: filter osoblja mora stajati sam,
-- a ne oslanjati se na to da `register_device` osoblju ne upisuje identitet.
update public.devices set auth_identity_id = (select ana from ident)
where id = (select id from vlasnik_uredjaj);

grant select on vlasnik_uredjaj, ana_tel, ana_tablet, ana_bez_tokena, ana, ana_b_tel, ana_b,
  bob_tel, bob, ident to public;

-- Termin upisan direktno (kao `postgres`): `book_appointment` bi trazio radno vrijeme i rok
-- unaprijed, a ovdje se mjeri samo pravilo podsjetnika. `source = 'manual'` da upis ne pravi
-- obavijest salonu; bez radnika, da se termini ne sudaraju na exclusion constraintu.
--
-- Termin je u trenutku `p_kad`, upisan u lokalnom vremenu svog salona. Pomaci su apsolutni
-- (R + 24 h), a ne „sutra u podne": prelaz na zimsko vrijeme izmedju d i d + 1 bi inace
-- pomjerio trenutak podsjetnika za sat i test bi padao dva vikenda godisnje.
create function pg_temp.termin(p_ko text, p_kad timestamptz,
  p_status public.appointment_status default 'confirmed', p_salon text default 'a')
returns uuid language plpgsql as $$
declare v_id uuid; v_salon uuid; v_lok timestamp;
begin
  select case when p_salon = 'a' then f.salon else f.salon_b end into v_salon from fix f;
  select p_kad at time zone st.timezone into v_lok
  from public.salon_settings st where st.salon_id = v_salon;
  insert into public.appointments(salon_id, service_id, customer_id, auth_identity_id,
    device_id, customer_name, date, start_time, end_time, status, source)
  select
    v_salon,
    case when p_salon = 'a' then f.usluga else f.usluga_b end,
    case when p_salon = 'b' then (select customer_id from ana_b)
         when p_ko = 'ana' then (select customer_id from ana)
         else (select customer_id from bob) end,
    case when p_ko = 'ana' then i.ana else i.bob end,
    case when p_salon = 'b' then (select id from ana_b_tel)
         when p_ko = 'ana' then (select id from ana_tel)
         else (select id from bob_tel) end,
    p_ko, v_lok::date, v_lok::time,
    -- `end_time > start_time`: termin ne prelazi ponoc.
    case when v_lok::time > time '23:00' then time '23:59:59'
         else v_lok::time + interval '30 minutes' end,
    p_status, 'manual'
  from fix f, ident i
  returning id into v_id;
  return v_id;
end $$;

-- Dan od danas (po Sarajevu) u lokalno vrijeme — za claim, koji gleda pravi now().
create function pg_temp.lok(p_dana int, p_time time) returns timestamptz language sql as $$
  select (((now() at time zone 'Europe/Sarajevo')::date + p_dana) + p_time)
    at time zone 'Europe/Sarajevo'
$$;

create function pg_temp.redova(p_termin uuid, p_tip text) returns int language sql as $$
  select count(*)::int from public.notification_logs
  where appointment_id = p_termin and type::text = p_tip
$$;

-- Lokalni trenutak salona A kao timestamptz.
create function pg_temp.u(p_date date, p_time time) returns timestamptz language sql as $$
  select (p_date + p_time) at time zone 'Europe/Sarajevo'
$$;

-- Salon A pocinje sa N = 2, da se kasnije vidi da promjena na 3 mijenja trenutak.
update public.salon_settings set reminders_enabled = true, hourly_reminder_enabled = true,
  hourly_reminder_hours = 2
where salon_id = (select salon from fix);
update public.salon_settings set reminders_enabled = true, hourly_reminder_enabled = true,
  hourly_reminder_hours = 3
where salon_id = (select salon_b from fix);

create temporary table t as select
  -- dnevni tacno u R: pocetak R + 24 h
  pg_temp.termin('ana', (select r from fix) + interval '24 hours') as t1,
  -- satni: pocetak R + 2 h 30 min
  pg_temp.termin('ana', (select r from fix) + interval '150 minutes') as t2,
  -- potvrdjen kasnije od trenutka satnog (R + 1 h - 3 h = R - 2 h, potvrdjen u R - 30 min)
  pg_temp.termin('ana', (select r from fix) + interval '1 hour') as t3,
  -- zakazan kasnije od trenutka dnevnog (R + 23 h - 24 h = R - 1 h, zakazan u R - 30 min)
  pg_temp.termin('ana', (select r from fix) + interval '23 hours') as t4,
  pg_temp.termin('ana', (select r from fix) + interval '23 hours 15 minutes', 'cancelled') as t5_otkazan,
  pg_temp.termin('ana', (select r from fix) + interval '23 hours 30 minutes', 'pending') as t5_ceka,
  pg_temp.termin('bob', (select r from fix) + interval '24 hours') as t6_bob,
  -- vec je poceo u R
  pg_temp.termin('ana', (select r from fix) - interval '1 hour') as t8,
  -- blizu ponoci: dnevni prozor se zatvara u ponoc pred dan termina (d + 1 u 06:00)
  pg_temp.termin('ana', pg_temp.u((select d from fix) + 1, '06:00')) as t9;
grant select on t to public;

update public.appointments set confirmed_at = (select r from fix) - interval '30 minutes'
where id = (select t3 from t);
-- `confirmed_at = null`: termin iz vremena prije taska 56 cita se kao `created_at`.
update public.appointments set created_at = (select r from fix) - interval '30 minutes',
  confirmed_at = null
where id = (select t4 from t);

select ok((select confirmed_at is not null from public.appointments where id = (select t1 from t)),
  'Upis potvrdjenog termina pise confirmed_at');
select ok((select confirmed_at is null from public.appointments where id = (select t5_ceka from t)),
  'Zahtjev na cekanju nema confirmed_at');

-- ---------------------------------------------------------------------------
-- 1. Ponoc pred dan termina (prije glavnog prolaza)
-- ---------------------------------------------------------------------------
select is(pg_temp.redova((select t9 from t), 'reminder_d1'), 0, 'Polazno: t9 nema dnevni');
select private.queue_reminders(pg_temp.u((select d from fix) + 1, '00:10'));
select is(pg_temp.redova((select t9 from t), 'reminder_d1'), 0,
  'Dnevni ne nastaje poslije ponoci pred dan termina, iako termin jos nije poceo');

-- ---------------------------------------------------------------------------
-- 2. Zona salona: salon B radi u New Yorku
-- ---------------------------------------------------------------------------
update public.salon_settings set timezone = 'America/New_York'
where salon_id = (select salon_b from fix);
create temporary table tb as select
  pg_temp.termin('ana', ((select d from fix) + 1 + time '00:30') at time zone 'America/New_York',
    'confirmed', 'b') as t11;
grant select on tb to public;

-- Trenutak dnevnog je 24 h prije d + 1 u 00:30 po New Yorku. Da se racuna po Sarajevu (ili UTC-u), bio bi
-- sest (pet) sati ranije i red bi postojao vec minut prije pravog trenutka.
select private.queue_reminders(
  ((select d from fix) + 1 + time '00:30') at time zone 'America/New_York' - interval '24 hours 1 minute');
select is(pg_temp.redova((select t11 from tb), 'reminder_d1'), 0,
  'Zona salona: minut prije 24 h po lokalnom vremenu salona nema dnevnog');
select private.queue_reminders(
  ((select d from fix) + 1 + time '00:30') at time zone 'America/New_York' - interval '23 hours 59 minutes');
select is(pg_temp.redova((select t11 from tb), 'reminder_d1'), 1,
  'Zona salona: minut poslije nastaje tacno jedan dnevni');
select is((select device_id from public.notification_logs
  where appointment_id = (select t11 from tb) and type = 'reminder_d1'),
  (select id from ana_b_tel), 'Termin salona B ide samo Aninom uredjaju u salonu B');

-- ---------------------------------------------------------------------------
-- 3. Glavni prolaz u R (salon A, N = 2)
-- ---------------------------------------------------------------------------
create temporary table prolaz1 as
  select private.queue_reminders((select r from fix)) as broj;
grant select on prolaz1 to public;
select ok((select broj from prolaz1) > 0, 'Prvi prolaz pravi redove');

select is(pg_temp.redova((select t1 from t), 'reminder_d1'), 2,
  'Dnevni tacno 24 h prije: jedan red po Aninom uredjaju sa tokenom (telefon i tablet)');
select is(
  (select array_agg(device_id order by device_id) from public.notification_logs
   where appointment_id = (select t1 from t) and type = 'reminder_d1'),
  (select array_agg(id order by id) from (
    select id from ana_tel union all select id from ana_tablet) x),
  'Dnevni ide telefonu i tabletu vlasnice termina, nikom drugom');
select is((select count(*)::int from public.notification_logs
  where device_id = (select id from ana_bez_tokena)), 0, 'Uredjaj bez tokena ne dobija nista');
select is((select count(*)::int from public.notification_logs
  where device_id = (select id from vlasnik_uredjaj) and type in ('reminder_d1', 'reminder_h3')),
  0, 'Uredjaj osoblja ne dobija podsjetnik');
select is((select count(*)::int from public.notification_logs n
  join public.appointments a on a.id = n.appointment_id
  where n.device_id = (select id from bob_tel) and a.auth_identity_id = (select ana from ident)),
  0, 'Bobov uredjaj ne dobija Anin podsjetnik');
select is((select count(*)::int from public.notification_logs n
  join public.appointments a on a.id = n.appointment_id
  where n.device_id = (select id from ana_b_tel) and a.salon_id = (select salon from fix)),
  0, 'Anin uredjaj u salonu B ne dobija podsjetnik za termin salona A');
select is(pg_temp.redova((select t6_bob from t), 'reminder_d1'), 1,
  'Bob dobija svoj dnevni, na svoj uredjaj');
select is(pg_temp.redova((select t1 from t), 'reminder_h3'), 0,
  'Termin sutra u podne jos nema satnog');
select is(pg_temp.redova((select t2 from t), 'reminder_h3'), 0,
  'N = 2: termin za 2 h 30 min jos nema satnog');
select is(pg_temp.redova((select t2 from t), 'reminder_d1'), 0,
  'Termin danas nema dnevnog: ponoc pred njegov dan je prosla');
select is(pg_temp.redova((select t5_otkazan from t), 'reminder_d1'), 0, 'Otkazan termin nema podsjetnik');
select is(pg_temp.redova((select t5_ceka from t), 'reminder_d1'), 0, 'Zahtjev na cekanju nema podsjetnik');
select is(pg_temp.redova((select t4 from t), 'reminder_d1'), 0,
  'Termin zakazan poslije trenutka dnevnog ne dobija dnevni');
select is(pg_temp.redova((select t8 from t), 'reminder_h3'), 0,
  'Termin koji je vec poceo ne dobija satni');
select is(pg_temp.redova((select t8 from t), 'reminder_d1'), 0,
  'Termin koji je vec poceo ne dobija dnevni');
select is(pg_temp.redova((select t9 from t), 'reminder_d1'), 2,
  'Isti termin blizu ponoci dobija dnevni dok je prozor otvoren');

-- ---------------------------------------------------------------------------
-- 4. Drugi prolaz
-- ---------------------------------------------------------------------------
create temporary table prije as select count(*)::int as n from public.notification_logs;
grant select on prije to public;
select is(private.queue_reminders((select r from fix)), 0, 'Drugi prolaz ne pravi nijedan red');
select is((select count(*)::int from public.notification_logs), (select n from prije),
  'Broj redova je isti poslije drugog prolaza');

-- ---------------------------------------------------------------------------
-- 5. Vlasnik mijenja N na 3 kroz update_salon_settings
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fd000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table snimljeno as select * from public.update_salon_settings(
  (select salon from fix), 'manual', 'exact_slot', 5, 15, 2, 30, 3, false, true,
  p_hourly_reminder_hours => 3);
reset role;
grant select on snimljeno to public;
select is((select hourly_reminder_hours from snimljeno), 3, 'Vlasnik snima N = 3');
select ok((select reminders_enabled and hourly_reminder_enabled from snimljeno),
  'Prekidaci koji nisu poslani ostaju kakvi su bili');

select private.queue_reminders((select r from fix));
select is(pg_temp.redova((select t2 from t), 'reminder_h3'), 2,
  'N = 3: isti termin za 2 h 30 min sada dobija satni, na oba uredjaja');
select is(pg_temp.redova((select t3 from t), 'reminder_h3'), 0,
  'Termin potvrdjen poslije trenutka satnog ne dobija satni');
select is(pg_temp.redova((select t8 from t), 'reminder_h3'), 0,
  'Ni sa N = 3 termin koji je poceo ne dobija satni');

-- ---------------------------------------------------------------------------
-- 6. Ugasen dnevni, pa ugasen satni
-- ---------------------------------------------------------------------------
update public.salon_settings set reminders_enabled = false, hourly_reminder_enabled = true
where salon_id = (select salon from fix);
create temporary table t_ugaseno as select
  pg_temp.termin('ana', (select r from fix) + interval '23 hours 45 minutes') as d1_ugasen,
  pg_temp.termin('ana', (select r from fix) + interval '165 minutes') as h3_radi;
grant select on t_ugaseno to public;
select private.queue_reminders((select r from fix));
select is(pg_temp.redova((select d1_ugasen from t_ugaseno), 'reminder_d1'), 0,
  'Ugasen dnevni ne pravi red');
select is(pg_temp.redova((select h3_radi from t_ugaseno), 'reminder_h3'), 2,
  'Ugasen dnevni ne gasi satni');

update public.salon_settings set reminders_enabled = true, hourly_reminder_enabled = false
where salon_id = (select salon from fix);
create temporary table t_ugaseno2 as select
  pg_temp.termin('ana', (select r from fix) + interval '170 minutes') as h3_ugasen,
  pg_temp.termin('ana', (select r from fix) + interval '23 hours 50 minutes') as d1_radi;
grant select on t_ugaseno2 to public;
select private.queue_reminders((select r from fix));
select is(pg_temp.redova((select h3_ugasen from t_ugaseno2), 'reminder_h3'), 0,
  'Ugasen satni ne pravi red');
select is(pg_temp.redova((select d1_radi from t_ugaseno2), 'reminder_d1'), 2,
  'Ugasen satni ne gasi dnevni');

-- ---------------------------------------------------------------------------
-- 7. Slanje (pravi now()): podsjetnik koji vise ne vrijedi ide u `logged`
-- ---------------------------------------------------------------------------
update public.salon_settings set reminders_enabled = true, hourly_reminder_enabled = true,
  timezone = 'Europe/Sarajevo'
where salon_id in ((select salon from fix), (select salon_b from fix));
-- Override salona A nadjacava pack; salon B cita rijec iz svog packa.
update public.salons set terminology_override = '{"appointmentSingular":"Tretman"}'
where id = (select salon from fix);
update public.vertical_packs set terminology = terminology || '{"appointmentSingular":"Rezervacija"}'
where key = (select vertical_pack_key from public.salons where id = (select salon_b from fix));

create temporary table c as select
  pg_temp.termin('ana', pg_temp.lok(2, '12:00')) as vrijedi,
  pg_temp.termin('ana', pg_temp.lok(2, '13:00')) as otkazan,
  pg_temp.termin('ana', pg_temp.lok(-1, '10:00')) as poceo,
  -- dnevni za termin danas: ponoc pred njegov dan je prosla (ili je i sam termin prosao)
  pg_temp.termin('ana', pg_temp.lok(0, '23:58')) as zakasnio,
  pg_temp.termin('ana', pg_temp.lok(2, '12:00'), 'confirmed', 'b') as u_b;
grant select on c to public;

insert into public.notification_logs(salon_id, appointment_id, device_id, type)
select (select salon from fix), x.termin, (select id from ana_tel), x.tip::public.notification_type
from (values
  ((select vrijedi from c), 'reminder_d1'),
  ((select vrijedi from c), 'reminder_h3'),
  ((select otkazan from c), 'reminder_d1'),
  ((select poceo from c), 'reminder_h3'),
  ((select zakasnio from c), 'reminder_d1')
) x(termin, tip);
insert into public.notification_logs(salon_id, appointment_id, device_id, type)
values ((select salon_b from fix), (select u_b from c), (select id from ana_b_tel), 'reminder_d1');

-- Red je cekao, a salon je u medjuvremenu otkazao termin.
update public.appointments set status = 'cancelled', cancelled_by = 'salon'
where id = (select otkazan from c);

create temporary table preuzeto as select * from public.claim_push_notifications(100);
grant select on preuzeto to public;

create function pg_temp.stanje(p_termin uuid, p_tip text) returns text language sql as $$
  select status::text || coalesce(':' || error, '') from public.notification_logs
  where appointment_id = p_termin and type::text = p_tip limit 1
$$;

select is(pg_temp.stanje((select vrijedi from c), 'reminder_d1'), 'sending',
  'Vazeci dnevni se preuzima za slanje');
select is(pg_temp.stanje((select vrijedi from c), 'reminder_h3'), 'sending',
  'Vazeci satni se preuzima za slanje');
select is(pg_temp.stanje((select otkazan from c), 'reminder_d1'),
  'logged:appointment_not_confirmed', 'Podsjetnik otkazanog termina ne odlazi');
select is(pg_temp.stanje((select poceo from c), 'reminder_h3'),
  'logged:appointment_started', 'Podsjetnik termina koji je poceo ne odlazi');
-- Termin u 23:58 je ili jos ispred (dnevni je zakasnio preko ponoci) ili je i on prosao; u oba
-- slucaja red ne odlazi.
select ok(pg_temp.stanje((select zakasnio from c), 'reminder_d1')
    in ('logged:reminder_late', 'logged:appointment_started'),
  'Dnevni poslije ponoci pred dan termina ne odlazi');
select is((select appointment_term from preuzeto
  where appointment_id = (select vrijedi from c) and type = 'reminder_d1'), 'Tretman',
  'Rijec za termin: override salona nadjacava pack');
select is((select appointment_term from preuzeto
  where appointment_id = (select u_b from c)), 'Rezervacija',
  'Rijec za termin: salon bez override-a cita svoj vertikalni pack');
select ok((select starts_in_minutes between 24 * 60 and 3 * 24 * 60 from preuzeto
  where appointment_id = (select vrijedi from c) and type = 'reminder_h3'),
  'Satni nosi minute do pocetka racunate pri slanju');
select ok((select starts_in_minutes is null from preuzeto
  where appointment_id = (select vrijedi from c) and type = 'reminder_d1'),
  'Dnevni ne nosi minute');
-- Samo tipovi podsjetnika: otkazivanje od salona je klijentu napravilo i red `cancelled`.
select ok(not exists (select 1 from preuzeto where appointment_id in
    ((select otkazan from c), (select poceo from c), (select zakasnio from c))
    and type in ('reminder_d1', 'reminder_h3')),
  'Nijedan nevazeci podsjetnik nije u preuzetim');

-- Salon ugasi podsjetnik dok red ceka.
create temporary table c2 as select
  pg_temp.termin('ana', pg_temp.lok(2, '14:00')) as d1,
  pg_temp.termin('ana', pg_temp.lok(2, '15:00')) as h3;
grant select on c2 to public;
insert into public.notification_logs(salon_id, appointment_id, device_id, type) values
  ((select salon from fix), (select d1 from c2), (select id from ana_tel), 'reminder_d1'),
  ((select salon from fix), (select h3 from c2), (select id from ana_tel), 'reminder_h3');
update public.salon_settings set reminders_enabled = false
where salon_id = (select salon from fix);
select public.claim_push_notifications(100);
select is(pg_temp.stanje((select d1 from c2), 'reminder_d1'), 'logged:reminder_disabled',
  'Dnevni koji ceka ne odlazi kad salon ugasi dnevni');
select is(pg_temp.stanje((select h3 from c2), 'reminder_h3'), 'sending',
  'Satni i dalje odlazi kad je ugasen samo dnevni');

create temporary table c3 as select
  pg_temp.termin('ana', pg_temp.lok(2, '16:00')) as h3;
grant select on c3 to public;
insert into public.notification_logs(salon_id, appointment_id, device_id, type) values
  ((select salon from fix), (select h3 from c3), (select id from ana_tel), 'reminder_h3');
update public.salon_settings set reminders_enabled = true, hourly_reminder_enabled = false
where salon_id = (select salon from fix);
select public.claim_push_notifications(100);
select is(pg_temp.stanje((select h3 from c3), 'reminder_h3'), 'logged:reminder_disabled',
  'Satni koji ceka ne odlazi kad salon ugasi satni');

-- ---------------------------------------------------------------------------
-- 8. Trenutak potvrde
-- ---------------------------------------------------------------------------
create temporary table p as select
  pg_temp.termin('ana', (select r from fix) + interval '5 days', 'pending') as zahtjev;
grant select on p to public;
update public.appointments set status = 'confirmed', pending_expires_at = null
where id = (select zahtjev from p);
select ok((select confirmed_at = now() from public.appointments where id = (select zahtjev from p)),
  'Prelaz u confirmed pise confirmed_at');
update public.appointments set status = 'completed' where id = (select zahtjev from p);
select ok((select confirmed_at = now() from public.appointments where id = (select zahtjev from p)),
  'Zavrsen termin zadrzava trenutak potvrde');
insert into public.appointments(salon_id, service_id, customer_id, auth_identity_id, device_id,
  customer_name, date, start_time, end_time, status, source, confirmed_at)
select f.salon, f.usluga, (select customer_id from ana), i.ana, (select id from ana_tel),
  'ana', f.d + 6, '10:00', '10:30', 'confirmed', 'manual', now() - interval '30 days'
from fix f, ident i;
select ok((select confirmed_at = now() from public.appointments
  where date = (select d from fix) + 6 and customer_id = (select customer_id from ana)),
  'Upis ne moze postaviti confirmed_at unazad');

-- ---------------------------------------------------------------------------
-- 9. Grantovi, cron i update_salon_settings
-- ---------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'private.queue_reminders(timestamptz)', 'EXECUTE'),
  'Anon ne pravi podsjetnike');
select ok(not has_function_privilege('authenticated', 'private.queue_reminders(timestamptz)', 'EXECUTE'),
  'Prijavljen korisnik ne pravi podsjetnike');
select ok(has_function_privilege('service_role', 'private.queue_reminders(timestamptz)', 'EXECUTE'),
  'service_role (cron) pravi podsjetnike');
select ok(not has_function_privilege('anon', 'private.stamp_confirmed_at()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'private.stamp_confirmed_at()', 'EXECUTE'),
  'Trigger funkcija nije pozivljiva iz aplikacije');
select ok(not has_function_privilege('anon', 'public.claim_push_notifications(int)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.claim_push_notifications(int)', 'EXECUTE'),
  'Claim i dalje samo za service_role');
select ok(has_function_privilege('service_role', 'public.claim_push_notifications(int)', 'EXECUTE'),
  'send-push (service_role) zove claim');
select is((select schedule from cron.job where jobname = 'queue-reminders'), '*/5 * * * *',
  'Cron queue-reminders ide svakih 5 minuta');
select is((select command from cron.job where jobname = 'queue-reminders'),
  'select private.queue_reminders()', 'Cron zove queue_reminders bez sata');

select ok(not has_function_privilege('anon',
  'public.update_salon_settings(uuid, text, text, int, int, int, int, int, boolean, boolean, boolean, boolean, int)',
  'EXECUTE'), 'Anon ne mijenja podsjetnike');

-- Klijent nije admin.
set local request.jwt.claims = '{"sub":"fd000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select throws_ok($$ select public.update_salon_settings(
  '550e8400-e29b-41d4-a716-446655440000', 'manual', 'exact_slot', 5, 15, 2, 30, 3, false, true,
  false, false, 3) $$, '42501', null, 'Klijent ne gasi podsjetnike salona');
reset role;

-- Vlasnik A nad salonom B.
set local request.jwt.claims = '{"sub":"fd000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok($$ select public.update_salon_settings(
  '550e8400-e29b-41d4-a716-446655440001', 'manual', 'exact_slot', 5, 15, 2, 30, 3, false, true,
  false, false, 3) $$, '42501', null, 'Vlasnik salona A ne mijenja podsjetnike salona B');
select throws_ok($$ select public.update_salon_settings(
  '550e8400-e29b-41d4-a716-446655440000', 'manual', 'exact_slot', 5, 15, 2, 30, 3, false, true,
  true, true, 0) $$, 'PT400', null, 'N = 0 se odbija rečenicom');
select throws_ok($$ select public.update_salon_settings(
  '550e8400-e29b-41d4-a716-446655440000', 'manual', 'exact_slot', 5, 15, 2, 30, 3, false, true,
  true, true, 13) $$, 'PT400', null, 'N = 13 se odbija rečenicom');
create temporary table ugaseno as select * from public.update_salon_settings(
  '550e8400-e29b-41d4-a716-446655440000', 'manual', 'exact_slot', 5, 15, 2, 30, 3, false, true,
  false, false, 12);
-- Stara Melura: deset argumenata, bez podsjetnika — ne smije ih vratiti na podrazumijevano.
create temporary table stari_poziv as select * from public.update_salon_settings(
  '550e8400-e29b-41d4-a716-446655440000', 'manual', 'exact_slot', 5, 15, 2, 30, 3, false, true);
reset role;
grant select on ugaseno, stari_poziv to public;
select ok((select not reminders_enabled and not hourly_reminder_enabled
  and hourly_reminder_hours = 12 from ugaseno), 'Vlasnik gasi oba podsjetnika i bira N = 12');
select ok((select not reminders_enabled and not hourly_reminder_enabled
  and hourly_reminder_hours = 12 from stari_poziv),
  'Poziv bez argumenata podsjetnika ih ne dira');

select throws_ok($$ update public.salon_settings set hourly_reminder_hours = 13
  where salon_id = '550e8400-e29b-41d4-a716-446655440000' $$, '23514', null,
  'Check granica drzi N u 1–12 i mimo RPC-a');

select * from finish();
rollback;
