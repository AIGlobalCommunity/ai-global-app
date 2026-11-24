create table public.agc_game_favorites(user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,game_key text not null check(game_key in ('signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals','solitaire','freecell','spider','hearts','blackjack','duck')),created_at timestamptz not null default now(),primary key(user_id,game_key));
alter table public.agc_game_favorites enable row level security;
revoke all on public.agc_game_favorites from public,anon,authenticated;
grant select,insert,delete on public.agc_game_favorites to authenticated;
create policy favorites_read on public.agc_game_favorites for select to authenticated using ((select auth.uid())=user_id and not coalesce((select (auth.jwt()->>'is_anonymous')::boolean),false));
create policy favorites_insert on public.agc_game_favorites for insert to authenticated with check ((select auth.uid())=user_id and not coalesce((select (auth.jwt()->>'is_anonymous')::boolean),false));
create policy favorites_delete on public.agc_game_favorites for delete to authenticated using ((select auth.uid())=user_id and not coalesce((select (auth.jwt()->>'is_anonymous')::boolean),false));