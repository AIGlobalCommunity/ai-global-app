# AGC: gated community + login configuration

Production project: `gjnddmurmegbklvedhnp`, `https://gjnddmurmegbklvedhnp.supabase.co`.

## Login-only site

The Flutter web app displays a sign-in/sign-up page until Supabase Auth has an active session. After login, Genesis, ranking, member account and local simulator become visible. Logged-out users cannot reach these Flutter pages, and Supabase RLS/GRANTs deny their anonymous requests for member rankings. **GitHub Pages itself is public**: landing/login HTML, bundle, images and open-source repository remain visible. It is NOT private hosting.

## REQUIRED: email confirmation redirects

In [Supabase Authentication URL Configuration](https://supabase.com/dashboard/project/gjnddmurmegbklvedhnp/auth/url-configuration):

1. Set **Site URL** to `https://aiglobalcommunity.github.io/ai-global-app/`.
2. Add **Redirect URL** `https://aiglobalcommunity.github.io/ai-global-app/`.
3. In Authentication → Providers → Email, leave **Confirm email** enabled.
4. Register using an inbox you control. Confirm email from the email link, return to the web app and sign in.

Without the first two settings, email confirmation may redirect incorrectly. Do not turn off email confirmation to work around it.

## Security and release notes

- Public demo leaderboard contains fictional/test profiles and is labeled DEMO.
- Demo and real rank endpoints now require authenticated JWTs; anonymous SELECT privileges have been removed.
- Sign-up is available to visitors solely from the gated entrance. Add bot protection (captcha), rate limiting, privacy policy and updated account abuse checks before advertising public enrollment.
- Auth session state is handled by a live listener; sign-out immediately returns to the login gate.
- The public Supabase publishable key in Flutter is not a secret. **Never** commit the service-role key.
- Prelaunch review still needed for referral-claim SECURITY DEFINER RPC and account verification.
