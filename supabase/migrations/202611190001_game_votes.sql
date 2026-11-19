create table public.agc_game_votes (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  game text not null check (game in ('signal','defender','wolf','blocks','snake')),
  positive boolean not null,
  primary key (user_id, game)
);
alter table public.agc_game_votes enable row level security;
revoke all on public.agc_game_votes from public, anon, authenticated;
grant select, insert, update (positive) on public.agc_game_votes to authenticated;
create policy own_game_votes on public.agc_game_votes to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create function public.agc_rate_game(p_game text, p_positive boolean)
returns void language sql security invoker set search_path = '' as $$
  insert into public.agc_game_votes(game, positive) values (p_game, p_positive)
  on conflict (user_id, game) do update set positive = excluded.positive;
$$;
revoke all on function public.agc_rate_game(text, boolean) from public, anon;
grant execute on function public.agc_rate_game(text, boolean) to authenticated;

create function public.agc_game_ratings()
returns table(game text, likes bigint, dislikes bigint, mine boolean)
language sql stable security definer set search_path = '' as $$
  select v.game, count(*) filter(where v.positive), count(*) filter(where not v.positive),
    bool_or(v.positive) filter(where v.user_id = (select auth.uid()))
  from public.agc_game_votes v group by v.game;
$$;
revoke all on function public.agc_game_ratings() from public;
grant execute on function public.agc_game_ratings() to anon, authenticated;
