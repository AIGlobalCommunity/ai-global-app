create table if not exists public.agc_duck_rooms(id uuid primary key default gen_random_uuid(),host_id uuid not null references auth.users(id) on delete cascade,status text not null default 'lobby' check(status in ('lobby','playing','finished')),players jsonb not null check(jsonb_array_length(players) between 1 and 4),targets jsonb not null default '[]',started_at bigint,version integer not null default 0,invite_hash text,expires_at timestamptz,created_at timestamptz default now());
create table if not exists public.agc_duck_invites(room_id uuid references public.agc_duck_rooms(id) on delete cascade,recipient_id uuid references auth.users(id) on delete cascade,created_at timestamptz default now(),primary key(room_id,recipient_id));
alter table public.agc_duck_rooms enable row level security;
alter table public.agc_duck_invites enable row level security;
revoke all on public.agc_duck_rooms,public.agc_duck_invites from public,anon,authenticated;
grant all on public.agc_duck_rooms,public.agc_duck_invites to service_role;
create or replace function public.agc_join_duck_guest(p_hash text,p_nick text,p_session_hash text) returns jsonb language plpgsql security invoker set search_path='' as $$
declare i public.agc_game_invite_links%rowtype; r public.agc_duck_rooms%rowtype; g uuid;
begin
select * into i from public.agc_game_invite_links where token_hash=p_hash and game='duck' and not revoked and expires_at>now() for update;
if not found then raise exception 'Zaproszenie nieważne'; end if;
select * into r from public.agc_duck_rooms where id=i.room_id for update;
if not found or r.status<>'lobby' or jsonb_array_length(r.players)>=4 then raise exception 'Pokój niedostępny lub pełny'; end if;
if exists(select 1 from jsonb_array_elements(r.players) p where lower(p->>'name')=lower(p_nick)) then raise exception 'Nick zajęty'; end if;
insert into public.agc_game_guest_sessions(invite_id,nickname,session_hash,expires_at) values(i.id,p_nick,p_session_hash,now()+interval '24 hours') returning id into g;
update public.agc_duck_rooms set players=r.players||jsonb_build_array(jsonb_build_object('id',g,'uid',null,'name',p_nick,'score',0,'guest_id',g)),version=r.version+1 where id=r.id;
return jsonb_build_object('guest',g,'room',r.id,'game','duck');
end;$$;
revoke all on function public.agc_join_duck_guest(text,text,text) from public,anon,authenticated;
grant execute on function public.agc_join_duck_guest(text,text,text) to service_role;