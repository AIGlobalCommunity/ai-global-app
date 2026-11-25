create or replace function public.agc_duck_save_multiplayer_scores() returns trigger language plpgsql security invoker set search_path='' as $$
declare p jsonb; u uuid; s int;
begin
if new.status<>'finished' or old.status='finished' or new.started_at is null then return new; end if;
for p in select value from jsonb_array_elements(new.players) loop
if p->>'uid' is null then continue; end if;
u:=(p->>'uid')::uuid;s:=coalesce((p->>'score')::int,0);
if s<10 then continue; end if;
insert into public.agc_game_scores(member_id,game_key,best_score,best_level,updated_at) values(u,'duck',s,1,now()) on conflict(member_id,game_key) do update set best_score=greatest(agc_game_scores.best_score,excluded.best_score),updated_at=now();
insert into public.agc_daily_scores(member_id,game_key,score_day,best_score) values(u,'duck',(now() at time zone 'Europe/Warsaw')::date,s) on conflict(member_id,game_key,score_day) do update set best_score=greatest(agc_daily_scores.best_score,excluded.best_score);
end loop;return new;end;$$;
revoke all on function public.agc_duck_save_multiplayer_scores() from public,anon,authenticated;
grant execute on function public.agc_duck_save_multiplayer_scores() to service_role;
create trigger agc_duck_multiplayer_score after update of status on public.agc_duck_rooms for each row execute function public.agc_duck_save_multiplayer_scores();