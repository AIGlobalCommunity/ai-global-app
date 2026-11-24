create or replace function public.agc_join_blackjack_guest(p_hash text,p_nick text,p_session_hash text) returns jsonb language plpgsql security invoker set search_path='' as $$
declare i public.agc_game_invite_links%rowtype; r public.agc_blackjack_rooms%rowtype; g uuid; n integer;
begin
select * into i from public.agc_game_invite_links where token_hash=p_hash and game='blackjack' and not revoked and expires_at>now() for update;
if not found then raise exception 'Zaproszenie nieważne'; end if;
select * into r from public.agc_blackjack_rooms where id=i.room_id for update;
if not found or r.status<>'lobby' or r.mode<>'multiplayer' then raise exception 'Pokój niedostępny'; end if;
if exists(select 1 from jsonb_array_elements(r.seats) p where lower(p->>'name')=lower(p_nick)) then raise exception 'Nick zajęty'; end if;
select x into n from generate_series(1,jsonb_array_length(r.seats)-1) x where r.seats->x->>'id' is null and r.seats->x->>'guest_id' is null and not exists(select 1 from public.agc_blackjack_invites v where v.room_id=r.id and v.seat=x and v.status in ('pending','accepted')) order by x limit 1;
if n is null then raise exception 'Brak wolnych miejsc'; end if;
insert into public.agc_game_guest_sessions(invite_id,nickname,session_hash,expires_at) values(i.id,p_nick,p_session_hash,now()+interval '24 hours') returning id into g;
update public.agc_blackjack_rooms set seats=jsonb_set(r.seats,array[n::text],jsonb_build_object('id',null,'guest_id',g,'name',p_nick,'type','human')),version=r.version+1,updated_at=now() where id=r.id;
return jsonb_build_object('guest',g,'room',r.id,'game','blackjack');
end;$$;
revoke all on function public.agc_join_blackjack_guest(text,text,text) from public,anon,authenticated;
grant execute on function public.agc_join_blackjack_guest(text,text,text) to service_role;