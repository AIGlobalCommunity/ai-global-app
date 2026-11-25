-- Anonymous Supabase Auth sessions are temporary game identities, never Genesis members.
-- Preserve the existing registered member creation behavior unchanged.
create or replace function public.agc_new_user()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare requested_handle text;
declare requested_visibility boolean;
declare organization text;
begin
  -- This runs during auth.users insert. Prevent profile creation and signup rewards
  -- for temporary multiplayer guests; otherwise a GCO/ranking block would reject signup.
  if new.is_anonymous then
    return new;
  end if;
  if new.raw_user_meta_data->>'account_type' = 'founder' then
    organization := btrim(coalesce(new.raw_user_meta_data->>'organization_name',''));
    if char_length(organization) not between 2 and 120 then
      raise exception 'Organization name must be 2-120 characters';
    end if;
    insert into public.agc_founder_accounts(user_id, organization_name)
      values(new.id,organization);
    return new;
  end if;
  requested_handle := btrim(coalesce(new.raw_user_meta_data->>'handle', ''));
  if requested_handle = '' then
    requested_handle := 'Genesis_' || substr(replace(new.id::text, '-', ''), 1, 12);
  elsif requested_handle !~ '^[A-Za-z0-9_]{3,20}$' then
    raise exception 'Invalid nickname: use 3-20 letters, numbers or underscore';
  end if;
  requested_visibility := coalesce((new.raw_user_meta_data->>'show_nick_publicly')::boolean, true);
  insert into public.agc_profiles(id,handle,referral_code,show_nick_publicly)
  values(new.id,requested_handle,
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
    requested_visibility);
  insert into public.agc_points(member_id,points,reason,source_key)
  values(new.id,100,'signup','signup:' || new.id::text);
  return new;
end;
$function$;
