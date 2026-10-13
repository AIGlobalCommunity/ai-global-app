# AGC Supabase setup

**Supabase project created and migrations deployed on 2026-10-13.**
Project: `gjnddmurmegbklvedhnp` in Frankfurt (`eu-central-1`).
API URL: `https://gjnddmurmegbklvedhnp.supabase.co`.
The 120 clearly labeled fictional accounts are already seeded in `agc_demo_members`.
No real member accounts or payment transactions have been created.
For additional environments, follow the setup steps below.

1. Create your own Supabase project at https://supabase.com/dashboard.
2. Open SQL Editor. Run `migrations/202610130001_genesis.sql`, then `migrations/202610130002_secure_rankings.sql`, then `seed_demo.sql` **only for development**.
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

## Deployment notes (2026-10-13)

Supabase region Frankfurt, active project. Verified: 120 demo records, 120 demo leaderboard rows, zero real members.
Security Advisor: one remaining intentional warning for authenticated users calling the
`SECURITY DEFINER` referral-claim RPC. The function checks `auth.uid()`, email verification,
self-referral and single redemption. This must receive a separate prelaunch security review.
The public leaderboard reads a restricted public scores table with RLS; private codes
remain visible only to their owner. All trigger functions are denied to the API roles.

**Run Flutter against this project** using its URL and the public publishable key
in `--dart-define` configuration (not a service key). Configuration is not yet
committed to app binaries. Review the CI build and authorization flows before launch.

## Flutter integration completed

The Flutter client contains this project's **public** Supabase URL and publishable key as development defaults. No secret key is shipped. Override the public settings with `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` if switching environments. `main()` initializes Supabase; widget tests without initialization display the demo fallback.

### Validated database-only transaction test

On 2026-10-13, two temporary `auth.users` records were inserted inside a transaction, both received 100 GP, a verified referral gave the inviter another 100 GP, and claiming the same invitation again gave 0 additional GP. The transaction was **ROLLED BACK**: verified afterward that there were 0 persisted auth users, profiles and referrals, and still 120 isolated DEMO profiles. This validates SQL logic but **not** a full live email-verification or mobile authentication flow. Before production, create a real test account using a controlled inbox, verify it through Supabase Auth, and test one real referral end-to-end.

### Status

Pull Request #2 is intentionally a draft stacked on PR #1. CI is being exercised; only merge after all jobs pass. Verify security and abuse resistance before admitting real public registrations.
