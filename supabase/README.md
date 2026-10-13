# AGC Supabase setup

**No production database has been provisioned or populated by this PR.**
These are SQL migration and removable, clearly labeled sample data.

1. Create your own Supabase project at https://supabase.com/dashboard.
2. Open SQL Editor. Run `migrations/202610130001_genesis.sql` then `seed_demo.sql` **only for development**.
3. Supabase project URL and **anon/publishable key** may be supplied to Flutter with
   `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...`.
   NEVER place the service-role key in Flutter, Git, or a client app.
4. In Authentication, enable email verification to ensure referral credits only occur
   for confirmed accounts. Configure email provider and anti-abuse/rate limits.
5. Demo cleanup: `TRUNCATE public.agc_demo_members;` (not auth.users and not real profiles).
6. Database tables `agc_profiles`, `agc_points` and `agc_referrals` are separate
   from fictional `agc_demo_members`. `agc_leaderboard` excludes demo accounts.
7. Contributions are *not* accepted by this code. Only your future verified payment
   webhook may call `agc_credit_points` as service role, within legal/payment rules.

### Auth and referrals
- Supabase Auth provisions profile + 100 GP signup points through trigger.
- After email verification, signed-in member calls
  `supabase.rpc('agc_claim_invite', params: {'code': 'XXXXXX'})`.
- Referrer receives 100 GP once per verified new account.
- Member referral codes live in `agc_profiles.referral_code`.
- Public live ranking: `agc_leaderboard`, demo: `agc_demo_leaderboard`.

### Important launch restrictions
- Current AGC points are prestige only, not monetary assets.
- Don't launch referrals without abuse controls (rate limiting, fake-account detection).
- No claim of real users, real donations, or real ranking activity while showing demo.
- Revisit privacy, GDPR retention, and payment legality before public registration.
