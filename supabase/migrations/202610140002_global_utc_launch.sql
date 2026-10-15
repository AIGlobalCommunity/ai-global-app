update public.agc_launch_schedule
set official_launch_at = '2026-11-01 00:00:00+00'::timestamptz,
    manifesto_at = '2027-08-01 00:00:00+00'::timestamptz,
    genesis_end_at = '2029-11-01 00:00:00+00'::timestamptz,
    updated_at = now()
where id=1;
comment on column public.agc_launch_schedule.official_launch_at is 'Official AGC launch 2026-11-01 00:00 UTC, global reference time';
comment on column public.agc_launch_schedule.manifesto_at is 'Manifesto 2027-08-01 00:00 UTC';
comment on column public.agc_launch_schedule.genesis_end_at is 'Genesis era ends 2029-11-01 00:00 UTC';