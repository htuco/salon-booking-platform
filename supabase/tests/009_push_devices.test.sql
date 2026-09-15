begin;
set local search_path = public, extensions;
select no_plan();

insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data) values
('fa000000-0000-4000-8000-000000000001','push1@test.invalid','{}','{}'),
('fa000000-0000-4000-8000-000000000002','push2@test.invalid','{}','{}'),
('fa000000-0000-4000-8000-000000000003','pushadmin@test.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}','{}');
insert into public.users(id,salon_id,name,email,role) values
('fa000000-0000-4000-8000-000000000003','550e8400-e29b-41d4-a716-446655440000',
 'Push admin','pushadmin@test.invalid','salon_admin');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local request.jwt.claims = '{"role":"anon"}';
set local role anon;
create temporary table guest_device as select public.register_device(
 '550e8400-e29b-41d4-a716-446655440000','fa000000-0000-4000-8000-000000000011',
 repeat('a',64),'ios','client-token') id;
select is((select public.register_device('550e8400-e29b-41d4-a716-446655440000',
 'fa000000-0000-4000-8000-000000000011',repeat('a',64),'ios','client-token')),
 (select id from guest_device),'Anon registracija je idempotentna');
select throws_ok($$select public.register_device('550e8400-e29b-41d4-a716-446655440000',
 'fa000000-0000-4000-8000-000000000011',repeat('b',64),'ios','stolen')$$,
 '42501','Nije dozvoljeno','Poznat ID bez tajne ne daje preuzimanje uredjaja');
select throws_ok($$select public.claim_push_notifications()$$,'42501',null,
 'Anon ne moze preuzeti slanje');
select throws_ok($$select * from private.device_credentials$$,'42501',null,
 'Anon ne moze procitati hash tajne');
set local request.headers = '{}';
select throws_ok($$select public.register_device('550e8400-e29b-41d4-a716-446655440000',
 'fa000000-0000-4000-8000-000000000012',repeat('a',64),'ios')$$,
 '42501','Nije dozvoljeno','Nedostajuci header je odbijen');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select throws_ok($$select public.register_device('550e8400-e29b-41d4-a716-446655440000',
 'fa000000-0000-4000-8000-000000000012',repeat('a',64),'ios')$$,
 '42501','Nije dozvoljeno','Tudji salon iz headera je odbijen');
reset role;
grant select on guest_device to public;
select is((select auth_identity_id from public.devices where id=(select id from guest_device)),
 null::uuid,'Prije prijave nema izmisljenog identiteta');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;
select is(public.register_device('550e8400-e29b-41d4-a716-446655440000',
 'fa000000-0000-4000-8000-000000000011',repeat('a',64),'ios','refreshed-token'),
 (select id from guest_device),'Prijava veze isti devices.id');
select is((select count(*)::int from public.devices),1,'Vlasnik vidi vlastiti uredjaj');
select throws_ok($$update public.devices set fcm_token='stolen'$$,'42501',null,
 'Direktan update nije dozvoljen');
select throws_ok($$select public.register_device('550e8400-e29b-41d4-a716-446655440000',
 'fa000000-0000-4000-8000-000000000012',repeat('a',64),'ios','x',true)$$,
 '42501','Nije dozvoljeno','Klijent ne moze prijaviti staff uredjaj');
select throws_ok($$select * from private.device_credentials$$,'42501',null,
 'Klijent ne cita hash tajne');
select throws_ok($$select public.claim_push_notifications()$$,'42501',null,
 'Klijent ne moze pozvati servisni RPC');

set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is((select count(*)::int from public.devices),0,'Drugi klijent ne vidi prvi uredjaj');
select throws_ok($$select public.register_device('550e8400-e29b-41d4-a716-446655440000',
 'fa000000-0000-4000-8000-000000000011',repeat('b',64),'ios','stolen')$$,
 '42501','Nije dozvoljeno','Drugi identitet ne preuzima instalaciju bez tajne');
reset role;

set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select lives_ok($$select public.register_device('550e8400-e29b-41d4-a716-446655440000',
 'fa000000-0000-4000-8000-000000000013',repeat('c',64),'android','owner-token',true)$$,
 'Admin registruje vlastiti uredjaj');
select throws_ok($$select public.register_device('550e8400-e29b-41d4-a716-446655440001',
 'fa000000-0000-4000-8000-000000000013',repeat('c',64),'android','owner-token',true)$$,
 '42501','Nije dozvoljeno','Admin ne registruje uredjaj tudjeg salona');

set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000001","role":"authenticated"}';
create temporary table push_appointment as select (public.book_appointment(
 '550e8400-e29b-41d4-a716-446655440000',
 (public.ensure_customer('550e8400-e29b-41d4-a716-446655440000')).id,
 '10000000-0000-4000-8000-000000000001',
 (date_trunc('week',now() at time zone 'Europe/Sarajevo')+interval '8 days')::date,
 '15:00','20000000-0000-4000-8000-000000000001',null,(select id from guest_device))).id;
reset role;
grant select on push_appointment to public;
select is((select count(*)::int from public.notification_logs where appointment_id=(select id from push_appointment)
 and type='new_request'),1,'Novi zahtjev automatski stvara red za vlasnika');

set local role authenticated;
create temporary table rejected_appointment as select (public.book_appointment(
 '550e8400-e29b-41d4-a716-446655440000',
 (public.ensure_customer('550e8400-e29b-41d4-a716-446655440000')).id,
 '10000000-0000-4000-8000-000000000001',
 (date_trunc('week',now() at time zone 'Europe/Sarajevo')+interval '8 days')::date,
 '16:00','20000000-0000-4000-8000-000000000001',null,(select id from guest_device))).id;
reset role;
grant select on rejected_appointment to public;

set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select lives_ok($$select public.set_appointment_status('550e8400-e29b-41d4-a716-446655440000',(select id from push_appointment),'confirmed')$$,
 'Potvrda ide kroz postojeci RPC');
select lives_ok($$select public.set_appointment_status('550e8400-e29b-41d4-a716-446655440000',(select id from push_appointment),'confirmed')$$,
 'Ponovljena potvrda je dozvoljena');
select lives_ok($$select public.cancel_appointment('550e8400-e29b-41d4-a716-446655440000',
 (select id from rejected_appointment),'Nema slobodnog radnika')$$,'Odbijanje ide kroz cancel RPC');
reset role;
select is((select count(*)::int from public.notification_logs where appointment_id=(select id from push_appointment)
 and type='confirmed'),1,'Ponovljena potvrda ne stvara dupli log');
select is((select count(*)::int from public.notification_logs where appointment_id=(select id from rejected_appointment)
 and type='rejected'),1,'Odbijanje daje klijentski rejected log');

-- Transportna tabela ne smije nositi trajnu tajnu, cak ni kad je citljiva.
-- Vault i HTTP red su u rollback transakciji; stvarni HTTP poziv ne izlazi iz testa.
do $$ declare v_id uuid; begin
  select id into v_id from vault.secrets where name='push_worker_url';
  if v_id is null then perform vault.create_secret('http://localhost/push-test','push_worker_url');
  else perform vault.update_secret(v_id,'http://localhost/push-test'); end if;
  select id into v_id from vault.secrets where name='push_worker_secret';
  if v_id is null then perform vault.create_secret('push-test-secret','push_worker_secret');
  else perform vault.update_secret(v_id,'push-test-secret'); end if;
end $$;
select lives_ok('select private.dispatch_push()','Cron moze zakazati potpisan HTTP zahtjev');
select ok((select headers->>'Authorization' ~ '^Bearer [0-9]{10}\.[a-f0-9]{64}$'
 from net.http_request_queue where url='http://localhost/push-test' order by id desc limit 1),
 'Transport nosi timestamp i HMAC');
select ok((select headers::text not like '%push-test-secret%'
 from net.http_request_queue where url='http://localhost/push-test' order by id desc limit 1),
 'Trajna tajna ostaje u Vaultu');

set local role service_role;
select is((select count(*)::int from public.claim_push_notifications(100)),4,
 'Worker preuzima zahtjeve, potvrdu i odbijanje');
select is((select count(*)::int from public.claim_push_notifications(100)),0,
 'Drugi worker ne preuzima poruke koje su vec u slanju');
reset role;

select throws_ok($$update public.appointments set device_id=(select id from guest_device),
 auth_identity_id=null where id=(select id from push_appointment)$$,'42501','Nije dozvoljeno',
 'Isti salon nije dovoljan: termin mora pripadati identitetu uredjaja');
select lives_ok($$select public.cancel_appointment('550e8400-e29b-41d4-a716-446655440000',
 (select id from push_appointment),'Otkazivanje potvrde')$$,'Salon otkazuje potvrdjen termin');
select is((select count(*)::int from public.notification_logs where appointment_id=(select id from push_appointment)
 and type='cancelled' and status='queued'),1,'Otkazivanje potvrde ceka slanje');
select lives_ok($$select public.unregister_device('550e8400-e29b-41d4-a716-446655440000',
 'fa000000-0000-4000-8000-000000000011',repeat('a',64))$$,'Odjava koristi tajnu instalacije');
select is((select fcm_token from public.devices where id=(select id from guest_device)),
 null::text,'Odjava uklanja token');
select is((select status::text from public.notification_logs where appointment_id=(select id from push_appointment)
 and type='cancelled'),'logged','Odjava zaustavlja poruku koja jos nije preuzeta');
select is((select count(*)::int from public.claim_push_notifications(100)),0,
 'Nakon odjave nema slanja starom korisniku');

select * from finish();
rollback;
