begin;
set local search_path = public, extensions;
select no_plan();

-- All fixtures are rolled back, including users and identities.
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data)
values
('a0000000-0000-4000-8000-000000000001','admin-a@rls.invalid','{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}','{}'),
('a0000000-0000-4000-8000-000000000002','admin-b@rls.invalid','{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}','{}'),
('a0000000-0000-4000-8000-000000000003','client@rls.invalid','{"providers":["email"]}','{"name":"Shared Client"}'),
('a0000000-0000-4000-8000-000000000004','other@rls.invalid','{"providers":["email"]}','{"name":"Other Client"}');
insert into public.users(id,salon_id,name,email,role) values
('a0000000-0000-4000-8000-000000000001','550e8400-e29b-41d4-a716-446655440000','Owner A','admin-a@rls.invalid','salon_admin'),
('a0000000-0000-4000-8000-000000000002','550e8400-e29b-41d4-a716-446655440001','Owner B','admin-b@rls.invalid','salon_admin');
update public.auth_identities set id='b0000000-0000-4000-8000-000000000001' where supabase_user_id='a0000000-0000-4000-8000-000000000003';
update public.auth_identities set id='b0000000-0000-4000-8000-000000000002' where supabase_user_id='a0000000-0000-4000-8000-000000000004';

insert into public.customers(id,salon_id,auth_identity_id,name,visit_count) values
('c0000000-0000-4000-8000-000000000001','550e8400-e29b-41d4-a716-446655440000','b0000000-0000-4000-8000-000000000001','Shared Client',2),
('c0000000-0000-4000-8000-000000000002','550e8400-e29b-41d4-a716-446655440001','b0000000-0000-4000-8000-000000000001','Shared Client',9),
('c0000000-0000-4000-8000-000000000003','550e8400-e29b-41d4-a716-446655440000','b0000000-0000-4000-8000-000000000002','Other Client',0);
insert into public.appointments(id,salon_id,service_id,employee_id,customer_id,auth_identity_id,customer_name,date,start_time,end_time,status) values
('d0000000-0000-4000-8000-000000000001','550e8400-e29b-41d4-a716-446655440000','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','c0000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001','Shared Client','2030-01-07','10:00','10:30','confirmed'),
('d0000000-0000-4000-8000-000000000002','550e8400-e29b-41d4-a716-446655440001','10000000-0000-4000-8000-000000000005','20000000-0000-4000-8000-000000000003','c0000000-0000-4000-8000-000000000002','b0000000-0000-4000-8000-000000000001','Shared Client','2030-01-07','10:00','10:45','confirmed');
insert into public.salons(id,name,slug,city,status,vertical_pack_key) values
('550e8400-e29b-41d4-a716-446655440099','Inactive fixture','inactive-fixture','Vitez','inactive','barber');
insert into public.services(salon_id,name,price,duration_minutes) values
('550e8400-e29b-41d4-a716-446655440099','Hidden service',1,30);
insert into public.employees(salon_id,name) values ('550e8400-e29b-41d4-a716-446655440099','Hidden worker');

select is((select count(*)::int from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('vertical_packs','salons','salon_builds','users','services','employees','employee_services','working_hours','auth_identities','customers','devices','appointments','blocked_slots','notification_logs','salon_settings')
and c.relrowsecurity),15,'RLS enabled on all 15 MVP entities');
select is((select count(*)::int from public.auth_identities where supabase_user_id='a0000000-0000-4000-8000-000000000003'),1,'Auth trigger creates one identity');
update auth.users set last_sign_in_at=now() where id='a0000000-0000-4000-8000-000000000003';
select is((select count(*)::int from public.auth_identities where supabase_user_id='a0000000-0000-4000-8000-000000000003'),1,'Auth update upserts without duplicate identity');

set local role anon;
select is((select count(*)::int from public.salons),2,'Anonymous sees both active salons');
select is((select count(*)::int from public.services),8,'Anonymous sees only active salon services');
select is((select count(*)::int from public.employees),4,'Anonymous sees only active salon employees');
select throws_ok($$insert into public.services(salon_id,name,price,duration_minutes) values('550e8400-e29b-41d4-a716-446655440000','Attack',1,30)$$,'42501','permission denied for table services','Anonymous cannot insert');
select throws_ok($$update public.services set price=0$$,'42501','permission denied for table services','Anonymous cannot update');
select throws_ok($$delete from public.services$$,'42501','permission denied for table services','Anonymous cannot delete');
select throws_ok($$select * from public.customers$$,'42501','permission denied for table customers','Anonymous cannot read customers');
reset role;

set local request.jwt.claims = '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
set local role authenticated;
-- Counted as a leak, not as a total. These used to assert `= 1` and `= 2`, which silently
-- assumed an empty seed: task 23 added demo customers and appointments so the admin list has
-- something to show, and both assertions broke without a single policy changing. An absolute
-- count tests the fixture; what this file is actually about is whether *anything* from salon B
-- crosses over, so that is what it now counts.
select is((select count(*)::int from public.appointments where salon_id<>'550e8400-e29b-41d4-a716-446655440000'),0,'Owner A sees only salon A even with salon B header');
select is((select count(*)::int from public.appointments where salon_id='550e8400-e29b-41d4-a716-446655440001'),0,'Owner A cannot SELECT salon B appointments');
-- Task 24 revoked INSERT/UPDATE on appointments for `authenticated`, so this now fails on the
-- grant before RLS is consulted at all. The claim is unchanged and the proof is strictly
-- stronger: previously the write was allowed and filtered down to zero rows, now the write
-- path does not exist. Writes go through book_appointment / set_appointment_status /
-- cancel_appointment, which check salon ownership themselves.
select throws_ok($$update public.appointments set customer_name='Compromised' where salon_id='550e8400-e29b-41d4-a716-446655440001'$$,'42501',null,'Owner A cannot UPDATE salon B appointments');
select results_eq($$delete from public.appointments where salon_id='550e8400-e29b-41d4-a716-446655440001' returning id$$,$$select null::uuid where false$$,'Owner A cannot DELETE salon B appointments');
select is((select count(*)::int from public.customers where salon_id<>'550e8400-e29b-41d4-a716-446655440000'),0,'Owner A only sees its own customer records');
-- Kept as a positive check so the assertion above cannot pass on an empty result: zero rows
-- visible would satisfy "no foreign rows" while proving nothing at all.
select cmp_ok((select count(*)::int from public.customers),'>',0,'Owner A still sees its own customers');
select is((select count(*)::int from public.auth_identities),0,'Salon admin cannot read any global identity data');
select is((select sum(visit_count)::int from public.customers),2,'Visit counts do not reveal other salon history');
select throws_ok($$insert into public.services(salon_id,name,price,duration_minutes) values('550e8400-e29b-41d4-a716-446655440001','Attack',1,30)$$,'42501',null,'Owner cannot insert into another salon');
select throws_ok($$insert into public.employee_services(salon_id,employee_id,service_id) values('550e8400-e29b-41d4-a716-446655440000','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000005')$$,'23503',null,'Composite FK rejects cross-tenant employee/service');
select throws_ok($$insert into public.blocked_slots(salon_id,employee_id,date,start_time,end_time) values('550e8400-e29b-41d4-a716-446655440000','20000000-0000-4000-8000-000000000003','2030-01-07','11:00','12:00')$$,'23503',null,'Composite FK rejects cross-tenant blocked employee');
reset role;
select is((select customer_name from public.appointments where id='d0000000-0000-4000-8000-000000000002'),'Shared Client','Other salon appointment survives unauthorized mutation');

set local request.jwt.claims = '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]},"user_metadata":{"role":"super_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local role authenticated;
select is((select count(*)::int from public.customers),1,'Client A sees only own salon A customer');
select is((select visit_count from public.customers),2,'Client A cannot see own salon B visit count');
select is((select count(*)::int from public.appointments),1,'Client A sees only own salon A appointment');
select is((select count(*)::int from public.appointments where salon_id='550e8400-e29b-41d4-a716-446655440001'),0,'Client A cannot query own salon B appointment without context switch');
select is((select count(*)::int from public.auth_identities),1,'Client sees only own global identity');
select ok(not private.is_super_admin(),'User metadata cannot grant super-admin');
select ok(not private.is_admin('550e8400-e29b-41d4-a716-446655440001'),'User metadata cannot grant salon-admin');
select results_eq($$update public.customers set is_vip=true returning id$$,$$select null::uuid where false$$,'Client cannot alter VIP or private customer fields');
select throws_ok($$insert into public.customers(salon_id,name,phone) values('550e8400-e29b-41d4-a716-446655440000','Injected','123')$$,'42501',null,'Client cannot bypass customer upsert to write phone');
set local request.headers = '{}';
select is((select count(*)::int from public.customers),0,'Missing salon context fails closed');
select is((select count(*)::int from public.appointments),0,'Missing salon context hides appointments');
set local request.headers = '{"x-salon-id":"not-a-uuid"}';
select is((select count(*)::int from public.customers),0,'Malformed salon context fails closed');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440099"}';
select is((select count(*)::int from public.customers),0,'Inactive salon context fails closed');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select is((select count(*)::int from public.customers),1,'Explicit switch sees only own salon B row');
select is((select visit_count from public.customers),9,'Customer statistics remain per salon');
reset role;

-- A forged/mistaken trusted claim still cannot manufacture staff membership.
set local request.jwt.claims = '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select ok(not private.is_admin('550e8400-e29b-41d4-a716-446655440001'),'Admin requires database membership as well as trusted claim');
select is((select count(*)::int from public.appointments),0,'Staff-shaped claim cannot use client read policies');
reset role;
select * from finish();
rollback;
