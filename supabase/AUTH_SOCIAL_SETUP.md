# Google + Facebook sign-in — THE GENESIS ERA

Production site: https://thegenesisera.com/
Supabase project: gjnddmurmegbklvedhnp

The Flutter app already calls `Supabase.auth.signInWithOAuth` for both providers. A first successful OAuth sign-in creates a Genesis member through the `agc_new_user` database trigger. New members have public nicknames by default; explicit opt-out during email sign-up remains respected.

## 1. Supabase URL configuration
Open https://supabase.com/dashboard/project/gjnddmurmegbklvedhnp/auth/url-configuration

- **Site URL:** `https://thegenesisera.com/`
- **Redirect URLs:** add `https://thegenesisera.com/**`
- Keep any existing URLs needed for testing.

## 2. Callback URL for BOTH providers

`https://gjnddmurmegbklvedhnp.supabase.co/auth/v1/callback`

This is the **Supabase Auth** callback, not the website URL.

## 3. Google

1. Open https://console.cloud.google.com/apis/credentials and select/create a Google Cloud project.
2. Configure the Google Auth Platform consent/branding screen for an external app and its allowed audience.
3. Create an OAuth client of type **Web application**.
4. Add the callback URL above under **Authorized redirect URIs**. Add `https://thegenesisera.com` under authorized JavaScript origins if the console requires it.
5. In Supabase **Authentication → Sign In / Providers → Google**, enable Google and paste the client ID and secret.
6. Publish the consent screen or configure test users before trying an account that is not an administrator.

## 4. Facebook (Meta)

1. Open https://developers.facebook.com/apps/ and create a Meta app supporting **Facebook Login**.
2. In Facebook Login settings, add the Supabase callback URL above under **Valid OAuth Redirect URIs**.
3. Configure the `email` permission (Supabase requires a usable email address).
4. In Supabase **Authentication → Sign In / Providers → Facebook**, enable Facebook and paste the Meta App ID and App Secret.
5. Complete Meta's required app configuration and switch the app to Live when ready for public users.

## 5. Verify

- Open https://thegenesisera.com in a private browser window.
- Click **Continue with Google** and sign in. Confirm you return to THE GENESIS ERA and see the authenticated member area.
- Sign out; repeat with **Continue with Facebook**.
- Confirm a new member profile has a short generated `Genesis_...` nickname and public visibility.
- Confirm email sign-up defaults to a checked public nickname checkbox, but unchecking it still saves a private nickname.

**Security:** Never put Google client secrets or Facebook App Secrets into Flutter code, GitHub, screenshots, or chat messages. Enter them directly into Supabase provider settings.

Reference: https://supabase.com/docs/guides/auth/social-login/auth-facebook
