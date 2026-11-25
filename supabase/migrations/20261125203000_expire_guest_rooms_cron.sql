-- Expire abandoned anonymous game lobbies after 45 minutes and playing rooms after 2 hours without activity.
-- No registered account rooms are affected. Existing join credentials are revoked only for ended rooms.
create or replace function public.agc_expire_guest_rooms()
returns integer language plpgsql security definer set search_path='' as $$
declare v_total integer:=0; v_n integer; v_game text; v_table text;
begin
 for v_game,v_table in
  select * from (values
   ('duck','agc_duck_rooms'),
   ('hearts','agc_hearts_rooms'),
   ('blackjack','agc_blackjack_rooms')
  ) as x(game_name,table_name)
 loop
  execute format(
   'with ended as (
     update public.%I
     set status=''finished'',updated_at=now()
     where guest_host and (
      (status=''lobby'' and updated_at<now()-interval ''45 minutes'')
      or (status=''playing'' and updated_at<now()-interval ''2 hours'')
     )
     returning id
    )
    update public.agc_game_invite_links l
    set revoked=true
    from ended where l.game=$1 and l.room_id=ended.id',
    v_table
  ) using v_game;
  execute format(
   'with ended as (
     update public.%I
     set status=''finished'',updated_at=now()
     where guest_host and (
      (status=''lobby'' and updated_at<now()-interval ''45 minutes'')
      or (status=''playing'' and updated_at<now()-interval ''2 hours'')
     )
     returning id
    )
    select count(*) from ended',
    v_table
  ) into v_n;
  v_total:=v_total+coalesce(v_n,0);
 end loop;
 delete from public.agc_multiplayer_rate_events where created_at<now()-interval '2 days';
 return v_total;
end $$;
revoke all on function public.agc_expire_guest_rooms() from public,anon,authenticated;
grant execute on function public.agc_expire_guest_rooms() to service_role;

-- Supabase Cron (pg_cron) drives eviction independent of user traffic.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('agc_multiplayer_guest_cleanup_5min','*/5 * * * *',
 'select public.agc_expire_guest_rooms()');
