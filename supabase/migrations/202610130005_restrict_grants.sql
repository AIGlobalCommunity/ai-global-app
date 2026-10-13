-- Lock down all privileges on members-only leaderboard API objects.
revoke all privileges on public.agc_public_scores from anon, authenticated;
revoke all privileges on public.agc_demo_members from anon, authenticated;
revoke all privileges on public.agc_leaderboard from anon, authenticated;
revoke all privileges on public.agc_demo_leaderboard from anon, authenticated;
grant select on public.agc_public_scores, public.agc_demo_members,
  public.agc_leaderboard, public.agc_demo_leaderboard to authenticated;
