create table public.agc_game_invite_links(id uuid primary key default gen_random_uuid(), game text not null check(game in ('blackjack','hearts','duck')), room_id uuid not null, host_id uuid not null references auth.users(id) on delete cascade, token_hash text not null unique, expires_at timestamptz not null, revoked boolean not null default false, unique(game,room_id));
create table public.agc_game_guest_sessions(id uuid primary key default gen_random_uuid(), invite_id uuid not null references public.agc_game_invite_links(id) on delete cascade, nickname text not null check(char_length(nickname) between 2 and 32), session_hash text not null unique, expires_at timestamptz not null, revoked boolean not null default false);
create unique index agc_game_guest_unique_nick on public.agc_game_guest_sessions(invite_id,lower(nickname)) where not revoked;
alter table public.agc_game_invite_links enable row level security;
alter table public.agc_game_guest_sessions enable row level security;
revoke all on public.agc_game_invite_links,public.agc_game_guest_sessions from public,anon,authenticated;
grant all on public.agc_game_invite_links,public.agc_game_guest_sessions to service_role;