-- Add Solitaire to the existing arcade scores, votes and daily leaderboards.
alter table public.agc_game_scores drop constraint if exists agc_game_scores_supported_games;
alter table public.agc_game_scores add constraint agc_game_scores_supported_games
  check (game_key = any (array['signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals','solitaire']));
alter table public.agc_game_votes drop constraint if exists agc_game_votes_game_check;
alter table public.agc_game_votes add constraint agc_game_votes_game_check
  check (game = any (array['signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals','solitaire']));
create or replace function public.agc_submit_game_score(p_game_key text,p_score integer,p_level integer)
returns boolean language plpgsql security definer set search_path = ''
as $function$
declare
  player_id uuid := (select auth.uid());
  changed bigint;
begin
  if player_id is null then raise exception 'Player session required'; end if;
  if p_game_key is null or p_game_key not in ('signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals','solitaire')
    or p_score is null or p_score not between 1 and 10000000
    or p_level is null or p_level not between 1 and 1000 then
    raise exception 'Invalid game score';
  end if;
  if p_game_key = 'signal' and p_score > p_level * 1500 then
    raise exception 'Score exceeds game level limit';
  end if;
  insert into public.agc_game_scores as scores(member_id,game_key,best_score,best_level)
    values(player_id,p_game_key,p_score,p_level)
    on conflict (member_id,game_key) do update
    set best_score=excluded.best_score,best_level=excluded.best_level,updated_at=now()
    where scores.best_score < excluded.best_score and scores.updated_at < now()-interval '2 seconds';
  get diagnostics changed = row_count;
  insert into public.agc_daily_scores as d(member_id,game_key,score_day,best_score)
    values(player_id,p_game_key,(now() at time zone 'Europe/Warsaw')::date,p_score)
    on conflict(member_id,game_key,score_day) do update
    set best_score=excluded.best_score where d.best_score < excluded.best_score;
  return changed > 0;
end;
$function$;
-- Raw browser scores remain unverified; never auto-promote to prize results.
