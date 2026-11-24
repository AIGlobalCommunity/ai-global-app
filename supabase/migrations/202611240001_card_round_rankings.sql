create or replace function public.agc_hearts_award_verified_scores()
returns trigger language plpgsql security definer set search_path='' as $$
declare p jsonb; seat int; uid uuid; score int; v_score_day date; total int;
begin
 if old.status='finished' or new.status<>'finished' then return new; end if;
 v_score_day:=(now() at time zone 'Europe/Warsaw')::date;
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
  values(uid,'hearts',v_score_day,score)
  on conflict(member_id,game_key,score_day) do update set best_score=greatest(public.agc_daily_scores.best_score,excluded.best_score);
  insert into public.agc_verified_daily_scores(member_id,game_key,score_day,best_score,verified_at,evidence_ref)
  values(uid,'hearts',v_score_day,score,now(),'hearts-room:'||new.id::text)
  on conflict(member_id,game_key,score_day) do update set
   best_score=greatest(public.agc_verified_daily_scores.best_score,excluded.best_score),
   verified_at=now(),evidence_ref=excluded.evidence_ref;
 end loop;
 return new;
end;$$;

create or replace function public.agc_blackjack_award_verified_scores()
returns trigger language plpgsql security definer set search_path='' as $$
declare p jsonb; seat int; uid uuid; score int; v_score_day date;
begin
 if old.status='finished' or new.status<>'finished' then return new; end if;
 v_score_day:=(now() at time zone 'Europe/Warsaw')::date;
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
  values(uid,'blackjack',v_score_day,score)
  on conflict(member_id,game_key,score_day) do update set best_score=greatest(public.agc_daily_scores.best_score,excluded.best_score);
  insert into public.agc_verified_daily_scores(member_id,game_key,score_day,best_score,verified_at,evidence_ref)
  values(uid,'blackjack',v_score_day,score,now(),'blackjack-room:'||new.id::text)
  on conflict(member_id,game_key,score_day) do update set
   best_score=greatest(public.agc_verified_daily_scores.best_score,excluded.best_score),
   verified_at=now(),evidence_ref=excluded.evidence_ref;
 end loop;
 return new;
end;$$;


create or replace function public.agc_card_round_checkpoint() returns trigger language plpgsql security definer set search_path='' as $$
declare g text; i integer; p jsonb; uid uuid; v_score integer; v_round integer; v_day date := (now() at time zone 'Europe/Warsaw')::date;
begin
 if new.state is null or old.state is null then return new; end if;
 g := case when TG_TABLE_NAME='agc_hearts_rooms' then 'hearts' else 'blackjack' end;
 if new.status <> 'finished' and coalesce((new.state->>'round')::int,0)<=coalesce((old.state->>'round')::int,0) then return new; end if;
 v_round:=greatest(1,(new.state->>'round')::int);
 for i in 0..jsonb_array_length(new.seats)-1 loop
 p:=new.seats->i; if p->>'type' is distinct from 'human' or p->>'id' is null then continue; end if;
 uid:=(p->>'id')::uuid;
 v_score:=case when g='hearts' then greatest(10,1500-coalesce((new.state->'total'->>i)::int,0)*10) else greatest(10,coalesce((new.state->'scores'->>i)::int,0)) end;
 insert into public.agc_game_scores(member_id,game_key,best_score,best_level,updated_at) values(uid,g,v_score,v_round,now()) on conflict(member_id,game_key) do update set best_score=greatest(public.agc_game_scores.best_score,excluded.best_score),updated_at=now();
 insert into public.agc_daily_scores(member_id,game_key,score_day,best_score) values(uid,g,v_day,v_score) on conflict(member_id,game_key,score_day) do update set best_score=greatest(public.agc_daily_scores.best_score,excluded.best_score);
 end loop; return new;
end; $$;
revoke all on function public.agc_card_round_checkpoint() from public,anon,authenticated;
drop trigger if exists agc_round_checkpoint on public.agc_hearts_rooms;
create trigger agc_round_checkpoint after update of state on public.agc_hearts_rooms for each row execute function public.agc_card_round_checkpoint();
drop trigger if exists agc_round_checkpoint on public.agc_blackjack_rooms;
create trigger agc_round_checkpoint after update of state on public.agc_blackjack_rooms for each row execute function public.agc_card_round_checkpoint();