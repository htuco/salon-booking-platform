-- Synchronize the global identity using trusted Supabase Auth data.
create function private.sync_auth_identity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 insert into public.auth_identities(supabase_user_id,providers,email,email_verified,display_name,is_anonymous,last_login_at)
 values(new.id,
 coalesce(array(select jsonb_array_elements_text(new.raw_app_meta_data->'providers')),array[]::text[]),
 new.email,new.email_confirmed_at is not null,
 coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name'),
 coalesce(new.is_anonymous,false),coalesce(new.last_sign_in_at,now()))
 on conflict(supabase_user_id) do update set
 providers=excluded.providers,email=excluded.email,email_verified=excluded.email_verified,
 display_name=coalesce(excluded.display_name,public.auth_identities.display_name),
 is_anonymous=excluded.is_anonymous,last_login_at=excluded.last_login_at
 where public.auth_identities.deleted_at is null;
 return new;
end $$;
revoke all on function private.sync_auth_identity() from public;
create trigger sync_auth_identity after insert or update on auth.users
for each row execute function private.sync_auth_identity();
