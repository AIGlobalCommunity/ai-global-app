-- AGC Genesis v1. Real account identities live in Supabase Auth.
-- Apply through Supabase SQL editor or migration CLI after reviewing policies.
create extension if not exists pgcrypto;

create table public.agc_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  handle text not null unique check (length(handle) between 3 and 40),
  referral_code text not null unique,
  country_code text,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false
);

create table public.agc_referrals (
  invited_id uuid primary key references public.agc_profiles(id) on delete cascade,
  inviter_id uuid not null references public.agc_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  rewarded_at timestamptz,
  check (invited_id <> inviter_id)
);

create table public.agc_points (
  id bigint generated always as identity primary key,
  member_id uuid not null references public.agc_profiles(id) on delete cascade,
  points integer not null check (points > 0 and points <= 10000),
  reason text not null check (reason in ('signup','verified_referral','event','consultation','contribution')),
  source_key text not null unique,
  created_at timestamptz not null default now()
);
create index agc_points_member_idx on public.agc_points(member_id);
create index agc_points_date_idx on public.agc_points(created_at);
create index agc_referrals_inviter_idx on public.agc_referrals(inviter_id);

-- Secure signup: user names are assigned automatically, and cannot be forged.
create or replace function public.agc_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  nickname text;
begin
  nickname := 'Genesis_' || replace(new.id::text, '-', '');
  insert into public.agc_profiles (id, handle, referral_code)
  values (new.id, nickname, upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)));
  insert into public.agc_points(member_id, points, reason, source_key)
  values(new.id, 100, 'signup', 'signup:' || new.id::text);
  return new;
end;
$$;

create trigger agc_user_created
after insert on auth.users
for each row execute function public.agc_new_user();

-- Anonymous viewers may see pseudonyms and aggregate scores, never emails or payments.
alter table public.agc_profiles enable row level security;
alter table public.agc_referrals enable row level security;
alter table public.agc_points enable row level security;

create policy agc_own_profile on public.agc_profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy agc_own_referrals on public.agc_referrals
  for select to authenticated using (auth.uid() = invited_id or auth.uid() = inviter_id);
create policy agc_own_points on public.agc_points
  for select to authenticated using (auth.uid() = member_id);

-- Only authenticated members may read their own profile and private referral code.
revoke all on public.agc_profiles from anon, authenticated;
grant select on public.agc_profiles to authenticated;
grant select on public.agc_points to authenticated;
grant select on public.agc_referrals to authenticated;

-- Profile update is intentionally disabled in v1 until a safe editable-profile API exists.
-- Points are server-owned; clients MUST NOT have INSERT/UPDATE/DELETE permissions.
revoke insert, update, delete on public.agc_profiles from anon, authenticated;
revoke insert, update, delete on public.agc_referrals from anon, authenticated;
revoke insert, update, delete on public.agc_points from anon, authenticated;

-- A referral is credited at most once and only after the referee confirms email.
-- Inviter gets +100 GP, referee retains their +100 signup GP.
create or replace function public.agc_claim_invite(code text)
returns boolean language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := auth.uid();
  inviter uuid;
  confirmed boolean;
begin
  if me is null then raise exception 'Sign in required'; end if;
  select (u.email_confirmed_at is not null) into confirmed from auth.users u where u.id = me;
  if confirmed is distinct from true then raise exception 'Verify your email first'; end if;
  select p.id into inviter from public.agc_profiles p where p.referral_code = upper(trim(code));
  if inviter is null or inviter = me then return false; end if;
  insert into public.agc_referrals(invited_id, inviter_id, rewarded_at)
    values (me, inviter, now())
    on conflict (invited_id) do nothing;
  if not found then return false; end if;
  insert into public.agc_points(member_id, points, reason, source_key)
    values(inviter, 100, 'verified_referral', 'referral:' || me::text);
  return true;
end;
$$;
revoke all on function public.agc_claim_invite(text) from public;
grant execute on function public.agc_claim_invite(text) to authenticated;

-- Contributions and events must be entered by a trusted server after validation.
-- This SQL function is NOT executable by end-users. Contribution limit: 200 GP per calendar month.
create or replace function public.agc_credit_points(
  target_id uuid, kind text, amount integer, unique_key text
) returns void language plpgsql security definer set search_path = ''
as $$
declare
  current_month_total integer;
begin
  if auth.role() <> 'service_role' then raise exception 'Server-only action'; end if;
  if kind not in ('event','consultation','contribution') or amount <= 0 then
    raise exception 'Invalid credit';
  end if;
  if kind = 'contribution' then
    perform pg_advisory_xact_lock(hashtext(target_id::text || 'contribution'));
    select coalesce(sum(points), 0) into current_month_total
    from public.agc_points
    where member_id = target_id and reason = 'contribution'
      and date_trunc('month', created_at at time zone 'UTC') =
          date_trunc('month', now() at time zone 'UTC');
    if current_month_total + amount > 200 then raise exception 'Monthly points cap exceeded'; end if;
  end if;
  insert into public.agc_points(member_id, points, reason, source_key)
    values(target_id, amount, kind, unique_key)
    on conflict (source_key) do nothing;
end;
$$;
revoke all on function public.agc_credit_points(uuid,text,integer,text) from public, anon, authenticated;
grant execute on function public.agc_credit_points(uuid,text,integer,text) to service_role;

-- Owner-executed view is intentionally SECURITY DEFINER to expose only
-- approved public leaderboard columns and aggregate points. Review ownership.
create or replace view public.agc_leaderboard as
select p.id, p.handle, p.country_code, p.created_at,
       coalesce(sum(e.points), 0)::bigint as genesis_points,
       row_number() over (
         order by coalesce(sum(e.points), 0) desc, p.created_at asc, p.id asc
       )::bigint as place
from public.agc_profiles p
left join public.agc_points e on e.member_id = p.id
where p.is_demo = false
group by p.id, p.handle, p.country_code, p.created_at;
grant select on public.agc_leaderboard to anon, authenticated;

-- Demo members are in an isolated table: never count toward live awards.
create table public.agc_demo_members (
  id integer primary key,
  handle text not null unique,
  country_code text not null,
  genesis_points integer not null check (genesis_points >= 0),
  is_demo boolean not null default true check (is_demo = true)
);
alter table public.agc_demo_members enable row level security;
create policy agc_read_demo on public.agc_demo_members for select using (true);
grant select on public.agc_demo_members to anon, authenticated;
revoke insert, update, delete on public.agc_demo_members from anon, authenticated;

create or replace view public.agc_demo_leaderboard with (security_invoker = true) as
select id, handle, country_code, genesis_points, true as is_demo,
       row_number() over (order by genesis_points desc, id asc)::bigint as place
from public.agc_demo_members;
grant select on public.agc_demo_leaderboard to anon, authenticated;

comment on table public.agc_demo_members is
  'FICTIONAL TEST RECORDS. Never include in real rankings, revenue, or user counts.';
