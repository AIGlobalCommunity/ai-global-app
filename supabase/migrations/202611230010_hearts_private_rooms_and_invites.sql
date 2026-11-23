create table if not exists public.agc_hearts_rooms(
 id uuid primary key default gen_random_uuid(),
 host_id uuid not null references auth.users(id) on delete cascade,
 mode text not null check(mode in ('ai','multiplayer')),
 status text not null default 'lobby' check(status in ('lobby','playing','finished')),
 seats jsonb not null default '[]'::jsonb,
 state jsonb,
 version integer not null default 0,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists agc_hearts_rooms_host_idx on public.agc_hearts_rooms(host_id,created_at desc);
create table if not exists public.agc_hearts_invites(
 id uuid primary key default gen_random_uuid(),
 room_id uuid not null references public.agc_hearts_rooms(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 seat integer not null check(seat between 1 and 3),
 status text not null default 'pending' check(status in ('pending','accepted','declined')),
 created_at timestamptz not null default now(),
 unique(room_id,recipient_id),unique(room_id,seat)
);
create index if not exists agc_hearts_invites_recipient_idx on public.agc_hearts_invites(recipient_id,status,created_at desc);
alter table public.agc_hearts_rooms enable row level security;
alter table public.agc_hearts_invites enable row level security;
revoke all on public.agc_hearts_rooms,public.agc_hearts_invites from anon,authenticated;
comment on table public.agc_hearts_rooms is 'Private authoritative Hearts game state, accessed only via authenticated server verifier.';
comment on table public.agc_hearts_invites is 'Private invite lookup by exact handle or email on server, never exposed publicly.';
