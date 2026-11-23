create table if not exists public.agc_card_runs (
 id uuid primary key default gen_random_uuid(),
 member_id uuid not null references auth.users(id) on delete cascade,
 game_key text not null check(game_key in ('solitaire','freecell','spider')),
 mode integer not null check(mode in (1,2,3,4)),
 deck jsonb not null,
 started_at timestamptz not null default now(),
 finished_at timestamptz,
 verified_score integer,
 status text not null default 'active' check(status in ('active','verified','rejected'))
);
create index if not exists agc_card_runs_owner on public.agc_card_runs(member_id,game_key,started_at desc);
alter table public.agc_card_runs enable row level security;
revoke all on public.agc_card_runs from anon,authenticated;
comment on table public.agc_card_runs is 'Server-issued card deck and session, inaccessible to clients; only the verifier with service_role can write.';
