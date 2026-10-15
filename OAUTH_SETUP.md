# Logowanie Google / Facebook dla AI Global Community

Status: **interfejs i klient OAuth zaimplementowane dla Flutter Web**, ale **nieaktywowana jeszcze konfiguracja dostawców po stronie Supabase**. Nie twórz fałszywych przycisków ani nie deklaruj, że logowanie działa bez skonfigurowanych OAuth Client IDs i Secrets.

## Wspólne ustawienia

W projekcie Supabase `gjnddmurmegbklvedhnp`:
- [Authentication → URL Configuration](https://supabase.com/dashboard/project/gjnddmurmegbklvedhnp/auth/url-configuration): Site URL = `https://aiglobalcommunity.github.io/ai-global-app/`
- Redirect URLs: `https://aiglobalcommunity.github.io/ai-global-app/`
- OAuth callback dostawców: `https://gjnddmurmegbklvedhnp.supabase.co/auth/v1/callback`
- [Authentication → Providers](https://supabase.com/dashboard/project/gjnddmurmegbklvedhnp/auth/providers): włączyć Google i Facebook dopiero po skonfigurowaniu aplikacji u dostawców.

## Google

1. Otwórz [Google Auth Platform](https://console.cloud.google.com/auth/overview), utwórz aplikację OAuth (Web application) i skonfiguruj ekran zgody oraz odbiorców.
2. Authorized JavaScript origin: `https://aiglobalcommunity.github.io`.
3. Authorized redirect URI: `https://gjnddmurmegbklvedhnp.supabase.co/auth/v1/callback`.
4. Zapisz wygenerowany **Client ID** i **Client Secret** w panelu Supabase → Authentication → Providers → Google. **Sekretu nie wpisuj do kodu Flutter/GitHuba i nie przesyłaj w czacie.**
5. Dodaj użytkowników testowych, jeśli aplikacja Google jest jeszcze w trybie testowym.

## Facebook (Meta)

1. Utwórz aplikację w [Meta for Developers](https://developers.facebook.com/apps/), dodaj Facebook Login, skonfiguruj uprawnienie e-mail.
2. W Valid OAuth Redirect URIs ustaw `https://gjnddmurmegbklvedhnp.supabase.co/auth/v1/callback`; skonfiguruj domeny aplikacji zgodnie z wymaganiami Meta.
3. App ID i App Secret wprowadź **bezpośrednio** w Supabase → Authentication → Providers → Facebook.
4. Dopóki Meta wymaga trybu deweloperskiego, mogą zalogować się tylko testerzy i role aplikacji. Do otwartego dostępu konieczny jest właściwy tryb i ewentualna weryfikacja.

## Zachowanie aplikacji

- Google i Facebook używają `Supabase.auth.signInWithOAuth` i wracają na GitHub Pages.
- Nowe konto OAuth uruchamia istniejący trigger `agc_new_user` w Supabase. Automatycznie generowany jest unikalny nick `Genesis_<UUID>`, referral code i 100 GP. **Wybór własnego nicku po OAuth to osobna przyszła funkcja**; rejestracja e-mail/hasło nadal wymaga podania nicku.
- Na iOS/Android logowanie przez OAuth wymaga skonfigurowania deep link / redirect URIs w aplikacjach natywnych — obecna implementacja wspiera web (Safari/Chrome).
- Nie dodawaj service-role ani OAuth Client Secret do publicznego projektu.
- Dopiero po testach na realnych kontach Google i Meta ogłaszaj dostępność tej formy logowania.

Dokumentacja: https://supabase.com/docs/guides/auth/social-login/auth-google , https://supabase.com/docs/guides/auth/social-login/auth-facebook oraz https://supabase.com/docs/reference/dart/auth-signinwithoauth
