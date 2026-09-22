-- Task 39: salon dobija obavijest o novoj rezervaciji i kad je salon u `auto` modu.
--
-- `queue_appointment_push` je napisan u tasku 25, kad je `pending` bio jedini ishod
-- klijentske rezervacije. Grana za `INSERT` zato glasi:
--
--   if new.source <> 'app' or new.status <> 'pending' then return new; end if;
--
-- Task 37 je spojio `salon_settings.booking_mode` na `book_appointment`, pa klijentska
-- rezervacija u `auto` modu nastaje kao `confirmed`. Time je **drugi uslov postao lazan**
-- i trigger tiho odustaje: salon u `auto` modu nije dobio nijednu obavijest o novoj
-- rezervaciji. Nije pukao ni FCM ni cron — red se prestao stvarati.
--
-- Dokaz iz hostovanog projekta prije ove migracije: 17 `app` termina 2026-09-21, nula
-- redova u `notification_logs` za njih, i **nula redova tipa `new_request` ikad**.
--
-- **Zasto novi tip, a ne `new_request`.** Naslov koji worker salje za `new_request` je
-- „Novi zahtjev". U `auto` modu nema zahtjeva — termin je vec potvrdjen i vlasnik nema na
-- sta odgovoriti. Poslati mu „Novi zahtjev" znaci poslati ga da trazi ekran zahtjeva koji
-- je prazan. Tip nosi **sta se desilo**, ne kome se salje, pa dva razlicita dogadjaja ne
-- dijele jedan tip.
--
-- **Klijent u `auto` modu namjerno ne dobija push.** Tip `confirmed` se salje na *promjenu*
-- statusa, a u `auto` modu promjene nema: termin je potvrdjen u trenutku upisa, dok klijent
-- gleda ekran koji mu to pise. Push „Zahtjev je potvrdjen" sekundu nakon sto je klijent sam
-- rezervisao javlja mu ono sto vec vidi, i to rijecju „zahtjev" koji nije ni postojao.
-- Ovo je odluka, ne previd — v. status blok taska 39.

-- Nova vrijednost se u istoj transakciji ne smije **upotrijebiti**, ali tijelo plpgsql
-- funkcije se razrjesava tek pri pozivu, u nekoj kasnijoj transakciji. Zato `create or
-- replace` ispod smije pisati 'new_booking' iako je tip prosiren red iznad.
alter type public.notification_type add value if not exists 'new_booking';

create or replace function private.queue_appointment_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_type public.notification_type; v_staff boolean := false;
begin
  if tg_op = 'INSERT' then
    -- Rucni unos iz salona ne obavjestava salon o samom sebi, pa `source` i dalje presudjuje
    -- prvi. Status vise ne odlucuje **hoce li** se slati nego **sta** se salje.
    if new.source <> 'app' then return new; end if;
    if new.status = 'pending' then
      v_type := 'new_request';
    elsif new.status = 'confirmed' then
      v_type := 'new_booking';
    else
      -- Otkazan ili zavrsen termin ne nastaje kroz `book_appointment`. Ako ikad nastane,
      -- to nije dogadjaj o kojem se salon obavjestava kao o novoj rezervaciji.
      return new;
    end if;
    v_staff := true;
  elsif new.status is not distinct from old.status then
    return new;
  elsif new.status = 'confirmed' then
    v_type := 'confirmed';
  elsif new.status = 'cancelled' and new.cancelled_by = 'salon' then
    v_type := case when old.status = 'pending' then 'rejected'::public.notification_type
      else 'cancelled'::public.notification_type end;
  elsif new.status = 'cancelled' and new.cancelled_by = 'customer' then
    v_type := 'cancelled'; v_staff := true;
  else return new;
  end if;

  insert into public.notification_logs(salon_id, appointment_id, device_id, type)
  select new.salon_id, new.id, d.id, v_type from public.devices d
  where d.salon_id = new.salon_id and d.fcm_token is not null and (
    (v_staff and exists (select 1 from public.users u where u.id = d.staff_user_id
      and u.salon_id = new.salon_id and u.role = 'salon_admin'))
    or (not v_staff and d.id = new.device_id and d.staff_user_id is null
      and d.auth_identity_id = new.auth_identity_id)
  ) on conflict (appointment_id, device_id, type) do nothing;
  return new;
end $$;

-- `create or replace` ne dira privilegije postojece funkcije, ali nad bazom u kojoj je
-- funkcija nastala ovdje (`db reset`, cist CI checkout) naslijedila bi podrazumijevani
-- `execute` za `public`. Isti razlog kao u migraciji taska 37.
revoke all on function private.queue_appointment_push() from public, anon, authenticated;

comment on function private.queue_appointment_push() is
  'Puni notification_logs iz promjene termina. INSERT sa source=app javlja salonu: new_request u manual modu, new_booking u auto modu. Promjena statusa javlja klijentu (confirmed/rejected/cancelled), a otkazivanje od klijenta salonu.';
