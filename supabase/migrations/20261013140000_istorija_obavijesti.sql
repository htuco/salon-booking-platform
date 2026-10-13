-- Task 70: istorija obavijesti u klijentskoj app-i.
--
-- `notification_logs` od taska 25 biljezi svaku push poruku, ali klijent nije imao nijednu
-- putanju do nje: jedina politika je `staff_notification_logs`. Ekran „Obavijesti" je zato
-- bio namjerno prazan.
--
-- **RPC, a ne klijentska politika nad tabelom.** Red loga je po *uredjaju*, a ne po
-- korisniku: ista potvrda poslana na dva telefona su dva reda, a ekran treba jednu stavku.
-- Uz to klijent treba naziv usluge, radnika i vrijeme termina, koje politika nad
-- `notification_logs` ne bi dala bez druge politike nad `appointments`. Funkcija vraca
-- izvedenu, deduplikovanu listu i nista vise — isti obrazac kao `get_available_slots`.
--
-- **Vlasnistvo ide preko termina, ne preko uredjaja.** `unregister_device` (odjava) brise
-- identitet sa uredjaja, pa bi istorija vezana za uredjaj nestala pri svakoj odjavi. Termin
-- nosi `auth_identity_id` trajno. Uredjaj se gleda samo da bi se odbacili redovi poslani
-- osoblju (`staff_user_id is not null`): otkazivanje od klijenta javlja salonu tip
-- `cancelled`, i taj red nije klijentova obavijest iako je o njegovom terminu.
--
-- **Procitano** je kolona na redu loga. Oznaka „procitano" se postavlja za sve redove
-- jednog dogadjaja zajedno (svi uredjaji), pa deduplikacija ne moze dati pola procitanu
-- stavku.

alter table public.notification_logs add column read_at timestamptz;

create function public.my_notifications(p_limit integer default 50)
returns table (
  appointment_id uuid,
  type text,
  created_at timestamptz,
  read boolean,
  service_name text,
  employee_name text,
  date date,
  start_time time
)
language plpgsql stable security definer set search_path = '' as $$
declare v_salon uuid;
begin
  v_salon := private.client_salon_id();
  if not private.is_client() or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  return query
  select d.appointment_id, d.type, d.created_at, d.read,
    d.service_name, d.employee_name, d.date, d.start_time
  from (
    select n.appointment_id, n.type::text as type,
      min(n.created_at) as created_at,
      bool_and(n.read_at is not null) as read,
      a.service_name, a.employee_name, a.date, a.start_time
    from public.notification_logs n
    join public.appointments a on a.salon_id = n.salon_id and a.id = n.appointment_id
    join public.devices dv on dv.salon_id = n.salon_id and dv.id = n.device_id
    where n.salon_id = v_salon
      and a.auth_identity_id is not null
      and private.owns_identity(a.auth_identity_id)
      and dv.staff_user_id is null
    group by n.appointment_id, n.type, a.service_name, a.employee_name, a.date, a.start_time
  ) d
  order by d.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
end $$;

revoke all on function public.my_notifications(integer) from public, anon;
grant execute on function public.my_notifications(integer) to authenticated;

comment on function public.my_notifications(integer) is
  'Obavijesti klijenta u salonu iz x-salon-id: jedna stavka po (termin, tip), najnovije prve, sa oznakom procitanog. Samo termini ciji je identitet pozivaoca i samo redovi poslani klijentskim uredjajima. 42501 za osoblje, anon i bez konteksta.';

create function public.mark_notifications_read()
returns integer
language plpgsql security definer set search_path = '' as $$
declare v_salon uuid; v_count integer;
begin
  v_salon := private.client_salon_id();
  if not private.is_client() or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  update public.notification_logs n
  set read_at = now()
  from public.appointments a, public.devices dv
  where n.salon_id = v_salon and n.read_at is null
    and a.salon_id = n.salon_id and a.id = n.appointment_id
    and a.auth_identity_id is not null
    and private.owns_identity(a.auth_identity_id)
    and dv.salon_id = n.salon_id and dv.id = n.device_id
    and dv.staff_user_id is null;

  get diagnostics v_count = row_count;
  return v_count;
end $$;

revoke all on function public.mark_notifications_read() from public, anon;
grant execute on function public.mark_notifications_read() to authenticated;

comment on function public.mark_notifications_read() is
  'Oznacava procitanim sve obavijesti klijenta u salonu iz x-salon-id (isti skup kao my_notifications). Vraca broj redova.';
