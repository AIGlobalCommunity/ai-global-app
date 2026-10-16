create unique index if not exists agc_profiles_handle_ci_unique
 on public.agc_profiles (lower(handle));
create or replace function public.agc_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $body$
declare
  requested_handle text;
begin
  requested_handle := btrim(coalesce(new.raw_user_meta_data->>'handle', ''));
  if requested_handle = '' then
    requested_handle := 'Genesis_' || replace(new.id::text, '-', '');
  elsif requested_handle !~ '^[A-Za-z0-9_]{3,20}$' then
    raise exception 'Invalid nickname: use 3-20 letters, numbers or underscore';
  end if;
  insert into public.agc_profiles(id,handle,referral_code)
  values(new.id, requested_handle, upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)));
  insert into public.agc_points(member_id,points,reason,source_key)
  values(new.id,100,'signup','signup:' || new.id::text);
  return new;
end;
$body$;
