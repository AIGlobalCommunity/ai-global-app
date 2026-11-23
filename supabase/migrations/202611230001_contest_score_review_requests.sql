-- Defense in depth: manual-only review queue for ordinary gameplay scores.
-- Deployed to game Supabase gjnddmurmegbklvedhnp.
create table if not exists public.agc_contest_score_reviews (
 id uuid primary key default gen_random_uuid(),
 member_id uuid not null references auth.users(id) on delete cascade,
 game_key text not null check (game_key in ('signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals')),
 score_day date not null,
 claimed_score integer not null check (claimed_score between 1 and 10000000),
 evidence_ref text not null check (char_length(trim(evidence_ref)) between 1 and 500),
 status text not null default 'pending' check (status in ('pending','approved','rejected')),
 moderator_id uuid references auth.users(id),
 reviewed_at timestamptz,
 review_note text,
 created_at timestamptz not null default now(),
 unique(member_id,game_key,score_day,claimed_score)
);
alter table public.agc_contest_score_reviews enable row level security;
revoke all on table public.agc_contest_score_reviews from public,anon,authenticated;
create index if not exists agc_contest_score_reviews_pending_idx on public.agc_contest_score_reviews(status,score_day,created_at);
create or replace function public.agc_request_contest_score_review(
 p_game_key text,p_day date,p_score integer,p_evidence_ref text)
returns uuid language plpgsql security definer set search_path='' as $fn$
declare me uuid:=auth.uid(); rid uuid; today_pl date:=(now() at time zone 'Europe/Warsaw')::date;
begin
 if me is null or not exists(select 1 from auth.users where id=me and not is_anonymous) then
   raise exception 'Verified player account required';
 end if;
 if p_game_key is null or p_game_key not in ('signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals')
 or p_day is null or p_day<today_pl-7 or p_day>today_pl or p_score is null or p_score<1 or p_score>10000000
 or p_evidence_ref is null or char_length(trim(p_evidence_ref)) not between 1 and 500 then
   raise exception 'Invalid review request';
 end if;
 if not exists(select 1 from public.agc_daily_scores d where d.member_id=me and d.game_key=p_game_key and d.score_day=p_day and d.best_score>=p_score) then
   raise exception 'No matching recorded daily score';
 end if;
 if (select count(*) from public.agc_contest_score_reviews c where c.member_id=me and c.created_at>now()-interval '24 hours')>=10 then
   raise exception 'Review request rate limit reached';
 end if;
 insert into public.agc_contest_score_reviews(member_id,game_key,score_day,claimed_score,evidence_ref)
 values(me,p_game_key,p_day,p_score,trim(p_evidence_ref))
 on conflict(member_id,game_key,score_day,claimed_score) do nothing returning id into rid;
 if rid is null then
   select id into rid from public.agc_contest_score_reviews
   where member_id=me and game_key=p_game_key and score_day=p_day and claimed_score=p_score;
 end if;
 return rid;
end $fn$;
revoke all on function public.agc_request_contest_score_review(text,date,integer,text) from public,anon;
grant execute on function public.agc_request_contest_score_review(text,date,integer,text) to authenticated;
revoke insert,update,delete on public.agc_verified_daily_scores from anon,authenticated;
