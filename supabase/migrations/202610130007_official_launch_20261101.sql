alter table public.agc_launch_schedule
  add column if not exists manifesto_at timestamptz,
  add column if not exists genesis_end_at timestamptz;
update public.agc_launch_schedule
set official_launch_at = ('2026-11-01 00:00:00'::timestamp at time zone 'Europe/Warsaw'),
    manifesto_at = ('2027-08-01 00:00:00'::timestamp at time zone 'Europe/Warsaw'),
    genesis_end_at = ('2029-11-01 00:00:00'::timestamp at time zone 'Europe/Warsaw'),
    updated_at = now()
where id = 1;
comment on column public.agc_launch_schedule.manifesto_at is 'Manifesto announcement 9 calendar months after 2026-11-01 Warsaw start.';
comment on column public.agc_launch_schedule.genesis_end_at is 'Genesis 36-calendar-month endpoint, 2029-11-01 00:00 Europe/Warsaw.';
