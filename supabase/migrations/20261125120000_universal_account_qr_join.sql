create or replace function public.agc_join_account_qr(p_hash text,p_uid uuid,p_nick text) returns jsonb language plpgsql security invoker set search_path='' as $$
declare i public.agc_game_invite_links%rowtype; r record; n int; t text; v text; seats jsonb;
begin
select * into i from public.agc_game_invite_links where token_hash=p_hash and not revoked and expires_at>now() for update;
if not found then raise exception 'Zaproszenie nieważne'; end if;
if i.game not in ('duck','hearts','blackjack') then raise exception 'Nieobsługiwana gra'; end if;
t:='agc_'||i.game||'_rooms';
execute format('select * from public.%I where id=$1 for update',t) into r using i.room_id;
if r.id is null or r.status<>'lobby' then raise exception 'Pokój niedostępny'; end if;
if i.game='duck' then
if not exists(select 1 from jsonb_array_elements(r.players) p where p->>'uid'=p_uid::text) then
if jsonb_array_length(r.players)>=4 then raise exception 'Pokój pełny'; end if;
update public.agc_duck_rooms set players=r.players||jsonb_build_array(jsonb_build_object('id',p_uid,'uid',p_uid,'name',p_nick,'score',0)),version=r.version+1 where id=r.id;
end if;
else
if r.mode<>'multiplayer' then raise exception 'Pokój niedostępny'; end if;
seats:=r.seats;
if not exists(select 1 from jsonb_array_elements(seats) p where p->>'id'=p_uid::text) then
v:='agc_'||i.game||'_invites';
execute format('select x from generate_series(1,jsonb_array_length($1)-1) x where $1->x->>''id'' is null and $1->x->>''guest_id'' is null and not exists(select 1 from public.%I v where v.room_id=$2 and v.seat=x and v.status in (''pending'',''accepted'') and v.recipient_id<>$3) order by x limit 1',v) into n using seats,r.id,p_uid;
if n is null then raise exception 'Brak wolnych miejsc'; end if;
seats:=jsonb_set(seats,array[n::text],jsonb_build_object('id',p_uid,'name',p_nick,'type','human','ready',true));
execute format('update public.%I set seats=$1,version=version+1,updated_at=now() where id=$2',t) using seats,r.id;
end if;
end if;
return jsonb_build_object('room',r.id,'game',i.game,'authenticated',true);
end;$$;
revoke all on function public.agc_join_account_qr(text,uuid,text) from public,anon,authenticated;
grant execute on function public.agc_join_account_qr(text,uuid,text) to service_role;