create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

create function private.dispatch_push() returns void
language plpgsql security definer set search_path = '' as $$
declare v_url text; v_secret text; v_timestamp text; v_signature text;
begin
  if not exists(select 1 from public.notification_logs where status = 'queued') then return; end if;
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'push_worker_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'push_worker_secret';
  -- Lokalni build bez Firebase naloga zadrzava queued poruke, ne glumi slanje.
  if v_url is null or v_secret is null then return; end if;
  -- pg_net posjeduje supabase_admin. Trajna tajna ne smije u njegove transportne tabele.
  v_timestamp := floor(extract(epoch from clock_timestamp()))::bigint::text;
  v_signature := encode(extensions.hmac('send-push:' || v_timestamp, v_secret, 'sha256'),'hex');
  perform net.http_post(url := v_url,
    headers := jsonb_build_object('Content-Type','application/json',
      'Authorization','Bearer ' || v_timestamp || '.' || v_signature),
    body := '{}'::jsonb, timeout_milliseconds := 1000);
end $$;
revoke all on function private.dispatch_push() from public, anon, authenticated;
grant execute on function private.dispatch_push() to service_role;
select cron.schedule('send-push-queued', '* * * * *', 'select private.dispatch_push()');
