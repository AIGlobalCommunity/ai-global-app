
-- Do not award global scores to anonymous hosts during server-authoritative rounds.
-- Guest game turns must succeed without triggering the ranked-asset rejection trigger.
create or replace function public.agc_duck_save_multiplayer_scores()
returns trigger language plpgsql security invoker set search_path='' as $$
declare p jsonb; u uuid; s int;
begin
 if new.status<>'finished' or old.status='finished' or new.started_at is null then return new; end if;
 for p in select value from jsonb_array_elements(new.players) loop
  if p->>'uid' is null then continue; end if;
  u:=(p->>'uid')::uuid;
  if not exists(select 1 from auth.users where id=u and not is_anonymous) then continue; end if;
  s:=coalesce((p->>'score')::int,0);
  if s<10 then continue; end if;
  insert into public.agc_game_scores(member_id,game_key,best_score,best_level,updated_at)
   values(u,'duck',s,1,now()) on conflict(member_id,game_key) do update
   set best_score=greatest(agc_game_scores.best_score,excluded.best_score),updated_at=now();
  insert into public.agc_daily_scores(member_id,game_key,score_day,best_score)
   values(u,'duck',(now() at time zone 'Europe/Warsaw')::date,s)
   on conflict(member_id,game_key,score_day) do update
   set best_score=greatest(agc_daily_scores.best_score,excluded.best_score);
 end loop;
 return new;
end $$;

create or replace function public.agc_blackjack_round_score_checkpoint()
returns trigger language plpgsql security definer set search_path='' as $$
declare p jsonb; i int; uid uuid; points int; rnd int; d date:=(now() at time zone 'Europe/Warsaw')::date;
begin
 if new.state is null or new.state->'last' is null or new.state->'last'='null'::jsonb
   or new.state->'last' is not distinct from old.state->'last' then return new; end if;
 rnd:=(new.state->'last'->>'round')::int;
 for i in 0..jsonb_array_length(new.seats)-1 loop
  p:=new.seats->i;
  if p->>'type' is distinct from 'human' or p->>'id' is null then continue; end if;
  uid:=(p->>'id')::uuid;
  if not exists(select 1 from auth.users where id=uid and not is_anonymous) then continue; end if;
  points:=coalesce((new.state->'scores'->>i)::int,0);
  if points<=0 then continue; end if;
  insert into public.agc_game_scores(member_id,game_key,best_score,best_level,updated_at)
   values(uid,'blackjack',points,rnd,now()) on conflict(member_id,game_key) do update
   set best_score=greatest(public.agc_game_scores.best_score,excluded.best_score),
   best_level=case when excluded.best_score>public.agc_game_scores.best_score then excluded.best_level else public.agc_game_scores.best_level end,
   updated_at=now();
  insert into public.agc_daily_scores(member_id,game_key,score_day,best_score)
   values(uid,'blackjack',d,points) on conflict(member_id,game_key,score_day) do update
   set best_score=greatest(public.agc_daily_scores.best_score,excluded.best_score);
 end loop;
 return new;
end $$;

create or replace function public.agc_hearts_round_score()
returns trigger language plpgsql security definer set search_path='' as $$
declare i int; p jsonb; uid uuid; v_score int; v_round int; v_day date := (now() at time zone 'Europe/Warsaw')::date;
begin
 if new.state is null or coalesce((new.state->>'turn')::int,0)<>-1
  or coalesce(jsonb_array_length(new.state->'history'),0)<>13 then return new; end if;
 if tg_op='UPDATE' then
  if old.state->>'round'=new.state->>'round' and old.state->>'turn'='-1' then return new; end if;
 end if;
 v_round:=greatest(1,(new.state->>'round')::int);
 for i in 0..jsonb_array_length(new.seats)-1 loop
  p:=new.seats->i;
  if p->>'type' is distinct from 'human' or p->>'id' is null then continue; end if;
  uid:=(p->>'id')::uuid;
  if not exists(select 1 from auth.users where id=uid and not is_anonymous) then continue; end if;
  v_score:=greatest(10,1500-(new.state->'total'->>i)::int*10);
  insert into public.agc_game_scores(member_id,game_key,best_score,best_level,updated_at)
   values(uid,'hearts',v_score,v_round,now()) on conflict(member_id,game_key) do update
   set best_level=case when excluded.best_score>agc_game_scores.best_score then excluded.best_level else agc_game_scores.best_level end,
   best_score=greatest(agc_game_scores.best_score,excluded.best_score),updated_at=now();
  insert into public.agc_daily_scores(member_id,game_key,score_day,best_score)
   values(uid,'hearts',v_day,v_score) on conflict(member_id,game_key,score_day) do update
   set best_score=greatest(agc_daily_scores.best_score,excluded.best_score);
 end loop;
 return new;
end $$;
