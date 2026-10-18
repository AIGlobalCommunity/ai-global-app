-- Public nickname visibility is enabled by default for new members,
-- including Google/Facebook OAuth. Explicit opt-out remains respected.
-- Existing members and their privacy settings are not modified.
alter table public.agc_profiles
  alter column show_nick_publicly set default true;

create or replace function public.agc_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  requested_handle text;
  requested_visibility boolean;
begin
  requested_handle := btrim(coalesce(new.raw_user_meta_data->>'handle', ''));
  if requested_handle = '' then
    -- OAuth users do not supply a nickname; keep the generated handle compact.
    requested_handle := 'Genesis_' || substr(replace(new.id::text, '-', ''), 1, 12);
  elsif requested_handle !~ '^[A-Za-z0-9_]{3,20}$' then
    raise exception 'Invalid nickname: use 3-20 letters, numbers or underscore';
  end if;

  requested_visibility := coalesce(
    (new.raw_user_meta_data->>'show_nick_publicly')::boolean, true);

  insert into public.agc_profiles(id, handle, referral_code, show_nick_publicly)
  values(
    new.id, requested_handle,
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
    requested_visibility
  );

  insert into public.agc_points(member_id, points, reason, source_key)
  values(new.id, 100, 'signup', 'signup:' || new.id::text);
  return new;
end;
$function$;
