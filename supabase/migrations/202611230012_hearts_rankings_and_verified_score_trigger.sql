alter table public.agc_game_scores drop constraint if exists agc_game_scores_supported_games;
alter table public.agc_game_scores add constraint agc_game_scores_supported_games check (game_key = any(array['signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals','solitaire','freecell','spider','hearts']));
alter table public.agc_game_votes drop constraint if exists agc_game_votes_game_check;
alter table public.agc_game_votes add constraint agc_game_votes_game_check check (game = any(array['signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals','solitaire','freecell','spider','hearts']));
alter table public.agc_verified_daily_scores drop constraint if exists agc_verified_daily_scores_game_key_check;
alter table public.agc_verified_daily_scores add constraint agc_verified_daily_scores_game_key_check check (game_key = any(array['signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals','solitaire','freecell','spider','hearts']));
create or replace function public.agc_hearts_award_verified_scores()
returns trigger language plpgsql security definer set search_path='' as $$
declare p jsonb; seat int; uid uuid; score int; score_day date; total int;
begin
 if old.status='finished' or new.status<>'finished' then return new; end if;
 score_day:=(now() at time zone 'Europe/Warsaw')::date;
 for seat in 0..3 loop
  p:=new.seats->seat;
  if p->>'type'<>'human' or p->>'id' is null then continue; end if;
  uid:=(p->>'id')::uuid;
  total:=(new.state->'total'->>seat)::int;
  score:=greatest(10,1500-total*10+case when (new.state->>'winner')::int=seat then 500 else 0 end);
  insert into public.agc_game_scores(member_id,game_key,best_score,best_level,updated_at)
  values(uid,'hearts',score,(new.state->>'round')::int,now())
  on conflict(member_id,game_key) do update set
   best_score=greatest(public.agc_game_scores.best_score,excluded.best_score),
   best_level=case when excluded.best_score>public.agc_game_scores.best_score then excluded.best_level else public.agc_game_scores.best_level end,
   updated_at=now();
  insert into public.agc_daily_scores(member_id,game_key,score_day,best_score)
  values(uid,'hearts',score,score_day)
  on conflict(member_id,game_key,score_day) do update set best_score=greatest(public.agc_daily_scores.best_score,excluded.best_score);
  insert into public.agc_verified_daily_scores(member_id,game_key,score_day,best_score,verified_at,evidence_ref)
  values(uid,'hearts',score,score_day,now(),'hearts-room:'||new.id::text)
  on conflict(member_id,game_key,score_day) do update set
   best_score=greatest(public.agc_verified_daily_scores.best_score,excluded.best_score),
   verified_at=now(),evidence_ref=excluded.evidence_ref;
 end loop;
 return new;
end;$$;
revoke all on function public.agc_hearts_award_verified_scores() from public,anon,authenticated;
drop trigger if exists agc_hearts_award_verified_scores_trigger on public.agc_hearts_rooms;
create trigger agc_hearts_award_verified_scores_trigger after update of status on public.agc_hearts_rooms
for each row when (old.status is distinct from new.status and new.status='finished')
execute function public.agc_hearts_award_verified_scores();
