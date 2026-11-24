create or replace function public.agc_blackjack_round_score_checkpoint() returns trigger language plpgsql security definer set search_path='' as $$
declare p jsonb; i int; uid uuid; points int; rnd int; d date:=(now() at time zone 'Europe/Warsaw')::date;
begin
 if new.state is null or new.state->'last' is null or new.state->'last'='null'::jsonb or new.state->'last' is not distinct from old.state->'last' then return new; end if;
 rnd:=(new.state->'last'->>'round')::int;
 for i in 0..jsonb_array_length(new.seats)-1 loop
 p:=new.seats->i;
 if p->>'type' is distinct from 'human' or p->>'id' is null then continue; end if;
 uid:=(p->>'id')::uuid; points:=coalesce((new.state->'scores'->>i)::int,0);
 if points<=0 then continue; end if;
 insert into public.agc_game_scores(member_id,game_key,best_score,best_level,updated_at) values(uid,'blackjack',points,rnd,now()) on conflict(member_id,game_key) do update set best_score=greatest(public.agc_game_scores.best_score,excluded.best_score),best_level=case when excluded.best_score>public.agc_game_scores.best_score then excluded.best_level else public.agc_game_scores.best_level end,updated_at=now();
 insert into public.agc_daily_scores(member_id,game_key,score_day,best_score) values(uid,'blackjack',d,points) on conflict(member_id,game_key,score_day) do update set best_score=greatest(public.agc_daily_scores.best_score,excluded.best_score);
 end loop; return new;
end;$$;
revoke all on function public.agc_blackjack_round_score_checkpoint() from public,anon,authenticated;
create trigger agc_blackjack_round_score_checkpoint after update of state on public.agc_blackjack_rooms for each row execute function public.agc_blackjack_round_score_checkpoint();