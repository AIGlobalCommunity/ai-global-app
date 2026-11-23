create table if not exists public.agc_blackjack_rooms(
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
create index if not exists agc_blackjack_rooms_host_idx on public.agc_blackjack_rooms(host_id,created_at desc);
create table if not exists public.agc_blackjack_invites(
 id uuid primary key default gen_random_uuid(),
 room_id uuid not null references public.agc_blackjack_rooms(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 seat integer not null check(seat between 1 and 10),
 status text not null default 'pending' check(status in ('pending','accepted','declined')),
 created_at timestamptz not null default now(),
 unique(room_id,recipient_id),unique(room_id,seat)
);
create index if not exists agc_blackjack_invites_recipient_idx on public.agc_blackjack_invites(recipient_id,status,created_at desc);
alter table public.agc_blackjack_rooms enable row level security;
alter table public.agc_blackjack_invites enable row level security;
revoke all on public.agc_blackjack_rooms,public.agc_blackjack_invites from anon,authenticated;
comment on table public.agc_blackjack_rooms is 'Server-authoritative Blackjack (21) rooms, 1 to 11 players, 5 rounds, no monetary stakes.';
comment on table public.agc_blackjack_invites is 'Private invitations for up to ten portal players.';
alter table public.agc_game_scores drop constraint if exists agc_game_scores_supported_games;
alter table public.agc_game_scores add constraint agc_game_scores_supported_games check(game_key=any(array['signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals','solitaire','freecell','spider','hearts','blackjack']));
alter table public.agc_game_votes drop constraint if exists agc_game_votes_game_check;
alter table public.agc_game_votes add constraint agc_game_votes_game_check check(game=any(array['signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals','solitaire','freecell','spider','hearts','blackjack']));
alter table public.agc_verified_daily_scores drop constraint if exists agc_verified_daily_scores_game_key_check;
alter table public.agc_verified_daily_scores add constraint agc_verified_daily_scores_game_key_check check(game_key=any(array['signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals','solitaire','freecell','spider','hearts','blackjack']));
create or replace function public.agc_blackjack_award_verified_scores()
returns trigger language plpgsql security definer set search_path='' as $$
declare p jsonb; seat int; uid uuid; score int; score_day date;
begin
 if old.status='finished' or new.status<>'finished' then return new; end if;
 score_day:=(now() at time zone 'Europe/Warsaw')::date;
 for seat in 0..jsonb_array_length(new.seats)-1 loop
  p:=new.seats->seat;
  if p->>'type'<>'human' or p->>'id' is null then continue; end if;
  uid:=(p->>'id')::uuid;
  score:=greatest(10,(new.state->'scores'->>seat)::int);
  insert into public.agc_game_scores(member_id,game_key,best_score,best_level,updated_at)
  values(uid,'blackjack',score,(new.state->>'round')::int,now())
  on conflict(member_id,game_key) do update set
   best_score=greatest(public.agc_game_scores.best_score,excluded.best_score),
   best_level=case when excluded.best_score>public.agc_game_scores.best_score then excluded.best_level else public.agc_game_scores.best_level end,
   updated_at=now();
  insert into public.agc_daily_scores(member_id,game_key,score_day,best_score)
  values(uid,'blackjack',score,score_day)
  on conflict(member_id,game_key,score_day) do update set best_score=greatest(public.agc_daily_scores.best_score,excluded.best_score);
  insert into public.agc_verified_daily_scores(member_id,game_key,score_day,best_score,verified_at,evidence_ref)
  values(uid,'blackjack',score,score_day,now(),'blackjack-room:'||new.id::text)
  on conflict(member_id,game_key,score_day) do update set
   best_score=greatest(public.agc_verified_daily_scores.best_score,excluded.best_score),
   verified_at=now(),evidence_ref=excluded.evidence_ref;
 end loop;
 return new;
end;$$;
revoke all on function public.agc_blackjack_award_verified_scores() from public,anon,authenticated;
drop trigger if exists agc_blackjack_award_verified_scores_trigger on public.agc_blackjack_rooms;
create trigger agc_blackjack_award_verified_scores_trigger after update of status on public.agc_blackjack_rooms
for each row when (old.status is distinct from new.status and new.status='finished')
execute function public.agc_blackjack_award_verified_scores();
