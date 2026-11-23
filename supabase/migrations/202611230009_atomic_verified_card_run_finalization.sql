alter table public.agc_card_runs add column if not exists actions jsonb;
alter table public.agc_card_runs add column if not exists move_count integer;
alter table public.agc_card_runs add column if not exists elapsed_seconds integer;
create or replace function public.agc_finalize_verified_card_run(p_run uuid,p_member uuid,p_game text,p_actions jsonb,p_moves integer,p_seconds integer,p_score integer)
returns boolean language plpgsql security definer set search_path='' as $$
declare r public.agc_card_runs%rowtype;
begin
 if auth.role() <> 'service_role' then raise exception 'Service role only'; end if;
 if p_score < 10 or p_score > 10000000 or p_moves < 1 or p_moves > 12000 or p_seconds < 20 or p_seconds > 14400 or jsonb_typeof(p_actions) <> 'array' then raise exception 'Invalid verified run'; end if;
 select * into r from public.agc_card_runs where id=p_run for update;
 if not found or r.member_id<>p_member or r.game_key<>p_game or r.status<>'active' then raise exception 'Run already finalized or invalid'; end if;
 if abs(extract(epoch from (now()-r.started_at))-p_seconds)>120 then raise exception 'Invalid elapsed time'; end if;
 update public.agc_card_runs set status='verified',actions=p_actions,move_count=p_moves,elapsed_seconds=p_seconds,verified_score=p_score,finished_at=now() where id=p_run;
 insert into public.agc_game_scores(member_id,game_key,best_score,best_level,updated_at)
 values(p_member,p_game,p_score,r.mode,now())
 on conflict (member_id,game_key) do update set
 best_score=greatest(public.agc_game_scores.best_score,excluded.best_score),
 best_level=case when excluded.best_score>public.agc_game_scores.best_score then excluded.best_level else public.agc_game_scores.best_level end,
 updated_at=case when excluded.best_score>public.agc_game_scores.best_score then now() else public.agc_game_scores.updated_at end;
 insert into public.agc_daily_scores(member_id,game_key,score_day,best_score)
 values(p_member,p_game,(now() at time zone 'Europe/Warsaw')::date,p_score)
 on conflict (member_id,game_key,score_day) do update set best_score=greatest(public.agc_daily_scores.best_score,excluded.best_score);
 insert into public.agc_card_score_verification(member_id,game_key,claimed_score,claimed_level,verification_status,verified_at,verifier_note)
 values(p_member,p_game,p_score,r.mode,'verified',now(),'Verified full server-side move replay for run '||p_run::text);
 insert into public.agc_verified_daily_scores(member_id,game_key,score_day,best_score,verified_at,evidence_ref)
 values(p_member,p_game,(now() at time zone 'Europe/Warsaw')::date,p_score,now(),'card-run:'||p_run::text)
 on conflict (member_id,game_key,score_day) do update set
 best_score=greatest(public.agc_verified_daily_scores.best_score,excluded.best_score),
 verified_at=case when excluded.best_score>public.agc_verified_daily_scores.best_score then now() else public.agc_verified_daily_scores.verified_at end,
 evidence_ref=case when excluded.best_score>public.agc_verified_daily_scores.best_score then excluded.evidence_ref else public.agc_verified_daily_scores.evidence_ref end;
 return true;
end;$$;
revoke all on function public.agc_finalize_verified_card_run(uuid,uuid,text,jsonb,integer,integer,integer) from public,anon,authenticated;
grant execute on function public.agc_finalize_verified_card_run(uuid,uuid,text,jsonb,integer,integer,integer) to service_role;
