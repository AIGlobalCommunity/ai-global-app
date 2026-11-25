-- Prevent guests from impersonating registered member handles.
create or replace function public.agc_multiplayer_reserved_nick(p_nick text)
returns boolean language sql stable security invoker set search_path='' as $$
 select exists(
   select 1 from public.agc_profiles p
   where lower(p.handle)=lower(trim(p_nick))
 )
$$;
revoke all on function public.agc_multiplayer_reserved_nick(text) from public,anon,authenticated;
grant execute on function public.agc_multiplayer_reserved_nick(text) to service_role;
