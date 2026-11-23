create table if not exists public.agc_card_score_verification (
 id uuid primary key default gen_random_uuid(),
 member_id uuid not null references auth.users(id) on delete cascade,
 game_key text not null check(game_key in ('solitaire','freecell','spider')),
 claimed_score integer not null check(claimed_score between 0 and 10000000),
 claimed_level integer not null check(claimed_level between 1 and 4),
 verification_status text not null default 'unverified' check(verification_status in ('unverified','verified','rejected')),
 created_at timestamptz not null default now(),
 verified_at timestamptz,
 verifier_note text
);
create index if not exists agc_card_score_verification_member_game on public.agc_card_score_verification(member_id,game_key,created_at desc);
alter table public.agc_card_score_verification enable row level security;
create policy agc_card_verification_own_read on public.agc_card_score_verification for select to authenticated using (member_id = (select auth.uid()));
create or replace function public.agc_card_score_review_status(p_game text)
returns table(verification_status text,claimed_score integer,created_at timestamptz)
language sql stable security invoker set search_path='' as $$
 select v.verification_status,v.claimed_score,v.created_at from public.agc_card_score_verification v
 where v.member_id=(select auth.uid()) and v.game_key=p_game
 order by v.created_at desc limit 1;
$$;
comment on table public.agc_card_score_verification is 'Card-game contest evidence status; unverified scores are NOT validated and must not be treated as contest-approved.';
