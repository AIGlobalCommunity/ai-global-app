-- Anonymous Supabase Auth identities may host multiplayer, but never earn ranked scores or GCO.
-- All multiplayer room tables remain private and service-role-only.
alter table public.agc_duck_rooms add column if not exists guest_host boolean not null default false;
alter table public.agc_hearts_rooms add column if not exists guest_host boolean not null default false;
alter table public.agc_blackjack_rooms add column if not exists guest_host boolean not null default false;
alter table public.agc_duck_rooms add column if not exists updated_at timestamptz not null default now();
alter table public.agc_game_invite_links add column if not exists renewed_at timestamptz not null default now();

create unique index if not exists agc_duck_one_active_guest_room on public.agc_duck_rooms(host_id)
 where guest_host and status in ('lobby','playing');
create unique index if not exists agc_hearts_one_active_guest_room on public.agc_hearts_rooms(host_id)
 where guest_host and status in ('lobby','playing');
create unique index if not exists agc_blackjack_one_active_guest_room on public.agc_blackjack_rooms(host_id)
 where guest_host and status in ('lobby','playing');

create table if not exists public.agc_multiplayer_rate_events(
 id bigint generated always as identity primary key,
 actor_id uuid not null,
 ip_hash text not null check(length(ip_hash)=64),
 action text not null check(action in ('create','renew','join','join_account','invite')),
 created_at timestamptz not null default now()
);
create index if not exists agc_multiplayer_rate_actor on public.agc_multiplayer_rate_events(actor_id,action,created_at desc);
create index if not exists agc_multiplayer_rate_ip on public.agc_multiplayer_rate_events(ip_hash,action,created_at desc);
alter table public.agc_multiplayer_rate_events enable row level security;
revoke all on public.agc_multiplayer_rate_events from public,anon,authenticated;
grant all on public.agc_multiplayer_rate_events to service_role;

create or replace function public.agc_multiplayer_allow_action(
 p_actor uuid,p_ip_hash text,p_action text,p_actor_limit integer,p_ip_limit integer,p_period interval
) returns boolean language plpgsql security invoker set search_path='' as $$
begin
 if p_actor is null or p_ip_hash is null or length(p_ip_hash)<>64
  or p_action not in ('create','renew','join','join_account','invite')
  or p_actor_limit not between 1 and 1000 or p_ip_limit not between 1 and 10000
  or p_period < interval '1 second' or p_period > interval '1 day'
 then return false; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_ip_hash||':'||p_action,0));
 if (select count(*) from public.agc_multiplayer_rate_events
   where actor_id=p_actor and action=p_action and created_at>now()-p_period)>=p_actor_limit
 or (select count(*) from public.agc_multiplayer_rate_events
   where ip_hash=p_ip_hash and action=p_action and created_at>now()-p_period)>=p_ip_limit
 then return false; end if;
 insert into public.agc_multiplayer_rate_events(actor_id,ip_hash,action) values(p_actor,p_ip_hash,p_action);
 return true;
end $$;
revoke all on function public.agc_multiplayer_allow_action(uuid,text,text,integer,integer,interval) from public,anon,authenticated;
grant execute on function public.agc_multiplayer_allow_action(uuid,text,text,integer,integer,interval) to service_role;

-- Defense in depth: even service-role score saving must reject anonymous identities.
create or replace function public.agc_no_guest_ranked_assets()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from auth.users u where u.id=new.member_id and u.is_anonymous) then
   raise exception 'Guest accounts cannot write global ranking or GCO';
 end if;
 return new;
end $$;
revoke all on function public.agc_no_guest_ranked_assets() from public,anon,authenticated;
do $$ declare tbl text; begin
 foreach tbl in array array['agc_game_scores','agc_daily_scores','agc_verified_daily_scores','agc_coin_ledger','agc_points'] loop
 execute format('drop trigger if exists agc_no_guest_ranked_assets on public.%I',tbl);
 execute format('create trigger agc_no_guest_ranked_assets before insert or update on public.%I for each row execute function public.agc_no_guest_ranked_assets()',tbl);
 end loop;
end $$;
-- Room expiration and rate-event cleanup are performed by Edge Functions on subsequent requests.
