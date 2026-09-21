begin;
set local search_path = public, extensions;
select no_plan();
create temporary table efix as select
 '550e8400-e29b-41d4-a716-446655440000'::uuid salon,
 '550e8400-e29b-41d4-a716-446655440001'::uuid drugi,
 '10000000-0000-4000-8000-000000000001'::uuid usluga,
 '10000000-0000-4000-8000-000000000002'::uuid usluga2;
grant select on efix to public;

select ok(not has_table_privilege('authenticated','public.employees','INSERT'), 'Nema direktnog insert radnika');
select ok(not has_table_privilege('authenticated','public.employees','UPDATE'), 'Nema direktnog update radnika');
select ok(not has_table_privilege('authenticated','public.employees','DELETE'), 'Radnik se ne brise');
select ok(not has_table_privilege('authenticated','public.employee_services','INSERT'), 'Nema direktnog insert veze');
select ok(not has_table_privilege('authenticated','public.employee_services','UPDATE'), 'Nema direktnog update veze');
select ok(not has_table_privilege('authenticated','public.employee_services','DELETE'), 'Nema direktnog delete veze');

set local request.jwt.claims = '{"sub":"11111111-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table novi_radnik as select * from public.create_employee(
 (select salon from efix),'  Test radnik  ','Barber','Bio',null,
 array[(select usluga from efix),(select usluga from efix)]);
reset role;
grant select on novi_radnik to public;
select is((select name from novi_radnik),'Test radnik','Ime je normalizovano');
select is((select experience_years from novi_radnik),null::integer,'Staz ostaje nullable');
select is((select count(*)::int from employee_services where employee_id=(select id from novi_radnik)),1,'Duplikati ne prave duple veze');
select is((select count(*)::int from public.users where id=(select id from novi_radnik)),0,'Radnik nije nalog');

set local role authenticated;
select throws_ok($$select create_employee((select salon from efix),' ','','',null,'{}')$$,'PT400',null,'Prazno ime je odbijeno');
select throws_ok($$select create_employee((select salon from efix),'Test','','',-1,'{}')$$,'PT400',null,'Negativan staz je odbijen');
select throws_ok($$select create_employee((select salon from efix),'Test','','',null,null)$$,'PT400',null,'NULL lista nije prazna lista');
select throws_ok($$select create_employee((select salon from efix),'Test','','',null,array[null::uuid])$$,'42501',null,'NULL service ID je odbijen');
select throws_ok($$select update_employee((select salon from efix),(select id from novi_radnik),'Ne smije ostati','','',2,array['10000000-0000-4000-8000-000000000005'::uuid])$$,'42501',null,'Tudja usluga odbijena prije izmjene');
select is((select name from employees where id=(select id from novi_radnik)),'Test radnik','Neuspjela izmjena je atomska');
select lives_ok($$select update_employee((select salon from efix),(select id from novi_radnik),'Novo ime','Stilista','Opis',4,array[(select usluga2 from efix)])$$,'Admin mijenja profil i veze zajedno');
select is((select service_id from employee_services where employee_id=(select id from novi_radnik)),(select usluga2 from efix),'Stara veza zamijenjena novom');
select lives_ok($$select update_employee((select salon from efix),(select id from novi_radnik),'Novo ime','','',null,'{}')$$,'Sve usluge mogu biti uklonjene');
select is((select count(*)::int from employee_services where employee_id=(select id from novi_radnik)),0,'Prazna lista stvarno uklanja veze');
select lives_ok($$select update_employee((select salon from efix),(select id from novi_radnik),'Novo ime','','',null,array[(select usluga from efix)])$$,'Usluge se mogu ponovo dodijeliti');
reset role;

-- Buduci i prosli termin ostaju netaknuti; trigger prepisuje podmetnuto ime.
insert into appointments(salon_id,service_id,employee_id,customer_id,customer_name,date,start_time,end_time,status,employee_name)
select efix.salon,efix.usluga,n.id,c.id,c.name,d.d,'09:00','09:30','confirmed','Podmetnuto'
from efix cross join novi_radnik n
cross join lateral (select id,name from customers where salon_id=efix.salon limit 1) c
cross join (values(current_date-8),(current_date+8)) d(d);
select is((select count(*)::int from appointments where employee_id=(select id from novi_radnik) and employee_name='Novo ime'),2,'Snapshot dolazi iz radnika, ne payload-a');
create temporary table sacuvani as select id,date,start_time,end_time,status,employee_id,employee_name from appointments where employee_id=(select id from novi_radnik);
set local role authenticated;
select lives_ok($$select set_employee_active((select salon from efix),(select id from novi_radnik),false)$$,'Deaktivacija uz buduce termine je dozvoljena');
select throws_ok($$delete from employees where id=(select id from novi_radnik)$$,'42501',null,'Brisanje uz buduce termine nije dozvoljeno');
select throws_ok($$select set_employee_active((select salon from efix),(select id from novi_radnik),null)$$,'PT400',null,'NULL status je odbijen');
reset role;
select results_eq('select id,date,start_time,end_time,status,employee_id,employee_name from appointments where employee_id=(select id from novi_radnik) order by id','select * from sacuvani order by id','Deaktivacija cuva prosle i buduce termine');
select is((select count(*)::int from employee_services where employee_id=(select id from novi_radnik)),1,'Deaktivacija cuva veze');
select is_empty($$select * from get_available_slots((select salon from efix),(select usluga from efix),current_date+8,(select id from novi_radnik))$$,'Neaktivan radnik nema novih slotova');

set local role anon;
select is((select count(*)::int from employees where id=(select id from novi_radnik)),0,'Anon ne vidi neaktivnog radnika');
select throws_ok($$select create_employee((select salon from efix),'Napad','','',null,'{}')$$,'42501',null,'Anon nema create RPC');
select throws_ok($$select update_employee((select salon from efix),(select id from novi_radnik),'Napad','','',null,'{}')$$,'42501',null,'Anon nema update RPC');
select throws_ok($$select set_employee_active((select salon from efix),(select id from novi_radnik),true)$$,'42501',null,'Anon nema status RPC');
reset role;

set local request.jwt.claims = '{"sub":"11111111-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select is((select count(*)::int from employees where id=(select id from novi_radnik)),0,'Admin B ne vidi neaktivnog radnika A');
select throws_ok($$select create_employee((select salon from efix),'Napad','','',null,'{}')$$,'42501',null,'Admin B ne kreira u salonu A');
select throws_ok($$select update_employee((select salon from efix),(select id from novi_radnik),'Napad','','',null,'{}')$$,'42501',null,'Admin B ne mijenja radnika A');
select throws_ok($$select set_employee_active((select salon from efix),(select id from novi_radnik),true)$$,'42501',null,'Admin B ne aktivira radnika A');
select throws_ok($$select update_employee((select drugi from efix),(select id from novi_radnik),'Napad','','',null,'{}')$$,'42501',null,'Vlastiti salon uz tudji ID ne zaobilazi zastitu');
select throws_ok($$select set_employee_active((select drugi from efix),(select id from novi_radnik),true)$$,'42501',null,'Status provjerava i ID i salon');
reset role;

set local request.jwt.claims = '{"role":"authenticated","app_metadata":{}}';
set local role authenticated;
select throws_ok($$select create_employee((select salon from efix),'Napad','','',null,'{}')$$,'42501',null,'Klijent ne kreira radnika');
select throws_ok($$select update_employee((select salon from efix),(select id from novi_radnik),'Napad','','',null,'{}')$$,'42501',null,'Klijent ne mijenja radnika');
select throws_ok($$select set_employee_active((select salon from efix),(select id from novi_radnik),true)$$,'42501',null,'Klijent ne aktivira radnika');
reset role;
set local request.jwt.claims = '{"sub":"11111111-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select lives_ok($$select set_employee_active((select salon from efix),(select id from novi_radnik),true)$$,'Vlasnik ponovo aktivira radnika');
reset role;
set local role anon;
select is((select count(*)::int from employees where id=(select id from novi_radnik)),1,'Aktivan radnik je ponovo javan');
reset role;
select * from finish();
rollback;
