create or replace function public.agc_track_unverified_card_score() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.game_key in ('solitaire','freecell','spider') and (tg_op='INSERT' or new.best_score>old.best_score) then
  insert into public.agc_card_score_verification(member_id,game_key,claimed_score,claimed_level,verification_status)
  values(new.member_id,new.game_key,new.best_score,new.best_level,'unverified');
 end if;
 return new;
end;
$$;
drop trigger if exists agc_track_unverified_card_score_trigger on public.agc_game_scores;
create trigger agc_track_unverified_card_score_trigger after insert or update of best_score on public.agc_game_scores
for each row execute function public.agc_track_unverified_card_score();
create or replace view public.agc_verified_card_contest_scores with (security_invoker=true) as
select member_id,game_key,max(claimed_score) as verified_best_score
from public.agc_card_score_verification
where verification_status='verified'
group by member_id,game_key;
comment on view public.agc_verified_card_contest_scores is 'Contest-safe verified card scores only; no score qualifies without explicit verification.';
