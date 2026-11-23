create or replace function public.agc_hearts_resolve_invitee(p_identity text)
returns uuid language sql security definer set search_path='' as $$
 select u.id from auth.users u
 left join public.agc_profiles p on p.id=u.id
 where length(trim(p_identity)) between 3 and 254
 and (lower(u.email)=lower(trim(p_identity)) or lower(p.handle)=lower(trim(p_identity)))
 order by case when lower(p.handle)=lower(trim(p_identity)) then 0 else 1 end
 limit 1;
$$;
revoke all on function public.agc_hearts_resolve_invitee(text) from public,anon,authenticated;
grant execute on function public.agc_hearts_resolve_invitee(text) to service_role;
