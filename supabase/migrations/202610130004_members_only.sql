-- AGC members-only read access, independent of the Flutter screen gate.
revoke select on public.agc_public_scores from anon;
revoke select on public.agc_leaderboard from anon;
revoke select on public.agc_demo_members from anon;
revoke select on public.agc_demo_leaderboard from anon;
drop policy if exists agc_public_scores_read on public.agc_public_scores;
create policy agc_members_scores_read on public.agc_public_scores for select to authenticated using ((select auth.uid()) is not null);
drop policy if exists agc_read_demo on public.agc_demo_members;
create policy agc_members_demo_read on public.agc_demo_members for select to authenticated using ((select auth.uid()) is not null);
grant select on public.agc_public_scores, public.agc_leaderboard,
  public.agc_demo_members, public.agc_demo_leaderboard to authenticated;
