-- Development-only seed, explicitly fictional. NEVER add to production live member totals.
-- Run after migration; repeatable. To purge: TRUNCATE public.agc_demo_members;
insert into public.agc_demo_members(id, handle, country_code, genesis_points)
select n,
       (array['Aurora','Nova','Signal','Quantum','Unity','Horizon','Orbit','Genesis',
              'Mind','Eclipse','Future','Echo'])[1 + ((n - 1) % 12)]
         || '_DEMO_' || lpad(n::text, 4, '0'),
       (array['PL','US','DE','FR','JP','BR','IN','GB','ES','CA'])[1 + ((n - 1) % 10)],
       (12000 - n * 61 + ((n * 19) % 47))
from generate_series(1, 120) as n
on conflict (id) do update
set handle = excluded.handle,
    country_code = excluded.country_code,
    genesis_points = excluded.genesis_points;
