create table public.agc_launch_schedule (
  id integer primary key default 1 check (id = 1),
  official_launch_at timestamptz,
  updated_at timestamptz not null default now()
);
insert into public.agc_launch_schedule (id, official_launch_at) values (1, null);
alter table public.agc_launch_schedule enable row level security;
create policy agc_read_launch_schedule on public.agc_launch_schedule
 for select to anon, authenticated using (true);
revoke all on public.agc_launch_schedule from anon, authenticated;
grant select on public.agc_launch_schedule to anon, authenticated;
comment on column public.agc_launch_schedule.official_launch_at is
  'NULL until founder announces official AGC start; do not display a fake countdown.';
