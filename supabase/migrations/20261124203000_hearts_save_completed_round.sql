create or replace function public.agc_hearts_round_score() returns trigger language plpgsql security definer set search_path='' as $$
declare i int; p jsonb; uid uuid; v_score int; v_round int; v_day date := (now() at time zone 'Europe/Warsaw')::date;
begin
 if new.state is null or coalesce((new.state->>'turn')::int,0)<>-1 or coalesce(jsonb_array_length(new.state->'history'),0)<>13 then return new; end if;
 if TG_OP='UPDATE' then
 if old.state->>'round'=new.state->>'round' and old.state->>'turn'='-1' then return new; end if;
 end if;
 v_round:=greatest(1,(new.state->>'round')::int);
 for i in 0..jsonb_array_length(new.seats)-1 loop
 p:=new.seats->i;
 if p->>'type' is distinct from 'human' or p->>'id' is null then continue; end if;
 uid:=(p->>'id')::uuid;
 v_score:=greatest(10,1500-(new.state->'total'->>i)::int*10);
 insert into public.agc_game_scores(member_id,game_key,best_score,best_level,updated_at) values(uid,'hearts',v_score,v_round,now()) on conflict(member_id,game_key) do update set best_level=case when excluded.best_score>agc_game_scores.best_score then excluded.best_level else agc_game_scores.best_level end,best_score=greatest(agc_game_scores.best_score,excluded.best_score),updated_at=now();
 insert into public.agc_daily_scores(member_id,game_key,score_day,best_score) values(uid,'hearts',v_day,v_score) on conflict(member_id,game_key,score_day) do update set best_score=greatest(agc_daily_scores.best_score,excluded.best_score);
 end loop;
 return new;
end;$$;
revoke all on function public.agc_hearts_round_score() from public,anon,authenticated;
drop trigger if exists agc_hearts_round_score_trigger on public.agc_hearts_rooms;
create trigger agc_hearts_round_score_trigger after insert or update of state on public.agc_hearts_rooms for each row execute function public.agc_hearts_round_score();