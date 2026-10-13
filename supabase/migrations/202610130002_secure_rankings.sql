-- Expose rankings through a restricted public score table, not a privileged view.
create table public.agc_public_scores (
  id uuid primary key references public.agc_profiles(id) on delete cascade,
  handle text not null,
  country_code text,
  created_at timestamptz not null,
  genesis_points bigint not null default 0 check (genesis_points >= 0)
);
alter table public.agc_public_scores enable row level security;
create policy agc_public_scores_read on public.agc_public_scores
  for select to anon, authenticated using (true);
grant select on public.agc_public_scores to anon, authenticated;
revoke insert, update, delete on public.agc_public_scores from anon, authenticated;
insert into public.agc_public_scores(id,handle,country_code,created_at,genesis_points)
select p.id,p.handle,p.country_code,p.created_at,coalesce(sum(a.points),0)
from public.agc_profiles p left join public.agc_points a on a.member_id=p.id
where not p.is_demo
group by p.id,p.handle,p.country_code,p.created_at;

create function public.agc_score_new_profile()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if not new.is_demo then
    insert into public.agc_public_scores(id,handle,country_code,created_at)
    values(new.id,new.handle,new.country_code,new.created_at);
  end if;
  return new;
end; $$;
create trigger agc_profile_to_scores after insert on public.agc_profiles
  for each row execute function public.agc_score_new_profile();

create function public.agc_score_point_insert()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  update public.agc_public_scores set genesis_points=genesis_points+new.points
  where id=new.member_id;
  return new;
end; $$;
create trigger agc_points_to_scores after insert on public.agc_points
  for each row execute function public.agc_score_point_insert();

create function public.agc_score_point_delete()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  update public.agc_public_scores set genesis_points=genesis_points-old.points
  where id=old.member_id;
  return old;
end; $$;
create trigger agc_points_scores_delete after delete on public.agc_points
  for each row execute function public.agc_score_point_delete();

create or replace view public.agc_leaderboard with (security_invoker=true) as
select id,handle,country_code,created_at,genesis_points,
  row_number() over (order by genesis_points desc,created_at asc,id asc)::bigint as place
from public.agc_public_scores;
grant select on public.agc_leaderboard to anon,authenticated;

revoke all on function public.agc_new_user() from public,anon,authenticated;
revoke all on function public.agc_score_new_profile() from public,anon,authenticated;
revoke all on function public.agc_score_point_insert() from public,anon,authenticated;
revoke all on function public.agc_score_point_delete() from public,anon,authenticated;
revoke all on function public.agc_claim_invite(text) from public,anon;
grant execute on function public.agc_claim_invite(text) to authenticated;
